// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { VmSafe } from "../lib/forge-std/src/Vm.sol";

import { IAccessControl }                 from "../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IEnumerableIntegrations as IEI } from "../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";
import { IMainnetControllerFull }         from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

import { AccessControls } from "../lib/diamond-pau/src/AccessControls.sol";
import { Beacon }         from "../lib/diamond-pau/src/Beacon.sol";

import { Ethereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { PostDeployTestBase } from "./PostDeployTestBase.t.sol";

contract PostDeployTests is PostDeployTestBase {

    // Paste from script output.
    address internal constant ACCESS_CONTROLS = 0x0000000000000000000000000000000000000000;
    address internal constant CONTROLLER      = 0x0000000000000000000000000000000000000000;
    address internal constant DEPLOYER        = 0x0000000000000000000000000000000000000000;

    // Get from SKY
    address internal constant BEACON = 0x0000000000000000000000000000000000000000;

    AccessControls         internal accessControls;
    Beacon                 internal beacon;
    IMainnetControllerFull internal controller;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        accessControls = AccessControls(ACCESS_CONTROLS);
        beacon         = Beacon(BEACON);
        controller     = Controller(CONTROLLER);
    }

    function _getBlock() internal pure returns (uint256) {
        return 24684236;
    }

    function test_deployState() external view {

       /*******************************************************************************************/
       /*** AccessControls post deploy state                                                    ***/
       /*******************************************************************************************/

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,       ALLOCATOR),          true);
        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,       BACKSTOP_ALLOCATOR), true);
        assertEq(accessControls.hasRole(ALLOCATOR_ADMIN_ROLE, ALLOCATOR_ADMIN),    true);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE,   ADMIN),              true);

        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE),   1);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ROLE),       2);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ADMIN_ROLE), 1);

        assertEq(accessControls.getRoleAdmin(ALLOCATOR_ROLE), ALLOCATOR_ADMIN_ROLE); // via setRoleAdmin.

        // DEPLOYER has no roles on AccessControls
        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,       DEPLOYER), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE,   DEPLOYER), false);
        assertEq(accessControls.hasRole(ALLOCATOR_ADMIN_ROLE, DEPLOYER), false);

       /*******************************************************************************************/
       /*** Controller post deploy state                                                        ***/
       /*******************************************************************************************/

        // Constructor initializes with the correct state.
        assertEq(controller.accessControls(), ACCESS_CONTROLS);
        assertEq(controller.beacon(),         BEACON);
        assertEq(controller.proxy(),          ALM_PROXY);
        assertEq(controller.rateLimits(),     RATE_LIMITS);


        // Configurations: updateIntegrations.

        IEI.Integration[] memory integrations = controller.integrations();

        assertEq(integrations.length, 24);

        assertEq(integrations[0].id,  bytes32(keccak256(abi.encodePacked("AAVE_FACET"))));
        assertEq(integrations[1].id,  bytes32(keccak256(abi.encodePacked("CCTP_FACET"))));
        assertEq(integrations[2].id,  bytes32(keccak256(abi.encodePacked("CENTRIFUGE_FACET"))));
        assertEq(integrations[3].id,  bytes32(keccak256(abi.encodePacked("CURVE_FACET"))));
        assertEq(integrations[4].id,  bytes32(keccak256(abi.encodePacked("DAI_USDS_FACET"))));
        assertEq(integrations[5].id,  bytes32(keccak256(abi.encodePacked("ERC4626_FACET"))));
        assertEq(integrations[6].id,  bytes32(keccak256(abi.encodePacked("ERC7540_FACET"))));
        assertEq(integrations[7].id,  bytes32(keccak256(abi.encodePacked("ETHENA_FACET"))));
        assertEq(integrations[8].id,  bytes32(keccak256(abi.encodePacked("FARM_FACET"))));
        assertEq(integrations[9].id,  bytes32(keccak256(abi.encodePacked("LAYER_ZERO_FACET"))));
        assertEq(integrations[10].id, bytes32(keccak256(abi.encodePacked("MAPLE_FACET"))));
        assertEq(integrations[11].id, bytes32(keccak256(abi.encodePacked("MERKL_FACET"))));
        assertEq(integrations[12].id, bytes32(keccak256(abi.encodePacked("OTC_FACET"))));
        assertEq(integrations[13].id, bytes32(keccak256(abi.encodePacked("PENDLE_FACET"))));
        assertEq(integrations[14].id, bytes32(keccak256(abi.encodePacked("PSM_FACET"))));
        assertEq(integrations[15].id, bytes32(keccak256(abi.encodePacked("SPARK_VAULT_FACET"))));
        assertEq(integrations[16].id, bytes32(keccak256(abi.encodePacked("SUPERSTATE_FACET"))));
        assertEq(integrations[17].id, bytes32(keccak256(abi.encodePacked("TRANSFER_ASSET_FACET"))));
        assertEq(integrations[18].id, bytes32(keccak256(abi.encodePacked("TRANSFER_ASSET_FACET"))));
        assertEq(integrations[19].id, bytes32(keccak256(abi.encodePacked("UNISWAP_V3_FACET"))));
        assertEq(integrations[20].id, bytes32(keccak256(abi.encodePacked("UNISWAP_V4_FACET"))));
        assertEq(integrations[21].id, bytes32(keccak256(abi.encodePacked("USDS_FACET"))));
        assertEq(integrations[22].id, bytes32(keccak256(abi.encodePacked("WEETH_FACET"))));
        assertEq(integrations[23].id, bytes32(keccak256(abi.encodePacked("WRAP_PROXY_ETH_FACET"))));
        assertEq(integrations[24].id, bytes32(keccak256(abi.encodePacked("WSTETH_FACET"))));

        for (uint256 i = 0; i < integrations.length; i++) {
            _assertIntegration(integrations[i].id);
        }

        // Configurations: migrate erc4626 max exchange rates.

        // Configurations: migrate curve max slippage.

        // Configurations: migrate aave max slippage.

        // Configurations: migrate uniswapV4 pools.
    
    }

    function test_postDeployEvents() external {

       /*******************************************************************************************/
       /*** AccessControls events                                                               ***/
       /*******************************************************************************************/

        VmSafe.EthGetLogs[] memory accessControlsAllLogs = _getEvents(block.chainid, ACCESS_CONTROLS, "");

        assertEq(accessControlsAllLogs.length, 7);

        // RoleGranted(DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER) from Deploy: AccessControls constructor.
        assertEq(accessControlsAllLogs[0].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[0].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[0].topics[2]), DEPLOYER);
        assertEq(_toAddress(accessControlsAllLogs[0].topics[3]), DEPLOYER);

        // RoleGranted(ALLOCATOR_ROLE, ALLOCATOR, DEPLOYER) from TransferRoles: ALLOCATOR_ROLE grant.
        assertEq(accessControlsAllLogs[1].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[1].topics[1],             ALLOCATOR_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[1].topics[2]), ALLOCATOR);
        assertEq(_toAddress(accessControlsAllLogs[1].topics[3]), DEPLOYER);

        // RoleGranted(ALLOCATOR_ROLE, BACKSTOP_ALLOCATOR, DEPLOYER) from TransferRoles: ALLOCATOR_ROLE grant.
        assertEq(accessControlsAllLogs[2].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[2].topics[1],             ALLOCATOR_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[2].topics[2]), BACKSTOP_ALLOCATOR);
        assertEq(_toAddress(accessControlsAllLogs[2].topics[3]), DEPLOYER);

        // RoleGranted(ALLOCATOR_ADMIN_ROLE, ALLOCATOR_ADMIN, DEPLOYER) from TransferRoles: ALLOCATOR_ADMIN_ROLE grant.
        assertEq(accessControlsAllLogs[3].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[3].topics[1],             ALLOCATOR_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[3].topics[2]), ALLOCATOR_ADMIN);
        assertEq(_toAddress(accessControlsAllLogs[3].topics[3]), DEPLOYER);

        // RoleAdminChanged(ALLOCATOR_ROLE, DEFAULT_ADMIN_ROLE, ALLOCATOR_ADMIN_ROLE) from TransferRoles: setRoleAdmin.
        // From AccessControls.setRoleAdmin.
        assertEq(accessControlsAllLogs[4].topics[0], IAccessControl.RoleAdminChanged.selector);
        assertEq(accessControlsAllLogs[4].topics[1], ALLOCATOR_ROLE);
        assertEq(accessControlsAllLogs[4].topics[2], DEFAULT_ADMIN_ROLE);
        assertEq(accessControlsAllLogs[4].topics[3], ALLOCATOR_ADMIN_ROLE);

        // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, DEPLOYER) from TransferRoles: DEFAULT_ADMIN_ROLE grant.
        // Role transfers from deployer to admin.
        assertEq(accessControlsAllLogs[5].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[5].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[5].topics[2]), ADMIN);
        assertEq(_toAddress(accessControlsAllLogs[5].topics[3]), DEPLOYER);

        // RoleRevoked(DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER) from TransferRoles: DEFAULT_ADMIN_ROLE revoke.
        // Role revoked from deployer.
        assertEq(accessControlsAllLogs[6].topics[0],             IAccessControl.RoleRevoked.selector);
        assertEq(accessControlsAllLogs[6].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[6].topics[2]), DEPLOYER);
        assertEq(_toAddress(accessControlsAllLogs[6].topics[3]), DEPLOYER);

       /*******************************************************************************************/
       /*** Controller events                                                                   ***/
       /*******************************************************************************************/

        VmSafe.EthGetLogs[] memory controllerAllLogs = _getEvents(block.chainid, CONTROLLER, "");

        assertEq(controllerAllLogs.length, 32);

    }

    function _assertIntegration(bytes32 integrationId) internal view{
        IEI.Config memory beaconConfig     = beacon.getConfig(integrationId);
        IEI.Config memory controllerConfig = controller.getConfig(integrationId);

        assertEq(controllerConfig.facet,        beaconConfig.facet);
        assertEq(controllerConfig.wires.length, beaconConfig.wires.length);

        for (uint256 i = 0; i < controllerConfig.wires.length; ++i) {
            assertEq(controllerConfig.wires[i].callSelector,     beaconConfig.wires[i].callSelector);
            assertEq(controllerConfig.wires[i].delegateSelector, beaconConfig.wires[i].delegateSelector);
        }
    }

}
