// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Ethereum as SparkEthereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { PostProductionDeployTestBase } from "../PostProductionDeployTestBase.t.sol";

/// Parallel production deployment: 0-DeploySparkPAUParallel only, attached to the existing
/// ALMProxy, with SPARK_PROXY as the admin on every deployed component. No configure script is run.
contract PostProductionDeployParallel is PostProductionDeployTestBase {

    function _getBlock() internal pure override returns (uint256) {
        return 0; // Paste from script output : After deploy script execution
    }

    function _isFullDeployment() internal pure override returns (bool) {
        return false;
    }

    function _setDeploymentAddresses() internal override {
        // Paste from script output.
        ACCESS_CONTROLS    = 0x0000000000000000000000000000000000000000;
        ADMINISTERED_AGENT = 0x0000000000000000000000000000000000000000;
        CONTROLLER         = 0x0000000000000000000000000000000000000000;
        RATE_LIMITS        = 0x0000000000000000000000000000000000000000;

        // A parallel deployment attaches to the existing ALMProxy.
        ALM_PROXY = EXISTING_ALM_PROXY;

        // Paste from script/input/1/deploy-mainnet-production.json.
        ADMIN    = SparkEthereum.SPARK_PROXY;
        DEPLOYER = 0x0000000000000000000000000000000000000000;
    }

}
