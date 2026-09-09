// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { stdJson }  from "../../../lib/forge-std/src/StdJson.sol";

import { IEnumerableIntegrations as IEI } from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { PostDeployTestBase } from "../../PostDeployTestBase.t.sol";

interface ISparkVaultLike {

    event DepositCapSet(uint256 oldCap, uint256 newCap);

    function TAKER_ROLE() external view returns (bytes32);

    function hasRole(bytes32 role, address account) external view returns (bool);

}

abstract contract XLayerPostDeployTestsBase is PostDeployTestBase {

    bytes32 internal constant CCTP_FACET_ID           = "CCTP_FACET";
    bytes32 internal constant TRANSFER_ASSET_FACET_ID = "TRANSFER_ASSET_FACET";
    bytes32 internal constant SPARK_VAULT_FACET_ID    = "SPARK_VAULT_FACET";

    uint32 internal constant ETHEREUM_CCTP_DOMAIN = 0;

    address internal constant USDC = 0xB6CEceAB302E2E4948951eE7843FC24E92933061;

    address internal ETHEREUM_CCTP_MINT_RECIPIENT;

    uint32  internal CCTP_MIN_FEE_CAP_RATE;
    uint32  internal CCTP_MAX_FEE_CAP_RATE;

    uint256 internal CCTP_USDC_MAX_AMOUNT;
    uint256 internal CCTP_USDC_SLOPE;
    uint256 internal TRANSFER_ASSET_USDC_MAX_AMOUNT;
    uint256 internal TRANSFER_ASSET_USDC_SLOPE;

    address internal SPUSDC;

    uint256 internal SPARK_VAULT_USDC_MAX_AMOUNT;
    uint256 internal SPARK_VAULT_USDC_SLOPE;

    function setUp() public virtual override {
        super.setUp();

        vm.createSelectFork(getChain("xlayer").rpcUrl, _getBlock());

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
        assertEq(ISparkVaultLike(SPUSDC).hasRole(ISparkVaultLike(SPUSDC).TAKER_ROLE(), address(almProxy)), true);

        // 3b. Rate limits state

        _assertRateLimitData(controller.sparkVault_getTakeRateLimitKey(SPUSDC), SPARK_VAULT_USDC_MAX_AMOUNT, SPARK_VAULT_USDC_SLOPE);
    }

}

abstract contract XLayerPostDeployEventTestsBase is XLayerPostDeployTestsBase {

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
            key       : controller.cctp_getToDomainRateLimitKey(ETHEREUM_CCTP_DOMAIN),
            maxAmount : CCTP_USDC_MAX_AMOUNT,
            slope     : CCTP_USDC_SLOPE
        });

        // Assert transferAsset_getTransferRateLimitKey(USDC, SPUSDC) rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[6],
            key       : controller.transferAsset_getTransferRateLimitKey(USDC, SPUSDC),
            maxAmount : TRANSFER_ASSET_USDC_MAX_AMOUNT,
            slope     : TRANSFER_ASSET_USDC_SLOPE
        });

        // Assert sparkVault_getTakeRateLimitKey(SPUSDC) rate limit
        _assertRateLimitDataSetEvent({
            log       : logs[7],
            key       : controller.sparkVault_getTakeRateLimitKey(SPUSDC),
            maxAmount : SPARK_VAULT_USDC_MAX_AMOUNT,
            slope     : SPARK_VAULT_USDC_SLOPE
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

        // Assert TRANSFER_ASSET_FACET_ID integration set event
        _assertIntegrationSetEvent({
            log           : logs[2],
            integrationId : TRANSFER_ASSET_FACET_ID
        });

        // Assert SPARK_VAULT_FACET_ID integration set event
        _assertIntegrationSetEvent({
            log           : logs[3],
            integrationId : SPARK_VAULT_FACET_ID
        });

        // Assert CCTPDomainParametersSet event
        _assertCCTPDomainParametersSetEvent({
            log               : logs[4],
            destinationDomain : ETHEREUM_CCTP_DOMAIN,
            mintRecipient     : ETHEREUM_CCTP_MINT_RECIPIENT,
            minFeeCapRate     : CCTP_MIN_FEE_CAP_RATE,
            maxFeeCapRate     : CCTP_MAX_FEE_CAP_RATE
        });
    }

    function _assertSparkVaultEvents() internal {
        RawLog[] memory logs = _logsFor(SPUSDC);

        assertEq(logs.length, 2);

        // Assert DepositCapSet event
        _assertDepositCapSetEvent({
            log        : logs[0],
            depositCap : 1_000_000e6
        });

        // Grant almProxy TAKER_ROLE
        _assertRoleGrantedEvent({
            log     : logs[1],
            role    : ISparkVaultLike(SPUSDC).TAKER_ROLE(),
            account : address(almProxy),
            sender  : deployer
        });
    }

    function _assertDepositCapSetEvent(RawLog memory log, uint256 depositCap) internal pure {
        ( , uint256 loggedNewCap ) = abi.decode(log.data, (uint256, uint256));

        assertEq(log.topics[0], ISparkVaultLike.DepositCapSet.selector);

        assertEq(loggedNewCap, depositCap);
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

    function test_sparkVaultEvents() external {
        _assertSparkVaultEvents();
    }

}

contract XLayerPostDeployTestsStaging is XLayerPostDeployTestsBase {

    using stdJson for string;

    function _setUpDeployment() internal override {
        string memory json = vm.readFile("deployments/xlayer-staging.json");

        // CCTP facet onboarding.
        ETHEREUM_CCTP_MINT_RECIPIENT = 0x5A7e6fF9A4836275b469C7413fA40294661A2017;

        CCTP_MIN_FEE_CAP_RATE = 0;
        CCTP_MAX_FEE_CAP_RATE = 100;
        CCTP_USDC_MAX_AMOUNT  = 10e6;
        CCTP_USDC_SLOPE       = uint256(100e6) / 1 hours;

        // TransferAsset facet onboarding.
        TRANSFER_ASSET_USDC_MAX_AMOUNT = 10e6;
        TRANSFER_ASSET_USDC_SLOPE      = uint256(100e6) / 1 hours;

        // SparkVault onboarding.
        SPUSDC = json.readAddress(".spUSDC");

        SPARK_VAULT_USDC_MAX_AMOUNT = 10e6;
        SPARK_VAULT_USDC_SLOPE      = uint256(100e6) / 1 hours;

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

    // Not exercised: this contract inherits the state tests only, because the Etherscan v2 log
    // endpoint does not cover chain 196. The X Layer events are asserted by XLayerForkDeployTests,
    // which records them on a fork.
    function _logsFor(address emitter) internal override returns (RawLog[] memory logs) {
        return _getEvents(block.chainid, emitter, "");
    }

    function _getBlock() internal override pure returns (uint256) {
        return 70207296;
    }

}
