// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { PostStagingDeployTestBase } from "../PostStagingDeployTestBase.t.sol";

/// Full staging deployment: 0-DeploySparkPAUFull with the deployer as admin, then
/// 1-ConfigureSparkPAUStagingFull which also wires the newly deployed ALMProxy.
contract PostStagingDeployFull is PostStagingDeployTestBase {

    function _getBlock() internal pure override returns (uint256) {
        return 0; // Paste from script output : After scripts execution
    }

    function _isFullDeployment() internal pure override returns (bool) {
        return true;
    }

    function _setDeploymentAddresses() internal override {
        // Paste from script output.
        ACCESS_CONTROLS    = 0x0000000000000000000000000000000000000000;
        ADMINISTERED_AGENT = 0x0000000000000000000000000000000000000000;
        ALM_PROXY          = 0x0000000000000000000000000000000000000000;
        CONTROLLER         = 0x0000000000000000000000000000000000000000;
        RATE_LIMITS        = 0x0000000000000000000000000000000000000000;

        // Paste from script/input/1/config-mainnet-staging.json.
        ADMIN    = 0xb52991d5d29f371f493910c36f5A849b3748Cc28;
        DEPLOYER = 0x0000000000000000000000000000000000000000;
        FREEZER  = 0x611C7c37F296240c2fF5a92f0B4a398B01B237c4;
        RELAYER  = 0x611C7c37F296240c2fF5a92f0B4a398B01B237c4;
    }

}
