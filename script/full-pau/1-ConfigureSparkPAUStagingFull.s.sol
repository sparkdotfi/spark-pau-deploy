// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ConfigureSparkPAUStagingBase } from "../ConfigureSparkPAUStagingBase.s.sol";

contract ConfigureSparkPAUStagingFull is ConfigureSparkPAUStagingBase {

    function run() public override {
        super.run();
    }

    function _isFullDeployment() internal override returns (bool isFullDeployment) {
        return true;
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
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(uint256(uint160(Base.ALM_PROXY))),
            0,
            100
        );

        // Set rate limits
        rateLimits.setRateLimitData(controller.cctp_toCCTPRateLimitKey(), 10e6, 0);

        rateLimits.setRateLimitData(
            controller.cctp_getToDomainRateLimitKey(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE),
            10e6,
            0
        );
    }

}
