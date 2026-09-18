// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IERC20 } from "../../../lib/diamond-pau/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { IAccessControls }                           from "../../../lib/diamond-pau/src/interfaces/IAccessControls.sol";
import { IALMProxy }                                 from "../../../lib/diamond-pau/src/interfaces/IALMProxy.sol";
import { IBeacon }                                   from "../../../lib/diamond-pau/src/interfaces/IBeacon.sol";
import { IPAUFactory }                               from "../../../lib/diamond-pau/src/interfaces/IPAUFactory.sol";
import { IRateLimits }                               from "../../../lib/diamond-pau/src/interfaces/IRateLimits.sol";
import { IMainnetControllerFull as IControllerFull } from "../../../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

import { Beacon }     from "../../../lib/diamond-pau/src/Beacon.sol";
import { PAUFactory } from "../../../lib/diamond-pau/src/PAUFactory.sol";
import { CCTPFacet }  from "../../../lib/diamond-pau/src/facets/cctp/CCTPFacet.sol";

import { AdministeredAgent }         from "../../../lib/pau-administered-agent/src/AdministeredAgent.sol";
import { AdministeredAgentFactory }  from "../../../lib/pau-administered-agent/src/AdministeredAgentFactory.sol";
import { IAdministeredAgent }        from "../../../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";
import { IAdministeredAgentFactory } from "../../../lib/pau-administered-agent/src/interfaces/IAdministeredAgentFactory.sol";

import { Arbitrum } from "../../../lib/spark-address-registry/src/Arbitrum.sol";
import { Ethereum } from "../../../lib/spark-address-registry/src/Ethereum.sol";

import { BeaconConfig }    from "../../../src/BeaconConfig.sol";
import { InitParallelPAU } from "../../../src/InitParallelPAU.sol";

import { ArbitrumPostDeployTestsBase } from "./PostDeployTests.t.sol";

/**
 * @notice Runs the exact production code path (the two parallel-controller scripts) on an
 *         Arbitrum fork as the deployer, asserts the same end state the post-deploy test
 *         checks, then simulates the governance spell and pushes a real CCTP V2 burn through
 *         the new controller to prove the Arbitrum -> Ethereum route works.
 *
 *         Script 0 (deploy): deploys Beacon (admin-owned), PAUFactory, AgentFactory, CCTPFacet,
 *                            AccessControls, RateLimits, Controller, AdministeredAgent.
 *         Script 1 (configure): wires CCTP on Beacon, calls InitParallelPAU.initParallelPAU,
 *                               then _transferAdminRoles (grants beacon to admin, revokes deployer
 *                               from Beacon/AccessControls/RateLimits/AdministeredAgent).
 */
