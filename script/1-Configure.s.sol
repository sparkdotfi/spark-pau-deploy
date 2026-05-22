// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { Ethereum }  from "../lib/spark-address-registry/src/Ethereum.sol";
import { SparkLend } from "../lib/spark-address-registry/src/SparkLend.sol";

import { IMainnetControllerFull } from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { console2 } from "../lib/forge-std/src/console2.sol";

interface IOldMainnetControllerLike {

    function uniswapV4TickLimits(bytes32 poolId) external view returns (int24 tickLower, int24 tickUpper, uint24 maxTickSpacing);

    function maxSlippages(address pool) external view returns (uint256 maxSlippage);

    function maxExchangeRates(address vault) external view returns (uint256 maxExchangeRate);

}

contract ConfigureController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    struct IntegrationIds {
        bytes32 aaveFacet;
        bytes32 basinFacet;
        bytes32 cctpFacet;
        bytes32 centrifugeFacet;
        bytes32 curveFacet;
        bytes32 daiUsdsFacet;
        bytes32 erc4626Facet;
        bytes32 erc7540Facet;
        bytes32 ethenaFacet;
        bytes32 farmFacet;
        bytes32 layerZeroFacet;
        bytes32 mapleFacet;
        bytes32 merklFacet;
        bytes32 otcFacet;
        bytes32 pendleFacet;
        bytes32 psmFacet;
        bytes32 psm3Facet;
        bytes32 sparkVaultFacet;
        bytes32 superstateFacet;
        bytes32 transferAssetFacet;
        bytes32 uniswapV3Facet;
        bytes32 uniswapV4Facet;
        bytes32 usdsFacet;
        bytes32 weethFacet;
        bytes32 wrapProxyETHFacet;
        bytes32 wstethFacet;
    }

    bytes32 internal constant PYUSD_USDS_POOL_ID = 0xe63e32b2ae40601662f760d6bf5d771057324fbd97784fe1d3717069f7b75d45;
    bytes32 internal constant USDT_USDS_POOL_ID  = 0x3b1b1f2e775a6db1664f8e7d59ad568605ea2406312c11aef03146c0cf89d5b9;

    IMainnetControllerFull    internal controller;
    IOldMainnetControllerLike internal oldController;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("config-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "ConfigureController/invalid-chain-id");

        controller    = IMainnetControllerFull(config.readAddress(".controller"));
        oldController = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER);

        vm.startBroadcast();

        // Step 1: Update integrations.

        _updateIntegrations(config);

        console2.log("Integrations updated");

        // Step 2: Migrate ERC4626 max exchange rates.

        _migrateERC4626MaxExchangeRates(Ethereum.MORPHO_VAULT_USDC_BC, 10);
        _migrateERC4626MaxExchangeRates(Ethereum.MORPHO_VAULT_DAI_1,   10);
        _migrateERC4626MaxExchangeRates(Ethereum.MORPHO_VAULT_USDS,    10);
        _migrateERC4626MaxExchangeRates(Ethereum.MORPHO_VAULT_V2_USDT, 1_000_000);
        _migrateERC4626MaxExchangeRates(Ethereum.SUSDS,                10);
        _migrateERC4626MaxExchangeRates(Ethereum.FLUID_SUSDS,          10);
        _migrateERC4626MaxExchangeRates(Ethereum.SUSDE,                10);
        _migrateERC4626MaxExchangeRates(Ethereum.SYRUP_USDC,           10);
        _migrateERC4626MaxExchangeRates(Ethereum.SYRUP_USDT,           10);
        _migrateERC4626MaxExchangeRates(Ethereum.ARKIS_VAULT,          10);

        console2.log("ERC4626 max exchange rates updated");

        // Step 3: Migrate curve max slippage.

        _migrateCurveMaxSlippage(Ethereum.CURVE_SUSDSUSDT);
        _migrateCurveMaxSlippage(Ethereum.CURVE_PYUSDUSDC);
        _migrateCurveMaxSlippage(Ethereum.CURVE_USDCUSDT);
        _migrateCurveMaxSlippage(Ethereum.CURVE_PYUSDUSDS);
        _migrateCurveMaxSlippage(Ethereum.CURVE_WEETHWETHNG);

        console2.log("Curve max slippage updated");

        // Step 4: Migrate aave max slippage.

        _migrateAaveMaxSlippage(Ethereum.ATOKEN_CORE_USDC);
        _migrateAaveMaxSlippage(Ethereum.ATOKEN_CORE_USDE);
        _migrateAaveMaxSlippage(Ethereum.ATOKEN_CORE_USDS);
        _migrateAaveMaxSlippage(Ethereum.ATOKEN_CORE_USDT);
        _migrateAaveMaxSlippage(Ethereum.ATOKEN_PRIME_USDS);

        _migrateAaveMaxSlippage(SparkLend.DAI_SPTOKEN);
        _migrateAaveMaxSlippage(SparkLend.USDC_SPTOKEN);
        _migrateAaveMaxSlippage(SparkLend.USDS_SPTOKEN);
        _migrateAaveMaxSlippage(SparkLend.USDT_SPTOKEN);
        _migrateAaveMaxSlippage(SparkLend.PYUSD_SPTOKEN);
        _migrateAaveMaxSlippage(SparkLend.WETH_SPTOKEN);

        console2.log("Aave max slippage updated");

        // Step 5: Migrate uniswapV4 pools.

        _migrateUniswapV4Pool(PYUSD_USDS_POOL_ID);
        _migrateUniswapV4Pool(USDT_USDS_POOL_ID);

        console2.log("UniswapV4 pools updated");

        vm.stopBroadcast();
    }

    function _migrateERC4626MaxExchangeRates(address vault, uint256 rate) internal {
        controller.erc4626_setMaxExchangeRate(vault, 1, rate);

        require(
            controller.erc4626_getMaxExchangeRate(vault) == oldController.maxExchangeRates(vault),
            "ConfigureController/max-exchange-rate-not-migrated"
        );
    }

    function _migrateCurveMaxSlippage(address pool) internal {
        controller.curve_setMaxSlippage(pool, oldController.maxSlippages(pool));
    }

    function _migrateAaveMaxSlippage(address aToken) internal {
        controller.aave_setMaxSlippage(aToken, oldController.maxSlippages(aToken));
    }

    function _migrateUniswapV4Pool(bytes32 poolId) internal {
        // Step 1: Migrate max slippage.

        controller.uniswapV4_setMaxSlippage(poolId, oldController.maxSlippages(address(uint160(uint256(poolId)))));

        // Step 2: Migrate tick limits.

        ( int24 tickLower, int24 tickUpper, uint24 maxTickSpacing ) = oldController.uniswapV4TickLimits(poolId);

        controller.uniswapV4_setTickLimits(poolId, tickLower, tickUpper, maxTickSpacing);
    }

    function _updateIntegrations(string memory config) internal {
        IntegrationIds memory allIntegrationIds = _readIntegrationIds(config);

        bytes32[] memory integrationIds = new bytes32[](config.readUint(".integrationIds.length"));

        bytes32 emptyIntegrationId = bytes32(keccak256(abi.encodePacked("")));

        uint256 i;

        if (allIntegrationIds.aaveFacet          != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.aaveFacet;
        if (allIntegrationIds.basinFacet         != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.basinFacet;
        if (allIntegrationIds.cctpFacet          != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.cctpFacet;
        if (allIntegrationIds.centrifugeFacet    != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.centrifugeFacet;
        if (allIntegrationIds.curveFacet         != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.curveFacet;
        if (allIntegrationIds.daiUsdsFacet       != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.daiUsdsFacet;
        if (allIntegrationIds.erc4626Facet       != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.erc4626Facet;
        if (allIntegrationIds.erc7540Facet       != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.erc7540Facet;
        if (allIntegrationIds.ethenaFacet        != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.ethenaFacet;
        if (allIntegrationIds.farmFacet          != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.farmFacet;
        if (allIntegrationIds.layerZeroFacet     != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.layerZeroFacet;
        if (allIntegrationIds.mapleFacet         != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.mapleFacet;
        if (allIntegrationIds.merklFacet         != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.merklFacet;
        if (allIntegrationIds.otcFacet           != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.otcFacet;
        if (allIntegrationIds.pendleFacet        != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.pendleFacet;
        if (allIntegrationIds.psmFacet           != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.psmFacet;
        if (allIntegrationIds.psm3Facet          != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.psm3Facet;
        if (allIntegrationIds.sparkVaultFacet    != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.sparkVaultFacet;
        if (allIntegrationIds.superstateFacet    != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.superstateFacet;
        if (allIntegrationIds.transferAssetFacet != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.transferAssetFacet;
        if (allIntegrationIds.uniswapV3Facet     != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.uniswapV3Facet;
        if (allIntegrationIds.uniswapV4Facet     != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.uniswapV4Facet;
        if (allIntegrationIds.usdsFacet          != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.usdsFacet;
        if (allIntegrationIds.weethFacet         != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.weethFacet;
        if (allIntegrationIds.wrapProxyETHFacet  != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.wrapProxyETHFacet;
        if (allIntegrationIds.wstethFacet        != emptyIntegrationId) integrationIds[i++] = allIntegrationIds.wstethFacet;

        require(i + 1 == config.readUint(".integrationIds.length"), "ConfigureController/invalid-number-of-facets");

        controller.updateIntegrations(integrationIds);
    }

    function _readIntegrationIds(
        string memory config
    ) internal pure returns (IntegrationIds memory integrationIds) {
        integrationIds.aaveFacet          = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.aaveFacet"))));
        integrationIds.basinFacet         = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.basinFacet"))));
        integrationIds.cctpFacet          = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.cctpFacet"))));
        integrationIds.centrifugeFacet    = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.centrifugeFacet"))));
        integrationIds.curveFacet         = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.curveFacet"))));
        integrationIds.daiUsdsFacet       = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.daiUsdsFacet"))));
        integrationIds.erc4626Facet       = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.erc4626Facet"))));
        integrationIds.erc7540Facet       = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.erc7540Facet"))));
        integrationIds.ethenaFacet        = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.ethenaFacet"))));
        integrationIds.farmFacet          = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.farmFacet"))));
        integrationIds.layerZeroFacet     = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.layerZeroFacet"))));
        integrationIds.mapleFacet         = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.mapleFacet"))));
        integrationIds.merklFacet         = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.merklFacet"))));
        integrationIds.otcFacet           = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.otcFacet"))));
        integrationIds.pendleFacet        = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.pendleFacet"))));
        integrationIds.psmFacet           = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.psmFacet"))));
        integrationIds.psm3Facet          = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.psm3Facet"))));
        integrationIds.sparkVaultFacet    = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.sparkVaultFacet"))));
        integrationIds.superstateFacet    = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.superstateFacet"))));
        integrationIds.transferAssetFacet = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.transferAssetFacet"))));
        integrationIds.uniswapV3Facet     = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.uniswapV3Facet"))));
        integrationIds.uniswapV4Facet     = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.uniswapV4Facet"))));
        integrationIds.usdsFacet          = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.usdsFacet"))));
        integrationIds.weethFacet         = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.weethFacet"))));
        integrationIds.wrapProxyETHFacet  = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.wrapProxyETHFacet"))));
        integrationIds.wstethFacet        = bytes32(keccak256(abi.encodePacked(config.readString(".integrationIds.wstethFacet"))));
    }

}
