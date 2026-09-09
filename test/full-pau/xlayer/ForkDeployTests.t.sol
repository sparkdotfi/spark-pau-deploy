// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { stdJson } from "../../../lib/forge-std/src/StdJson.sol";

import { PAUDeployment } from "../../../script/full-pau/PAUDeployment.sol";

import {
    ForkDeployTestBase,
    ForkDeploySparkPAUFullXLayer,
    ForkConfigureSparkPAUFullXLayer
} from "../../ForkDeployTestBase.t.sol";

import { IDefaultPAUAssemblerLike, PostDeployTestBase } from "../../PostDeployTestBase.t.sol";

import { XLayerPostDeployEventTestsBase, XLayerPostDeployTestsBase } from "./PostDeployTests.t.sol";

// Runs the real deploy and configure scripts on an X Layer fork and asserts the result with the
// same state assertions XLayerPostDeployTestsStaging runs against the real chain, plus the event
// assertions that Etherscan cannot provide for chain 196.
contract XLayerForkDeployTests is XLayerPostDeployEventTestsBase, ForkDeployTestBase {

    using stdJson for string;

    string internal constant DEPLOY_INPUT = "script/input/196/deploy-pau-with-assembler-xlayer-staging.json";
    string internal constant CONFIG_INPUT = "script/input/196/config-pau-with-assembler-xlayer-staging.json";

    function setUp() public override(XLayerPostDeployTestsBase, PostDeployTestBase) {
        super.setUp();
    }

    function _setUpDeployment() internal override {
        string memory deployInput = vm.readFile(DEPLOY_INPUT);
        string memory configInput = vm.readFile(CONFIG_INPUT);

        address _admin    = makeAddr("admin");
        address _deployer = makeAddr("deployer");

        // CCTP facet onboarding.
        ETHEREUM_CCTP_MINT_RECIPIENT = configInput.readAddress(".ethereumAlmProxy");

        CCTP_MIN_FEE_CAP_RATE = 0;
        CCTP_MAX_FEE_CAP_RATE = 100;
        CCTP_USDC_MAX_AMOUNT  = 10e6;
        CCTP_USDC_SLOPE       = uint256(100e6) / 1 hours;

        // TransferAsset facet onboarding.
        TRANSFER_ASSET_USDC_MAX_AMOUNT = 10e6;
        TRANSFER_ASSET_USDC_SLOPE      = uint256(100e6) / 1 hours;

        // SparkVault onboarding.
        SPUSDC = configInput.readAddress(".spusdc");

        SPARK_VAULT_USDC_MAX_AMOUNT = 10e6;
        SPARK_VAULT_USDC_SLOPE      = uint256(100e6) / 1 hours;

        // The real deployer held DEFAULT_ADMIN_ROLE on the Beacon and on the spUSDC Spark vault,
        // see ForkDeployTestBase.
        _grantDefaultAdminRole(configInput.readAddress(".beacon"), _deployer);
        _grantDefaultAdminRole(SPUSDC,                             _deployer);

        _setUpScriptEnv("xlayer");

        vm.recordLogs();

        PAUDeployment memory deployment = new ForkDeploySparkPAUFullXLayer(
            _deployInput(deployInput, _deployer)
        ).run();

        new ForkConfigureSparkPAUFullXLayer(
            _xlayerConfigInput(configInput, deployment, _admin, _deployer)
        ).run();

        _storeRecordedLogs();

        IDefaultPAUAssemblerLike _assembler = IDefaultPAUAssemblerLike(deployInput.readAddress(".defaultPAUAssembler"));

        _setUpAddresses(Addresses({
            agentFactory      : _assembler.administeredAgentFactory(),
            assembler         : address(_assembler),
            beacon            : deployment.beacon,
            pauFactory        : _assembler.pauFactory(),
            accessControls    : deployment.accessControls,
            administeredAgent : deployment.allocatorAgent,
            almProxy          : deployment.proxy,
            controller        : deployment.controller,
            rateLimits        : deployment.rateLimits,
            admin             : _admin,
            deployer          : _deployer,
            relayer           : deployInput.readAddress(".relayer"),
            freezer           : deployInput.readAddress(".freezer")
        }));
    }

    function _xlayerConfigInput(
        string        memory input,
        PAUDeployment memory deployment,
        address              _admin,
        address              _deployer
    )
        internal
        returns (string memory json)
    {
        _configInput(input, deployment, _admin, _deployer);

        vm.serializeUint(CONFIG_INPUT_KEY,    "ethereumDomainId", input.readUint(".ethereumDomainId"));
        vm.serializeAddress(CONFIG_INPUT_KEY, "ethereumAlmProxy", input.readAddress(".ethereumAlmProxy"));
        vm.serializeAddress(CONFIG_INPUT_KEY, "usdc",             input.readAddress(".usdc"));

        json = vm.serializeAddress(CONFIG_INPUT_KEY, "spusdc", input.readAddress(".spusdc"));
    }

    function _getBlock() internal override pure returns (uint256) {
        return 70207296;
    }

}