abstract contract ArbitrumParallelE2ETestsBase is ArbitrumPostDeployTestsBase {

    address internal constant DEPLOYER = 0xC758519Ace14E884fdbA9ccE25F2DbE81b7e136f;

    address internal ethereumAlmProxy;
    uint32  internal ethereumDomainId;

    function setUp() public virtual override {
        super.setUp();

        vm.createSelectFork(getChain("arbitrum_one").rpcUrl);

        admin    = Arbitrum.SPARK_EXECUTOR;
        deployer = DEPLOYER;
        relayer  = Arbitrum.ALM_RELAYER_MULTISIG;
        freezer  = Arbitrum.ALM_FREEZER_MULTISIG;
        grantor  = 0x4B61A0E48dd1e300f64090C60F414c1aC6CbC514; // TODO add in registry

        almProxy           = IALMProxy(Arbitrum.ALM_PROXY);
        legacyController   = Arbitrum.ALM_CONTROLLER;
        cctpTokenMessenger = Arbitrum.CCTP_TOKEN_MESSENGER;
        usdc               = Arbitrum.USDC;
        ethereumAlmProxy   = Ethereum.ALM_PROXY;
        ethereumDomainId   = 0;
    }

    function _assertFacetConstructors() internal view override {
        assertEq(CCTPFacet(cctpFacet).cctp(), cctpTokenMessenger);
        assertEq(CCTPFacet(cctpFacet).usdc(), usdc);
    }

    /**********************************************************************************************/
    /*** Guard rails                                                                            ***/
    /**********************************************************************************************/

    /// @dev Before the spell the controller can be called but cannot move anything — no
    ///      CONTROLLER role on the proxy and no rate limits. Rate limits fail closed first.
    function test_transferRevertsBeforeSpell() external {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        administeredAgent.call(
            address(controller),
            abi.encodeCall(controller.cctp_transfer, (1e6, ethereumDomainId, 0))
        );
    }

    /// @dev Only the AdministeredAgent holds ALLOCATOR_ROLE. A relayer calling the controller
    ///      directly is rejected by the onlyRole guard.
    function test_relayerCannotCallControllerDirectly() external {
        vm.expectRevert();
        vm.prank(relayer);
        controller.cctp_transfer(1e6, ethereumDomainId, 0);
    }

    /// @dev The deployer retains no authority anywhere after configure.
    function test_deployerCannotAdministerAfterConfigure() external {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = BeaconConfig.CCTP_INTEGRATION;

        vm.startPrank(deployer);

        vm.expectRevert();
        controller.removeIntegrations(ids);

        vm.expectRevert();
        beacon.revokeRole(DEFAULT_ADMIN_ROLE, admin);

        vm.expectRevert();
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE, admin);

        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** Simulated spell + live CCTP V2 burn                                                    ***/
    /**********************************************************************************************/

    /// @dev The spell grants CONTROLLER on the existing ALMProxy and sets the two CCTP rate
    ///      limits. After that a relayer can bridge USDC to the Spark Ethereum ALMProxy through
    ///      Circle's TokenMessengerV2, and the legacy controller is unaffected.
    function test_spellThenCCTPTransfer() external {
        uint256 maxAmount = 10_000_000e6;
        uint256 slope     = uint256(50_000_000e6) / 1 days;

        bytes32 totalKey  = controller.cctp_toCCTPRateLimitKey();
        bytes32 domainKey = controller.cctp_getToDomainRateLimitKey(ethereumDomainId);

        // --- Spell (Spark Executor is admin of the proxy, AccessControls, and the new RateLimits) ---

        vm.startPrank(Arbitrum.SPARK_EXECUTOR);

        // Spell action 1: Grant CONTROLLER on the existing ALMProxy.
        almProxy.grantRole(CONTROLLER_ROLE, address(controller));

        // Spell action 2: Configure Ethereum domain parameters (recipient = Ethereum ALMProxy).
        controller.cctp_setDomainParameters(
            ethereumDomainId,
            bytes32(uint256(uint160(ethereumAlmProxy))),
            0,  // minFeeCapRate: standard finality, fee-free
            0   // maxFeeCapRate: fee-free
        );

        // Spell action 3: Set CCTP rate limits on the new RateLimits contract.
        rateLimits.setRateLimitData(totalKey,  maxAmount, slope);
        rateLimits.setRateLimitData(domainKey, maxAmount, slope);

        vm.stopPrank();

        assertEq(almProxy.hasRole(CONTROLLER_ROLE, legacyController),    true);
        assertEq(almProxy.hasRole(CONTROLLER_ROLE, address(controller)), true);

        // --- Fund the proxy with idle USDC ---

        uint256 amount = 1_000_000e6;

        deal(usdc, address(almProxy), amount);

        uint256 usdcSupplyBefore = IERC20(usdc).totalSupply();

        // --- Relayer bridges through the AdministeredAgent ---

        vm.prank(relayer);
        administeredAgent.call(
            address(controller),
            abi.encodeCall(controller.cctp_transfer, (amount, ethereumDomainId, 0))
        );

        // USDC burned from the proxy, no leftover allowance, both limits consumed.
        assertEq(IERC20(usdc).balanceOf(address(almProxy)),                      0);
        assertEq(IERC20(usdc).allowance(address(almProxy), cctpTokenMessenger),  0);
        assertEq(IERC20(usdc).totalSupply(),                                      usdcSupplyBefore - amount);

        assertEq(rateLimits.getCurrentRateLimit(totalKey),  maxAmount - amount);
        assertEq(rateLimits.getCurrentRateLimit(domainKey), maxAmount - amount);

        // Over the remaining limit fails closed.
        deal(usdc, address(almProxy), maxAmount);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(relayer);
        administeredAgent.call(
            address(controller),
            abi.encodeCall(controller.cctp_transfer, (maxAmount, ethereumDomainId, 0))
        );

        // An unconfigured destination domain fails before hitting the proxy.
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        administeredAgent.call(
            address(controller),
            abi.encodeCall(controller.cctp_transfer, (1e6, 6, 0))
        );
    }

    /// @dev Kill switch: one admin transaction makes the CCTP facet unreachable; legacy
    ///      controller is untouched.
    function test_removeIntegrationIsKillSwitch() external {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = BeaconConfig.CCTP_INTEGRATION;

        vm.prank(admin);
        controller.removeIntegrations(ids);

        assertEq(controller.integrations().length, 0);

        vm.expectRevert();
        vm.prank(relayer);
        administeredAgent.call(
            address(controller),
            abi.encodeCall(controller.cctp_transfer, (1e6, ethereumDomainId, 0))
        );

        assertEq(almProxy.hasRole(CONTROLLER_ROLE, legacyController), true);
    }

}

