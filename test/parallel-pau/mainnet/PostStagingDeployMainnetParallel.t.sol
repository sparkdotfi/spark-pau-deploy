// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { VmSafe } from "../../../lib/forge-std/src/Vm.sol";

import { IAccessControls }                           from "../../../lib/diamond-pau/src/interfaces/IAccessControls.sol";
import { IALMProxy }                                 from "../../../lib/diamond-pau/src/interfaces/IALMProxy.sol";
import { IBeacon }                                   from "../../../lib/diamond-pau/src/interfaces/IBeacon.sol";
import { IEnumerableIntegrations as IEI }            from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";
import { IMainnetControllerFull as IControllerFull } from "../../../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";
import { IRateLimits }                               from "../../../lib/diamond-pau/src/interfaces/IRateLimits.sol";

import { IAdministeredAgent } from "../../../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { IPAUFactoryLike, PostDeployTestBase } from "../../PostDeployTestBase.t.sol";

contract PostStagingDeployMainnetParallel is PostDeployTestBase {

    // script/input/1/deploy-mainnet-staging.json
    address internal constant AGENT_FACTORY = 0x2968c3b5478cF93B70aB1e24255d4EDBBd27a089;
    address internal constant PAU_FACTORY   = 0x69A5d548830AC2A4Ba90A44a2C75BDA71f97fc66;

    // script/input/1/config-mainnet-staging.json
    address internal constant ADMIN    = 0xb52991d5d29f371f493910c36f5A849b3748Cc28;
    address internal constant DEPLOYER = 0xC758519Ace14E884fdbA9ccE25F2DbE81b7e136f;
    address internal constant FREEZER  = 0x611C7c37F296240c2fF5a92f0B4a398B01B237c4;
    address internal constant RELAYER  = 0x611C7c37F296240c2fF5a92f0B4a398B01B237c4;

    // script/output/1/deploy-mainnet-staging-1788367871.json
    address internal constant ACCESS_CONTROLS    = 0x68E83368f6b14CfE0E216b4c57Ed02AEF8570574;
    address internal constant ADMINISTERED_AGENT = 0xfFe07E9A44ABe851DD195e5f433f4860A25aEc06;
    address internal constant ALM_PROXY          = 0xe6A3179615cA28abd2d0a0d83bAAC21B24Ff7fFF;
    address internal constant CONTROLLER         = 0x803A3FdCA59aAF9bbAD86B34592300D95f033C0e;
    address internal constant RATE_LIMITS        = 0xaCea3604adEb2ad252eC093d0075245CB3cf9eE6;

    // script/parallel-pau/1-ConfigureSparkPAUStagingParallel.s.sol
    uint32  internal constant XLAYER_CCTP_DOMAIN         = 37;  // X Layer
    address internal constant XLAYER_CCTP_MINT_RECIPIENT = 0x802360b1B72421736918d9Fc3cfd88AB875bF238;

    uint32 internal constant XLAYER_CCTP_MIN_FEE_CAP_RATE = 0;
    uint32 internal constant XLAYER_CCTP_MAX_FEE_CAP_RATE = 100;

    uint256 internal constant XLAYER_CCTP_RATE_LIMIT_MAX_AMOUNT = 10e6;
    uint256 internal constant XLAYER_CCTP_RATE_LIMIT_SLOPE      = uint256(100e6) / 1 hours;

    address internal BEACON;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        BEACON = IPAUFactoryLike(PAU_FACTORY).beacon();

        accessControls    = IAccessControls(ACCESS_CONTROLS);
        administeredAgent = IAdministeredAgent(ADMINISTERED_AGENT);
        almProxy          = IALMProxy(ALM_PROXY);
        beacon            = IBeacon(BEACON);
        controller        = IControllerFull(CONTROLLER);
        rateLimits        = IRateLimits(RATE_LIMITS);
    }

    function _getBlock() internal pure returns (uint256) {
        return 25904689; // Sep-04-2026 02:55:35 PM +UTC
    }

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

        // A parallel deployment attaches to the ALMProxy named in the deploy input, which has
        // admins of its own. Granting CONTROLLER to the new controller is a governance spell
        // action, so both scripts leave the proxy untouched.

        assertEq(almProxy.hasRole(CONTROLLER_ROLE, CONTROLLER), false);

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

        _assertRateLimitData(
            controller.cctp_toCCTPRateLimitKey(),
            XLAYER_CCTP_RATE_LIMIT_MAX_AMOUNT,
            XLAYER_CCTP_RATE_LIMIT_SLOPE
        );

        _assertRateLimitData(
            controller.cctp_getToDomainRateLimitKey(XLAYER_CCTP_DOMAIN),
            XLAYER_CCTP_RATE_LIMIT_MAX_AMOUNT,
            XLAYER_CCTP_RATE_LIMIT_SLOPE
        );

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
        ) = controller.cctp_getDomainParameters(XLAYER_CCTP_DOMAIN);

        assertEq(mintRecipient, bytes32(uint256(uint160(XLAYER_CCTP_MINT_RECIPIENT))));
        assertEq(minFeeCapRate, XLAYER_CCTP_MIN_FEE_CAP_RATE);
        assertEq(maxFeeCapRate, XLAYER_CCTP_MAX_FEE_CAP_RATE);

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

        // A parallel deployment attaches to the existing ALMProxy, which carries unrelated history
        // and is left untouched by both scripts, so there is nothing to assert on it here.

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
        _assertRateLimitDataSetEvent(
            rateLimitsAllLogs[3],
            controller.cctp_toCCTPRateLimitKey(),
            XLAYER_CCTP_RATE_LIMIT_MAX_AMOUNT,
            XLAYER_CCTP_RATE_LIMIT_SLOPE
        );

        // RateLimitDataSet(cctp_getToDomainRateLimitKey) from the configure script: CCTP facet onboarding.
        _assertRateLimitDataSetEvent(
            rateLimitsAllLogs[4],
            controller.cctp_getToDomainRateLimitKey(XLAYER_CCTP_DOMAIN),
            XLAYER_CCTP_RATE_LIMIT_MAX_AMOUNT,
            XLAYER_CCTP_RATE_LIMIT_SLOPE
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

        // CCTPDomainParametersSet(CCTP_DOMAIN, CCTP_MINT_RECIPIENT, 0, 100) from the configure script: CCTP facet onboarding.
        _assertCCTPDomainParametersSetEvent(
            controllerAllLogs[2],
            XLAYER_CCTP_DOMAIN,
            XLAYER_CCTP_MINT_RECIPIENT,
            XLAYER_CCTP_MIN_FEE_CAP_RATE,
            XLAYER_CCTP_MAX_FEE_CAP_RATE
        );

        /******************************************************************************************/
        /*** AdministeredAgent events                                                           ***/
        /******************************************************************************************/

        VmSafe.EthGetLogs[] memory administeredAgentAllLogs = _getEvents(block.chainid, ADMINISTERED_AGENT, "");

        assertEq(administeredAgentAllLogs.length, 5);

        // AdminAdded(DEPLOYER, AGENT_FACTORY) from AdministeredAgent constructor.
        assertEq(administeredAgentAllLogs[0].topics[0],             IAdministeredAgent.AdminAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[0].topics[1]), DEPLOYER);
        assertEq(_toAddress(administeredAgentAllLogs[0].topics[2]), AGENT_FACTORY);

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

}
