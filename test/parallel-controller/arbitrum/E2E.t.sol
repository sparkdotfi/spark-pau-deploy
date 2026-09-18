// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IERC20 } from "../../../lib/diamond-pau/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { IAccessControls }                           from "../../../lib/diamond-pau/src/interfaces/IAccessControls.sol";
import { IALMProxy }                                 from "../../../lib/diamond-pau/src/interfaces/IALMProxy.sol";
import { IBeacon }                                   from "../../../lib/diamond-pau/src/interfaces/IBeacon.sol";
import { IEnumerableIntegrations as IEI }            from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";
import { IMainnetControllerFull as IControllerFull } from "../../../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";
import { IPAUFactory }                               from "../../../lib/diamond-pau/src/interfaces/IPAUFactory.sol";
import { IRateLimits }                               from "../../../lib/diamond-pau/src/interfaces/IRateLimits.sol";

import { IAdministeredAgent }        from "../../../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";
import { IAdministeredAgentFactory } from "../../../lib/pau-administered-agent/src/interfaces/IAdministeredAgentFactory.sol";

import { Arbitrum } from "../../../lib/spark-address-registry/src/Arbitrum.sol";
import { Ethereum } from "../../../lib/spark-address-registry/src/Ethereum.sol";

import { CCTPFacetWiring } from "../../../src/CCTPFacetWiring.sol";
import { ParallelPAULib }  from "../../../src/ParallelPAULib.sol";

import { ArbitrumParallelTestBase } from "./ArbitrumParallelTestBase.t.sol";

/**
 * @notice Runs the exact production code path (ParallelPAULib.deploy + configure) on an
 *         Arbitrum fork as the deployer, asserts the same end state the post-deploy test checks,
 *         then simulates the governance spell and pushes a real CCTP V2 burn through the new
 *         controller to prove the Arbitrum -> Ethereum route works before anything is broadcast.
 */
