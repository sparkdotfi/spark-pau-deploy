// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { stdJson } from "../../../lib/forge-std/src/StdJson.sol";

import { PAUDeployment } from "../../../script/full-pau/PAUDeployment.sol";

import {
    ForkDeployTestBase,
    ForkDeploySparkPAUFullMainnet,
    ForkConfigureSparkPAUFullMainnet
} from "../../ForkDeployTestBase.t.sol";

import { IDefaultPAUAssemblerLike, PostDeployTestBase } from "../../PostDeployTestBase.t.sol";

import { MainnetPostDeployEventTestsBase, MainnetPostDeployTestsBase } from "./PostDeployTests.t.sol";

// Runs the real deploy and configure scripts on a mainnet fork and asserts the result with the
// same state and event assertions MainnetPostDeployTestsStaging runs against the real chain.
contract MainnetForkDeployTests is MainnetPostDeployEventTestsBase, ForkDeployTestBase {

    using stdJson for string;

    string internal constant DEPLOY_INPUT = "script/input/1/deploy-pau-with-assembler-mainnet-staging.json";
    string internal constant CONFIG_INPUT = "script/input/1/config-pau-with-assembler-mainnet-staging.json";

    function setUp() public override(MainnetPostDeployTestsBase, PostDeployTestBase) {
        super.setUp();
    }

    function _setUpDeployment() internal override {
        string memory deployInput = vm.readFile(DEPLOY_INPUT);
        string memory configInput = vm.readFile(CONFIG_INPUT);

        address _admin    = makeAddr("admin");
        address _deployer = makeAddr("deployer");

        // CCTP facet onboarding.
        XLAYER_CCTP_MINT_RECIPIENT = configInput.readAddress(".xlayerAlmProxy");

        CCTP_MIN_FEE_CAP_RATE = 0;
        CCTP_MAX_FEE_CAP_RATE = 100;
        CCTP_USDC_MAX_AMOUNT  = 10e6;
        CCTP_USDC_SLOPE       = uint256(100e6) / 1 hours;

        // ERC4626 facet onboarding.
        ERC4626_USDC_MAX_AMOUNT = 10e6;
        ERC4626_USDC_SLOPE      = uint256(100e6) / 1 hours;

        // The real deployer held DEFAULT_ADMIN_ROLE on the Beacon, see ForkDeployTestBase.
        _grantDefaultAdminRole(configInput.readAddress(".beacon"), _deployer);

        _setUpScriptEnv("mainnet");

        vm.recordLogs();

        PAUDeployment memory deployment = new ForkDeploySparkPAUFullMainnet(
            _deployInput(deployInput, _deployer)
        ).run();

        new ForkConfigureSparkPAUFullMainnet(
            _mainnetConfigInput(configInput, deployment, _admin, _deployer)
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

    function _mainnetConfigInput(
        string        memory input,
        PAUDeployment memory deployment,
        address              _admin,
        address              _deployer
    )
        internal
        returns (string memory json)
    {
        _configInput(input, deployment, _admin, _deployer);

        vm.serializeUint(CONFIG_INPUT_KEY,    "xlayerDomainId", input.readUint(".xlayerDomainId"));
        vm.serializeAddress(CONFIG_INPUT_KEY, "xlayerAlmProxy", input.readAddress(".xlayerAlmProxy"));
        vm.serializeAddress(CONFIG_INPUT_KEY, "usdc",           input.readAddress(".usdc"));

        json = vm.serializeAddress(CONFIG_INPUT_KEY, "susdc", input.readAddress(".susdc"));
    }

    function _getBlock() internal override pure returns (uint256) {
        return 25941422;
    }

}
