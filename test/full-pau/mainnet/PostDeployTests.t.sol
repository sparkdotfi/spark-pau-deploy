// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { VmSafe } from "../../../lib/forge-std/src/Vm.sol";

import { IAccessControl } from "../../../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IEnumerableIntegrations as IEI } from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { IAdministeredAgent } from "../../../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { PostDeployTestBase } from "../../PostDeployTestBase.t.sol";

interface IERC4626Like {

    function convertToShares(uint256 assets) external view returns (uint256 shares);

}

abstract contract MainnetPostDeployTestsBase is PostDeployTestBase {

    function setUp() public virtual override {
        super.setUp();

        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());
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

    /**********************************************************************************************/
    /*** Event assertions helpers                                                               ***/
    /**********************************************************************************************/

    function _assertAccessControlsEvents() internal {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(accessControls), "");

        assertEq(logs.length, 6);

        // Grant assembler DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[0],
            role    : DEFAULT_ADMIN_ROLE,
            account : address(assembler),
            sender  : address(pauFactory)
        });

        // Grant deployer DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[1],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : address(assembler)
        });

        // Grant administeredAgent ALLOCATOR_ROLE
        _assertRoleGrantedEvent({
            log     : logs[2],
            role    : ALLOCATOR_ROLE,
            account : address(administeredAgent),
            sender  : address(assembler)
        });

        // Revoke assembler DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[3],
            role    : DEFAULT_ADMIN_ROLE,
            account : address(assembler),
            sender  : address(assembler)
        });

        // Grant admin DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[4],
            role    : DEFAULT_ADMIN_ROLE,
            account : admin,
            sender  : deployer
        });

        // Revoke deployer DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[5],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : deployer
        });
    }

    function _assertALMProxyEvents() internal {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(almProxy), "");

        assertEq(logs.length, 6);

        // Grant assembler DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[0],
            role    : DEFAULT_ADMIN_ROLE,
            account : address(assembler),
            sender  : address(pauFactory)
        });

        // Grant deployer DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[1],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : address(assembler)
        });

        // Grant controller CONTROLLER_ROLE
        _assertRoleGrantedEvent({
            log     : logs[2],
            role    : CONTROLLER_ROLE,
            account : address(controller),
            sender  : address(assembler)
        });

        // Revoke assembler DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[3],
            role    : DEFAULT_ADMIN_ROLE,
            account : address(assembler),
            sender  : address(assembler)
        });

        // Grant admin DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[4],
            role    : DEFAULT_ADMIN_ROLE,
            account : admin,
            sender  : deployer
        });

        // Revoke deployer DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[5],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : deployer
        });
    }

    function _assertAdministeredAgentEvents(address relayer, address freezer) internal {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(administeredAgent), "");

        assertEq(logs.length, 7);

        // Add assembler as admin
        _assertAdminAddedEvent({
            log     : logs[0],
            account : address(assembler),
            caller  : address(agentFactory)
        });

        // Add deployer as admin
        _assertAdminAddedEvent({
            log     : logs[1],
            account : deployer,
            caller  : address(assembler)
        });

        // Add relayer as actor
        _assertActorAddedEvent({
            log     : logs[2],
            account : relayer,
            caller  : address(assembler)
        });

        // Add freezer as revoker
        _assertRevokerAddedEvent({
            log     : logs[3],
            account : freezer,
            caller  : address(assembler)
        });

        // Remove assembler as admin
        _assertAdminRemovedEvent({
            log     : logs[4],
            account : address(assembler),
            caller  : address(assembler)
        });

        // Add admin as admin
        _assertAdminAddedEvent({
            log     : logs[5],
            account : admin,
            caller  : deployer
        });

        // Remove deployer as admin
        _assertAdminRemovedEvent({
            log     : logs[6],
            account : deployer,
            caller  : deployer
        });
    }

}

