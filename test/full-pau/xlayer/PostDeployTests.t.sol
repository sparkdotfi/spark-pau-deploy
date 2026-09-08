// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IEnumerableIntegrations as IEI } from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { PostDeployTestBase } from "../../PostDeployTestBase.t.sol";

interface ISparkVaultLike {

    function TAKER_ROLE() external view returns (bytes32);

    function hasRole(bytes32 role, address account) external view returns (bool);

}

/// There are no event assertions on X Layer: the Etherscan v2 log endpoint does not cover chain
/// 196, so _getEvents cannot be used. Only the on-chain end state is asserted.
abstract contract XLayerPostDeployTestsBase is PostDeployTestBase {

    function setUp() public virtual override {
        super.setUp();

        vm.createSelectFork(getChain("xlayer").rpcUrl, _getBlock());
    }

    function _getBlock() internal virtual pure returns (uint256) {
        return 0;
    }

    /**********************************************************************************************/
    /*** State Assertions                                                                       ***/
    /**********************************************************************************************/

    function _assertAdministeredAgentState(address relayer, address freezer) internal view {
        assertEq(administeredAgent.adminCount(),   1);
        assertEq(administeredAgent.actorCount(),   1);
        assertEq(administeredAgent.grantorCount(), 0);
        assertEq(administeredAgent.revokerCount(), 1);

        assertEq(administeredAgent.getAdmin(0),   admin);
        assertEq(administeredAgent.getActor(0),   relayer);
        assertEq(administeredAgent.getRevoker(0), freezer);

        assertEq(administeredAgent.getIsAdmin(deployer),              false);
        assertEq(administeredAgent.getIsAdmin(address(assembler)),    false);
        assertEq(administeredAgent.getIsAdmin(address(agentFactory)), false);
    }

    function _assertAccessControlsState() internal view {
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, admin),     true);
        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE, address(administeredAgent)), true);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ROLE),                  1);

        // Neither the deployer nor the deploy infrastructure retains any role.

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     deployer), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, deployer), false);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     address(assembler)), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, address(assembler)), false);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     address(pauFactory)), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, address(pauFactory)), false);
    }

    function _assertALMProxyState() internal view {
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),               true);
        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    address(controller)), true);

        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    deployer), false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, deployer), false);

        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    address(assembler)), false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, address(assembler)), false);

        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    address(pauFactory)), false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, address(pauFactory)), false);
    }

    function _assertRateLimitsState() internal view {
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin),               true);
        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    address(controller)), true);

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    deployer), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, deployer), false);

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    address(assembler)), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, address(assembler)), false);

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    address(pauFactory)), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, address(pauFactory)), false);
    }

    function _assertControllerState() internal view {
        assertEq(controller.accessControls(), address(accessControls));
        assertEq(controller.beacon(),         address(beacon));
        assertEq(controller.proxy(),          address(almProxy));
        assertEq(controller.rateLimits(),     address(rateLimits));
    }

}

