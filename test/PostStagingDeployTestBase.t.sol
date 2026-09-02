// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { VmSafe } from "../lib/forge-std/src/Vm.sol";

import { ICCTPFacet }                     from "../lib/diamond-pau/src/facets/cctp/ICCTPFacet.sol";
import { IEnumerableIntegrations as IEI } from "../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";
import { IRateLimits }                    from "../lib/diamond-pau/src/interfaces/IRateLimits.sol";

import { CCTPv2Forwarder } from "../lib/diamond-pau/lib/grove-xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { IAdministeredAgent } from "../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { PostDeployTestBase } from "./PostDeployTestBase.t.sol";

/// Staging runs the deploy script with the deployer as admin, then the configure script which
/// configures the stack and hands every component over to the staging admin.
abstract contract PostStagingDeployTestBase is PostDeployTestBase {

    bytes32 internal constant CCTP_FACET_ID = bytes32(abi.encodePacked("CCTP_FACET"));

    uint32 internal constant CCTP_BASE_DOMAIN = CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE;

    // BASE_ALM_PROXY from the configure script, bytes32 encoded as the CCTP mint recipient.
    address internal constant BASE_ALM_PROXY      = 0x370E141E3a568A314bF84decB8c07b82Bb7f1831;
    bytes32 internal constant CCTP_MINT_RECIPIENT = bytes32(uint256(uint160(BASE_ALM_PROXY)));

    uint32 internal constant CCTP_MIN_FEE_CAP_RATE = 0;
    uint32 internal constant CCTP_MAX_FEE_CAP_RATE = 100;

    uint256 internal constant CCTP_RATE_LIMIT_MAX_AMOUNT = 10e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE      = 0;

    // Agent actor and revoker from the config input, assigned by _setDeploymentAddresses.
    address internal FREEZER;
    address internal RELAYER;

    function test_deployState() external view {
        /******************************************************************************************/
        /*** AccessControls post deploy state                                                   ***/
        /******************************************************************************************/

        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, ADMIN),     true);
        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE, ADMINISTERED_AGENT), true);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ROLE),          1);

        // DEPLOYER/PAU_FACTORY has no roles on AccessControls

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     DEPLOYER), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), false);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     PAU_FACTORY), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, PAU_FACTORY), false);

        /******************************************************************************************/
        /*** ALMProxy post deploy state                                                         ***/
        /******************************************************************************************/

        if (_isFullDeployment()) {
            assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, ADMIN),      true);
            assertEq(almProxy.hasRole(CONTROLLER_ROLE,    CONTROLLER), true);

            // DEPLOYER/PAU_FACTORY has no roles on the ALMProxy

            assertEq(almProxy.hasRole(CONTROLLER_ROLE,    DEPLOYER), false);
            assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), false);

            assertEq(almProxy.hasRole(CONTROLLER_ROLE,    PAU_FACTORY), false);
            assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, PAU_FACTORY), false);
        } else {
            // A parallel deployment attaches to the ALMProxy named in the deploy input, which has
            // admins of its own. Granting CONTROLLER to the new controller is a governance spell
            // action, so both scripts leave the proxy untouched.

            assertEq(almProxy.hasRole(CONTROLLER_ROLE, CONTROLLER), false);
        }

        /******************************************************************************************/
        /*** RateLimits post deploy state                                                       ***/
        /******************************************************************************************/

        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, ADMIN),      true);
        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    CONTROLLER), true);

        // DEPLOYER/PAU_FACTORY has no roles on RateLimits

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    DEPLOYER), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), false);

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    PAU_FACTORY), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, PAU_FACTORY), false);

        // Configurations: CCTP rate limits.

        _assertRateLimitData(controller.cctp_toCCTPRateLimitKey());
        _assertRateLimitData(controller.cctp_getToDomainRateLimitKey(CCTP_BASE_DOMAIN));

        /******************************************************************************************/
        /*** Controller post deploy state                                                       ***/
        /******************************************************************************************/

        // Constructor initializes with the correct state.
        assertEq(controller.accessControls(), ACCESS_CONTROLS);
        assertEq(controller.beacon(),         BEACON);
        assertEq(controller.proxy(),          ALM_PROXY);
        assertEq(controller.rateLimits(),     RATE_LIMITS);

        // Configurations: updateIntegrations.

        IEI.Integration[] memory integrations = controller.integrations();

        assertEq(integrations.length, 1);
        assertEq(integrations[0].id,  CCTP_FACET_ID);

        for (uint256 i = 0; i < integrations.length; i++) {
            _assertIntegration(integrations[i].id);
        }

        // Configurations: CCTP domain parameters.

        (
            bytes32 mintRecipient,
            uint32  minFeeCapRate,
            uint32  maxFeeCapRate
        ) = controller.cctp_getDomainParameters(CCTP_BASE_DOMAIN);

        assertEq(mintRecipient, CCTP_MINT_RECIPIENT);
        assertEq(minFeeCapRate, CCTP_MIN_FEE_CAP_RATE);
        assertEq(maxFeeCapRate, CCTP_MAX_FEE_CAP_RATE);

        /******************************************************************************************/
        /*** AdministeredAgent post deploy state                                                ***/
        /******************************************************************************************/

        assertEq(administeredAgent.adminCount(),   1);
        assertEq(administeredAgent.actorCount(),   1);
        assertEq(administeredAgent.grantorCount(), 0);
        assertEq(administeredAgent.revokerCount(), 1);

        assertEq(administeredAgent.getAdmin(0),   ADMIN);
        assertEq(administeredAgent.getActor(0),   RELAYER);
        assertEq(administeredAgent.getRevoker(0), FREEZER);

        // Deployer is no longer an admin on the AdministeredAgent.

        assertEq(administeredAgent.getIsAdmin(DEPLOYER), false);
    }

    function test_postDeployEvents() external {
        /******************************************************************************************/
        /*** AccessControls events                                                              ***/
        /******************************************************************************************/

        VmSafe.EthGetLogs[] memory accessControlsAllLogs = _getEvents(block.chainid, ACCESS_CONTROLS, "");

        assertEq(accessControlsAllLogs.length, 4);

        // RoleGranted(DEFAULT_ADMIN_ROLE, DEPLOYER, PAU_FACTORY) from PAUFactory.deployAccessControls: AccessControls constructor.
        _assertRoleGrantedEvent(accessControlsAllLogs[0], DEFAULT_ADMIN_ROLE, DEPLOYER, PAU_FACTORY);

        // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, DEPLOYER) from InitPAULib._grantDefaultAdmins.
        // Role transfers from deployer to admin.
        _assertRoleGrantedEvent(accessControlsAllLogs[1], DEFAULT_ADMIN_ROLE, ADMIN, DEPLOYER);

        // RoleGranted(ALLOCATOR_ROLE, ADMINISTERED_AGENT, DEPLOYER) from InitPAULib._grantRoles: ALLOCATOR_ROLE grant.
        _assertRoleGrantedEvent(accessControlsAllLogs[2], ALLOCATOR_ROLE, ADMINISTERED_AGENT, DEPLOYER);

        // RoleRevoked(DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER) from the configure script: DEFAULT_ADMIN_ROLE revoke.
        // Role revoked from deployer.
        _assertRoleRevokedEvent(accessControlsAllLogs[3], DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER);

        /******************************************************************************************/
        /*** ALMProxy events                                                                    ***/
        /******************************************************************************************/

        // A parallel deployment attaches to the existing ALMProxy, which carries unrelated history,
        // so only a full deployment can assert on its complete log set.

        if (_isFullDeployment()) {
            VmSafe.EthGetLogs[] memory almProxyAllLogs = _getEvents(block.chainid, ALM_PROXY, "");

            assertEq(almProxyAllLogs.length, 4);

            // RoleGranted(DEFAULT_ADMIN_ROLE, DEPLOYER, PAU_FACTORY) from PAUFactory.deployALMProxy: ALMProxy constructor.
            _assertRoleGrantedEvent(almProxyAllLogs[0], DEFAULT_ADMIN_ROLE, DEPLOYER, PAU_FACTORY);

            // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, DEPLOYER) from InitPAULib._grantDefaultAdmins.
            // Role transfers from deployer to admin.
            _assertRoleGrantedEvent(almProxyAllLogs[1], DEFAULT_ADMIN_ROLE, ADMIN, DEPLOYER);

            // RoleGranted(CONTROLLER_ROLE, CONTROLLER, DEPLOYER) from InitPAULib._grantRoles: CONTROLLER_ROLE grant.
            _assertRoleGrantedEvent(almProxyAllLogs[2], CONTROLLER_ROLE, CONTROLLER, DEPLOYER);

            // RoleRevoked(DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER) from the configure script: DEFAULT_ADMIN_ROLE revoke.
            // Role revoked from deployer.
            _assertRoleRevokedEvent(almProxyAllLogs[3], DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER);
        }

        /******************************************************************************************/
        /*** RateLimits events                                                                  ***/
        /******************************************************************************************/

        VmSafe.EthGetLogs[] memory rateLimitsAllLogs = _getEvents(block.chainid, RATE_LIMITS, "");

        assertEq(rateLimitsAllLogs.length, 6);

        // RoleGranted(DEFAULT_ADMIN_ROLE, DEPLOYER, PAU_FACTORY) from PAUFactory.deployRateLimits: RateLimits constructor.
        _assertRoleGrantedEvent(rateLimitsAllLogs[0], DEFAULT_ADMIN_ROLE, DEPLOYER, PAU_FACTORY);

        // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, DEPLOYER) from InitPAULib._grantDefaultAdmins.
        // Role transfers from deployer to admin.
        _assertRoleGrantedEvent(rateLimitsAllLogs[1], DEFAULT_ADMIN_ROLE, ADMIN, DEPLOYER);

        // RoleGranted(CONTROLLER_ROLE, CONTROLLER, DEPLOYER) from InitPAULib._grantRoles: CONTROLLER_ROLE grant.
        _assertRoleGrantedEvent(rateLimitsAllLogs[2], CONTROLLER_ROLE, CONTROLLER, DEPLOYER);

        // RateLimitDataSet(cctp_toCCTPRateLimitKey) from the configure script: CCTP facet onboarding.
        _assertRateLimitDataSetEvent(rateLimitsAllLogs[3], controller.cctp_toCCTPRateLimitKey());

        // RateLimitDataSet(cctp_getToDomainRateLimitKey) from the configure script: CCTP facet onboarding.
        _assertRateLimitDataSetEvent(
            rateLimitsAllLogs[4],
            controller.cctp_getToDomainRateLimitKey(CCTP_BASE_DOMAIN)
        );

        // RoleRevoked(DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER) from the configure script: DEFAULT_ADMIN_ROLE revoke.
        // Role revoked from deployer.
        _assertRoleRevokedEvent(rateLimitsAllLogs[5], DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER);

        /******************************************************************************************/
        /*** Controller events                                                                  ***/
        /******************************************************************************************/

        VmSafe.EthGetLogs[] memory controllerAllLogs = _getEvents(block.chainid, CONTROLLER, "");

        assertEq(controllerAllLogs.length, 3);

        // Initialized(1) from Controller constructor.
        _assertInitializedEvent(controllerAllLogs[0]);

        // IntegrationSet(integrationId, config) from InitPAULib: updateIntegrations.
        _assertIntegrationSetEvent(controllerAllLogs[1], CCTP_FACET_ID);

        // CCTPDomainParametersSet(CCTP_BASE_DOMAIN, CCTP_MINT_RECIPIENT, 0, 100) from the configure script: CCTP facet onboarding.
        _assertCCTPDomainParametersSetEvent(controllerAllLogs[2]);

        /******************************************************************************************/
        /*** AdministeredAgent events                                                           ***/
        /******************************************************************************************/

        VmSafe.EthGetLogs[] memory administeredAgentAllLogs = _getEvents(block.chainid, ADMINISTERED_AGENT, "");

        assertEq(administeredAgentAllLogs.length, 5);

        // AdminAdded(DEPLOYER, ADMINISTERED_AGENT_FACTORY) from AdministeredAgent constructor.
        assertEq(administeredAgentAllLogs[0].topics[0],             IAdministeredAgent.AdminAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[0].topics[1]), DEPLOYER);
        assertEq(_toAddress(administeredAgentAllLogs[0].topics[2]), ADMINISTERED_AGENT_FACTORY);

        // AdminAdded(ADMIN, DEPLOYER) from InitPAULib._configureAgent: addAdmin.
        assertEq(administeredAgentAllLogs[1].topics[0],             IAdministeredAgent.AdminAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[1].topics[1]), ADMIN);
        assertEq(_toAddress(administeredAgentAllLogs[1].topics[2]), DEPLOYER);

        // ActorAdded(RELAYER, DEPLOYER) from InitPAULib._configureAgent: addActor.
        assertEq(administeredAgentAllLogs[2].topics[0],             IAdministeredAgent.ActorAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[2].topics[1]), RELAYER);
        assertEq(_toAddress(administeredAgentAllLogs[2].topics[2]), DEPLOYER);

        // RevokerAdded(FREEZER, DEPLOYER) from InitPAULib._configureAgent: addRevoker.
        assertEq(administeredAgentAllLogs[3].topics[0],             IAdministeredAgent.RevokerAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[3].topics[1]), FREEZER);
        assertEq(_toAddress(administeredAgentAllLogs[3].topics[2]), DEPLOYER);

        // AdminRemoved(DEPLOYER, DEPLOYER) from the configure script: removeAdmin.
        assertEq(administeredAgentAllLogs[4].topics[0],             IAdministeredAgent.AdminRemoved.selector);
        assertEq(_toAddress(administeredAgentAllLogs[4].topics[1]), DEPLOYER);
        assertEq(_toAddress(administeredAgentAllLogs[4].topics[2]), DEPLOYER);
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _assertIntegration(bytes32 integrationId) internal view {
        IEI.Config memory beaconConfig     = beacon.getConfig(integrationId);
        IEI.Config memory controllerConfig = controller.getConfig(integrationId);

        assertEq(controllerConfig.facet,        beaconConfig.facet);
        assertEq(controllerConfig.wires.length, beaconConfig.wires.length);

        for (uint256 i = 0; i < controllerConfig.wires.length; ++i) {
            assertEq(controllerConfig.wires[i].callSelector,     beaconConfig.wires[i].callSelector);
            assertEq(controllerConfig.wires[i].delegateSelector, beaconConfig.wires[i].delegateSelector);
        }
    }

    function _assertRateLimitData(bytes32 key) internal view {
        IRateLimits.RateLimitData memory data = rateLimits.getRateLimitData(key);

        assertEq(data.maxAmount, CCTP_RATE_LIMIT_MAX_AMOUNT);
        assertEq(data.slope,     CCTP_RATE_LIMIT_SLOPE);
    }

    /**********************************************************************************************/
    /*** Event test helpers                                                                     ***/
    /**********************************************************************************************/

    function _assertCCTPDomainParametersSetEvent(VmSafe.EthGetLogs memory log) internal pure {
        (uint32 minFeeCapRate, uint32 maxFeeCapRate) = abi.decode(log.data, (uint32, uint32));

        assertEq(log.topics[0],          ICCTPFacet.CCTPDomainParametersSet.selector);
        assertEq(uint256(log.topics[1]), uint256(CCTP_BASE_DOMAIN));
        assertEq(log.topics[2],          CCTP_MINT_RECIPIENT);

        assertEq(minFeeCapRate, CCTP_MIN_FEE_CAP_RATE);
        assertEq(maxFeeCapRate, CCTP_MAX_FEE_CAP_RATE);
    }

    function _assertIntegrationSetEvent(VmSafe.EthGetLogs memory log, bytes32 integrationId) internal view {
        IEI.Config memory controllerConfig = abi.decode(log.data, (IEI.Config));
        IEI.Config memory beaconConfig     = beacon.getConfig(integrationId);

        assertEq(log.topics[0], IEI.IntegrationSet.selector);
        assertEq(log.topics[1], integrationId);

        assertEq(controllerConfig.facet,        beaconConfig.facet);
        assertEq(controllerConfig.wires.length, beaconConfig.wires.length);

        for (uint256 i = 0; i < controllerConfig.wires.length; ++i) {
            assertEq(controllerConfig.wires[i].callSelector,     beaconConfig.wires[i].callSelector);
            assertEq(controllerConfig.wires[i].delegateSelector, beaconConfig.wires[i].delegateSelector);
        }
    }

    function _assertRateLimitDataSetEvent(VmSafe.EthGetLogs memory log, bytes32 key) internal pure {
        (
            uint256 maxAmount,
            uint256 slope,
            uint256 lastAmount,
        ) = abi.decode(log.data, (uint256, uint256, uint256, uint256));

        assertEq(log.topics[0], IRateLimits.RateLimitDataSet.selector);
        assertEq(log.topics[1], key);

        assertEq(maxAmount,  CCTP_RATE_LIMIT_MAX_AMOUNT);
        assertEq(slope,      CCTP_RATE_LIMIT_SLOPE);
        assertEq(lastAmount, CCTP_RATE_LIMIT_MAX_AMOUNT);
    }

}
