// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { console2 }        from "../lib/forge-std/src/console2.sol";
import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { Ethereum as SkyEthereum }   from "../lib/sky-pau-registry/src/Ethereum.sol";

import { IPAUFactory } from "../lib/diamond-pau/src/interfaces/IPAUFactory.sol";

interface IAdministeredAgentFactoryLike {

    function deploy(address admin) external returns (address administeredAgent);

}

abstract contract DeploySparkPAUBase is Script {

    using stdJson     for string;
    using ScriptTools for string;

    IPAUFactory                   pauFactory               = IPAUFactory(SkyEthereum.PAU_FACTORY);
    IAdministeredAgentFactoryLike administeredAgentFactory = IAdministeredAgentFactoryLike(SkyEthereum.ADMINISTERED_AGENT_FACTORY);

    address internal admin;
    address internal deployer;

    function run() public virtual {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("deploy-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "DeploySparkPAUBase/Invalid chain ID");

        admin    = config.readAddress(".admin");
        deployer = config.readAddress(".deployer");

        vm.startBroadcast();

        require(msg.sender == deployer, "DeploySparkPAUBase/sender-not-deployer");

        // Step 1: Deploy AccessControls, ALMProxy and RateLimits as Controller contract.

        address accessControls = _deployAccessControls();
        address proxy          = _deployALMProxy();
        address rateLimits     = _deployRateLimits();
        address controller     = _deployController(accessControls, proxy, rateLimits);

        // Step 2: Deploy AdministeredAgent contract.

        address administeredAgent = _deployAdministeredAgent();

        vm.stopBroadcast();

        if (accessControls    != address(0)) ScriptTools.exportContract(fileSlug, "accessControls",    address(accessControls));
        if (proxy             != address(0)) ScriptTools.exportContract(fileSlug, "almProxy",          address(proxy));
        if (rateLimits        != address(0)) ScriptTools.exportContract(fileSlug, "rateLimits",        address(rateLimits));
        if (controller        != address(0)) ScriptTools.exportContract(fileSlug, "controller",        address(controller));
        if (administeredAgent != address(0)) ScriptTools.exportContract(fileSlug, "administeredAgent", address(administeredAgent));
    }

    function _deployAccessControls() internal virtual returns (address accessControls) {
        accessControls = pauFactory.deployAccessControls(admin);

        console2.log("AccessControls deployed at: ", accessControls);
    }

    function _deployALMProxy() internal virtual returns (address proxy) {
        proxy = pauFactory.deployALMProxy(admin);

        console2.log("ALMProxy deployed at: ", proxy);
    }

    function _deployRateLimits() internal virtual returns (address rateLimits) {
        rateLimits = pauFactory.deployRateLimits(admin);

        console2.log("RateLimits deployed at: ", rateLimits);
    }

    function _deployController(
        address accessControls,
        address proxy,
        address rateLimits
    ) internal virtual returns (address controller) {
        controller = pauFactory.deployController({
            accessControls : accessControls,
            proxy          : proxy,
            rateLimits     : rateLimits
        });

        console2.log("Controller deployed at: ", controller);
    }

    function _deployAdministeredAgent() internal virtual returns (address administeredAgent) {
        administeredAgent = administeredAgentFactory.deploy(admin);

        console2.log("AdministeredAgent deployed at: ", administeredAgent);
    }

}
