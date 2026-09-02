// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { VmSafe } from "../lib/forge-std/src/Vm.sol";

import { IAdministeredAgent } from "../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { PostDeployTestBase } from "./PostDeployTestBase.t.sol";

/// Production runs the deploy script only, with SPARK_PROXY as the admin on every component. The
/// stack is left unconfigured: integrations, roles and rate limits are onboarded by a governance
/// spell, so no configuration state or events are expected here.
abstract contract PostProductionDeployTestBase is PostDeployTestBase {

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
        /*** ALMProxy post deploy state                                                         ***/
        /******************************************************************************************/

        if (_isFullDeployment()) {
            assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, ADMIN), true);

            // The CONTROLLER role is granted by the governance spell, not by the deploy script.

            assertEq(almProxy.hasRole(CONTROLLER_ROLE, CONTROLLER), false);

            // DEPLOYER/PAU_FACTORY has no roles on the ALMProxy

            assertEq(almProxy.hasRole(CONTROLLER_ROLE,    DEPLOYER), false);
            assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), false);

            assertEq(almProxy.hasRole(CONTROLLER_ROLE,    PAU_FACTORY), false);
            assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, PAU_FACTORY), false);
        } else {
            // A parallel deployment attaches to the existing ALMProxy and leaves it untouched.

            assertEq(controller.proxy(), EXISTING_ALM_PROXY);

            // New Controller role needs to be granted by the governance spell
            assertEq(almProxy.hasRole(CONTROLLER_ROLE, CONTROLLER), false);
        }

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
        _assertRoleGrantedEvent(accessControlsAllLogs[0], DEFAULT_ADMIN_ROLE, ADMIN, PAU_FACTORY);

        /******************************************************************************************/
        /*** ALMProxy events                                                                    ***/
        /******************************************************************************************/

        // A parallel deployment attaches to the existing ALMProxy, which carries unrelated history,
        // so only a full deployment can assert on its complete log set.

        if (_isFullDeployment()) {
            VmSafe.EthGetLogs[] memory almProxyAllLogs = _getEvents(block.chainid, ALM_PROXY, "");

            assertEq(almProxyAllLogs.length, 1);

            // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, PAU_FACTORY) from PAUFactory.deployALMProxy: ALMProxy constructor.
            _assertRoleGrantedEvent(almProxyAllLogs[0], DEFAULT_ADMIN_ROLE, ADMIN, PAU_FACTORY);
        }

        /******************************************************************************************/
        /*** RateLimits events                                                                  ***/
        /******************************************************************************************/

        VmSafe.EthGetLogs[] memory rateLimitsAllLogs = _getEvents(block.chainid, RATE_LIMITS, "");

        assertEq(rateLimitsAllLogs.length, 1);

        // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, PAU_FACTORY) from PAUFactory.deployRateLimits: RateLimits constructor.
        _assertRoleGrantedEvent(rateLimitsAllLogs[0], DEFAULT_ADMIN_ROLE, ADMIN, PAU_FACTORY);

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

}
