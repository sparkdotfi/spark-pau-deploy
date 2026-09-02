// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ConfigureSparkPAUStagingBase } from "../ConfigureSparkPAUStagingBase.s.sol";

contract ConfigureSparkPAUStagingParallel is ConfigureSparkPAUStagingBase {

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

}
