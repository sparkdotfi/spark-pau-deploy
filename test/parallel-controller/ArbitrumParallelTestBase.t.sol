// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IAccessControlEnumerable } from "../../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

import { IEnumerableIntegrations as IEI } from "../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { ICCTPFacet } from "../../lib/diamond-pau/src/facets/cctp/ICCTPFacet.sol";

import { BeaconConfig } from "../../src/BeaconConfig.sol";

import { PostDeployTestBase } from "../PostDeployTestBase.t.sol";

/**
 * @notice State assertions shared by the fork end-to-end test (runs the deploy + configure
 *         scripts on a fork) and the post-deploy test (reads the production addresses from
 *         deployments/arbitrum-production.json). Both must see the same end state after the
 *         two scripts have run.
 */
abstract contract ArbitrumParallelTestBase is PostDeployTestBase {

    address internal legacyController;
    address internal backstopRelayer;
    address internal cctpFacet;
    address internal cctpTokenMessenger;
    address internal usdc;
    address internal ethereumAlmProxy;
    uint32  internal ethereumDomainId;

    /**********************************************************************************************/
    /*** Shared State Assertions                                                                ***/
    /**********************************************************************************************/

    function _assertBeaconState() internal view {
        IAccessControlEnumerable beaconRoles = IAccessControlEnumerable(address(beacon));

        // admin holds DEFAULT_ADMIN_ROLE; deployer was revoked in the configure script.
        assertEq(beaconRoles.hasRole(DEFAULT_ADMIN_ROLE, admin),     true);
        assertEq(beaconRoles.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
        assertEq(beaconRoles.hasRole(DEFAULT_ADMIN_ROLE, deployer),  false);

        // PAUFactory is pointed at this Beacon.
        assertEq(pauFactory.beacon(), address(beacon));

        // Exactly one integration: CCTP_FACET.
        IEI.Integration[] memory integrations = beacon.integrations();

        assertEq(integrations.length, 1);
        assertEq(integrations[0].id,  BeaconConfig.CCTP_INTEGRATION);

        // Facet address and wire count match what BeaconConfig.setCCTPIntegration wrote.
        IEI.Config memory config = beacon.getConfig(BeaconConfig.CCTP_INTEGRATION);

        assertEq(config.facet,        cctpFacet);
        assertEq(config.wires.length, 10);

        // Facet immutables: Circle TokenMessengerV2 and native USDC.
        assertEq(ICCTPFacet(cctpFacet).cctp(), cctpTokenMessenger);
        assertEq(ICCTPFacet(cctpFacet).usdc(), usdc);
    }

    function _assertParallelAccessControlsState() internal view {
        IAccessControlEnumerable ac = IAccessControlEnumerable(address(accessControls));

        assertEq(ac.hasRole(DEFAULT_ADMIN_ROLE, admin),     true);
        assertEq(ac.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
        assertEq(ac.hasRole(DEFAULT_ADMIN_ROLE, deployer),  false);

        assertEq(ac.hasRole(ALLOCATOR_ROLE, address(administeredAgent)), true);
        assertEq(ac.getRoleMemberCount(ALLOCATOR_ROLE),                  1);

        assertEq(ac.hasRole(ALLOCATOR_ROLE, deployer), false);
    }

    function _assertParallelALMProxyState() internal view {
        // Untouched by both scripts: the legacy controller keeps operating; the Diamond
        // controller is granted CONTROLLER by the governance spell (not yet at this point).
        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    legacyController),    true);
        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    address(controller)), false);
        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    deployer),            false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, deployer),            false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),               true);
    }

    function _assertParallelRateLimitsState() internal view {
        IAccessControlEnumerable rl = IAccessControlEnumerable(address(rateLimits));

        assertEq(rl.hasRole(DEFAULT_ADMIN_ROLE, admin),               true);
        assertEq(rl.hasRole(DEFAULT_ADMIN_ROLE, deployer),            false);
        assertEq(rl.hasRole(CONTROLLER_ROLE,    address(controller)), true);

        // No rate limits set yet — the spell sets them. Unset keys fail closed.
        _assertRateLimitData(controller.cctp_toCCTPRateLimitKey(),                      0, 0);
        _assertRateLimitData(controller.cctp_getToDomainRateLimitKey(ethereumDomainId), 0, 0);
    }

    function _assertParallelControllerState() internal view {
        _assertControllerInitializationState();

        IEI.Integration[] memory integrations = controller.integrations();

        assertEq(integrations.length, 1);
        assertEq(integrations[0].id,  BeaconConfig.CCTP_INTEGRATION);

        _assertIntegration(BeaconConfig.CCTP_INTEGRATION);

        // Facet reachable through the controller with the expected immutables.
        assertEq(controller.cctp_cctp(), cctpTokenMessenger);
        assertEq(controller.cctp_usdc(), usdc);
    }

    function _assertParallelAdministeredAgentState() internal view {
        // admin added, deployer removed in configure script.
        // 1 actor (relayer only — backstop is not wired on Arbitrum parallel).
        assertEq(administeredAgent.adminCount(),   1);
        assertEq(administeredAgent.actorCount(),   1);
        assertEq(administeredAgent.grantorCount(), 1);
        assertEq(administeredAgent.revokerCount(), 1);

        assertEq(administeredAgent.getAdmin(0),   admin);
        assertEq(administeredAgent.getActor(0),   relayer);
        assertEq(administeredAgent.getGrantor(0), grantor);
        assertEq(administeredAgent.getRevoker(0), freezer);

        assertEq(administeredAgent.getIsAdmin(deployer),              false);
        assertEq(administeredAgent.getIsAdmin(address(agentFactory)), false);
    }

}
