// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { console2 }        from "../lib/forge-std/src/console2.sol";
import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

interface IAdministeredAgentFactoryLike {

    function deploy(address admin) external returns (address administeredAgent);

}

interface IPAUFactoryLike {

    function deployAccessControls(address admin) external returns (address accessControls);

    function deployALMProxy(address admin) external returns (address proxy);

    function deployRateLimits(address admin) external returns (address rateLimits);

    function deployController(address accessControls, address proxy, address rateLimits) external returns (address controller);

}

abstract contract DeploySparkPAUBase is Script {

    using stdJson     for string;
    using ScriptTools for string;

    IPAUFactoryLike               pauFactory;
    IAdministeredAgentFactoryLike administeredAgentFactory;

    address internal admin;
    address internal deployer;
    address internal almProxy;

    function run() public virtual {
        _setXLayerAndRHChainForks();

        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork("https://rpc.xlayer.tech");

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("deploy-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "DeploySparkPAUBase/Invalid chain ID");

        admin    = config.readAddress(".admin");
        deployer = config.readAddress(".deployer");
        almProxy = config.readAddress(".almProxy");

        pauFactory               = IPAUFactoryLike(config.readAddress(".pauFactory"));
        administeredAgentFactory = IAdministeredAgentFactoryLike(config.readAddress(".agentFactory"));

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

        ScriptTools.exportContract(fileSlug, "accessControls",    address(accessControls));
        ScriptTools.exportContract(fileSlug, "almProxy",          address(proxy));
        ScriptTools.exportContract(fileSlug, "rateLimits",        address(rateLimits));
        ScriptTools.exportContract(fileSlug, "controller",        address(controller));
        ScriptTools.exportContract(fileSlug, "administeredAgent", address(administeredAgent));
    }

    function _deployAccessControls() internal virtual returns (address accessControls) {
        accessControls = pauFactory.deployAccessControls(admin);

        console2.log("AccessControls deployed at: ", accessControls);
    }

    function _deployALMProxy() internal virtual returns (address proxy) { }

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

    function _setXLayerAndRHChainForks() internal {
        setChain("xlayer", ChainData({
            name    : "XLayer",
            rpcUrl  : vm.envString("XLAYER_RPC_URL"),
            chainId : 196
        }));

        setChain("robinhood_chain", ChainData({
            name    : "Robinhood Chain",
            rpcUrl  : vm.envString("RH_RPC_URL"),
            chainId : 4663
        }));
    }

}
