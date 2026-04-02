// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson, console } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { PAUWire } from "../src/PAUWire.sol";

contract WireFacets is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("facets-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        address controller = config.readAddress(".controller");

        PAUWire.FacetAddresses memory facets = _readFacetAddresses(config);

        console.log("Wiring PAU facets for %s %s...", env, chain);

        vm.startBroadcast();

        // Wire facets

        PAUWire.wireFacets(controller, facets);

        vm.stopBroadcast();
    }

    function _readFacetAddresses(
        string memory config
    ) internal pure returns (PAUWire.FacetAddresses memory facets) {
        facets.aaveFacet          = config.readAddress(".facetAddresses.aaveFacet");
        facets.cctpFacet          = config.readAddress(".facetAddresses.cctpFacet");
        facets.centrifugeFacet    = config.readAddress(".facetAddresses.centrifugeFacet");
        facets.curveFacet         = config.readAddress(".facetAddresses.curveFacet");
        facets.daiUsdsFacet       = config.readAddress(".facetAddresses.daiUsdsFacet");
        facets.erc4626Facet       = config.readAddress(".facetAddresses.erc4626Facet");
        facets.erc7540Facet       = config.readAddress(".facetAddresses.erc7540Facet");
        facets.farmFacet          = config.readAddress(".facetAddresses.farmFacet");
        facets.layerZeroFacet     = config.readAddress(".facetAddresses.layerZeroFacet");
        facets.mapleFacet         = config.readAddress(".facetAddresses.mapleFacet");
        facets.merklFacet         = config.readAddress(".facetAddresses.merklFacet");
        facets.otcFacet           = config.readAddress(".facetAddresses.otcFacet");
        facets.pendleFacet        = config.readAddress(".facetAddresses.pendleFacet");
        facets.psmFacet           = config.readAddress(".facetAddresses.psmFacet");
        facets.psm3Facet          = config.readAddress(".facetAddresses.psm3Facet");
        facets.sparkVaultFacet    = config.readAddress(".facetAddresses.sparkVaultFacet");
        facets.superstateFacet    = config.readAddress(".facetAddresses.superstateFacet");
        facets.transferAssetFacet = config.readAddress(".facetAddresses.transferAssetFacet");
        facets.uniswapV3Facet     = config.readAddress(".facetAddresses.uniswapV3Facet");
        facets.uniswapV4Facet     = config.readAddress(".facetAddresses.uniswapV4Facet");
        facets.usdeFacet          = config.readAddress(".facetAddresses.usdeFacet");
        facets.usdsFacet          = config.readAddress(".facetAddresses.usdsFacet");
        facets.weethFacet         = config.readAddress(".facetAddresses.weethFacet");
        facets.wrapProxyETHFacet  = config.readAddress(".facetAddresses.wrapProxyETHFacet");
        facets.wstethFacet        = config.readAddress(".facetAddresses.wstethFacet");
    }

}