contract ArbitrumParallelE2ETestLocal is ArbitrumParallelE2ETestsBase {

    function setUp() public override {
        super.setUp();

        vm.startPrank(deployer);
        _runDeployScript();
        _runConfigureScript();
        vm.stopPrank();
    }

    // Not running events tests in Local E2E tests.

    function test_beaconEvents() external override {}
    function test_administeredAgentEvents() external override {}
    function test_accessControlsEvents() external override {}
    function test_rateLimitsEvents() external override {}
    function test_controllerEvents() external override {}

    /**********************************************************************************************/
    /*** Script helpers                                                                         ***/
    /**********************************************************************************************/

    /// @dev Mirrors DeploySparkPAUParallelBase.run() + DeploySparkPAUParallelArbitrum._deployFacets().
    function _runDeployScript() internal {
        // deployer is the temporary initial admin of all four contracts;
        // configure script hands everything over to admin and revokes deployer.
        beacon       = new Beacon(deployer);
        pauFactory   = new PAUFactory(address(beacon));
        agentFactory = new AdministeredAgentFactory();

        cctpFacet = address(new CCTPFacet({
            cctp_ : cctpTokenMessenger,
            usdc_ : usdc
        }));

        accessControls    = IAccessControls(pauFactory.deployAccessControls(deployer));
        rateLimits        = IRateLimits(pauFactory.deployRateLimits(deployer));
        controller        = IControllerFull(pauFactory.deployController(address(accessControls), Arbitrum.ALM_PROXY, address(rateLimits)));
        administeredAgent = IAdministeredAgent(agentFactory.deploy(deployer));
    }

    /// @dev Mirrors ConfigureSparkPAUParallelBase.run() with ArbitrumStaging overrides.
    function _runConfigureScript() internal {
        // Step 1: Wire CCTP on Beacon.
        BeaconConfig.setCCTPIntegration(address(beacon), cctpFacet);

        // Step 2: Build InitParallelPAU params (mirrors _getAdminConfig + _getAgentConfigs).
        address[] memory accessControlAdmins = new address[](1);
        accessControlAdmins[0] = admin;

        address[] memory rateLimitsAdmins = new address[](1);
        rateLimitsAdmins[0] = admin;

        InitParallelPAU.AdminConfig memory adminConfig = InitParallelPAU.AdminConfig({
            accessControlAdmins : accessControlAdmins,
            rateLimitsAdmins    : rateLimitsAdmins
        });

        InitParallelPAU.AdministeredAgentConfig[] memory agentConfigs =
            _buildAgentConfigs();

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = BeaconConfig.CCTP_INTEGRATION;

        InitParallelPAU.initParallelPAU(address(controller), integrationIds, adminConfig, agentConfigs);

        // Step 3: _transferAdminRoles (mirrors ConfigureSparkPAUParallelBase._transferAdminRoles).
        beacon.grantRole(DEFAULT_ADMIN_ROLE, admin);

        beacon.revokeRole(DEFAULT_ADMIN_ROLE,         deployer);
        accessControls.revokeRole(DEFAULT_ADMIN_ROLE, deployer);
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE,     deployer);

        administeredAgent.removeAdmin(deployer);
    }

    function _buildAgentConfigs()
        internal
        view
        returns (InitParallelPAU.AdministeredAgentConfig[] memory agentConfigs)
    {
        address[] memory agentAdmins   = new address[](1);
        address[] memory agentActors   = new address[](1);
        address[] memory agentGrantors = new address[](1);
        address[] memory agentRevokers = new address[](1);

        agentAdmins[0]   = admin;
        agentActors[0]   = relayer;
        agentGrantors[0] = grantor;
        agentRevokers[0] = freezer;

        agentConfigs = new InitParallelPAU.AdministeredAgentConfig[](1);
        agentConfigs[0] = InitParallelPAU.AdministeredAgentConfig({
            agent    : address(administeredAgent),
            admins   : agentAdmins,
            actors   : agentActors,
            grantors : agentGrantors,
            revokers : agentRevokers
        });
    }

}


contract ArbitrumParallelE2ETestLive is ArbitrumParallelE2ETestsBase {

    function setUp() public override {
        super.setUp();

        beacon       = IBeacon(0x86036CE5d2f792367C0AA43164e688d13c5A60A8);
        pauFactory   = IPAUFactory(0x3968a022D955Bbb7927cc011A48601B65a33F346);
        agentFactory = IAdministeredAgentFactory(0xCBA0C0a2a0B6Bb11233ec4EA85C5bFfea33e724d);

        cctpFacet         = 0xeCCA0D296Cb133081d41E9772B60D57F5fd2798E;
        accessControls    = IAccessControls(0x8386f819860D54B1180539Ff4852E4CAECef8A1D);
        rateLimits        = IRateLimits(0x4824C4336a1a11979068A544958dCe5D49B42752);
        controller        = IControllerFull(0x04ACB9e9bbd64A425677edC535D6B30cfD74E42f);
        administeredAgent = IAdministeredAgent(0x0745aae633E8318a063D383791bCc0d8C82F46C6);
    }

    function _getBlock() internal override pure returns (uint256) {
        return 506472875;
    }

}
