// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { console2 } from "../lib/forge-std/src/console2.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { Ethereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { IAdministeredAgent } from "../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { IMainnetControllerFull } from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

interface IAccessControlsLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

}

interface ILegacyMainnetControllerLike {

    function uniswapV4TickLimits(bytes32 poolId) external view returns (int24 tickLower, int24 tickUpper, uint24 maxTickSpacing);

    function maxSlippages(address pool) external view returns (uint256 maxSlippage);

}

contract ConfigureController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    bytes32 internal constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");

    bytes32 internal constant PYUSD_USDS_POOL_ID = 0xe63e32b2ae40601662f760d6bf5d771057324fbd97784fe1d3717069f7b75d45;
    bytes32 internal constant USDT_USDS_POOL_ID  = 0x3b1b1f2e775a6db1664f8e7d59ad568605ea2406312c11aef03146c0cf89d5b9;

    IAccessControlsLike          internal accessControls;
    IMainnetControllerFull       internal controller;
    ILegacyMainnetControllerLike internal legacyController;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("config-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "ConfigureController/invalid-chain-id");

        controller       = IMainnetControllerFull(config.readAddress(".controller"));
        legacyController = ILegacyMainnetControllerLike(Ethereum.ALM_CONTROLLER);
        accessControls   = IAccessControlsLike(controller.accessControls());

        address deployer = config.readAddress(".deployer");

        vm.startBroadcast();

        require(msg.sender == deployer, "ConfigureController/sender-not-deployer");

        // Step 1: Update integrations.

        _updateIntegrations();

        console2.log("Integrations updated");

        // Step 2: Copy uniswapV4 pools.

        _copyUniswapV4PoolConfig(PYUSD_USDS_POOL_ID);
        _copyUniswapV4PoolConfig(USDT_USDS_POOL_ID);

        console2.log("UniswapV4 pools config copied");

        // Step 3: Grant ALLOCATOR_ROLE to administeredAgent.

        address administeredAgent = config.readAddress(".administeredAgent");

        accessControls.grantRole(ALLOCATOR_ROLE, administeredAgent);

        // Step 4: Transfer DEFAULT_ADMIN_ROLE to admin and revoke from deployer.

        accessControls.grantRole(accessControls.DEFAULT_ADMIN_ROLE(),  Ethereum.SPARK_PROXY);
        accessControls.revokeRole(accessControls.DEFAULT_ADMIN_ROLE(), deployer);

        // Step 5: Add admins, actors and revokers to administeredAgent.

        IAdministeredAgent(administeredAgent).addActor(Ethereum.ALM_RELAYER_MULTISIG);
        IAdministeredAgent(administeredAgent).addActor(Ethereum.ALM_BACKSTOP_RELAYER_MULTISIG);
        IAdministeredAgent(administeredAgent).addRevoker(Ethereum.ALM_FREEZER_MULTISIG);

        // Step 6: Add admin to administeredAgent and remove deployer.

        IAdministeredAgent(administeredAgent).addAdmin(Ethereum.SPARK_PROXY);
        IAdministeredAgent(administeredAgent).removeAdmin(deployer);

        console2.log("AccessControls and AdministeredAgent roles configured and transferred");

        vm.stopBroadcast();
    }

    function _copyUniswapV4PoolConfig(bytes32 poolId) internal {
        // Step 1: Copy max slippage.

        controller.uniswapV4_setMaxSlippage(poolId, legacyController.maxSlippages(address(uint160(uint256(poolId)))));

        // Step 2: Copy tick limits.

        ( int24 tickLower, int24 tickUpper, uint24 maxTickSpacing ) = legacyController.uniswapV4TickLimits(poolId);

        controller.uniswapV4_setTickLimits(poolId, tickLower, tickUpper, maxTickSpacing);
    }

    function _updateIntegrations() internal {
        bytes32[] memory integrationIds = new bytes32[](1);

        integrationIds[0] = "UNISWAP_V4_FACET";

        controller.updateIntegrations(integrationIds);
    }

}
