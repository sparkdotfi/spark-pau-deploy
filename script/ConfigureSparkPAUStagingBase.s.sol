// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { console2 } from "../lib/forge-std/src/console2.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { IMainnetControllerFull as IControllerFull } from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

import { InitPAULib } from "../src/InitPAULib.sol";

interface IAccessControlsLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function revokeRole(bytes32 role, address account) external;

}

interface IAdministeredAgentLike {

    function removeAdmin(address admin) external;

}

interface IALMProxyLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function revokeRole(bytes32 role, address account) external;

}

interface IRateLimitsLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function revokeRole(bytes32 role, address account) external;

    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;

}

/// This script is meant to be overridden by the child contract to configure the PAU stack.
/// It will configure the PAU stack with a full deployment by default.
abstract contract ConfigureSparkPAUStagingBase is Script {

    using stdJson     for string;
    using ScriptTools for string;

    IAccessControlsLike    internal accessControls;
    IALMProxyLike          internal almProxy;
    IControllerFull        internal controller;
    IRateLimitsLike        internal rateLimits;
    IAdministeredAgentLike internal administeredAgent;

    address internal admin;
    address internal deployer;
    address internal relayer;
    address internal freezer;

    function run() public virtual {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory fileSlug = string(abi.encodePacked("config-", chain, "-", "staging"));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "ConfigureSparkPAUStagingBase/invalid-chain-id");

        controller        = IControllerFull(config.readAddress(".controller"));
        almProxy          = IALMProxyLike(controller.proxy());
        rateLimits        = IRateLimitsLike(controller.rateLimits());
        accessControls    = IAccessControlsLike(controller.accessControls());
        administeredAgent = IAdministeredAgentLike(config.readAddress(".administeredAgent"));

        admin    = config.readAddress(".admin");
        deployer = config.readAddress(".deployer");
        relayer  = config.readAddress(".relayer");
        freezer  = config.readAddress(".freezer");

        require(admin != deployer, "ConfigureSparkPAUStagingBase/admin-is-deployer");

        vm.startBroadcast();

        require(msg.sender == deployer, "ConfigureSparkPAUStagingBase/sender-not-deployer");

        // Step 1: Initialize PAU stack.

        bytes32[]                            memory integrationIds = _getIntegrationIds();
        InitPAULib.AdminConfig               memory adminConfig    = _getAdminConfig();
        InitPAULib.AdministeredAgentConfig[] memory agentConfigs   = _getAgentConfigs();

        InitPAULib.initPAU(_isFullDeployment(), address(controller), integrationIds, adminConfig, agentConfigs);

        console2.log("PAU stack initialized");

        // Step 2: Onboard Facets

        _onboardFacets();

        // Step 3: Remove deployer as admin of AccessControls, AdministeredAgent and RateLimits.

        _removeDeployerAsAdmin();

        console2.log("AccessControls, AdministeredAgent and RateLimits roles configured");

        vm.stopBroadcast();
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _isFullDeployment() internal virtual returns (bool isFullDeployment) {
        return true; // Full deployment by default
    }

    function _getIntegrationIds() internal virtual returns (bytes32[] memory integrationIds) { }

    function _onboardFacets() internal virtual { }

    function _getAdminConfig() internal virtual returns (InitPAULib.AdminConfig memory adminConfig) {
        address[] memory accessControlAdmins = new address[](1);
        address[] memory almProxyAdmins      = new address[](1);
        address[] memory rateLimitsAdmins    = new address[](1);

        accessControlAdmins[0] = admin;
        almProxyAdmins[0]      = admin;
        rateLimitsAdmins[0]    = admin;

        adminConfig = InitPAULib.AdminConfig({
            accessControlAdmins : accessControlAdmins,
            proxyAdmins         : almProxyAdmins,
            rateLimitsAdmins    : rateLimitsAdmins
        });
    }

    function _getAgentConfigs() internal virtual returns (InitPAULib.AdministeredAgentConfig[] memory agentConfigs) {
        address[] memory agentAdmins   = new address[](1);
        address[] memory agentActors   = new address[](1);
        address[] memory agentGrantors = new address[](0);
        address[] memory agentRevokers = new address[](1);

        agentAdmins[0]   = admin;
        agentActors[0]   = relayer;
        agentRevokers[0] = freezer;

        agentConfigs = new InitPAULib.AdministeredAgentConfig[](1);

        agentConfigs[0] = InitPAULib.AdministeredAgentConfig({
            agent    : address(administeredAgent),
            admins   : agentAdmins,
            actors   : agentActors,
            grantors : agentGrantors,
            revokers : agentRevokers
        });
    }

    function _removeDeployerAsAdmin() internal {
        accessControls.revokeRole(accessControls.DEFAULT_ADMIN_ROLE(), deployer);
        rateLimits.revokeRole(rateLimits.DEFAULT_ADMIN_ROLE(),         deployer);

        administeredAgent.removeAdmin(deployer);

        if (_isFullDeployment()) almProxy.revokeRole(almProxy.DEFAULT_ADMIN_ROLE(), deployer); // Revoking possible only in full deployment
    }

}
