// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IEnumerableIntegrations as IEI } from "../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { IFacet }     from "../lib/diamond-pau/src/facets/IFacet.sol";
import { ICCTPFacet } from "../lib/diamond-pau/src/facets/cctp/ICCTPFacet.sol";

import { IMainnetControllerFull as IControllerFull } from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

/**
 * @title  CCTPFacetWiring
 * @notice Canonical Beacon wiring for the CCTP facet: the ten `cctp_*` selectors exposed on a
 *         Controller and the facet selector each one delegates to.
 * @dev    The wire order matches the CCTP_FACET integration on the Spark Ethereum Beacon so a
 *         Beacon deployed on another chain with this library can be diffed against it wire for
 *         wire (see test/parallel-controller/arbitrum/PostDeployTests.t.sol).
 */
library CCTPFacetWiring {

    bytes32 internal constant INTEGRATION_ID = "CCTP_FACET";

    uint256 internal constant WIRE_COUNT = 10;

    function wires() internal pure returns (IEI.Wire[] memory wires_) {
        wires_ = new IEI.Wire[](WIRE_COUNT);

        wires_[0] = IEI.Wire(IControllerFull.cctp_setDomainParameters.selector,     ICCTPFacet.setDomainParameters.selector);
        wires_[1] = IEI.Wire(IControllerFull.cctp_transfer.selector,                ICCTPFacet.transfer.selector);
        wires_[2] = IEI.Wire(IControllerFull.cctp_toCCTPRateLimitKey.selector,      ICCTPFacet.toCCTPRateLimitKey.selector);
        wires_[3] = IEI.Wire(IControllerFull.cctp_getDomainParameters.selector,     ICCTPFacet.getDomainParameters.selector);
        wires_[4] = IEI.Wire(IControllerFull.cctp_getToDomainRateLimitKey.selector, ICCTPFacet.getToDomainRateLimitKey.selector);
        wires_[5] = IEI.Wire(IControllerFull.cctp_VERSION.selector,                 IFacet.VERSION.selector);
        wires_[6] = IEI.Wire(IControllerFull.cctp_DESTINATION_CALLER.selector,      ICCTPFacet.DESTINATION_CALLER.selector);
        wires_[7] = IEI.Wire(IControllerFull.cctp_MIN_FINALITY_THRESHOLD.selector,  ICCTPFacet.MIN_FINALITY_THRESHOLD.selector);
        wires_[8] = IEI.Wire(IControllerFull.cctp_cctp.selector,                    ICCTPFacet.cctp.selector);
        wires_[9] = IEI.Wire(IControllerFull.cctp_usdc.selector,                    ICCTPFacet.usdc.selector);
    }

    function config(address facet) internal pure returns (IEI.Config memory config_) {
        config_ = IEI.Config({
            facet : facet,
            wires : wires()
        });
    }

}
