// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { PostStagingDeployTestBase } from "../PostStagingDeployTestBase.t.sol";

/// Parallel staging deployment: 0-DeploySparkPAUParallel with the deployer as admin, then
/// 1-ConfigureSparkPAUStagingParallel. The existing ALMProxy is left untouched by both scripts.
contract PostStagingDeployParallel is PostStagingDeployTestBase {

    function _getBlock() internal pure override returns (uint256) {
        return 25170722; // Paste from script output : After scripts execution
    }

    function _isFullDeployment() internal pure override returns (bool) {
        return false;
    }

    function _setDeploymentAddresses() internal override {
        // Paste from script output.
        ACCESS_CONTROLS    = 0xD63f44D65180bCEbb1EB3D52858FbE65eE8162A3;
        ADMINISTERED_AGENT = 0x0000000000000000000000000000000000000000;
        CONTROLLER         = 0x0DCeDfBDb225F0D0973cf05de08c051A663F463c;
        RATE_LIMITS        = 0x0000000000000000000000000000000000000000;

        // A parallel deployment attaches to the existing ALMProxy.
        ALM_PROXY = EXISTING_ALM_PROXY;

        // Paste from script/input/1/config-mainnet-staging.json.
        ADMIN    = 0xb52991d5d29f371f493910c36f5A849b3748Cc28;
        DEPLOYER = 0x1ca4ECaF0E13ca833c80dA835DEEa15e1684361d;
    }

}
