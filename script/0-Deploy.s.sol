// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { AccessControls } from "../lib/diamond-pau/src/AccessControls.sol";
import { Controller }     from "../lib/diamond-pau/src/Controller.sol";

import { console2 } from "../lib/forge-std/src/console2.sol";

contract DeployAccessControls is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("config-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "Invalid chain ID");

        vm.startBroadcast();

        /// @dev Set admin as deployer initially to grant full control 
        ///      and then use TransferOwnership script to transfer and configure roles.
        address accessControls = address(new AccessControls({
            admin: config.readAddress(".admin")
        }));

        console2.log("AccessControls deployed to: ", accessControls);

        vm.stopBroadcast();

        ScriptTools.exportContract(fileSlug, "accessControls", address(accessControls));
    }

}

contract DeployController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));
        
        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("config-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "Invalid chain ID");

        vm.startBroadcast();

        address controller = address(new Controller({
            accessControls_ : config.readAddress(".accessControls"),
            beacon_         : config.readAddress(".beacon"),
            proxy_          : config.readAddress(".proxy"),
            rateLimits_     : config.readAddress(".rateLimits")
        }));

        console2.log("Controller deployed to: ", controller);

        vm.stopBroadcast();

        ScriptTools.exportContract(fileSlug, "controller", address(controller));
    }

}
