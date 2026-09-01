// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { console2 } from "../lib/forge-std/src/console2.sol";

import { CCTPv2Forwarder } from "../lib/diamond-pau/lib/grove-xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { Base }     from "../lib/spark-address-registry/src/Base.sol";
import { Ethereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { IAdministeredAgent } from "../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { IMainnetControllerFull as IControllerFull } from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

import { InitPAULib } from "../src/InitPAULib.sol";

interface IAccessControlsLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function revokeRole(bytes32 role, address account) external;

}

interface IRateLimitsLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function revokeRole(bytes32 role, address account) external;

    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;

}

contract ConfigureSparkPAUStaging is Script {

    using stdJson     for string;
    using ScriptTools for string;

    IAccessControlsLike internal accessControls;
    IControllerFull     internal controller;
    IRateLimitsLike     internal rateLimits;
    IAdministeredAgent  internal administeredAgent;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory fileSlug = string(abi.encodePacked("config-", chain, "-", "staging"));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "ConfigureSparkPAUStaging/invalid-chain-id");

        controller        = IControllerFull(config.readAddress(".controller"));
        rateLimits        = IRateLimitsLike(controller.rateLimits());
        accessControls    = IAccessControlsLike(controller.accessControls());
        administeredAgent = IAdministeredAgent(config.readAddress(".administeredAgent"));

        address admin    = config.readAddress(".admin");
        address deployer = config.readAddress(".deployer");

        require(admin != deployer, "ConfigureSparkPAUStaging/admin-is-deployer");

        vm.startBroadcast();

        require(msg.sender == deployer, "ConfigureSparkPAUStaging/sender-not-deployer");

        // Step 1: Initialize PAU stack.

        bytes32[] memory integrationIds = new bytes32[](1);

        integrationIds[0] = "CCTP_FACET";

        address[] memory accessControlAdmins = new address[](1);
        address[] memory rateLimitsAdmins    = new address[](1);

        accessControlAdmins[0] = admin;
        rateLimitsAdmins[0]    = admin;

        InitPAULib.AdminConfig memory adminConfig = InitPAULib.AdminConfig({
            accessControlAdmins : accessControlAdmins,
            rateLimitsAdmins    : rateLimitsAdmins
        });

        address[] memory agentAdmins   = new address[](1);
        address[] memory agentActors   = new address[](2);
        address[] memory agentGrantors = new address[](0);
        address[] memory agentRevokers = new address[](1);

        agentAdmins[0]   = admin;
        agentActors[0]   = Ethereum.ALM_RELAYER_MULTISIG;
        agentActors[1]   = Ethereum.ALM_BACKSTOP_RELAYER_MULTISIG;
        agentRevokers[0] = Ethereum.ALM_FREEZER_MULTISIG;

        InitPAULib.AdministeredAgentConfig[] memory agentConfigs = new InitPAULib.AdministeredAgentConfig[](1);

        agentConfigs[0] = InitPAULib.AdministeredAgentConfig({
            agent    : address(administeredAgent),
            admins   : agentAdmins,
            actors   : agentActors,
            grantors : agentGrantors,
            revokers : agentRevokers
        });

        InitPAULib.initPAU(address(controller), integrationIds, adminConfig, agentConfigs);

        console2.log("PAU stack initialized");

        // Step 2: Onboard Facets

        _onboardCCTPFacet();

        // Step 3: Remove deployer as admin of AccessControls, AdministeredAgent and RateLimits.

        accessControls.revokeRole(accessControls.DEFAULT_ADMIN_ROLE(), deployer);
        rateLimits.revokeRole(rateLimits.DEFAULT_ADMIN_ROLE(),         deployer);

        administeredAgent.removeAdmin(deployer);

        console2.log("AccessControls, AdministeredAgent and RateLimits roles configured");

        vm.stopBroadcast();
    }

    function _onboardCCTPFacet() internal {
        // Set domain parameters
        controller.cctp_setDomainParameters(
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(uint256(uint160(Base.ALM_PROXY))),
            0,
            100
        );

        // Set rate limits
        rateLimits.setRateLimitData(controller.cctp_toCCTPRateLimitKey(), 10e6, 0);

        rateLimits.setRateLimitData(
            controller.cctp_getToDomainRateLimitKey(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE),
            10e6,
            0
        );
    }

}
