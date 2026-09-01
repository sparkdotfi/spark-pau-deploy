// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { VmSafe } from "../lib/forge-std/src/Vm.sol";

import { IAccessControl }                            from "../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IAccessControls }                           from "../lib/diamond-pau/src/interfaces/IAccessControls.sol";
import { Initializable }                             from "../lib/diamond-pau/lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IMainnetControllerFull as IControllerFull } from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";
import { IRateLimits }                               from "../lib/diamond-pau/src/interfaces/IRateLimits.sol";

import { Ethereum as SkyEthereum }   from "../lib/sky-pau-registry/src/Ethereum.sol";
import { Ethereum as SparkEthereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { IAdministeredAgent } from "../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { PostDeployTestBase } from "./PostDeployTestBase.t.sol";

contract PostProductionDeployTests is PostDeployTestBase {

    // Paste from script output.
    address internal constant ACCESS_CONTROLS    = 0x0000000000000000000000000000000000000000;
    address internal constant ADMINISTERED_AGENT = 0x0000000000000000000000000000000000000000;
    address internal constant CONTROLLER         = 0x0000000000000000000000000000000000000000;
    address internal constant RATE_LIMITS        = 0x0000000000000000000000000000000000000000;
    address internal constant DEPLOYER           = 0x0000000000000000000000000000000000000000;

    address internal constant ADMINISTERED_AGENT_FACTORY = SkyEthereum.ADMINISTERED_AGENT_FACTORY;
    address internal constant BEACON                     = SkyEthereum.BEACON;
    address internal constant PAU_FACTORY                = SkyEthereum.PAU_FACTORY;

    address internal constant ADMIN              = SparkEthereum.SPARK_PROXY;
    address internal constant ALLOCATOR          = SparkEthereum.ALM_RELAYER_MULTISIG;
    address internal constant REVOKER            = SparkEthereum.ALM_FREEZER_MULTISIG;
    address internal constant ALM_PROXY          = SparkEthereum.ALM_PROXY;
    address internal constant BACKSTOP_ALLOCATOR = SparkEthereum.ALM_BACKSTOP_RELAYER_MULTISIG;

    IAccessControls    internal accessControls;
    IAdministeredAgent internal administeredAgent;
    IControllerFull    internal controller;
    IRateLimits        internal rateLimits;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        accessControls    = IAccessControls(ACCESS_CONTROLS);
        administeredAgent = IAdministeredAgent(ADMINISTERED_AGENT);
        controller        = IControllerFull(CONTROLLER);
        rateLimits        = IRateLimits(RATE_LIMITS);
    }

    function _getBlock() internal pure returns (uint256) {
        return 0; // After deploy script execution
    }

    function test_deployState() external view {
        /******************************************************************************************/
        /*** AccessControls post deploy state                                                   ***/
        /******************************************************************************************/

        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, ADMIN),     true);
        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);

        // No ALLOCATOR_ROLE is granted by the deploy script.

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE, ADMINISTERED_AGENT), false);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ROLE),          0);

        // DEPLOYER/PAU_FACTORY has no roles on AccessControls

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     DEPLOYER), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), false);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     PAU_FACTORY), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, PAU_FACTORY), false);

        /******************************************************************************************/
        /*** RateLimits post deploy state                                                       ***/
        /******************************************************************************************/

        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, ADMIN), true);

        // The CONTROLLER role is granted by the governance spell, not by the deploy script.

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE, CONTROLLER), false);

        // DEPLOYER/PAU_FACTORY has no roles on RateLimits

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    DEPLOYER), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), false);

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    PAU_FACTORY), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, PAU_FACTORY), false);

        /******************************************************************************************/
        /*** Controller post deploy state                                                       ***/
        /******************************************************************************************/

        // Constructor initializes with the correct state.
        assertEq(controller.accessControls(), ACCESS_CONTROLS);
        assertEq(controller.beacon(),         BEACON);
        assertEq(controller.proxy(),          ALM_PROXY);
        assertEq(controller.rateLimits(),     RATE_LIMITS);

        // No integrations are wired by the deploy script.

        assertEq(controller.integrations().length, 0);

        /******************************************************************************************/
        /*** AdministeredAgent post deploy state                                                ***/
        /******************************************************************************************/

        assertEq(administeredAgent.adminCount(),   1);
        assertEq(administeredAgent.actorCount(),   0);
        assertEq(administeredAgent.grantorCount(), 0);
        assertEq(administeredAgent.revokerCount(), 0);

        assertEq(administeredAgent.getAdmin(0), ADMIN);

        // Actors and revokers are added by the governance spell, not by the deploy script.

        assertEq(administeredAgent.getIsActor(ALLOCATOR),          false);
        assertEq(administeredAgent.getIsActor(BACKSTOP_ALLOCATOR), false);
        assertEq(administeredAgent.getIsRevoker(REVOKER),          false);
        assertEq(administeredAgent.getIsAdmin(DEPLOYER),           false);
    }

    function test_postDeployEvents() external {
        /******************************************************************************************/
        /*** AccessControls events                                                              ***/
        /******************************************************************************************/

        VmSafe.EthGetLogs[] memory accessControlsAllLogs = _getEvents(block.chainid, ACCESS_CONTROLS, "");

        assertEq(accessControlsAllLogs.length, 1);

        // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, PAU_FACTORY) from PAUFactory.deployAccessControls: AccessControls constructor.
        assertEq(accessControlsAllLogs[0].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[0].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[0].topics[2]), ADMIN);
        assertEq(_toAddress(accessControlsAllLogs[0].topics[3]), PAU_FACTORY);

        /******************************************************************************************/
        /*** RateLimits events                                                                  ***/
        /******************************************************************************************/

        VmSafe.EthGetLogs[] memory rateLimitsAllLogs = _getEvents(block.chainid, RATE_LIMITS, "");

        assertEq(rateLimitsAllLogs.length, 1);

        // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, PAU_FACTORY) from PAUFactory.deployRateLimits: RateLimits constructor.
        assertEq(rateLimitsAllLogs[0].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(rateLimitsAllLogs[0].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(rateLimitsAllLogs[0].topics[2]), ADMIN);
        assertEq(_toAddress(rateLimitsAllLogs[0].topics[3]), PAU_FACTORY);

        /******************************************************************************************/
        /*** Controller events                                                                  ***/
        /******************************************************************************************/

        VmSafe.EthGetLogs[] memory controllerAllLogs = _getEvents(block.chainid, CONTROLLER, "");

        assertEq(controllerAllLogs.length, 1);

        // Initialized(1) from Controller constructor.
        _assertInitializedEvent(controllerAllLogs[0]);

        /******************************************************************************************/
        /*** AdministeredAgent events                                                           ***/
        /******************************************************************************************/

        VmSafe.EthGetLogs[] memory administeredAgentAllLogs = _getEvents(block.chainid, ADMINISTERED_AGENT, "");

        assertEq(administeredAgentAllLogs.length, 1);

        // AdminAdded(ADMIN, ADMINISTERED_AGENT_FACTORY) from AdministeredAgent constructor.
        assertEq(administeredAgentAllLogs[0].topics[0],             IAdministeredAgent.AdminAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[0].topics[1]), ADMIN);
        assertEq(_toAddress(administeredAgentAllLogs[0].topics[2]), ADMINISTERED_AGENT_FACTORY);
    }

    /**********************************************************************************************/
    /*** Event test helpers                                                                     ***/
    /**********************************************************************************************/

    function _assertInitializedEvent(VmSafe.EthGetLogs memory log) internal pure {
        assertEq(log.topics[0], Initializable.Initialized.selector);
        assertEq(log.data,      abi.encode(1));
    }

}
