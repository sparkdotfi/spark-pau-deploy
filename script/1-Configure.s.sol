// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { console2 } from "../lib/forge-std/src/console2.sol";

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

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("config-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        address controller = config.readAddress(".controller");

        IntegrationIds memory allIntegrationIds = _readIntegrationIds(config);

        vm.startBroadcast();

        _updateIntegrations(controller, allIntegrationIds, config);

        console2.log("Integrations updated");

        vm.stopBroadcast();
    }

    function _updateIntegrations(address controller, IntegrationIds memory allIntegrationIds, string memory config) internal {
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
