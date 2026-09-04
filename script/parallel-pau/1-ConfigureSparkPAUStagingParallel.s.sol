// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { CCTPv2Forwarder } from "../../lib/diamond-pau/lib/grove-xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { ConfigureSparkPAUStagingBase } from "../ConfigureSparkPAUStagingBase.s.sol";

contract ConfigureSparkPAUStagingParallel is ConfigureSparkPAUStagingBase {

    address internal constant XLAYER_ALM_PROXY = 0x802360b1B72421736918d9Fc3cfd88AB875bF238;

    uint32 internal constant DOMAIN_ID_CIRCLE_XLAYER = 37;

    function run() public override {
        super.run();
    }

    function _isFullDeployment() internal override returns (bool isFullDeployment) {
        return false;
    }

    function _getIntegrationIds() internal override returns (bytes32[] memory integrationIds) {
        integrationIds = new bytes32[](1);

        integrationIds[0] = "CCTP_FACET";

        return integrationIds;
    }

    function _onboardFacets() internal override {
        _onboardCCTPFacet();
    }

    function _onboardCCTPFacet() internal {
        // Set domain parameters
        controller.cctp_setDomainParameters(
            DOMAIN_ID_CIRCLE_XLAYER,
            bytes32(uint256(uint160(XLAYER_ALM_PROXY))),
            0,
            100
        );

        // Set rate limits
        rateLimits.setRateLimitData(controller.cctp_toCCTPRateLimitKey(), 10e6, 0);

        rateLimits.setRateLimitData(
            controller.cctp_getToDomainRateLimitKey(DOMAIN_ID_CIRCLE_XLAYER),
            10e6,
            0
        );
    }

}
