// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { stdJson } from "../lib/forge-std/src/StdJson.sol";

import {
    IAccessControlEnumerable
} from "../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

import { DeploySparkPAUFullMainnet, DeploySparkPAUFullXLayer }       from "../script/full-pau/0-DeploySparkPAUFull.s.sol";
import { ConfigureSparkPAUFullMainnet, ConfigureSparkPAUFullXLayer } from "../script/full-pau/1-ConfigureSparkPAUFull.s.sol";
import { PAUDeployment }                                             from "../script/full-pau/PAUDeployment.sol";

import { PostDeployTestBase } from "./PostDeployTestBase.t.sol";

/**************************************************************************************************/
/*** Script subclasses                                                                          ***/
/**************************************************************************************************/
// The real scripts with their four hooks overridden: they run on the fork the test has already
// selected, read the config the test built in memory, skip the --sender check (inside a test
// `msg.sender` is the test contract, not the broadcaster) and write nothing to script/output/.

contract ForkDeploySparkPAUFullMainnet is DeploySparkPAUFullMainnet {

    string internal configJson;

    constructor(string memory _configJson) {
        configJson = _configJson;
    }

    function _selectFork(string memory) internal override { }

    function _loadConfig(string memory) internal override returns (string memory) {
        return configJson;
    }

    function _checkBroadcaster(address) internal override { }

    function _export(string memory, PAUDeployment memory) internal override { }

}

contract ForkDeploySparkPAUFullXLayer is DeploySparkPAUFullXLayer {

    string internal configJson;

    constructor(string memory _configJson) {
        configJson = _configJson;
    }

    function _selectFork(string memory) internal override { }

    function _loadConfig(string memory) internal override returns (string memory) {
        return configJson;
    }

    function _checkBroadcaster(address) internal override { }

    function _export(string memory, PAUDeployment memory) internal override { }

}

contract ForkConfigureSparkPAUFullMainnet is ConfigureSparkPAUFullMainnet {

    string internal configJson;

    constructor(string memory _configJson) {
        configJson = _configJson;
    }

    function _selectFork(string memory) internal override { }

    function _loadConfig(string memory) internal override returns (string memory) {
        return configJson;
    }

    function _checkBroadcaster(address) internal override { }

}

contract ForkConfigureSparkPAUFullXLayer is ConfigureSparkPAUFullXLayer {

    string internal configJson;

    constructor(string memory _configJson) {
        configJson = _configJson;
    }

    function _selectFork(string memory) internal override { }

    function _loadConfig(string memory) internal override returns (string memory) {
        return configJson;
    }

    function _checkBroadcaster(address) internal override { }

}

/**************************************************************************************************/
/*** Fork deploy test base                                                                      ***/
/**************************************************************************************************/

abstract contract ForkDeployTestBase is PostDeployTestBase {

    using stdJson for string;

    string internal constant DEPLOY_INPUT_KEY = "fork-deploy-input";
    string internal constant CONFIG_INPUT_KEY = "fork-config-input";

    function _logsFor(address emitter) internal override returns (RawLog[] memory logs) {
        return _recordedLogsFor(emitter);
    }

    /**********************************************************************************************/
    /*** External preconditions                                                                 ***/
    /**********************************************************************************************/

    // The configure script grants and revokes DEFAULT_ADMIN_ROLE on contracts that predate the
    // deployment (the Beacon on both chains, the spUSDC Spark vault on X Layer), and whose admin
    // has since been handed from the real deployer to the real admin on chain. A fresh deployer
    // therefore reverts with AccessControlUnauthorizedAccount on the fork. This reconstructs the
    // precondition the real deployment ran under: whoever holds the role on the fork now grants
    // it to the fork deployer, exactly as the real deployer held it at real deploy time. The
    // scripts themselves are left semantically identical to production.
    function _grantDefaultAdminRole(address target, address account) internal {
        address roleAdmin = IAccessControlEnumerable(target).getRoleMember(DEFAULT_ADMIN_ROLE, 0);

        vm.prank(roleAdmin);
        IAccessControlEnumerable(target).grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /**********************************************************************************************/
    /*** Script set up helpers                                                                  ***/
    /**********************************************************************************************/

    // The scripts read CHAIN and ENV like `make deploy-*` sets them. Under test both only feed
    // `_selectFork` (a no-op) and the input/output file slug (unused, the config is injected and
    // nothing is exported), so it does not matter which test contract set them last.
    function _setUpScriptEnv(string memory chain) internal {
        vm.setEnv("CHAIN", chain);
        vm.setEnv("ENV",   "staging");
    }

    // Deploy input: the static keys are read from the checked-in input file, only `admin` and
    // `deployer` are the fork test's own address. Like in the checked-in file both hold the
    // deployer, so that the configure step can still run (see the Makefile header).
    function _deployInput(string memory input, address _deployer) internal returns (string memory json) {
        vm.serializeUint(DEPLOY_INPUT_KEY,    "chainId",             input.readUint(".chainId"));
        vm.serializeAddress(DEPLOY_INPUT_KEY, "defaultPAUAssembler", input.readAddress(".defaultPAUAssembler"));
        vm.serializeAddress(DEPLOY_INPUT_KEY, "relayer",             input.readAddress(".relayer"));
        vm.serializeAddress(DEPLOY_INPUT_KEY, "freezer",             input.readAddress(".freezer"));
        vm.serializeAddress(DEPLOY_INPUT_KEY, "admin",               _deployer);

        json = vm.serializeAddress(DEPLOY_INPUT_KEY, "deployer", _deployer);
    }

    // Config input, chain-agnostic part: the deployment keys come from the deploy script's return
    // value, `admin` and `deployer` are the fork test's own addresses. The chain-specific facet
    // keys are appended by the concrete test under the same object key.
    function _configInput(
        string        memory input,
        PAUDeployment memory deployment,
        address              _admin,
        address              _deployer
    )
        internal
        returns (string memory json)
    {
        vm.serializeUint(CONFIG_INPUT_KEY,    "chainId",           input.readUint(".chainId"));
        vm.serializeAddress(CONFIG_INPUT_KEY, "controller",        deployment.controller);
        vm.serializeAddress(CONFIG_INPUT_KEY, "administeredAgent", deployment.allocatorAgent);
        vm.serializeAddress(CONFIG_INPUT_KEY, "beacon",            deployment.beacon);
        vm.serializeAddress(CONFIG_INPUT_KEY, "admin",             _admin);

        json = vm.serializeAddress(CONFIG_INPUT_KEY, "deployer", _deployer);
    }

}
