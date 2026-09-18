// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { console2 }        from "../../lib/forge-std/src/console2.sol";
import { Script, stdJson } from "../../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../../lib/dss-test/src/ScriptTools.sol";

import { Arbitrum } from "../../lib/spark-address-registry/src/Arbitrum.sol";

import { ParallelPAULib } from "../../src/ParallelPAULib.sol";

/**
 * @title  DeploySparkPAUParallelBase
 * @notice Deploys a Diamond PAU controller stack next to an EXISTING ALMProxy (parallel
 *         controller topology) on a chain that has no Diamond PAU infrastructure yet. See
 *         ParallelPAULib.deploy for the steps.
 *
 *         Everything deployed here is owned by `deployer` until the configure script hands it
 *         to `admin`. Nothing touches the existing ALMProxy.
 *
 *         Input:  script/input/{chainId}/deploy-parallel-{chain}-{env}.json
 *         Output: script/output/{chainId}/deploy-parallel-{chain}-{env}-{timestamp}.json
 */
abstract contract DeploySparkPAUParallelBase is Script {

    using stdJson     for string;
    using ScriptTools for string;

    ParallelPAULib.DeployParams internal params;

    function run() public virtual {
        vm.createSelectFork(getChain(_rpcAlias()).rpcUrl);

        string memory chain = _chainSlug();

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("deploy-parallel-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "DeploySparkPAUParallel/invalid-chain-id");

        params = ParallelPAULib.DeployParams({
            deployer           : config.readAddress(".deployer"),
            almProxy           : config.readAddress(".almProxy"),
            cctpTokenMessenger : config.readAddress(".cctpTokenMessenger"),
            usdc               : config.readAddress(".usdc")
        });

        _validateInputs();

        vm.startBroadcast();

        require(msg.sender == params.deployer, "DeploySparkPAUParallel/sender-not-deployer");

        ParallelPAULib.Deployment memory d = ParallelPAULib.deploy(params);

        vm.stopBroadcast();

        console2.log("Beacon deployed at:                   ", d.beacon);
        console2.log("CCTPFacet deployed at:                ", d.cctpFacet);
        console2.log("PAUFactory deployed at:               ", d.pauFactory);
        console2.log("AdministeredAgentFactory deployed at: ", d.agentFactory);
        console2.log("AccessControls deployed at:           ", d.accessControls);
        console2.log("RateLimits deployed at:               ", d.rateLimits);
        console2.log("Controller deployed at:               ", d.controller);
        console2.log("AdministeredAgent deployed at:        ", d.administeredAgent);

        ScriptTools.exportContract(fileSlug, "beacon",            d.beacon);
        ScriptTools.exportContract(fileSlug, "cctpFacet",         d.cctpFacet);
        ScriptTools.exportContract(fileSlug, "pauFactory",        d.pauFactory);
        ScriptTools.exportContract(fileSlug, "agentFactory",      d.agentFactory);
        ScriptTools.exportContract(fileSlug, "accessControls",    d.accessControls);
        ScriptTools.exportContract(fileSlug, "rateLimits",        d.rateLimits);
        ScriptTools.exportContract(fileSlug, "controller",        d.controller);
        ScriptTools.exportContract(fileSlug, "administeredAgent", d.administeredAgent);
        ScriptTools.exportContract(fileSlug, "proxy",             params.almProxy);
    }

    /**********************************************************************************************/
    /*** Virtual Functions                                                                      ***/
    /**********************************************************************************************/

    /// @dev forge-std chain alias used for the fork (reads `<ALIAS>_RPC_URL`).
    function _rpcAlias() internal virtual pure returns (string memory);

    /// @dev Short chain name used in input/output file names.
    function _chainSlug() internal virtual pure returns (string memory);

    /// @dev Chain-specific pinning of the input file, run before broadcasting.
    function _validateInputs() internal virtual view;

}

contract DeploySparkPAUParallelArbitrum is DeploySparkPAUParallelBase {

    function run() public override {
        super.run();
    }

    function _rpcAlias() internal pure override returns (string memory) {
        return "arbitrum_one";
    }

    function _chainSlug() internal pure override returns (string memory) {
        return "arbitrum";
    }

    /// @dev Pin the input file to the address registry so a typo cannot deploy against the
    ///      wrong custody contract, bridge or token.
    function _validateInputs() internal view override {
        require(params.almProxy           == Arbitrum.ALM_PROXY,            "DeploySparkPAUParallel/alm-proxy-mismatch");
        require(params.cctpTokenMessenger == Arbitrum.CCTP_TOKEN_MESSENGER, "DeploySparkPAUParallel/cctp-mismatch");
        require(params.usdc               == Arbitrum.USDC,                 "DeploySparkPAUParallel/usdc-mismatch");
    }

}
