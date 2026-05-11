// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test }   from "../../lib/forge-std/src/Test.sol";
import { VmSafe } from "../../lib/forge-std/src/Vm.sol";

import { IAccessControl } from "../../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { AccessControls } from "../../lib/diamond-pau/src/AccessControls.sol";

contract TransferRolesTests is Test {

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant ALLOCATOR_ROLE     = keccak256("ALLOCATOR_ROLE");
    bytes32 internal constant FREEZER_ROLE       = keccak256("FREEZER_ROLE");

    address internal constant ACCESS_CONTROLS    = 0x0000000000000000000000000000000000000000;
    address internal constant ADMIN              = 0x0000000000000000000000000000000000000000;
    address internal constant ALLOCATOR          = 0x0000000000000000000000000000000000000000;
    address internal constant BACKSTOP_ALLOCATOR = 0x0000000000000000000000000000000000000000;
    address internal constant DEPLOYER           = 0x0000000000000000000000000000000000000000;
    address internal constant FREEZER            = 0x0000000000000000000000000000000000000000;

    AccessControls internal accessControls;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        accessControls = AccessControls(ACCESS_CONTROLS);
    }

    function _getBlock() internal pure returns (uint256) {
        return 24684236;
    }

    function test_transferRoles() external view {
        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     ALLOCATOR),          true);
        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     BACKSTOP_ALLOCATOR), true);
        assertEq(accessControls.hasRole(FREEZER_ROLE,       FREEZER),            true);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, ADMIN),              true);

        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ROLE),     2);
        assertEq(accessControls.getRoleMemberCount(FREEZER_ROLE),       1);

        assertEq(accessControls.getRoleAdmin(ALLOCATOR_ROLE),   FREEZER_ROLE); // via setRoleRevoker.
        assertEq(accessControls.getRoleRevoker(ALLOCATOR_ROLE), FREEZER_ROLE); // via setRoleRevoker.

        // DEPLOYER has no roles on AccessControls.
        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     DEPLOYER), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), false);
        assertEq(accessControls.hasRole(FREEZER_ROLE,       DEPLOYER), false);
    }

    function test_postDeployEvents() external {
        VmSafe.EthGetLogs[] memory accessControlsAllLogs = _getEvents(block.chainid, ACCESS_CONTROLS, "");

        assertEq(accessControlsAllLogs.length, 6);

        // RoleGranted(DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER) from 0-Deploy.s.sol.
        assertEq(accessControlsAllLogs[0].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[0].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[0].topics[2]), DEPLOYER);
        assertEq(_toAddress(accessControlsAllLogs[0].topics[3]), DEPLOYER);

        // RoleGranted(ALLOCATOR_ROLE, ALLOCATOR, DEPLOYER) from 2-TransferRoles.s.sol.
        assertEq(accessControlsAllLogs[1].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[1].topics[1],             ALLOCATOR_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[1].topics[2]), ALLOCATOR);
        assertEq(_toAddress(accessControlsAllLogs[1].topics[3]), DEPLOYER);

        // RoleGranted(FREEZER_ROLE, FREEZER, DEPLOYER) from 2-TransferRoles.s.sol.
        assertEq(accessControlsAllLogs[2].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[2].topics[1],             FREEZER_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[2].topics[2]), FREEZER);
        assertEq(_toAddress(accessControlsAllLogs[2].topics[3]), DEPLOYER);

        // RoleGranted(ALLOCATOR_ROLE, BACKSTOP_ALLOCATOR, DEPLOYER) from 2-TransferRoles.s.sol.
        assertEq(accessControlsAllLogs[1].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[1].topics[1],             ALLOCATOR_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[1].topics[2]), BACKSTOP_ALLOCATOR);
        assertEq(_toAddress(accessControlsAllLogs[1].topics[3]), DEPLOYER);

        // RoleAdminChanged(ALLOCATOR_ROLE, DEFAULT_ADMIN_ROLE, FREEZER_ROLE) from 2-TransferRoles.s.sol.
        // From AccessControls.setRoleRevoker.
        assertEq(accessControlsAllLogs[3].topics[0], IAccessControl.RoleAdminChanged.selector);
        assertEq(accessControlsAllLogs[3].topics[1], ALLOCATOR_ROLE);
        assertEq(accessControlsAllLogs[3].topics[2], DEFAULT_ADMIN_ROLE);
        assertEq(accessControlsAllLogs[3].topics[3], FREEZER_ROLE);

        // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, DEPLOYER) from 2-TransferRoles.s.sol.
        // Role transfers from deployer to admin.
        assertEq(accessControlsAllLogs[4].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[4].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[4].topics[2]), ADMIN);
        assertEq(_toAddress(accessControlsAllLogs[4].topics[3]), DEPLOYER);

        // RoleRevoked(DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER) from 2-TransferRoles.s.sol.
        // Role revoked from deployer.
        assertEq(accessControlsAllLogs[5].topics[0],             IAccessControl.RoleRevoked.selector);
        assertEq(accessControlsAllLogs[5].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[5].topics[2]), DEPLOYER);
        assertEq(_toAddress(accessControlsAllLogs[5].topics[3]), DEPLOYER);
    }

    /**********************************************************************************************/
    /*** Get events helpers                                                                     ***/
    /**********************************************************************************************/

    function _getEvents(uint256 chainId, address target, bytes32 topic0)
        internal
        returns (VmSafe.EthGetLogs[] memory logs)
    {
        return _getEvents(chainId, target, topic0, 0);
    }

    function _getEvents(uint256 chainId, address target, bytes32 topic0, uint256 retryCount)
        internal
        returns (VmSafe.EthGetLogs[] memory logs)
    {
        string memory apiKey = vm.envString("ETHERSCAN_API_KEY");

        require(retryCount < 4, "Etherscan API returned non-success status");

        string memory url = string(
            abi.encodePacked(
                "https://api.etherscan.io/v2/api?",
                "chainid=",
                vm.toString(chainId),
                "&module=logs&action=getLogs",
                "&fromBlock=0",
                "&toBlock=latest",
                "&address=",
                vm.toString(target),
                "&page=1",
                "&offset=1000",
                "&apikey=",
                apiKey
            )
        );

        if (topic0 != 0) {
            url = string(abi.encodePacked(url, "&topic0=", vm.toString(topic0)));
        }

        string[] memory inputs = new string[](8);
        inputs[0] = "curl";
        inputs[1] = "-s";
        inputs[2] = "--request";
        inputs[3] = "GET";
        inputs[4] = "--url";
        inputs[5] = url;
        inputs[6] = "--header";
        inputs[7] = "accept: application/json";

        string memory response;

        for (uint256 i; i < 10; i++) {
            response = string(vm.ffi(inputs));

            if (_isEqual(vm.parseJsonString(response, string(abi.encodePacked(".message"))), "NOTOK")) {
                vm.sleep(1000);  // Prevent rate limiting from Etherscan (5 calls/second)
                continue;
            }

            break;
        }

        uint256 i = 0;
        for(; i < 1000; i++) {
            try vm.parseJsonAddress(response, string(abi.encodePacked(".result[", vm.toString(i), "].address"))) {
            } catch {
                logs = new VmSafe.EthGetLogs[](i);
                break;
            }
        }

        for(uint256 j; j < i; ++j) {
            logs[j] = VmSafe.EthGetLogs({
                emitter:          vm.parseJsonAddress(response,      string(abi.encodePacked(".result[", vm.toString(j), "].address"))),
                topics:           vm.parseJsonBytes32Array(response, string(abi.encodePacked(".result[", vm.toString(j), "].topics"))),
                data:             vm.parseJsonBytes(response,        string(abi.encodePacked(".result[", vm.toString(j), "].data"))),
                blockNumber:      uint64(0),
                blockHash:        bytes32(0),
                transactionHash:  bytes32(0),
                transactionIndex: uint64(0),
                logIndex:         uint8(0),
                removed:          false
            });
        }
    }

    function _isEqual(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function _toAddress(bytes32 b) internal pure returns (address) {
        return address(uint160(uint256(b)));
    }

    function _toBool(bytes32 b) internal pure returns (bool) {
        require(uint256(b) <= 1, "PostDeployTestBase/to-bool-failed");

        return uint256(b) == uint256(1);
    }


}
