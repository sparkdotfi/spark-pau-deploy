// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { PAUFactory } from "../lib/diamond-pau/src/PAUFactory.sol";

library PAUDeploy {

    function deploy(address admin) internal returns (address controller) {
        PAUFactory factory = new PAUFactory();

        controller = factory.deploy(admin);
    }

}
