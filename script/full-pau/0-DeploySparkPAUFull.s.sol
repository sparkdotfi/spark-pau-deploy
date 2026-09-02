// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { console2 } from "../../lib/forge-std/src/console2.sol";

import { DeploySparkPAUBase } from "../DeploySparkPAUBase.s.sol";

contract DeploySparkPAUFull is DeploySparkPAUBase {

    function run() public override {
        super.run();
    }

    function _deployALMProxy() internal override returns (address proxy) {
        proxy = pauFactory.deployALMProxy(admin);

        console2.log("ALMProxy deployed at: ", proxy);
    }

}
