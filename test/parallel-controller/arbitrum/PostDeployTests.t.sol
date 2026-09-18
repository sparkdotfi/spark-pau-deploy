// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { stdJson } from "../../../lib/forge-std/src/StdJson.sol";
import { VmSafe }  from "../../../lib/forge-std/src/Vm.sol";

import { IBeacon }                        from "../../../lib/diamond-pau/src/interfaces/IBeacon.sol";
import { IEnumerableIntegrations as IEI } from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { ICCTPFacet } from "../../../lib/diamond-pau/src/facets/cctp/ICCTPFacet.sol";

import { BeaconConfig } from "../../../src/BeaconConfig.sol";

import { PostDeployTestBaseParallel } from "../PostDeployTestBaseParallel.t.sol";

abstract contract ArbitrumPostDeployTestsBase is PostDeployTestBaseParallel {

    // CCTP_FACET configuration
    bytes32 internal constant CCTP_FACET_ID = BeaconConfig.CCTP_INTEGRATION;

    address internal cctpFacet;
    address internal usdc;
    address internal cctpTokenMessenger;

    uint256 internal arbitrumFork;

    function setUp() public override virtual {
        super.setUp();

        arbitrumFork = vm.createSelectFork(getChain("arbitrum_one").rpcUrl, _getBlock());
    }

    function _getBlock() internal virtual pure returns (uint256) {
        return 0;
    }

    // Deployed factories

    function test_pauFactoryState() external view {
        _assertPauFactoryState();
    }

    // Deployed facets

    function test_facets_constructors() external view {
        _assertFacetConstructors();
    }

    // Deployed beacon

    function test_beaconState() external {
        _assertBeaconState();

        // Exactly one integration: CCTP_FACET.
        IEI.Integration[] memory integrations = beacon.integrations();

        assertEq(integrations.length, 1);
        assertEq(integrations[0].id,  CCTP_FACET_ID);

        // Facet address and wire count match what BeaconConfig.setCCTPIntegration wrote.
        assertEq(integrations[0].config.facet,        cctpFacet);
        assertEq(integrations[0].config.wires.length, 10);

        vm.createSelectFork(getChain("mainnet").rpcUrl, 26005219); // September 18, 2026

        for (uint256 i = 0; i < integrations.length; ++i) {
            IEI.Config memory arbitrumBeaconConfig = integrations[i].config;
            IEI.Config memory skyBeaconConfig      = skyMainnetBeacon.getConfig(integrations[i].id);

            // Facets are per-chain deployments, so only the wiring is compared across beacons.
            assertEq(arbitrumBeaconConfig.wires.length, skyBeaconConfig.wires.length);

            // Sky wires the same pairs in a different order, so each wire is matched through Sky's
            // dispatch rather than by position.
            for (uint256 j; j < arbitrumBeaconConfig.wires.length; ++j) {
                IEI.Dispatch memory skyDispatch = skyMainnetBeacon.getDispatch(arbitrumBeaconConfig.wires[j].callSelector);

                assertEq(skyDispatch.facet,            skyBeaconConfig.facet);
                assertEq(skyDispatch.delegateSelector, arbitrumBeaconConfig.wires[j].delegateSelector);
            }
        }

        vm.selectFork(arbitrumFork);
    }

    function test_beaconEvents() external virtual {
        _assertBeaconEvents();
    }

    // Deployed PAU stack

    function test_administeredAgentState() external view {
        _assertAdministeredAgentState();
    }

    function test_administeredAgentEvents() external virtual {
        _assertAdministeredAgentEvents();
    }

    function test_accessControlsState() external view {
        _assertAccessControlsState();
    }

    function test_accessControlsEvents() external virtual {
        _assertAccessControlsEvents();
    }

    function test_almProxyState_unchanged() external view {
        _assertALMProxyState_unchanged();
    }

    function test_rateLimitsState() external view {
        _assertRateLimitsInitializationState();
    }

    function test_rateLimitsEvents() external virtual {
        _assertRateLimitsEvents();
    }

    function test_controllerState() external view {
        _assertControllerInitializationState();

        // Exactly one integration: CCTP_FACET.
        IEI.Integration[] memory integrations = controller.integrations();

        assertEq(integrations.length, 1);
        assertEq(integrations[0].id,  CCTP_FACET_ID);

        // Facet address and wire count match Controller.updateIntegrations result.
        IEI.Config memory config = controller.getConfig(CCTP_FACET_ID);

        assertEq(config.facet,        cctpFacet);
        assertEq(config.wires.length, 10);

        // Check Controller integrations matches Arbitrum Beacon

        IEI.Config memory arbitrumBeaconConfig = beacon.getConfig(CCTP_FACET_ID);
        IEI.Config memory controllerConfig     = controller.getConfig(CCTP_FACET_ID);

        assertEq(arbitrumBeaconConfig.facet,        controllerConfig.facet);
        assertEq(arbitrumBeaconConfig.wires.length, controllerConfig.wires.length);

        for (uint256 i; i < controllerConfig.wires.length; i++) {
            assertEq(controllerConfig.wires[i].callSelector,     arbitrumBeaconConfig.wires[i].callSelector);
            assertEq(controllerConfig.wires[i].delegateSelector, arbitrumBeaconConfig.wires[i].delegateSelector);
        }
    }

    function test_controllerEvents() external virtual {
        _assertControllerEvents();
    }

    /**********************************************************************************************/
    /*** Event assertions helpers                                                               ***/
    /**********************************************************************************************/

    function _assertBeaconEvents() internal {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(beacon), "");

        assertEq(logs.length, 4);

        // Grant deployer DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[0],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : deployer
        });

        // Assert CCTP_FACET_ID integration set event
        _assertIntegrationSetEvent({
            log           : logs[1],
            integrationId : CCTP_FACET_ID
        });

        // Grant admin DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[2],
            role    : DEFAULT_ADMIN_ROLE,
            account : admin,
            sender  : deployer
        });

        // Revoke deployer DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[3],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : deployer
        });
    }

    function _assertAccessControlsEvents() internal {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(accessControls), "");

        assertEq(logs.length, 4);

        // Grant deployer DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[0],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : address(pauFactory)
        });

        // Grant admin DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[1],
            role    : DEFAULT_ADMIN_ROLE,
            account : admin,
            sender  : deployer
        });

        // Grant administeredAgent ALLOCATOR_ROLE
        _assertRoleGrantedEvent({
            log     : logs[2],
            role    : ALLOCATOR_ROLE,
            account : address(administeredAgent),
            sender  : deployer
        });

        // Revoke deployer DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[3],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : deployer
        });
    }

    function _assertAdministeredAgentEvents() internal virtual {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(administeredAgent), "");

        assertEq(logs.length, 6);

        // Add deployer as admin
        _assertAdminAddedEvent({
            log     : logs[0],
            account : deployer,
            caller  : address(agentFactory)
        });

        // Add admin as admin
        _assertAdminAddedEvent({
            log     : logs[1],
            account : admin,
            caller  : deployer
        });

        // Add relayer as actor
        _assertActorAddedEvent({
            log     : logs[2],
            account : relayer,
            caller  : deployer
        });

        // Add grantor
        _assertGrantorAddedEvent({
            log     : logs[3],
            account : grantor,
            caller  : deployer
        });

        // Add freezer as revoker
        _assertRevokerAddedEvent({
            log     : logs[4],
            account : freezer,
            caller  : deployer
        });

        // Remove deployer as admin
        _assertAdminRemovedEvent({
            log     : logs[5],
            account : deployer,
            caller  : deployer
        });
    }

    function _assertRateLimitsEvents() internal {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(rateLimits), "");

        assertEq(logs.length, 4);

        // Grant deployer DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[0],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : address(pauFactory)
        });

        // Grant admin DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[1],
            role    : DEFAULT_ADMIN_ROLE,
            account : admin,
            sender  : deployer
        });

        // Grant controller CONTROLLER_ROLE
        _assertRoleGrantedEvent({
            log     : logs[2],
            role    : CONTROLLER_ROLE,
            account : address(controller),
            sender  : deployer
        });

        // Revoke deployer DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[3],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : deployer
        });
    }

    function _assertControllerEvents() internal {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(controller), "");

        assertEq(logs.length, 2);

        // Assert controller Initialized event
        _assertInitializedEvent({
            log: logs[0]
        });

        // Assert CCTP_FACET_ID integration set event
        _assertIntegrationSetEvent({
            log           : logs[1],
            integrationId : CCTP_FACET_ID
        });
    }

}

contract ArbitrumPostDeployTestsProduction is ArbitrumPostDeployTestsBase {

    using stdJson for string;

    function setUp() public override {
        super.setUp();

        string memory json = vm.readFile("deployments/parallel-controller/arbitrum-production.json");

        _setUpAddresses(json);

        cctpFacet          = json.readAddress(".cctpFacet");
        usdc               = json.readAddress(".usdc");
        cctpTokenMessenger = json.readAddress(".cctpTokenMessenger");
    }

    function _getBlock() internal override pure returns (uint256) {
        return 506472875;
    }

    function _assertFacetConstructors() internal view override {
        assertEq(ICCTPFacet(cctpFacet).cctp(), cctpTokenMessenger);
        assertEq(ICCTPFacet(cctpFacet).usdc(), usdc);
    }

}
