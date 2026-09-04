// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { CCTPv2Forwarder } from "../../lib/diamond-pau/lib/grove-xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { ConfigureSparkPAUStagingBase } from "../ConfigureSparkPAUStagingBase.s.sol";

contract ConfigureSparkPAUStagingFull is ConfigureSparkPAUStagingBase {

    address internal constant ETHEREUM_ALM_PROXY = 0xe6A3179615cA28abd2d0a0d83bAAC21B24Ff7fFF;

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
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(uint256(uint160(ETHEREUM_ALM_PROXY))),
            0,
            100
        );

        // Set rate limits
        rateLimits.setRateLimitData(controller.cctp_toCCTPRateLimitKey(), 10e6, uint256(100e6) / 1 hours);

        rateLimits.setRateLimitData(
            controller.cctp_getToDomainRateLimitKey(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            10e6,
            uint256(100e6) / 1 hours
        );
    }

}
