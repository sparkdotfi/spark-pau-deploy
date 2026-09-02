// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Ethereum as SparkEthereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { DeploySparkPAUBase } from "../DeploySparkPAUBase.s.sol";

contract DeploySparkPAUParallel is DeploySparkPAUBase {

    function run() public override {
        super.run();
    }

    function _deployALMProxy() internal override returns (address proxy) {
        proxy = almProxy;
    }

}
