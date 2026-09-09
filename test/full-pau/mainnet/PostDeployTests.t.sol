// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { stdJson }  from "../../../lib/forge-std/src/StdJson.sol";

import { IEnumerableIntegrations as IEI } from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { Ethereum } from "../../../lib/spark-address-registry/src/Ethereum.sol";

import { PostDeployTestBase } from "../../PostDeployTestBase.t.sol";

abstract contract MainnetPostDeployTestsBase is PostDeployTestBase {

    bytes32 internal constant CCTP_FACET_ID    = "CCTP_FACET";
    bytes32 internal constant ERC4626_FACET_ID = "ERC4626_FACET";

    uint32 internal constant XLAYER_CCTP_DOMAIN = 37;

    address internal XLAYER_CCTP_MINT_RECIPIENT;

    uint32  internal CCTP_MIN_FEE_CAP_RATE;
    uint32  internal CCTP_MAX_FEE_CAP_RATE;

    uint256 internal CCTP_USDC_MAX_AMOUNT;
    uint256 internal CCTP_USDC_SLOPE;
    uint256 internal ERC4626_USDC_MAX_AMOUNT;
    uint256 internal ERC4626_USDC_SLOPE;

    function setUp() public virtual override {
        super.setUp();

        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        _setUpDeployment();
    }

    function _getBlock() internal virtual pure returns (uint256) {
        return 0;
    }

    /**********************************************************************************************/
    /*** State tests                                                                            ***/
    /**********************************************************************************************/

    function test_administeredAgentState() external view {
        _assertAdministeredAgentState();
    }

    function test_accessControlsState() external view {
        _assertAccessControlsState();
    }

    function test_almProxyState() external view {
        _assertALMProxyState();
    }

    function test_rateLimitsState() external view {
        _assertRateLimitsInitializationState();
    }

    function test_controllerState() external view {
        _assertControllerInitializationState();
    }

    function test_rateLimitsAndControllerOnboardingState() external view {
        // 0. Controller Integrations
        IEI.Integration[] memory integrations = controller.integrations();

        assertEq(integrations.length, 2);

        assertEq(integrations[0].id, CCTP_FACET_ID);
        assertEq(integrations[1].id, ERC4626_FACET_ID);

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

        // 2. ERC4626 facet onboarding

        // 2a. Controller state
        assertEq(controller.erc4626_getMaxExchangeRate(Ethereum.SUSDC), 1e25);

        // 2b. Rate limits state

        _assertRateLimitData(controller.erc4626_getDepositRateLimitKey(Ethereum.SUSDC, Ethereum.USDC), ERC4626_USDC_MAX_AMOUNT, ERC4626_USDC_SLOPE);
        _assertRateLimitData(controller.erc4626_getWithdrawRateLimitKey(Ethereum.SUSDC),               ERC4626_USDC_MAX_AMOUNT, ERC4626_USDC_SLOPE);
    }

}

