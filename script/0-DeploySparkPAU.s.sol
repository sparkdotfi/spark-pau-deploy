// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { console2 }        from "../lib/forge-std/src/console2.sol";
import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { Ethereum as SkyEthereum }   from "../lib/sky-pau-registry/src/Ethereum.sol";
import { Ethereum as SparkEthereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { IPAUFactory } from "../lib/diamond-pau/src/interfaces/IPAUFactory.sol";

interface IAdministeredAgentFactoryLike {

    function deploy(address admin) external returns (address administeredAgent);

}

contract DeploySparkPAU is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("deploy-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "DeploySparkPAU/Invalid chain ID");

        IPAUFactory                   pauFactory               = IPAUFactory(SkyEthereum.PAU_FACTORY);
        IAdministeredAgentFactoryLike administeredAgentFactory = IAdministeredAgentFactoryLike(SkyEthereum.ADMINISTERED_AGENT_FACTORY);

        address deployer = config.readAddress(".deployer");

        vm.startBroadcast();

        require(msg.sender == deployer, "DeploySparkPAU/sender-not-deployer");

        // Step 1: Deploy AccessControls contract.
        //         Deployer as the temporary admin to run configuration script.

        address accessControls = pauFactory.deployAccessControls(deployer);

        console2.log("AccessControls deployed at: ", accessControls);

        // Step 2: Deploy Controller contract.

        address controller = pauFactory.deployController({
            accessControls : accessControls,
            proxy          : SparkEthereum.ALM_PROXY,
            rateLimits     : SparkEthereum.ALM_RATE_LIMITS
        });

        console2.log("Controller deployed at: ", controller);

        // Step 3: Deploy AdministeredAgent contract.

        address administeredAgent = administeredAgentFactory.deploy(deployer);

        console2.log("AdministeredAgent deployed at: ", administeredAgent);

        vm.stopBroadcast();

        ScriptTools.exportContract(fileSlug, "accessControls",    address(accessControls));
        ScriptTools.exportContract(fileSlug, "administeredAgent", address(administeredAgent));
        ScriptTools.exportContract(fileSlug, "controller",        address(controller));
    }

}