contract ArbitrumParallelE2ETest is ArbitrumParallelTestBase {

    address internal constant DEPLOYER = 0xC758519Ace14E884fdbA9ccE25F2DbE81b7e136f;

    ParallelPAULib.Deployment internal deployment;

    function setUp() public override {
        super.setUp();

        vm.createSelectFork(getChain("arbitrum_one").rpcUrl);

        admin           = Arbitrum.SPARK_EXECUTOR;
        deployer        = DEPLOYER;
        relayer         = Arbitrum.ALM_RELAYER_MULTISIG;
        backstopRelayer = Arbitrum.ALM_BACKSTOP_RELAYER_MULTISIG;
        freezer         = Arbitrum.ALM_FREEZER_MULTISIG;
        grantor         = Ethereum.PAU_GRANTOR_MULTISIG; // Same Safe address on every chain.

        legacyController   = Arbitrum.ALM_CONTROLLER;
        cctpTokenMessenger = Arbitrum.CCTP_TOKEN_MESSENGER;
        usdc               = Arbitrum.USDC;
        ethereumAlmProxy   = Ethereum.ALM_PROXY;
        ethereumDomainId   = 0;

        // --- Deploy script ---

        ParallelPAULib.DeployParams memory deployParams = ParallelPAULib.DeployParams({
            deployer           : deployer,
            almProxy           : Arbitrum.ALM_PROXY,
            cctpTokenMessenger : cctpTokenMessenger,
            usdc               : usdc
        });

        vm.startPrank(deployer);

        deployment = ParallelPAULib.deploy(deployParams);

        // --- Configure script ---

        address[] memory relayers = new address[](2);

        relayers[0] = relayer;
        relayers[1] = backstopRelayer;

        ParallelPAULib.CCTPDomain[] memory domains = new ParallelPAULib.CCTPDomain[](1);

        domains[0] = ParallelPAULib.CCTPDomain({
            domainId      : ethereumDomainId,
            mintRecipient : ethereumAlmProxy,
            minFeeCapRate : 0,
            maxFeeCapRate : 0
        });

        ParallelPAULib.ConfigureParams memory configureParams = ParallelPAULib.ConfigureParams({
            controller        : deployment.controller,
            administeredAgent : deployment.administeredAgent,
            admin             : admin,
            deployer          : deployer,
            freezer           : freezer,
            grantor           : grantor,
            relayers          : relayers,
            cctpDomains       : domains
        });

        ParallelPAULib.configure(configureParams);

        vm.stopPrank();

        ParallelPAULib.checkConfigured(configureParams);

        // --- Bind the shared assertions to the fresh deployment ---

        agentFactory = IAdministeredAgentFactory(deployment.agentFactory);
        beacon       = IBeacon(deployment.beacon);
        pauFactory   = IPAUFactory(deployment.pauFactory);

        accessControls    = IAccessControls(deployment.accessControls);
        administeredAgent = IAdministeredAgent(deployment.administeredAgent);
        almProxy          = IALMProxy(Arbitrum.ALM_PROXY);
        controller        = IControllerFull(deployment.controller);
        rateLimits        = IRateLimits(deployment.rateLimits);

        cctpFacet = deployment.cctpFacet;
    }

    /**********************************************************************************************/
    /*** End state after deploy + configure                                                     ***/
    /**********************************************************************************************/

    function test_beaconState()            external view { _assertBeaconState(); }
    function test_accessControlsState()    external view { _assertAccessControlsState(); }
    function test_almProxyState()          external view { _assertParallelALMProxyState(); }
    function test_rateLimitsState()        external view { _assertParallelRateLimitsState(); }
    function test_controllerState()        external view { _assertParallelControllerState(); }
    function test_administeredAgentState() external view { _assertParallelAdministeredAgentState(); }

    /**********************************************************************************************/
    /*** Guard rails                                                                            ***/
    /**********************************************************************************************/

    /// @dev Before the spell the controller can be called but cannot move anything: no CONTROLLER
    ///      role on the proxy and no rate limits. Both fail closed.
    function test_transferRevertsBeforeSpell() external {
        vm.prank(relayer);
        vm.expectRevert("RateLimits/zero-maxAmount");
        administeredAgent.call(
            address(controller),
            abi.encodeCall(controller.cctp_transfer, (1e6, ethereumDomainId, 0))
        );
    }

    /// @dev Only the AdministeredAgent holds ALLOCATOR_ROLE. A relayer calling the controller
    ///      directly is rejected.
    function test_relayerCannotCallControllerDirectly() external {
        vm.prank(relayer);
        vm.expectRevert();
        controller.cctp_transfer(1e6, ethereumDomainId, 0);
    }

    /// @dev The deployer retains no authority anywhere after configure.
    function test_deployerCannotAdministerAfterConfigure() external {
        bytes32[] memory ids = new bytes32[](1);

        ids[0] = CCTPFacetWiring.INTEGRATION_ID;

        bytes32 key = controller.cctp_toCCTPRateLimitKey();

        vm.startPrank(deployer);

        vm.expectRevert();
        controller.removeIntegrations(ids);

        vm.expectRevert();
        beacon.removeIntegration(CCTPFacetWiring.INTEGRATION_ID);

        vm.expectRevert();
        rateLimits.setRateLimitData(key, 1, 0);

        vm.expectRevert();
        almProxy.grantRole(CONTROLLER_ROLE, address(controller));

        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** Simulated spell + live CCTP V2 burn                                                    ***/
    /**********************************************************************************************/

    /// @dev The Oct 8 spell grants CONTROLLER on the existing ALMProxy and sets the two CCTP
    ///      rate limits. After that a relayer can bridge USDC to the Spark Ethereum ALMProxy
    ///      through Circle's TokenMessengerV2, and the legacy controller is unaffected.
    function test_spellThenCCTPTransfer() external {
        uint256 maxAmount = 10_000_000e6;
        uint256 slope     = uint256(50_000_000e6) / 1 days;

        bytes32 totalKey  = controller.cctp_toCCTPRateLimitKey();
        bytes32 domainKey = controller.cctp_getToDomainRateLimitKey(ethereumDomainId);

        // --- Spell (Spark Executor is admin of the proxy and the new RateLimits) ---

        vm.startPrank(Arbitrum.SPARK_EXECUTOR);

        almProxy.grantRole(CONTROLLER_ROLE, address(controller));

        rateLimits.setRateLimitData(totalKey,  maxAmount, slope);
        rateLimits.setRateLimitData(domainKey, maxAmount, slope);

        vm.stopPrank();

        assertEq(almProxy.hasRole(CONTROLLER_ROLE, legacyController),    true);
        assertEq(almProxy.hasRole(CONTROLLER_ROLE, address(controller)), true);

        // --- Fund the proxy with idle USDC (it normally holds none) ---

        uint256 amount = 1_000_000e6;

        deal(usdc, address(almProxy), amount);

        uint256 usdcSupplyBefore = IERC20(usdc).totalSupply();

        // --- Relayer bridges through the AdministeredAgent ---

        vm.prank(relayer);
        administeredAgent.call(
            address(controller),
            abi.encodeCall(controller.cctp_transfer, (amount, ethereumDomainId, 0))
        );

        // USDC burned from the proxy, nothing left approved, both limits consumed.
        assertEq(IERC20(usdc).balanceOf(address(almProxy)),          0);
        assertEq(IERC20(usdc).allowance(address(almProxy), cctpTokenMessenger), 0);
        assertEq(IERC20(usdc).totalSupply(),                         usdcSupplyBefore - amount);

        assertEq(rateLimits.getCurrentRateLimit(totalKey),  maxAmount - amount);
        assertEq(rateLimits.getCurrentRateLimit(domainKey), maxAmount - amount);

        // Over the limit fails closed.
        deal(usdc, address(almProxy), maxAmount);

        vm.prank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        administeredAgent.call(
            address(controller),
            abi.encodeCall(controller.cctp_transfer, (maxAmount, ethereumDomainId, 0))
        );

        // Any other destination fails closed on its unset per-domain limit, before the facet
        // even reaches the domain-parameter check.
        vm.prank(relayer);
        vm.expectRevert("RateLimits/zero-maxAmount");
        administeredAgent.call(
            address(controller),
            abi.encodeCall(controller.cctp_transfer, (1e6, 6, 0))
        );
    }

    /// @dev Kill switch: one admin transaction makes the facet unreachable, legacy untouched.
    function test_removeIntegrationIsKillSwitch() external {
        bytes32[] memory ids = new bytes32[](1);

        ids[0] = CCTPFacetWiring.INTEGRATION_ID;

        vm.prank(admin);
        controller.removeIntegrations(ids);

        assertEq(controller.integrations().length, 0);

        vm.prank(relayer);
        vm.expectRevert();
        administeredAgent.call(
            address(controller),
            abi.encodeCall(controller.cctp_transfer, (1e6, ethereumDomainId, 0))
        );

        assertEq(almProxy.hasRole(CONTROLLER_ROLE, legacyController), true);
    }

}
