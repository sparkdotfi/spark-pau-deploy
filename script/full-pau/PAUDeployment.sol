// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

/**
 * @notice Addresses produced by one run of the deploy script. `run()` stores and returns it so
 *         that a caller (the configure step, a test) can consume the deployment without reading
 *         `script/output/`.
 */
struct PAUDeployment {
    address proxy;
    address controller;
    address accessControls;
    address rateLimits;
    address allocatorAgent;
    address beacon;
}