contract MainnetPostDeployTestsStaging is MainnetPostDeployTestsBase {

    // script/input/1/deploy-pau-with-assembler-mainnet-staging.json
    address internal constant ADMIN     = 0xb52991d5d29f371f493910c36f5A849b3748Cc28;
    address internal constant ASSEMBLER = 0xA9637570C04ccE6ea30097F68EfCAEb1fbb917A2;
    address internal constant DEPLOYER  = 0xC758519Ace14E884fdbA9ccE25F2DbE81b7e136f;
    address internal constant FREEZER   = 0x611C7c37F296240c2fF5a92f0B4a398B01B237c4;
    address internal constant RELAYER   = 0x611C7c37F296240c2fF5a92f0B4a398B01B237c4;

    // script/output/1/deploy-pau-with-assembler-mainnet-staging-1788773303.json
    address internal constant ACCESS_CONTROLS    = 0xF7C00D450494F5eb500A796A6685317618b6e6A0;
    address internal constant ADMINISTERED_AGENT = 0x8d165c44a8043C578fAA9fb35B99d324A7F83943;
    address internal constant ALM_PROXY          = 0xFB2252689E3a9c5d89cBBb65a174dba1163a8f19;
    address internal constant CONTROLLER         = 0xB87A3680f5957AB3dC5F26d77b59326C267683a4;
    address internal constant RATE_LIMITS        = 0xD9874309494f3E6901999AF225cb8a70ff7aE1cE;

    // From deployments outside of this repo.
    address internal constant AGENT_FACTORY = 0x74C35B0990ea530926d2656003Cb3E3Bf286cA69;
    address internal constant BEACON        = 0x5Fd90192d68b102e1C46c59a42275bB7d0175375;
    address internal constant PAU_FACTORY   = 0x333EADAE67df9De9368422F415de5A5f1BcD3925;

    bytes32 internal constant CCTP_FACET_ID    = bytes32(abi.encodePacked("CCTP_FACET"));
    bytes32 internal constant PSM_FACET_ID     = bytes32(abi.encodePacked("PSM_FACET"));
    bytes32 internal constant ERC4626_FACET_ID = bytes32(abi.encodePacked("ERC4626_FACET"));

    // CCTP facet onboarding.
    uint32  internal constant XLAYER_CCTP_DOMAIN         = 37;
    address internal constant XLAYER_CCTP_MINT_RECIPIENT = 0x4aeB3eA3cE2cF9ABaF8ED558C72A215743D7eb4F;

    uint32  internal constant CCTP_MIN_FEE_CAP_RATE = 0;
    uint32  internal constant CCTP_MAX_FEE_CAP_RATE = 100;
    uint256 internal constant CCTP_USDC_MAX_AMOUNT  = 10e6;
    uint256 internal constant CCTP_USDC_SLOPE       = uint256(100e6) / 1 hours;

    // PSM facet onboarding.
    uint256 internal constant PSM_USDC_MAX_AMOUNT  = 10e6;
    uint256 internal constant PSM_USDC_SLOPE       = uint256(100e6) / 1 hours;

    // ERC4626 facet onboarding.
    address internal constant SUSDC = 0xBc65ad17c5C0a2A4D159fa5a503f4992c7B545FE;
    address internal constant USDC  = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 internal constant ERC4626_USDC_MAX_AMOUNT = 10e6;
    uint256 internal constant ERC4626_USDC_SLOPE      = uint256(100e6) / 1 hours;

    uint256 internal constant ERC4626_MAX_EXPECTED_ASSETS         = 1.2e18;
    uint256 internal constant ERC4626_MAX_EXCHANGE_RATE_TOLERANCE = 0.001e18;  // 0.1%

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
        return 25931121;
    }

    function test_administeredAgentState() external {
        _assertAdministeredAgentState(RELAYER,  FREEZER);
        _assertAdministeredAgentEvents(RELAYER, FREEZER);
    }

    function test_accessControlsStateAndEvents() external {
        _assertAccessControlsState();
        _assertAccessControlsEvents();
    }

    function test_almProxyStateAndEvents() external {
        _assertALMProxyState();
        _assertALMProxyEvents();
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
        assertEq(integrations[1].id, PSM_FACET_ID);
        assertEq(integrations[2].id, ERC4626_FACET_ID);

        for (uint256 i = 0; i < integrations.length; i++) {
            _assertIntegration(integrations[i].id);
        }

        // 1. CCTP facet onboarding

        // 1a. Controller state
        (
            bytes32 mintRecipient,
            uint32  minFeeCapRate,
            uint32  maxFeeCapRate
        ) = controller.cctp_getDomainParameters(XLAYER_CCTP_DOMAIN);

        assertEq(mintRecipient, bytes32(uint256(uint160(XLAYER_CCTP_MINT_RECIPIENT))));
        assertEq(minFeeCapRate, CCTP_MIN_FEE_CAP_RATE);
        assertEq(maxFeeCapRate, CCTP_MAX_FEE_CAP_RATE);

        // 1b. Rate limits state

        _assertRateLimitData(controller.cctp_toCCTPRateLimitKey(),                        CCTP_USDC_MAX_AMOUNT, CCTP_USDC_SLOPE);
        _assertRateLimitData(controller.cctp_getToDomainRateLimitKey(XLAYER_CCTP_DOMAIN), CCTP_USDC_MAX_AMOUNT, CCTP_USDC_SLOPE);

        // 2. PSM facet onboarding (No controller state changes to assert)

        // 2b. Rate limits state

        _assertRateLimitData(controller.psm_usdcToUSDSSwapRateLimitKey(), PSM_USDC_MAX_AMOUNT, PSM_USDC_SLOPE);
        _assertRateLimitData(controller.psm_usdsToUSDCSwapRateLimitKey(), PSM_USDC_MAX_AMOUNT, PSM_USDC_SLOPE);

        // 3. ERC4626 facet onboarding

        // 3a. Controller state
        assertApproxEqRel(
            controller.erc4626_getMaxExchangeRate(SUSDC),
            _expectedMaxExchangeRate(),
            ERC4626_MAX_EXCHANGE_RATE_TOLERANCE
        );

        // 3b. Rate limits state

        _assertRateLimitData(controller.erc4626_getDepositRateLimitKey(SUSDC, USDC), ERC4626_USDC_MAX_AMOUNT, ERC4626_USDC_SLOPE);
        _assertRateLimitData(controller.erc4626_getWithdrawRateLimitKey(SUSDC), ERC4626_USDC_MAX_AMOUNT, ERC4626_USDC_SLOPE);
    }

    function test_rateLimitsEvents() external {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(rateLimits), "");

        assertEq(logs.length, 12); // 6 role grant/revoke events + 6 rate limit set events.

        // Grant assembler DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[0],
            role    : DEFAULT_ADMIN_ROLE,
            account : address(assembler),
            sender  : address(pauFactory)
        });

        // Grant deployer DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[1],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : address(assembler)
        });

        // Grant controller CONTROLLER_ROLE
        _assertRoleGrantedEvent({
            log     : logs[2],
            role    : CONTROLLER_ROLE,
            account : address(controller),
            sender  : address(assembler)
        });

        // Revoke assembler DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[3],
            role    : DEFAULT_ADMIN_ROLE,
            account : address(assembler),
            sender  : address(assembler)
        });

        // Assert cctp_toCCTPRateLimitKey rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[4],
            key       : controller.cctp_toCCTPRateLimitKey(),
            maxAmount : CCTP_USDC_MAX_AMOUNT,
            slope     : CCTP_USDC_SLOPE
        });

        // Assert cctp_getToDomainRateLimitKey rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[5],
            key       : controller.cctp_getToDomainRateLimitKey(XLAYER_CCTP_DOMAIN),
            maxAmount : CCTP_USDC_MAX_AMOUNT,
            slope     : CCTP_USDC_SLOPE
        });

        // Assert psm_usdcToUSDSSwapRateLimitKey rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[6],
            key       : controller.psm_usdcToUSDSSwapRateLimitKey(),
            maxAmount : PSM_USDC_MAX_AMOUNT,
            slope     : PSM_USDC_SLOPE
        });

        // Assert psm_usdsToUSDCSwapRateLimitKey rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[7],
            key       : controller.psm_usdsToUSDCSwapRateLimitKey(),
            maxAmount : PSM_USDC_MAX_AMOUNT,
            slope     : PSM_USDC_SLOPE
        });

        // Assert erc4626_getDepositRateLimitKey(SUSDC, USDC) rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[8],
            key       : controller.erc4626_getDepositRateLimitKey(SUSDC, USDC),
            maxAmount : ERC4626_USDC_MAX_AMOUNT,
            slope     : ERC4626_USDC_SLOPE
        });

        // Assert erc4626_getWithdrawRateLimitKey(SUSDC) rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[9],
            key       : controller.erc4626_getWithdrawRateLimitKey(SUSDC),
            maxAmount : ERC4626_USDC_MAX_AMOUNT,
            slope     : ERC4626_USDC_SLOPE
        });

        // Grant admin DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[10],
            role    : DEFAULT_ADMIN_ROLE,
            account : admin,
            sender  : deployer
        });

        // Revoke deployer DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[11],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : deployer
        });
    }

    function test_controllerEvents() external {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, CONTROLLER, "");

        assertEq(logs.length, 6);

        // Assert controller Initialized event
        _assertInitializedEvent({
            log: logs[0]
        });

        // Assert CCTP_FACET_ID integration set event
        _assertIntegrationSetEvent({
            log           : logs[1],
            integrationId : CCTP_FACET_ID
        });

        // Assert PSM_FACET_ID integration set event
        _assertIntegrationSetEvent({
            log           : logs[2],
            integrationId : PSM_FACET_ID
        });

        // Assert ERC4626_FACET_ID integration set event
        _assertIntegrationSetEvent({
            log           : logs[3],
            integrationId : ERC4626_FACET_ID
        });

        // Assert CCTPDomainParametersSet event
        _assertCCTPDomainParametersSetEvent({
            log               : logs[4],
            destinationDomain : XLAYER_CCTP_DOMAIN,
            mintRecipient     : XLAYER_CCTP_MINT_RECIPIENT,
            minFeeCapRate     : CCTP_MIN_FEE_CAP_RATE,
            maxFeeCapRate     : CCTP_MAX_FEE_CAP_RATE
        });

        // Assert ERC4626MaxExchangeRateSet event
        _assertERC4626MaxExchangeRateSetEvent({
            log             : logs[5],
            token           : SUSDC,
            maxExchangeRate : _expectedMaxExchangeRate(),
            maxPercentDelta : ERC4626_MAX_EXCHANGE_RATE_TOLERANCE
        });
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    /// Mirrors the configure script: EXCHANGE_RATE_PRECISION * 1.2e18 / convertToShares(1e18).
    /// Share price can drift after config, so callers compare with a relative tolerance.
    function _expectedMaxExchangeRate() internal view returns (uint256) {
        return controller.erc4626_EXCHANGE_RATE_PRECISION() * ERC4626_MAX_EXPECTED_ASSETS
            / IERC4626Like(SUSDC).convertToShares(1e18);
    }

}