abstract contract MainnetPostDeployEventTestsBase is MainnetPostDeployTestsBase {

    /**********************************************************************************************/
    /*** Event assertions helpers                                                               ***/
    /**********************************************************************************************/

    function _assertRateLimitsEvents() internal {
        RawLog[] memory logs = _logsFor(address(rateLimits));

        assertEq(logs.length, 10); // 6 role grant/revoke events + 4 rate limit set events.

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

        // Assert erc4626_getDepositRateLimitKey(SUSDC, USDC) rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[6],
            key       : controller.erc4626_getDepositRateLimitKey(Ethereum.SUSDC, Ethereum.USDC),
            maxAmount : ERC4626_USDC_MAX_AMOUNT,
            slope     : ERC4626_USDC_SLOPE
        });

        // Assert erc4626_getWithdrawRateLimitKey(SUSDC) rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[7],
            key       : controller.erc4626_getWithdrawRateLimitKey(Ethereum.SUSDC),
            maxAmount : ERC4626_USDC_MAX_AMOUNT,
            slope     : ERC4626_USDC_SLOPE
        });

        // Grant admin DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[8],
            role    : DEFAULT_ADMIN_ROLE,
            account : admin,
            sender  : deployer
        });

        // Revoke deployer DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[9],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : deployer
        });
    }

    function _assertControllerEvents() internal {
        RawLog[] memory logs = _logsFor(address(controller));

        assertEq(logs.length, 5);

        // Assert controller Initialized event
        _assertInitializedEvent({
            log: logs[0]
        });

        // Assert CCTP_FACET_ID integration set event
        _assertIntegrationSetEvent({
            log           : logs[1],
            integrationId : CCTP_FACET_ID
        });

        // Assert ERC4626_FACET_ID integration set event
        _assertIntegrationSetEvent({
            log           : logs[2],
            integrationId : ERC4626_FACET_ID
        });

        // Assert CCTPDomainParametersSet event
        _assertCCTPDomainParametersSetEvent({
            log               : logs[3],
            destinationDomain : XLAYER_CCTP_DOMAIN,
            mintRecipient     : XLAYER_CCTP_MINT_RECIPIENT,
            minFeeCapRate     : CCTP_MIN_FEE_CAP_RATE,
            maxFeeCapRate     : CCTP_MAX_FEE_CAP_RATE
        });

        // Assert ERC4626MaxExchangeRateSet event
        _assertERC4626MaxExchangeRateSetEvent({
            log             : logs[4],
            token           : Ethereum.SUSDC,
            maxExchangeRate : 1e25
        });
    }

    /**********************************************************************************************/
    /*** Event tests                                                                            ***/
    /**********************************************************************************************/

    function test_administeredAgentEvents() external {
        _assertAdministeredAgentEvents();
    }

    function test_accessControlsEvents() external {
        _assertAccessControlsEvents();
    }

    function test_almProxyEvents() external {
        _assertALMProxyEvents();
    }

    function test_rateLimitsEvents() external {
        _assertRateLimitsEvents();
    }

    function test_controllerEvents() external {
        _assertControllerEvents();
    }

}

contract MainnetPostDeployTestsStaging is MainnetPostDeployEventTestsBase {

    using stdJson for string;

    function _setUpDeployment() internal override {
        // CCTP facet onboarding.
        XLAYER_CCTP_MINT_RECIPIENT = 0x9e8741C793D695ED6660f7B2860FE011110D5869;

        CCTP_MIN_FEE_CAP_RATE = 0;
        CCTP_MAX_FEE_CAP_RATE = 100;
        CCTP_USDC_MAX_AMOUNT  = 10e6;
        CCTP_USDC_SLOPE       = uint256(100e6) / 1 hours;

        // ERC4626 facet onboarding.
        ERC4626_USDC_MAX_AMOUNT = 10e6;
        ERC4626_USDC_SLOPE      = uint256(100e6) / 1 hours;

        string memory json = vm.readFile("deployments/mainnet-staging.json");

        _setUpAddresses(Addresses({
            agentFactory      : json.readAddress(".agentFactory"),
            assembler         : json.readAddress(".defaultPAUAssembler"),
            beacon            : json.readAddress(".beacon"),
            pauFactory        : json.readAddress(".pauFactory"),
            accessControls    : json.readAddress(".accessControls"),
            administeredAgent : json.readAddress(".administeredAgent"),
            almProxy          : json.readAddress(".proxy"),
            controller        : json.readAddress(".controller"),
            rateLimits        : json.readAddress(".rateLimits"),
            admin             : json.readAddress(".admin"),
            deployer          : json.readAddress(".deployer"),
            relayer           : json.readAddress(".relayer"),
            freezer           : json.readAddress(".freezer")
        }));
    }

    function _logsFor(address emitter) internal override returns (RawLog[] memory logs) {
        return _getEvents(block.chainid, emitter, "");
    }

    function _getBlock() internal override pure returns (uint256) {
        return 25941422;
    }

}
