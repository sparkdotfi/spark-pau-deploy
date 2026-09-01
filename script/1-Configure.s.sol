// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { console2 } from "../lib/forge-std/src/console2.sol";

import { CCTPv2Forwarder } from "../lib/diamond-pau/lib/grove-xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { Ethereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { IAdministeredAgent } from "../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { IMainnetControllerFull as IControllerFull } from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

interface IAccessControlsLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

}

interface IRateLimitsLike {

    function CONTROLLER() external view returns (bytes32);

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;

}

contract ConfigureController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    bytes32 internal constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");

    IAccessControlsLike internal accessControls;
    IControllerFull     internal controller;
    IRateLimitsLike     internal rateLimits;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("config-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "ConfigureController/invalid-chain-id");

        controller       = IControllerFull(config.readAddress(".controller"));
        rateLimits       = IRateLimitsLike(controller.rateLimits());
        accessControls   = IAccessControlsLike(controller.accessControls());

        address deployer = config.readAddress(".deployer");

        vm.startBroadcast();

        require(msg.sender == deployer, "ConfigureController/sender-not-deployer");

        // Step 1: Update integrations.

        _updateIntegrations();

        console2.log("Integrations updated");

        // Step 2: Grant ALLOCATOR_ROLE to administeredAgent.

        address administeredAgent = config.readAddress(".administeredAgent");

        accessControls.grantRole(ALLOCATOR_ROLE, administeredAgent);

        // Step 3: Add admins, actors and revokers to administeredAgent.

        IAdministeredAgent(administeredAgent).addActor(Ethereum.ALM_RELAYER_MULTISIG);
        IAdministeredAgent(administeredAgent).addActor(Ethereum.ALM_BACKSTOP_RELAYER_MULTISIG);
        IAdministeredAgent(administeredAgent).addRevoker(Ethereum.ALM_FREEZER_MULTISIG);

        // Step 4: Grant CONTROLLER_ROLE on rateLimits to controller.

        rateLimits.grantRole(rateLimits.CONTROLLER(), address(controller));

        // Step 5: Onboard Facets

        _onboardCCTPFacet();

        // Step 6: Transfer DEFAULT_ADMIN_ROLE on accessControls to admin and revoke from deployer.

        accessControls.grantRole(accessControls.DEFAULT_ADMIN_ROLE(),  Ethereum.SPARK_PROXY);
        accessControls.revokeRole(accessControls.DEFAULT_ADMIN_ROLE(), deployer);

        // Step 7: Add admin to administeredAgent and remove deployer.

        IAdministeredAgent(administeredAgent).addAdmin(Ethereum.SPARK_PROXY);
        IAdministeredAgent(administeredAgent).removeAdmin(deployer);

        // Step 8: Transfer DEFAULT_ADMIN_ROLE on rateLimits to admin and revoke from deployer.

        rateLimits.grantRole(rateLimits.DEFAULT_ADMIN_ROLE(),  Ethereum.SPARK_PROXY);
        rateLimits.revokeRole(rateLimits.DEFAULT_ADMIN_ROLE(), deployer);

        console2.log("AccessControls, AdministeredAgent and RateLimits roles configured and transferred");

        vm.stopBroadcast();
    }

    function _updateIntegrations() internal {
        bytes32[] memory integrationIds = new bytes32[](1);

        integrationIds[0] = "CCTP_FACET";

        controller.updateIntegrations(integrationIds);
    }

    function _onboardCCTPFacet() internal {
        // Set domain parameters
        controller.cctp_setDomainParameters(
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE,
            recipient,
            0,
            100
        );

        // Set rate limits
        rateLimits.setRateLimitData(controller.cctp_toCCTPRateLimitKey(), 100e6,0);

        rateLimits.setRateLimitData(
            controller.cctp_getToDomainRateLimitKey(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE),
            100e6,
            0
        );
    }

}
