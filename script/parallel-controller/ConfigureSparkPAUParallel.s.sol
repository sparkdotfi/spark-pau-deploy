// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { console2 }        from "../../lib/forge-std/src/console2.sol";
import { Script, stdJson } from "../../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../../lib/dss-test/src/ScriptTools.sol";

import { Arbitrum } from "../../lib/spark-address-registry/src/Arbitrum.sol";
import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { ParallelPAULib } from "../../src/ParallelPAULib.sol";

/**
 * @title  ConfigureSparkPAUParallelBase
 * @notice Configures a parallel Diamond PAU controller stack deployed by
 *         DeploySparkPAUParallel and hands every admin role from `deployer` to `admin`. See
 *         ParallelPAULib.configure for the steps.
 *
 *         Deliberately NOT done here, both are governance spell actions on the existing ALMProxy:
 *           - ALMProxy.grantRole(CONTROLLER, controller)
 *           - RateLimits.setRateLimitData(...) for the CCTP keys
 *
 *         Input: script/input/{chainId}/config-parallel-{chain}-{env}.json
 */
abstract contract ConfigureSparkPAUParallelBase is Script {

    using stdJson     for string;
    using ScriptTools for string;

    ParallelPAULib.ConfigureParams internal params;

    string internal config;

    function run() public virtual {
        vm.createSelectFork(getChain(_rpcAlias()).rpcUrl);

        string memory chain = _chainSlug();

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("config-parallel-", chain, "-", env));

        config = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "ConfigureSparkPAUParallel/invalid-chain-id");

        params.controller        = config.readAddress(".controller");
        params.administeredAgent = config.readAddress(".administeredAgent");
        params.admin             = config.readAddress(".admin");
        params.deployer          = config.readAddress(".deployer");
        params.freezer           = config.readAddress(".freezer");
        params.grantor           = config.readAddress(".grantor");
        params.relayers          = config.readAddressArray(".relayers");

        _readCCTPDomains();
        _validateInputs();

        vm.startBroadcast();

        require(msg.sender == params.deployer, "ConfigureSparkPAUParallel/sender-not-deployer");

        ParallelPAULib.configure(params);

        vm.stopBroadcast();

        // Runs against the simulated end state before anything is broadcast.
        ParallelPAULib.checkConfigured(params);

        console2.log("Parallel controller configured. Admin handed from deployer to: ", params.admin);
        console2.log("Pending spell actions: ALMProxy CONTROLLER grant and CCTP rate limits.");
    }

    /**********************************************************************************************/
    /*** Virtual Functions                                                                      ***/
    /**********************************************************************************************/

    /// @dev forge-std chain alias used for the fork (reads `<ALIAS>_RPC_URL`).
    function _rpcAlias() internal virtual pure returns (string memory);

    /// @dev Short chain name used in input/output file names.
    function _chainSlug() internal virtual pure returns (string memory);

    function _readCCTPDomains() internal virtual;

    function _validateInputs() internal virtual view;

}

contract ConfigureSparkPAUParallelArbitrum is ConfigureSparkPAUParallelBase {

    using stdJson for string;

    function run() public override {
        super.run();
    }

    function _rpcAlias() internal pure override returns (string memory) {
        return "arbitrum_one";
    }

    function _chainSlug() internal pure override returns (string memory) {
        return "arbitrum";
    }

    /// @dev Arbitrum -> Ethereum only. Fee caps are 0/0: standard-finality, fee-free transfers,
    ///      matching the Spark Ethereum and X Layer production PAUs.
    function _readCCTPDomains() internal override {
        params.cctpDomains.push(ParallelPAULib.CCTPDomain({
            domainId      : uint32(config.readUint(".ethereumDomainId")),
            mintRecipient : config.readAddress(".ethereumAlmProxy"),
            minFeeCapRate : 0,
            maxFeeCapRate : 0
        }));
    }

    function _validateInputs() internal view override {
        require(params.admin == Arbitrum.SPARK_EXECUTOR, "ConfigureSparkPAUParallel/admin-not-spark-executor");

        // The mint recipient on Ethereum is the existing Spark ALMProxy, and nothing else.
        require(params.cctpDomains.length == 1,                                 "ConfigureSparkPAUParallel/one-domain");
        require(params.cctpDomains[0].domainId == 0,                            "ConfigureSparkPAUParallel/ethereum-domain-mismatch");
        require(params.cctpDomains[0].mintRecipient == Ethereum.ALM_PROXY,      "ConfigureSparkPAUParallel/ethereum-alm-proxy-mismatch");
    }

}
