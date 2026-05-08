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

interface IController {

    function updateIntegrations(bytes32[] calldata ids) external;

}

contract ConfigureController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    struct IntegrationIds {
        bytes32 aaveFacet;
        bytes32 cctpFacet;
        bytes32 centrifugeFacet;
        bytes32 curveFacet;
        bytes32 daiUsdsFacet;
        bytes32 erc4626Facet;
        bytes32 erc7540Facet;
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
        bytes32 ethenaFacet;
        bytes32 usdsFacet;
        bytes32 weethFacet;
        bytes32 wrapProxyETHFacet;
        bytes32 wstethFacet;
    }

    bytes32 internal constant PYUSD_USDS_POOL_ID = 0xe63e32b2ae40601662f760d6bf5d771057324fbd97784fe1d3717069f7b75d45;
    bytes32 internal constant USDT_USDS_POOL_ID  = 0x3b1b1f2e775a6db1664f8e7d59ad568605ea2406312c11aef03146c0cf89d5b9;

    address controller;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("config-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "Invalid chain ID");

        controller = config.readAddress(".controller");

        IntegrationIds memory allIntegrationIds = _readIntegrationIds(config);

        vm.startBroadcast();

        _updateIntegrations(allIntegrationIds, config);

        console2.log("Integrations updated");

        _migrateMaxExchangeRate(Ethereum.MORPHO_VAULT_USDC_BC, 10);
        _migrateMaxExchangeRate(Ethereum.MORPHO_VAULT_DAI_1,   10);
        _migrateMaxExchangeRate(Ethereum.MORPHO_VAULT_USDS,    10);
        _migrateMaxExchangeRate(Ethereum.MORPHO_VAULT_V2_USDT, 1_000_000);
        _migrateMaxExchangeRate(Ethereum.SUSDS,                10);
        _migrateMaxExchangeRate(Ethereum.FLUID_SUSDS,          10);
        _migrateMaxExchangeRate(Ethereum.SUSDE,                10);
        _migrateMaxExchangeRate(Ethereum.SYRUP_USDC,           10);
        _migrateMaxExchangeRate(Ethereum.SYRUP_USDT,           10);
        _migrateMaxExchangeRate(Ethereum.ARKIS_VAULT,          10);

        console2.log("Max exchange rates updated");

        _migrateCurveMaxSlippage(Ethereum.CURVE_SUSDSUSDT);
        _migrateCurveMaxSlippage(Ethereum.CURVE_PYUSDUSDC);
        _migrateCurveMaxSlippage(Ethereum.CURVE_USDCUSDT);
        _migrateCurveMaxSlippage(Ethereum.CURVE_PYUSDUSDS);
        _migrateCurveMaxSlippage(Ethereum.CURVE_WEETHWETHNG);

        console2.log("Curve max slippage updated");

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

        _migrateUniswapV4MaxSlippage(PYUSD_USDS_POOL_ID);
        _migrateUniswapV4MaxSlippage(USDT_USDS_POOL_ID);

        console2.log("UniswapV4 max slippage updated");

        _migrateUniswapV4TickLimits(PYUSD_USDS_POOL_ID);
        _migrateUniswapV4TickLimits(USDT_USDS_POOL_ID);

        console2.log("UniswapV4 tick limits updated");

        vm.stopBroadcast();
    }

    function _migrateMaxExchangeRate(address vault, uint256 rate) internal {
        uint256 oldMaxExchangeRate = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxExchangeRates(vault);

        IMainnetControllerFull(controller).setMaxExchangeRate(vault, 1, rate);

        require(
            IMainnetControllerFull(controller).maxExchangeRates(vault) == oldMaxExchangeRate,
            "Max exchange rate mismatch"
        );
    }

    function _migrateCurveMaxSlippage(address pool) internal {
        uint256 oldMaxSlippage = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxSlippages(pool);

        IMainnetControllerFull(controller).setCurveMaxSlippage(pool, oldMaxSlippage);
    }

    function _migrateAaveMaxSlippage(address aToken) internal {
        uint256 oldMaxSlippage = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxSlippages(aToken);

        IMainnetControllerFull(controller).setAaveMaxSlippage(aToken, oldMaxSlippage);
    }

    function _migrateUniswapV4MaxSlippage(bytes32 poolId) internal {
        uint256 oldMaxSlippage = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxSlippages(address(uint160(uint256(poolId))));

        IMainnetControllerFull(controller).setUniswapV4MaxSlippage(poolId, oldMaxSlippage);
    }

    function _migrateUniswapV4TickLimits(bytes32 poolId) internal {
        ( int24 tickLower, int24 tickUpper, uint24 maxTickSpacing ) = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).uniswapV4TickLimits(poolId);

        IMainnetControllerFull(controller).setUniswapV4TickLimits(poolId, tickLower, tickUpper, maxTickSpacing);
    }

    function _updateIntegrations(IntegrationIds memory allIntegrationIds, string memory config) internal {
        bytes32[] memory integrationIds = new bytes32[](config.readUint(".facets.length"));

        uint256 i = 0;

        if (allIntegrationIds.aaveFacet          != bytes32(0)) integrationIds[i++] = allIntegrationIds.aaveFacet;
        if (allIntegrationIds.cctpFacet          != bytes32(0)) integrationIds[i++] = allIntegrationIds.cctpFacet;
        if (allIntegrationIds.centrifugeFacet    != bytes32(0)) integrationIds[i++] = allIntegrationIds.centrifugeFacet;
        if (allIntegrationIds.curveFacet         != bytes32(0)) integrationIds[i++] = allIntegrationIds.curveFacet;
        if (allIntegrationIds.daiUsdsFacet       != bytes32(0)) integrationIds[i++] = allIntegrationIds.daiUsdsFacet;
        if (allIntegrationIds.erc4626Facet       != bytes32(0)) integrationIds[i++] = allIntegrationIds.erc4626Facet;
        if (allIntegrationIds.erc7540Facet       != bytes32(0)) integrationIds[i++] = allIntegrationIds.erc7540Facet;
        if (allIntegrationIds.farmFacet          != bytes32(0)) integrationIds[i++] = allIntegrationIds.farmFacet;
        if (allIntegrationIds.layerZeroFacet     != bytes32(0)) integrationIds[i++] = allIntegrationIds.layerZeroFacet;
        if (allIntegrationIds.mapleFacet         != bytes32(0)) integrationIds[i++] = allIntegrationIds.mapleFacet;
        if (allIntegrationIds.merklFacet         != bytes32(0)) integrationIds[i++] = allIntegrationIds.merklFacet;
        if (allIntegrationIds.otcFacet           != bytes32(0)) integrationIds[i++] = allIntegrationIds.otcFacet;
        if (allIntegrationIds.pendleFacet        != bytes32(0)) integrationIds[i++] = allIntegrationIds.pendleFacet;
        if (allIntegrationIds.psmFacet           != bytes32(0)) integrationIds[i++] = allIntegrationIds.psmFacet;
        if (allIntegrationIds.psm3Facet          != bytes32(0)) integrationIds[i++] = allIntegrationIds.psm3Facet;
        if (allIntegrationIds.sparkVaultFacet    != bytes32(0)) integrationIds[i++] = allIntegrationIds.sparkVaultFacet;
        if (allIntegrationIds.superstateFacet    != bytes32(0)) integrationIds[i++] = allIntegrationIds.superstateFacet;
        if (allIntegrationIds.transferAssetFacet != bytes32(0)) integrationIds[i++] = allIntegrationIds.transferAssetFacet;
        if (allIntegrationIds.uniswapV3Facet     != bytes32(0)) integrationIds[i++] = allIntegrationIds.uniswapV3Facet;
        if (allIntegrationIds.uniswapV4Facet     != bytes32(0)) integrationIds[i++] = allIntegrationIds.uniswapV4Facet;
        if (allIntegrationIds.ethenaFacet        != bytes32(0)) integrationIds[i++] = allIntegrationIds.ethenaFacet;
        if (allIntegrationIds.usdsFacet          != bytes32(0)) integrationIds[i++] = allIntegrationIds.usdsFacet;
        if (allIntegrationIds.weethFacet         != bytes32(0)) integrationIds[i++] = allIntegrationIds.weethFacet;
        if (allIntegrationIds.wrapProxyETHFacet  != bytes32(0)) integrationIds[i++] = allIntegrationIds.wrapProxyETHFacet;
        if (allIntegrationIds.wstethFacet        != bytes32(0)) integrationIds[i++] = allIntegrationIds.wstethFacet;

        IController(controller).updateIntegrations(integrationIds);
    }

    function _readIntegrationIds(
        string memory config
    ) internal pure returns (IntegrationIds memory integrationIds) {
        integrationIds.aaveFacet          = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.aaveFacet"))));
        integrationIds.cctpFacet          = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.cctpFacet"))));
        integrationIds.centrifugeFacet    = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.centrifugeFacet"))));
        integrationIds.curveFacet         = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.curveFacet"))));
        integrationIds.daiUsdsFacet       = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.daiUsdsFacet"))));
        integrationIds.erc4626Facet       = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.erc4626Facet"))));
        integrationIds.erc7540Facet       = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.erc7540Facet"))));
        integrationIds.farmFacet          = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.farmFacet"))));
        integrationIds.layerZeroFacet     = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.layerZeroFacet"))));
        integrationIds.mapleFacet         = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.mapleFacet"))));
        integrationIds.merklFacet         = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.merklFacet"))));
        integrationIds.otcFacet           = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.otcFacet"))));
        integrationIds.pendleFacet        = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.pendleFacet"))));
        integrationIds.psmFacet           = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.psmFacet"))));
        integrationIds.psm3Facet          = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.psm3Facet"))));
        integrationIds.sparkVaultFacet    = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.sparkVaultFacet"))));
        integrationIds.superstateFacet    = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.superstateFacet"))));
        integrationIds.transferAssetFacet = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.transferAssetFacet"))));
        integrationIds.uniswapV3Facet     = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.uniswapV3Facet"))));
        integrationIds.uniswapV4Facet     = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.uniswapV4Facet"))));
        integrationIds.ethenaFacet        = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.ethenaFacet"))));
        integrationIds.usdsFacet          = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.usdsFacet"))));
        integrationIds.weethFacet         = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.weethFacet"))));
        integrationIds.wrapProxyETHFacet  = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.wrapProxyETHFacet"))));
        integrationIds.wstethFacet        = bytes32(keccak256(abi.encodePacked(config.readString(".facetIds.wstethFacet"))));
    }

}
