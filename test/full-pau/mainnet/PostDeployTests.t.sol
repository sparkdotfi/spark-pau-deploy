// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { VmSafe } from "../../../lib/forge-std/src/Vm.sol";

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

    /**********************************************************************************************/
    /*** Event tests                                                                            ***/
    /**********************************************************************************************/

    function _assertAccessControlsEvents() internal {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(accessControls), "");

        assertEq(logs.length, 6);

        //[0] RoleGranted(DEFAULT_ADMIN_ROLE, assembler, pauFactory) : Assembler.deploy()
        _assertRoleGrantedEvent(logs[0], DEFAULT_ADMIN_ROLE, address(assembler), address(pauFactory));

        //[1] RoleGranted(DEFAULT_ADMIN_ROLE, deployer, assembler) : Assembler.deploy()
        _assertRoleGrantedEvent(logs[1], DEFAULT_ADMIN_ROLE, deployer, address(assembler));

        //[2] RoleGranted(ALLOCATOR_ROLE, administeredAgent, assembler) : Assembler.deploy()
        _assertRoleGrantedEvent(logs[2], ALLOCATOR_ROLE, address(administeredAgent), address(assembler));

        //[3] RoleRevoked(DEFAULT_ADMIN_ROLE, assembler, assembler) : Assembler.deploy()
        _assertRoleRevokedEvent(logs[3], DEFAULT_ADMIN_ROLE, address(assembler), address(assembler));

        //[4] RoleGranted(DEFAULT_ADMIN_ROLE, admin, deployer) : ConfigureSparkPAUFull.transferAdminRoles()
        _assertRoleGrantedEvent(logs[4], DEFAULT_ADMIN_ROLE, admin, deployer);

        //[5] RoleRevoked(DEFAULT_ADMIN_ROLE, deployer, deployer) : ConfigureSparkPAUFull.transferAdminRoles()
        _assertRoleRevokedEvent(logs[5], DEFAULT_ADMIN_ROLE, deployer, deployer);
    }

    function _assertALMProxyEvents() internal {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(almProxy), "");

        assertEq(logs.length, 6);

        //[0] RoleGranted(DEFAULT_ADMIN_ROLE, assembler, pauFactory) : Assembler.deploy()
        _assertRoleGrantedEvent(logs[0], DEFAULT_ADMIN_ROLE, address(assembler), address(pauFactory));

        //[1] RoleGranted(DEFAULT_ADMIN_ROLE, deployer, assembler) : Assembler.deploy()
        _assertRoleGrantedEvent(logs[1], DEFAULT_ADMIN_ROLE, deployer, address(assembler));

        //[2] RoleGranted(CONTROLLER_ROLE, controller, assembler) : Assembler.deploy()
        _assertRoleGrantedEvent(logs[2], CONTROLLER_ROLE, address(controller), address(assembler));

        //[3] RoleRevoked(DEFAULT_ADMIN_ROLE, assembler, assembler) : Assembler.deploy()
        _assertRoleRevokedEvent(logs[3], DEFAULT_ADMIN_ROLE, address(assembler), address(assembler));

        //[4] RoleGranted(DEFAULT_ADMIN_ROLE, admin, deployer) : ConfigureSparkPAUFull.transferAdminRoles()
        _assertRoleGrantedEvent(logs[4], DEFAULT_ADMIN_ROLE, admin, deployer);

        //[5] RoleRevoked(DEFAULT_ADMIN_ROLE, deployer, deployer) : ConfigureSparkPAUFull.transferAdminRoles()
        _assertRoleRevokedEvent(logs[5], DEFAULT_ADMIN_ROLE, deployer, deployer);
    }

    function _assertAdministeredAgentEvents(address relayer, address freezer) internal {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(administeredAgent), "");

        assertEq(logs.length, 7);

        //[0] AdminAdded(assembler, agentFactory) : Assembler.deploy()
        _assertAdminAddedEvent(logs[0], address(assembler), address(agentFactory));

        //[1] AdminAdded(deployer, assembler) : Assembler.deploy()
        _assertAdminAddedEvent(logs[1], deployer, address(assembler));

        //[2] ActorAdded(relayer, assembler) : Assembler.deploy()
        _assertActorAddedEvent(logs[2], relayer, address(assembler));

        //[3] RevokerAdded(freezer, assembler) : Assembler.deploy()
        _assertRevokerAddedEvent(logs[3], freezer, address(assembler));

        //[4] AdminRemoved(assembler, assembler) : Assembler.deploy()
        _assertAdminRemovedEvent(logs[4], address(assembler), address(assembler));

        //[5] AdminAdded(admin, deployer) : ConfigureSparkPAUFull.transferAdminRoles()
        _assertAdminAddedEvent(logs[5], admin, deployer);

        //[6] AdminRemoved(deployer, deployer) : ConfigureSparkPAUFull.transferAdminRoles()
        _assertAdminRemovedEvent(logs[6], deployer, deployer);
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
    address internal constant CONTROLLER         = 0xD9874309494f3E6901999AF225cb8a70ff7aE1cE;
    address internal constant RATE_LIMITS        = 0xD9874309494f3E6901999AF225cb8a70ff7aE1cE;

    // From deployments outside of this repo.
    address internal constant AGENT_FACTORY = 0x8d165c44a8043C578fAA9fb35B99d324A7F83943;
    address internal constant BEACON        = 0x5Fd90192d68b102e1C46c59a42275bB7d0175375;
    address internal constant PAU_FACTORY   = 0xB87A3680f5957AB3dC5F26d77b59326C267683a4;

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

    uint256 internal constant ERC4626_USDC_MAX_AMOUNT     = 10e18;
    uint256 internal constant ERC4626_USDC_SLOPE          = uint256(100e18) / 1 hours;
    uint256 internal constant ERC4626_MAX_EXPECTED_ASSETS = 1.2e18;

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
        return 25925802;
    }

    function test_accessControlsStateAndEvents() external {
        _assertAccessControlsState();
        _assertAccessControlsEvents();
    }

    function test_almProxyStateAndEvents() external {
        _assertALMProxyState();
        _assertALMProxyEvents();
    }

    function test_rateLimitsStateAndEvents() external view {
        _assertRateLimitsState();
    }

    function test_controllerStateAndEvents() external view {
        _assertControllerState();
    }

    function test_administeredAgentState() external {
        _assertAdministeredAgentState(RELAYER,  FREEZER);
        _assertAdministeredAgentEvents(RELAYER, FREEZER);
    }

    function test_rateLimitsStateWithOnboardings() external view {
        // CCTP facet onboarding.

        _assertRateLimitData(controller.cctp_toCCTPRateLimitKey(), CCTP_USDC_MAX_AMOUNT, CCTP_USDC_SLOPE);

        _assertRateLimitData(
            controller.cctp_getToDomainRateLimitKey(XLAYER_CCTP_DOMAIN),
            CCTP_USDC_MAX_AMOUNT,
            CCTP_USDC_SLOPE
        );

        // PSM facet onboarding.

        _assertRateLimitData(
            controller.psm_usdcToUSDSSwapRateLimitKey(),
            PSM_USDC_MAX_AMOUNT,
            PSM_USDC_SLOPE
        );

        _assertRateLimitData(
            controller.psm_usdsToUSDCSwapRateLimitKey(),
            PSM_USDC_MAX_AMOUNT,
            PSM_USDC_SLOPE
        );

        // ERC4626 facet onboarding.

        _assertRateLimitData(
            controller.erc4626_getDepositRateLimitKey(SUSDC, USDC),
            ERC4626_USDC_MAX_AMOUNT,
            ERC4626_USDC_SLOPE
        );

        _assertRateLimitData(
            controller.erc4626_getWithdrawRateLimitKey(SUSDC),
            ERC4626_USDC_MAX_AMOUNT,
            ERC4626_USDC_SLOPE
        );
    }

    function test_controllerStateWithOnboardings() external view {
        // Controller integrations.

        IEI.Integration[] memory integrations = controller.integrations();

        assertEq(integrations.length, 3);

        assertEq(integrations[0].id, CCTP_FACET_ID);
        assertEq(integrations[1].id, PSM_FACET_ID);
        assertEq(integrations[2].id, ERC4626_FACET_ID);

        for (uint256 i = 0; i < integrations.length; i++) {
            _assertIntegration(integrations[i].id);
        }

        // CCTP facet onboarding: domain parameters.

        (
            bytes32 mintRecipient,
            uint32  minFeeCapRate,
            uint32  maxFeeCapRate
        ) = controller.cctp_getDomainParameters(XLAYER_CCTP_DOMAIN);

        assertEq(mintRecipient, bytes32(uint256(uint160(XLAYER_CCTP_MINT_RECIPIENT))));
        assertEq(minFeeCapRate, CCTP_MIN_FEE_CAP_RATE);
        assertEq(maxFeeCapRate, CCTP_MAX_FEE_CAP_RATE);

        // ERC4626 facet onboarding: max exchange rate.

        assertEq(controller.erc4626_getMaxExchangeRate(SUSDC), _expectedMaxExchangeRate());
    }

    function test_rateLimitsEvents() external {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, RATE_LIMITS, "");

        assertEq(logs.length, 12);

        //[0] RoleGranted(DEFAULT_ADMIN_ROLE, assembler, pauFactory) : Assembler.deploy()
        _assertRoleGrantedEvent(logs[0], DEFAULT_ADMIN_ROLE, address(assembler), address(pauFactory));

        //[1] RoleGranted(DEFAULT_ADMIN_ROLE, deployer, assembler) : Assembler.deploy()
        _assertRoleGrantedEvent(logs[1], DEFAULT_ADMIN_ROLE, DEPLOYER, address(assembler));

        //[2] RoleGranted(CONTROLLER_ROLE, controller, assembler) : Assembler.deploy()
        _assertRoleGrantedEvent(logs[2], CONTROLLER_ROLE, CONTROLLER, address(assembler));

        //[3] RoleRevoked(DEFAULT_ADMIN_ROLE, assembler, assembler) : Assembler.deploy()
        _assertRoleRevokedEvent(logs[3], DEFAULT_ADMIN_ROLE, address(assembler), address(assembler));

        //[4] RateLimitDataSet(cctp_toCCTPRateLimitKey, 10e6, 100e6 / 1 hours) : ConfigureSparkPAUFull.onboardCCTPFacet()
        _assertRateLimitDataSetEvent(
            logs[4],
            controller.cctp_toCCTPRateLimitKey(),
            CCTP_USDC_MAX_AMOUNT,
            CCTP_USDC_SLOPE
        );

        //[5] RateLimitDataSet(cctp_getToDomainRateLimitKey(XLAYER_CCTP_DOMAIN), 10e6, 100e6 / 1 hours) : ConfigureSparkPAUFull.onboardCCTPFacet()
        _assertRateLimitDataSetEvent(
            logs[5],
            controller.cctp_getToDomainRateLimitKey(XLAYER_CCTP_DOMAIN),
            CCTP_USDC_MAX_AMOUNT,
            CCTP_USDC_SLOPE
        );

        // Configure: PSM facet onboarding.
        _assertRateLimitDataSetEvent(
            logs[6],
            controller.psm_usdcToUSDSSwapRateLimitKey(),
            PSM_USDC_MAX_AMOUNT,
            PSM_USDC_SLOPE
        );

        _assertRateLimitDataSetEvent(
            logs[7],
            controller.psm_usdsToUSDCSwapRateLimitKey(),
            PSM_USDC_MAX_AMOUNT,
            PSM_USDC_SLOPE
        );

        // Configure: ERC4626 facet onboarding.
        _assertRateLimitDataSetEvent(
            logs[8],
            controller.erc4626_getDepositRateLimitKey(SUSDC, USDC),
            ERC4626_USDC_MAX_AMOUNT,
            ERC4626_USDC_SLOPE
        );

        _assertRateLimitDataSetEvent(
            logs[9],
            controller.erc4626_getWithdrawRateLimitKey(SUSDC),
            ERC4626_USDC_MAX_AMOUNT,
            ERC4626_USDC_SLOPE
        );

        // Configure: DEFAULT_ADMIN_ROLE transfers from the deployer to the admin.
        _assertRoleGrantedEvent(logs[10], DEFAULT_ADMIN_ROLE, ADMIN,    DEPLOYER);
        _assertRoleRevokedEvent(logs[11], DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER);
    }

    function test_controllerEvents() external {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, CONTROLLER, "");

        assertEq(logs.length, 6);

        // Deploy: controller initialization and integration wiring.
        _assertInitializedEvent(logs[0]);

        _assertIntegrationSetEvent(logs[1], CCTP_FACET_ID);
        _assertIntegrationSetEvent(logs[2], PSM_FACET_ID);
        _assertIntegrationSetEvent(logs[3], ERC4626_FACET_ID);

        // Configure: CCTP facet onboarding.
        _assertCCTPDomainParametersSetEvent(
            logs[4],
            XLAYER_CCTP_DOMAIN,
            XLAYER_CCTP_MINT_RECIPIENT,
            CCTP_MIN_FEE_CAP_RATE,
            CCTP_MAX_FEE_CAP_RATE
        );

        // Configure: ERC4626 facet onboarding.
        _assertERC4626MaxExchangeRateSetEvent(logs[5], SUSDC, _expectedMaxExchangeRate());
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    /// Mirrors the configure script: the stored rate is the max expected assets scaled by the
    /// vault shares captured when the script ran.
    function _expectedMaxExchangeRate() internal view returns (uint256) {
        return controller.erc4626_EXCHANGE_RATE_PRECISION() * ERC4626_MAX_EXPECTED_ASSETS
            / IERC4626Like(SUSDC).convertToShares(1e18);
    }

}
