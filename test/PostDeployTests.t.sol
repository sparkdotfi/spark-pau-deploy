// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { VmSafe } from "../lib/forge-std/src/Vm.sol";

import { IAccessControl }                 from "../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { Initializable }                  from "../lib/diamond-pau/lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IEnumerableIntegrations as IEI } from "../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";
import { IMainnetControllerFull }         from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

import { IAccessControls } from "../lib/diamond-pau/src/interfaces/IAccessControls.sol";
import { IBeacon }         from "../lib/diamond-pau/src/interfaces/IBeacon.sol";

import { IUniswapV4Facet } from "../lib/diamond-pau/src/facets/uniswap-v4/IUniswapV4Facet.sol";

import { Ethereum as SkyEthereum }   from "../lib/sky-pau-registry/src/Ethereum.sol";
import { Ethereum as SparkEthereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { IAdministeredAgent } from "../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { PostDeployTestBase } from "./PostDeployTestBase.t.sol";

interface ILegacyMainnetControllerLike {

    function uniswapV4TickLimits(bytes32 poolId) external view returns (int24 tickLower, int24 tickUpper, uint24 maxTickSpacing);

    function maxSlippages(address pool) external view returns (uint256 maxSlippage);

}

contract PostDeployTests is PostDeployTestBase {

    // Paste from script output.
    address internal constant ACCESS_CONTROLS    = 0xD63f44D65180bCEbb1EB3D52858FbE65eE8162A3;
    address internal constant ADMINISTERED_AGENT = 0x0000000000000000000000000000000000000000;
    address internal constant CONTROLLER         = 0x0DCeDfBDb225F0D0973cf05de08c051A663F463c;
    address internal constant DEPLOYER           = 0x1ca4ECaF0E13ca833c80dA835DEEa15e1684361d;

    address internal constant ADMINISTERED_AGENT_FACTORY = SkyEthereum.ADMINISTERED_AGENT_FACTORY;
    address internal constant BEACON                     = SkyEthereum.BEACON;
    address internal constant PAU_FACTORY                = SkyEthereum.PAU_FACTORY;

    address internal constant ADMIN              = SparkEthereum.SPARK_PROXY;
    address internal constant ALLOCATOR          = SparkEthereum.ALM_RELAYER_MULTISIG;
    address internal constant REVOKER            = SparkEthereum.ALM_FREEZER_MULTISIG;
    address internal constant ALM_PROXY          = SparkEthereum.ALM_PROXY;
    address internal constant BACKSTOP_ALLOCATOR = SparkEthereum.ALM_BACKSTOP_RELAYER_MULTISIG;
    address internal constant RATE_LIMITS        = SparkEthereum.ALM_RATE_LIMITS;
    address internal constant LEGACY_CONTROLLER  = SparkEthereum.ALM_CONTROLLER;

    bytes32 internal constant PYUSD_USDS_POOL_ID = 0xe63e32b2ae40601662f760d6bf5d771057324fbd97784fe1d3717069f7b75d45;
    bytes32 internal constant USDT_USDS_POOL_ID  = 0x3b1b1f2e775a6db1664f8e7d59ad568605ea2406312c11aef03146c0cf89d5b9;

    IAccessControls              internal accessControls;
    IAdministeredAgent           internal administeredAgent;
    IBeacon                      internal beacon;
    IMainnetControllerFull       internal controller;
    ILegacyMainnetControllerLike internal legacyController;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        accessControls    = IAccessControls(ACCESS_CONTROLS);
        administeredAgent = IAdministeredAgent(ADMINISTERED_AGENT);
        beacon            = IBeacon(BEACON);
        controller        = IMainnetControllerFull(CONTROLLER);
        legacyController  = ILegacyMainnetControllerLike(LEGACY_CONTROLLER);
    }

    function _getBlock() internal pure returns (uint256) {
        return 25170722; // May-25-2026 07:07:47 AM +UTC : After scripts execution
    }

    function test_deployState() external view {
       /*******************************************************************************************/
       /*** AccessControls post deploy state                                                    ***/
       /*******************************************************************************************/

        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, ADMIN),     true);
        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE, ADMINISTERED_AGENT), true);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ROLE),          1);

        // DEPLOYER/PAU_FACTORY has no roles on AccessControls

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     DEPLOYER), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), false);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     PAU_FACTORY), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, PAU_FACTORY), false);

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

        assertEq(integrations.length, 1);
        assertEq(integrations[0].id,  bytes32(abi.encodePacked("UNISWAP_V4_FACET")));

        for (uint256 i = 0; i < integrations.length; i++) {
            _assertIntegration(integrations[i].id);
        }

        // Configurations: migrate uniswapV4 pools.

        _assertUniswapV4PoolConfigCopy(PYUSD_USDS_POOL_ID);
        _assertUniswapV4PoolConfigCopy(USDT_USDS_POOL_ID);

       /*******************************************************************************************/
       /*** AdministeredAgent post deploy state                                                 ***/
       /*******************************************************************************************/

        assertEq(administeredAgent.adminCount(),   1);
        assertEq(administeredAgent.actorCount(),   2);
        assertEq(administeredAgent.revokerCount(), 1);

        assertEq(administeredAgent.getAdmin(0),   ADMIN);
        assertEq(administeredAgent.getActor(0),   ALLOCATOR);
        assertEq(administeredAgent.getActor(1),   BACKSTOP_ALLOCATOR);
        assertEq(administeredAgent.getRevoker(0), REVOKER);
    }

    function test_postDeployEvents() external {
       /*******************************************************************************************/
       /*** AccessControls events                                                               ***/
       /*******************************************************************************************/

        VmSafe.EthGetLogs[] memory accessControlsAllLogs = _getEvents(block.chainid, ACCESS_CONTROLS, "");

        assertEq(accessControlsAllLogs.length, 4);

        // RoleGranted(DEFAULT_ADMIN_ROLE, DEPLOYER, PAU_FACTORY) from PAUFactory.deployAccessControls: AccessControls constructor.
        assertEq(accessControlsAllLogs[0].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[0].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[0].topics[2]), DEPLOYER);
        assertEq(_toAddress(accessControlsAllLogs[0].topics[3]), PAU_FACTORY);

        // RoleGranted(ALLOCATOR_ROLE, ADMINISTERED_AGENT, DEPLOYER) from ConfigureController: ALLOCATOR_ROLE grant.
        assertEq(accessControlsAllLogs[1].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[1].topics[1],             ALLOCATOR_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[1].topics[2]), ADMINISTERED_AGENT);
        assertEq(_toAddress(accessControlsAllLogs[1].topics[3]), DEPLOYER);

        // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, DEPLOYER) from ConfigureController: DEFAULT_ADMIN_ROLE grant.
        // Role transfers from deployer to admin.
        assertEq(accessControlsAllLogs[2].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[2].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[2].topics[2]), ADMIN);
        assertEq(_toAddress(accessControlsAllLogs[2].topics[3]), DEPLOYER);

        // RoleRevoked(DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER) from ConfigureController: DEFAULT_ADMIN_ROLE revoke.
        // Role revoked from deployer.
        assertEq(accessControlsAllLogs[3].topics[0],             IAccessControl.RoleRevoked.selector);
        assertEq(accessControlsAllLogs[3].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[3].topics[2]), DEPLOYER);
        assertEq(_toAddress(accessControlsAllLogs[3].topics[3]), DEPLOYER);

       /*******************************************************************************************/
       /*** Controller events                                                                   ***/
       /*******************************************************************************************/

        VmSafe.EthGetLogs[] memory controllerAllLogs = _getEvents(block.chainid, CONTROLLER, "");

        assertEq(controllerAllLogs.length, 6);

        // Initialized(1) from Controller constructor.
        _assertInitializedEvent(controllerAllLogs[0]);

        // IntegrationSet(integrationId, config) from ConfigureController: updateIntegrations.
        _assertIntegrationSetEvent(controllerAllLogs[1], bytes32(abi.encodePacked("UNISWAP_V4_FACET")));

        // UniswapV4 pool config copy events.
        _assertUniswapV4MaxSlippageSetEvent(controllerAllLogs[2], PYUSD_USDS_POOL_ID);
        _assertUniswapV4TickLimitsSetEvent(controllerAllLogs[3],  PYUSD_USDS_POOL_ID);

        _assertUniswapV4MaxSlippageSetEvent(controllerAllLogs[4], USDT_USDS_POOL_ID);
        _assertUniswapV4TickLimitsSetEvent(controllerAllLogs[5],  USDT_USDS_POOL_ID);

        /*******************************************************************************************/
        /*** AdministeredAgent events                                                            ***/
        /*******************************************************************************************/

        VmSafe.EthGetLogs[] memory administeredAgentAllLogs = _getEvents(block.chainid, ADMINISTERED_AGENT, "");

        assertEq(administeredAgentAllLogs.length, 6);

        // AdminAdded(DEPLOYER, ADMINISTERED_AGENT_FACTORY) from AdministeredAgent constructor.
        assertEq(administeredAgentAllLogs[0].topics[0],             IAdministeredAgent.AdminAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[0].topics[1]), DEPLOYER);
        assertEq(_toAddress(administeredAgentAllLogs[0].topics[2]), ADMINISTERED_AGENT_FACTORY);

        // ActorAdded(ALLOCATOR, DEPLOYER) from ConfigureController: addActor.
        assertEq(administeredAgentAllLogs[1].topics[0],             IAdministeredAgent.ActorAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[1].topics[1]), ALLOCATOR);
        assertEq(_toAddress(administeredAgentAllLogs[1].topics[2]), DEPLOYER);

        // ActorAdded(BACKSTOP_ALLOCATOR, DEPLOYER) from ConfigureController: addActor.
        assertEq(administeredAgentAllLogs[2].topics[0],             IAdministeredAgent.ActorAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[2].topics[1]), BACKSTOP_ALLOCATOR);
        assertEq(_toAddress(administeredAgentAllLogs[2].topics[2]), DEPLOYER);

        // RevokerAdded(REVOKER, DEPLOYER) from ConfigureController: addRevoker.
        assertEq(administeredAgentAllLogs[3].topics[0],             IAdministeredAgent.RevokerAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[3].topics[1]), REVOKER);
        assertEq(_toAddress(administeredAgentAllLogs[3].topics[2]), DEPLOYER);

        // AdminAdded(ADMIN, DEPLOYER) from ConfigureController: addAdmin.
        assertEq(administeredAgentAllLogs[4].topics[0],             IAdministeredAgent.AdminAdded.selector);
        assertEq(_toAddress(administeredAgentAllLogs[4].topics[1]), ADMIN);
        assertEq(_toAddress(administeredAgentAllLogs[4].topics[2]), DEPLOYER);

        // AdminRemoved(DEPLOYER, DEPLOYER) from ConfigureController: removeAdmin.
        assertEq(administeredAgentAllLogs[5].topics[0],             IAdministeredAgent.AdminRemoved.selector);
        assertEq(_toAddress(administeredAgentAllLogs[5].topics[1]), DEPLOYER);
        assertEq(_toAddress(administeredAgentAllLogs[5].topics[2]), DEPLOYER);
    }

    /*******************************************************************************************/
    /*** Helper functions                                                                    ***/
    /*******************************************************************************************/

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

    function _assertUniswapV4PoolConfigCopy(bytes32 poolId) internal view {
        uint256 oldMaxSlippage = legacyController.maxSlippages(address(uint160(uint256(poolId))));

        assertEq(controller.uniswapV4_getMaxSlippage(poolId), oldMaxSlippage);

        ( int24 oldTickLower, int24 oldTickUpper, uint24 oldMaxTickSpacing ) = legacyController.uniswapV4TickLimits(poolId);
        ( int24 newTickLower, int24 newTickUpper, uint24 newMaxTickSpacing ) = controller.uniswapV4_getTickLimits(poolId);

        assertEq(newTickLower,      oldTickLower);
        assertEq(newTickUpper,      oldTickUpper);
        assertEq(newMaxTickSpacing, oldMaxTickSpacing);
    }

    /*******************************************************************************************/
    /*** Event test helpers                                                                  ***/
    /*******************************************************************************************/

    function _assertInitializedEvent(VmSafe.EthGetLogs memory log) internal pure {
        assertEq(log.topics[0], Initializable.Initialized.selector);
        assertEq(log.data,      abi.encode(1));
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

    function _assertUniswapV4MaxSlippageSetEvent(VmSafe.EthGetLogs memory log, bytes32 poolId) internal view {
        uint256 oldMaxSlippage = legacyController.maxSlippages(address(uint160(uint256(poolId))));

        assertEq(log.topics[0], IUniswapV4Facet.UniswapV4MaxSlippageSet.selector);
        assertEq(log.topics[1], poolId);
        assertEq(log.data,      abi.encode(oldMaxSlippage));
    }

    function _assertUniswapV4TickLimitsSetEvent(VmSafe.EthGetLogs memory log, bytes32 poolId) internal view {
        ( int24 oldTickLower, int24 oldTickUpper, uint24 oldMaxTickSpacing ) = legacyController.uniswapV4TickLimits(poolId);

        assertEq(log.topics[0], IUniswapV4Facet.UniswapV4TickLimitsSet.selector);
        assertEq(log.topics[1], poolId);
        assertEq(log.data,      abi.encode(oldTickLower, oldTickUpper, oldMaxTickSpacing));
    }

}
