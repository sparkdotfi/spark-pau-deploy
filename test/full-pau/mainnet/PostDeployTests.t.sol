// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { stdJson }  from "../../../lib/forge-std/src/StdJson.sol";

import { VmSafe } from "../../../lib/forge-std/src/Vm.sol";

import { IAccessControl } from "../../../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IEnumerableIntegrations as IEI } from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { IAdministeredAgent } from "../../../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { Ethereum } from "../../../lib/spark-address-registry/src/Ethereum.sol";

import { PostDeployTestBase } from "../../PostDeployTestBase.t.sol";

interface IERC4626Like {

    function convertToShares(uint256 assets) external view returns (uint256 shares);

}

abstract contract MainnetPostDeployTestsBase is PostDeployTestBase {

    bytes32 internal constant CCTP_FACET_ID    = "CCTP_FACET";
    bytes32 internal constant PSM_FACET_ID     = "PSM_FACET";
    bytes32 internal constant ERC4626_FACET_ID = "ERC4626_FACET";

    uint32 internal constant XLAYER_CCTP_DOMAIN = 37;

    address internal XLAYER_CCTP_MINT_RECIPIENT;

    uint32  internal CCTP_MIN_FEE_CAP_RATE;
    uint32  internal CCTP_MAX_FEE_CAP_RATE;

    uint256 internal CCTP_USDC_MAX_AMOUNT;
    uint256 internal CCTP_USDC_SLOPE;
    uint256 internal PSM_USDC_MAX_AMOUNT;
    uint256 internal PSM_USDC_SLOPE;
    uint256 internal ERC4626_USDC_MAX_AMOUNT;
    uint256 internal ERC4626_USDC_SLOPE;
    uint256 internal ERC4626_MAX_EXPECTED_ASSETS;
    uint256 internal ERC4626_MAX_EXCHANGE_RATE_TOLERANCE;

    function setUp() public virtual override {
        super.setUp();

        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());
    }

    function _getBlock() internal virtual pure returns (uint256) {
        return 0;
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

    function _assertAdministeredAgentEvents() internal {
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

    function test_administeredAgentState() external {
        _assertAdministeredAgentState();
        _assertAdministeredAgentEvents();
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
            controller.erc4626_getMaxExchangeRate(Ethereum.SUSDC),
            _expectedMaxExchangeRate(),
            ERC4626_MAX_EXCHANGE_RATE_TOLERANCE
        );

        // 3b. Rate limits state

        _assertRateLimitData(controller.erc4626_getDepositRateLimitKey(Ethereum.SUSDC, Ethereum.USDC), ERC4626_USDC_MAX_AMOUNT, ERC4626_USDC_SLOPE);
        _assertRateLimitData(controller.erc4626_getWithdrawRateLimitKey(Ethereum.SUSDC), ERC4626_USDC_MAX_AMOUNT, ERC4626_USDC_SLOPE);
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
            key       : controller.erc4626_getDepositRateLimitKey(Ethereum.SUSDC, Ethereum.USDC),
            maxAmount : ERC4626_USDC_MAX_AMOUNT,
            slope     : ERC4626_USDC_SLOPE
        });

        // Assert erc4626_getWithdrawRateLimitKey(SUSDC) rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[9],
            key       : controller.erc4626_getWithdrawRateLimitKey(Ethereum.SUSDC),
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
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(controller), "");

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
            token           : Ethereum.SUSDC,
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
            / IERC4626Like(Ethereum.SUSDC).convertToShares(1e18);
    }

}

contract MainnetPostDeployTestsStaging is MainnetPostDeployTestsBase {

    using stdJson for string;

    function setUp() public override {
        super.setUp();

        // CCTP facet onboarding.
        XLAYER_CCTP_MINT_RECIPIENT = 0x4aeB3eA3cE2cF9ABaF8ED558C72A215743D7eb4F;

        CCTP_MIN_FEE_CAP_RATE = 0;
        CCTP_MAX_FEE_CAP_RATE = 100;
        CCTP_USDC_MAX_AMOUNT  = 10e6;
        CCTP_USDC_SLOPE       = uint256(100e6) / 1 hours;

        // PSM facet onboarding.
        PSM_USDC_MAX_AMOUNT  = 10e6;
        PSM_USDC_SLOPE       = uint256(100e6) / 1 hours;

        // ERC4626 facet onboarding.
        ERC4626_USDC_MAX_AMOUNT = 10e6;
        ERC4626_USDC_SLOPE      = uint256(100e6) / 1 hours;

        ERC4626_MAX_EXPECTED_ASSETS         = 1.2e18;
        ERC4626_MAX_EXCHANGE_RATE_TOLERANCE = 0.001e18;  // 0.1%

        string memory json = vm.readFile("deployments/mainnet-staging.json");

        _setUpAddresses({
            _agentFactory      : json.readAddress(".agentFactory"),
            _assembler         : json.readAddress(".defaultPAUAssembler"),
            _beacon            : json.readAddress(".beacon"),
            _pauFactory        : json.readAddress(".pauFactory"),
            _accessControls    : json.readAddress(".accessControls"),
            _administeredAgent : json.readAddress(".administeredAgent"),
            _almProxy          : json.readAddress(".proxy"),
            _controller        : json.readAddress(".controller"),
            _rateLimits        : json.readAddress(".rateLimits"),
            _admin             : json.readAddress(".admin"),
            _deployer          : json.readAddress(".deployer"),
            _relayer           : json.readAddress(".relayer"),
            _freezer           : json.readAddress(".freezer")
        });
    }

    function _getBlock() internal override pure returns (uint256) {
        return 25931121;
    }

}