contract XLayerPostDeployTestsStaging is XLayerPostDeployTestsBase {

    // script/input/196/{deploy,config}-pau-with-assembler-xlayer-staging.json
    address internal constant ADMIN     = 0xb52991d5d29f371f493910c36f5A849b3748Cc28;
    address internal constant ASSEMBLER = 0xB4A254db64cEd1F90E2343af1c4e437dC2a2B014;
    address internal constant DEPLOYER  = 0x23d43f3189Ab9CEBfFcC0352C0490387e3105FB3;
    address internal constant FREEZER   = 0xE4FB2B5B40EE539f5b9551cf699674d3082eD39b;
    address internal constant RELAYER   = 0xE4FB2B5B40EE539f5b9551cf699674d3082eD39b;

    // script/output/196/deploy-pau-with-assembler-xlayer-staging-1788774026.json
    address internal constant ACCESS_CONTROLS    = 0x512927F14BDEC0255Dd43d2Bd55FC16C87844A89;
    address internal constant ADMINISTERED_AGENT = 0xcF9F6Cb0a94aAfe367F2F0Dac0EE86e033abc4E0;
    address internal constant ALM_PROXY          = 0x4aeB3eA3cE2cF9ABaF8ED558C72A215743D7eb4F;
    address internal constant CONTROLLER         = 0x32b845F472f61b023b1bd77f2E0fb2b3F9db2053;
    address internal constant RATE_LIMITS        = 0x2D66F6C219d19b9E546Af7Ff02fFcCE145F95767;

    // From deployments outside of this repo.
    address internal constant AGENT_FACTORY = 0x039bC8CAe7A5b2B981E5ED98B840C76c7FBacDAc;
    address internal constant BEACON        = 0x13B471908224B25f15a16D1e3F44a9F99E8b5aD5;
    address internal constant PAU_FACTORY   = 0x257956534374d558c8868338ff7885a93B638277;

    bytes32 internal constant CCTP_FACET_ID           = bytes32(abi.encodePacked("CCTP_FACET"));
    bytes32 internal constant TRANSFER_ASSET_FACET_ID = bytes32(abi.encodePacked("TRANSFER_ASSET_FACET"));
    bytes32 internal constant SPARK_VAULT_FACET_ID    = bytes32(abi.encodePacked("SPARK_VAULT_FACET"));

    // CCTP facet onboarding.
    uint32  internal constant ETHEREUM_CCTP_DOMAIN         = 0;
    address internal constant ETHEREUM_CCTP_MINT_RECIPIENT = 0xFB2252689E3a9c5d89cBBb65a174dba1163a8f19;

    uint32  internal constant CCTP_MIN_FEE_CAP_RATE = 0;
    uint32  internal constant CCTP_MAX_FEE_CAP_RATE = 100;
    uint256 internal constant CCTP_USDC_MAX_AMOUNT  = 10e6;
    uint256 internal constant CCTP_USDC_SLOPE       = uint256(100e6) / 1 hours;

    // TransferAsset facet onboarding.
    address internal constant USDC = 0xB6CEceAB302E2E4948951eE7843FC24E92933061;

    uint256 internal constant TRANSFER_ASSET_USDC_MAX_AMOUNT = 10e6;
    uint256 internal constant TRANSFER_ASSET_USDC_SLOPE      = uint256(100e6) / 1 hours;

    // SparkVault facet onboarding.
    address internal constant SPUSDC = 0xf593142283736439d7F0B93ddB3B10E780Ba3074;

    uint256 internal constant SPARK_VAULT_USDC_MAX_AMOUNT = 10e6;
    uint256 internal constant SPARK_VAULT_USDC_SLOPE      = uint256(100e6) / 1 hours;

    function setUp() public override {
        super.setUp();

        _setUpAddresses(
            AGENT_FACTORY,
            ASSEMBLER,
            BEACON,
            PAU_FACTORY,
            ACCESS_CONTROLS,
            ADMINISTERED_AGENT,
            ALM_PROXY,
            CONTROLLER,
            RATE_LIMITS,
            ADMIN,
            DEPLOYER
        );
    }

    function _getBlock() internal override pure returns (uint256) {
        return 70084000;
    }

    function test_administeredAgentState() external view {
        _assertAdministeredAgentState(RELAYER, FREEZER);
    }

    function test_accessControlsState() external view {
        _assertAccessControlsState();
    }

    function test_almProxyState() external view {
        _assertALMProxyState();
    }

    function test_rateLimitsState() external view {
        _assertRateLimitsState();
    }

    function test_controllerState() external view {
        _assertControllerState();
    }

    function test_rateLimitsAndControllerOnboardingState() external view {
        // 0. Controller Integrations
        IEI.Integration[] memory integrations = controller.integrations();

        assertEq(integrations.length, 3);

        assertEq(integrations[0].id, CCTP_FACET_ID);
        assertEq(integrations[1].id, TRANSFER_ASSET_FACET_ID);
        assertEq(integrations[2].id, SPARK_VAULT_FACET_ID);

        for (uint256 i = 0; i < integrations.length; i++) {
            _assertIntegration(integrations[i].id);
        }

        // 1. CCTP facet onboarding

        // 1a. Controller state
        (
            bytes32 mintRecipient,
            uint32  minFeeCapRate,
            uint32  maxFeeCapRate
        ) = controller.cctp_getDomainParameters(ETHEREUM_CCTP_DOMAIN);

        assertEq(mintRecipient, bytes32(uint256(uint160(ETHEREUM_CCTP_MINT_RECIPIENT))));
        assertEq(minFeeCapRate, CCTP_MIN_FEE_CAP_RATE);
        assertEq(maxFeeCapRate, CCTP_MAX_FEE_CAP_RATE);

        // 1b. Rate limits state

        _assertRateLimitData(controller.cctp_toCCTPRateLimitKey(),                          CCTP_USDC_MAX_AMOUNT, CCTP_USDC_SLOPE);
        _assertRateLimitData(controller.cctp_getToDomainRateLimitKey(ETHEREUM_CCTP_DOMAIN), CCTP_USDC_MAX_AMOUNT, CCTP_USDC_SLOPE);

        // 2. TransferAsset facet onboarding

        // 2a. Controller state (No controller state changes to assert, the transferred asset is
        //     the USDC that the CCTP facet mints on this chain)
        assertEq(controller.cctp_usdc(), USDC);

        // 2b. Rate limits state

        _assertRateLimitData(controller.transferAsset_getTransferRateLimitKey(USDC, SPUSDC), TRANSFER_ASSET_USDC_MAX_AMOUNT, TRANSFER_ASSET_USDC_SLOPE);

        // 3. SparkVault facet onboarding

        // 3a. Spark vault state
        assertEq(ISparkVaultLike(SPUSDC).hasRole(ISparkVaultLike(SPUSDC).TAKER_ROLE(), ALM_PROXY), true);

        // 3b. Rate limits state

        _assertRateLimitData(controller.sparkVault_getTakeRateLimitKey(SPUSDC), SPARK_VAULT_USDC_MAX_AMOUNT, SPARK_VAULT_USDC_SLOPE);
    }

}
