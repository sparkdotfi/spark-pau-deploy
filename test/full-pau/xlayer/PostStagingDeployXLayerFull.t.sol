// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IAccessControls }                           from "../../../lib/diamond-pau/src/interfaces/IAccessControls.sol";
import { IALMProxy }                                 from "../../../lib/diamond-pau/src/interfaces/IALMProxy.sol";
import { IBeacon }                                   from "../../../lib/diamond-pau/src/interfaces/IBeacon.sol";
import { IEnumerableIntegrations as IEI }            from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";
import { IMainnetControllerFull as IControllerFull } from "../../../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";
import { IRateLimits }                               from "../../../lib/diamond-pau/src/interfaces/IRateLimits.sol";

import { CCTPv2Forwarder } from "../../../lib/diamond-pau/lib/grove-xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { IAdministeredAgent } from "../../../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { IPAUFactoryLike, PostDeployTestBase } from "../../PostDeployTestBase.t.sol";

/// X Layer staging, full deployment: 0-DeploySparkPAUFull brought up its own ALMProxy, then
/// 1-ConfigureSparkPAUStagingFull wired the CCTP facet to Ethereum and handed the stack to the
/// staging admin.
///
/// There is no event test here: the Etherscan v2 log endpoint does not cover chain 196, so
/// _getEvents cannot be used on X Layer. Only the on-chain end state is asserted.
contract PostStagingDeployXLayerFull is PostDeployTestBase {

    // script/input/196/deploy-xlayer-staging.json
    address internal constant AGENT_FACTORY = 0x039bC8CAe7A5b2B981E5ED98B840C76c7FBacDAc;
    address internal constant PAU_FACTORY   = 0x257956534374d558c8868338ff7885a93B638277;

    // script/input/196/config-xlayer-staging.json
    address internal constant ADMIN    = 0xb52991d5d29f371f493910c36f5A849b3748Cc28;
    address internal constant DEPLOYER = 0x23d43f3189Ab9CEBfFcC0352C0490387e3105FB3;
    address internal constant FREEZER  = 0xE4FB2B5B40EE539f5b9551cf699674d3082eD39b;
    address internal constant RELAYER  = 0xE4FB2B5B40EE539f5b9551cf699674d3082eD39b;

    // script/output/196/deploy-xlayer-staging-1788369464.json
    address internal constant ACCESS_CONTROLS    = 0x872cFB10AD1b6CDf231856066dffD268f898C664;
    address internal constant ADMINISTERED_AGENT = 0x939F3e857aa17bAFF48B6C65FF4fe6361710173F;
    address internal constant ALM_PROXY          = 0x802360b1B72421736918d9Fc3cfd88AB875bF238;
    address internal constant CONTROLLER         = 0x67912263513E8B9678A3e097Dd8f9326F725B0Fe;
    address internal constant RATE_LIMITS        = 0x06F01a7710D58eb905906360cd225177CA73C501;

    // script/full-pau/1-ConfigureSparkPAUStagingFull.s.sol
    uint32  internal constant ETHEREUM_CCTP_DOMAIN         = CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM;
    address internal constant ETHEREUM_CCTP_MINT_RECIPIENT = 0xe6A3179615cA28abd2d0a0d83bAAC21B24Ff7fFF;

    uint32 internal constant ETHEREUM_CCTP_MIN_FEE_CAP_RATE = 0;
    uint32 internal constant ETHEREUM_CCTP_MAX_FEE_CAP_RATE = 100;

    uint256 internal constant ETHEREUM_CCTP_RATE_LIMIT_MAX_AMOUNT = 10e6;
    uint256 internal constant ETHEREUM_CCTP_RATE_LIMIT_SLOPE      = uint256(100e6) / 1 hours;

    address internal BEACON;

    function setUp() public {
        setChain("xlayer", ChainData({
            name    : "XLayer",
            rpcUrl  : vm.envString("XLAYER_RPC_URL"),
            chainId : 196
        }));

        vm.createSelectFork(getChain("xlayer").rpcUrl, _getBlock());

        BEACON = IPAUFactoryLike(PAU_FACTORY).beacon();

        accessControls    = IAccessControls(ACCESS_CONTROLS);
        administeredAgent = IAdministeredAgent(ADMINISTERED_AGENT);
        almProxy          = IALMProxy(ALM_PROXY);
        beacon            = IBeacon(BEACON);
        controller        = IControllerFull(CONTROLLER);
        rateLimits        = IRateLimits(RATE_LIMITS);
    }

    function _getBlock() internal pure returns (uint256) {
        return 69765318; // (UTC) 09/04/2026, 15:05:54
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

        // A full deployment brings up its own ALMProxy, so the configure script wires the
        // CONTROLLER role on it and hands it to the admin alongside the rest of the stack.

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, ADMIN),      true);
        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    CONTROLLER), true);

        // DEPLOYER/PAU_FACTORY has no roles on the ALMProxy

        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    DEPLOYER), false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), false);

        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    PAU_FACTORY), false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, PAU_FACTORY), false);

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
            ETHEREUM_CCTP_RATE_LIMIT_MAX_AMOUNT,
            ETHEREUM_CCTP_RATE_LIMIT_SLOPE
        );

        _assertRateLimitData(
            controller.cctp_getToDomainRateLimitKey(ETHEREUM_CCTP_DOMAIN),
            ETHEREUM_CCTP_RATE_LIMIT_MAX_AMOUNT,
            ETHEREUM_CCTP_RATE_LIMIT_SLOPE
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
        ) = controller.cctp_getDomainParameters(ETHEREUM_CCTP_DOMAIN);

        assertEq(mintRecipient, bytes32(uint256(uint160(ETHEREUM_CCTP_MINT_RECIPIENT))));
        assertEq(minFeeCapRate, ETHEREUM_CCTP_MIN_FEE_CAP_RATE);
        assertEq(maxFeeCapRate, ETHEREUM_CCTP_MAX_FEE_CAP_RATE);

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

}
