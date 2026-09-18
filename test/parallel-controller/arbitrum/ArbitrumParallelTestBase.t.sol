// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IAccessControlEnumerable } from "../../../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

import { IEnumerableIntegrations as IEI } from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { ICCTPFacet } from "../../../lib/diamond-pau/src/facets/cctp/ICCTPFacet.sol";

import { Arbitrum } from "../../../lib/spark-address-registry/src/Arbitrum.sol";
import { Ethereum } from "../../../lib/spark-address-registry/src/Ethereum.sol";

import { CCTPFacetWiring } from "../../../src/CCTPFacetWiring.sol";

import { PostDeployTestBase } from "../../PostDeployTestBase.t.sol";

/**
 * @notice State assertions shared by the fork end-to-end test (runs ParallelPAULib on a fork)
 *         and the post-deploy test (reads the production addresses). Both must see the same
 *         end state after deploy + configure.
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

        assertEq(beaconRoles.hasRole(DEFAULT_ADMIN_ROLE, admin),     true);
        assertEq(beaconRoles.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
        assertEq(beaconRoles.hasRole(DEFAULT_ADMIN_ROLE, deployer),  false);

        assertEq(pauFactory.beacon(), address(beacon));

        IEI.Integration[] memory integrations = beacon.integrations();

        assertEq(integrations.length, 1);
        assertEq(integrations[0].id,  CCTPFacetWiring.INTEGRATION_ID);

        IEI.Config memory config = beacon.getConfig(CCTPFacetWiring.INTEGRATION_ID);

        assertEq(config.facet, cctpFacet);

        _assertWiresEqual(config.wires, CCTPFacetWiring.wires());

        // Facet immutables: Circle TokenMessengerV2 and native USDC on Arbitrum.
        assertEq(ICCTPFacet(cctpFacet).cctp(), cctpTokenMessenger);
        assertEq(ICCTPFacet(cctpFacet).usdc(), usdc);

        assertEq(cctpTokenMessenger, Arbitrum.CCTP_TOKEN_MESSENGER);
        assertEq(usdc,               Arbitrum.USDC);
    }

    function _assertParallelALMProxyState() internal view {
        assertEq(address(almProxy), Arbitrum.ALM_PROXY);

        // Untouched by both scripts: the legacy controller keeps operating, the Diamond controller
        // is granted CONTROLLER by the governance spell, and the deployer never had a role.
        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    legacyController),    true);
        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    address(controller)), false);
        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    deployer),            false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, deployer),            false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),               true);
    }

    function _assertParallelRateLimitsState() internal view {
        _assertRateLimitsInitializationState();

        // No rate limits set: the spell sets them. Unset keys fail closed.
        _assertRateLimitData(controller.cctp_toCCTPRateLimitKey(),                      0, 0);
        _assertRateLimitData(controller.cctp_getToDomainRateLimitKey(ethereumDomainId), 0, 0);
    }

    function _assertParallelControllerState() internal view {
        _assertControllerInitializationState();

        IEI.Integration[] memory integrations = controller.integrations();

        assertEq(integrations.length, 1);
        assertEq(integrations[0].id,  CCTPFacetWiring.INTEGRATION_ID);

        _assertIntegration(CCTPFacetWiring.INTEGRATION_ID);

        // Facet reachable through the controller with the expected immutables.
        assertEq(controller.cctp_cctp(), cctpTokenMessenger);
        assertEq(controller.cctp_usdc(), usdc);

        // Ethereum domain configured to the Spark Ethereum ALMProxy, fee-free.
        (
            bytes32 mintRecipient,
            uint32  minFeeCapRate,
            uint32  maxFeeCapRate
        ) = controller.cctp_getDomainParameters(ethereumDomainId);

        assertEq(mintRecipient,    bytes32(uint256(uint160(ethereumAlmProxy))));
        assertEq(ethereumAlmProxy, Ethereum.ALM_PROXY);
        assertEq(ethereumDomainId, 0);
        assertEq(minFeeCapRate,    0);
        assertEq(maxFeeCapRate,    0);
    }

    function _assertParallelAdministeredAgentState() internal view {
        assertEq(administeredAgent.adminCount(),   1);
        assertEq(administeredAgent.actorCount(),   2);
        assertEq(administeredAgent.grantorCount(), 1);
        assertEq(administeredAgent.revokerCount(), 1);

        assertEq(administeredAgent.getAdmin(0),   admin);
        assertEq(administeredAgent.getActor(0),   relayer);
        assertEq(administeredAgent.getActor(1),   backstopRelayer);
        assertEq(administeredAgent.getGrantor(0), grantor);
        assertEq(administeredAgent.getRevoker(0), freezer);

        assertEq(administeredAgent.getIsAdmin(deployer),              false);
        assertEq(administeredAgent.getIsAdmin(address(agentFactory)), false);
    }

    function _assertWiresEqual(IEI.Wire[] memory actual, IEI.Wire[] memory expected) internal pure {
        assertEq(actual.length, expected.length);

        for (uint256 i = 0; i < expected.length; ++i) {
            assertEq(actual[i].callSelector,     expected[i].callSelector);
            assertEq(actual[i].delegateSelector, expected[i].delegateSelector);
        }
    }

}
