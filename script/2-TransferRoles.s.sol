// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { console2 } from "../lib/forge-std/src/console2.sol";

interface IAccessControls {
    
    function grantRole(bytes32 role, address account) external;

    function setRoleRevoker(bytes32 role, bytes32 revokerRole) external;

    function revokeRole(bytes32 role, address account) external;

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

}

contract ConfigureController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    bytes32 constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");
    bytes32 constant FREEZER_ROLE   = keccak256("FREEZER_ROLE");

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));
        
        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("config-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "Invalid chain ID");

        IAccessControls accessControls = IAccessControls(config.readAddress(".accessControls"));

        address admin = config.readAddress(".admin");

        vm.startBroadcast();

        accessControls.grantRole(ALLOCATOR_ROLE, config.readAddress(".allocator"));
        accessControls.grantRole(FREEZER_ROLE,   config.readAddress(".freezer"));
        accessControls.grantRole(ALLOCATOR_ROLE, config.readAddress(".backstopAllocator"));

        accessControls.setRoleRevoker(ALLOCATOR_ROLE, FREEZER_ROLE);

        // Transfer DEFAULT_ADMIN_ROLE to final admin and revoke from deployer.

        accessControls.grantRole(accessControls.DEFAULT_ADMIN_ROLE(), admin);

        accessControls.revokeRole(accessControls.DEFAULT_ADMIN_ROLE(), msg.sender);

        console2.log("Admin transferred to: ", admin);

        vm.stopBroadcast();
    }

}
