// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson, console } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/diamond-pau/lib/dss-test/src/ScriptTools.sol";

import { IAccessControls } from "../lib/diamond-pau/src/interfaces/IAccessControls.sol";
import { IALMProxy }       from "../lib/diamond-pau/src/interfaces/IALMProxy.sol";
import { IRateLimits }     from "../lib/diamond-pau/src/interfaces/IRateLimits.sol";

import { PAUDeploy }               from "../deploy/PAUDeploy.sol";
import { PAUWire, FacetAddresses } from "../deploy/PAUWire.sol";

import { IControllerFull } from "../src/interfaces/IControllerFull.sol";

contract DeployPAU is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             vm.toString(block.chainid));
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        string memory chain    = vm.envOr("CHAIN", string("mainnet"));
        string memory fileSlug = string(abi.encodePacked("deploy-", chain, "-", vm.envString("ENV")));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        address admin   = config.readAddress(".admin");
        address freezer = config.readAddress(".freezer");
        address relayer = config.readAddress(".relayer");

        FacetAddresses memory facetAddresses = _readFacetAddresses(config);

        vm.createSelectFork(getChain(chain).rpcUrl);

        console.log("Deploying PAU system for %s...", chain);

        vm.startBroadcast();

        address deployer = msg.sender;

        require(deployer != admin, "DeployPAU/deployer-must-differ-from-admin");

        // Step 1: Deploy PAU system with deployer as temporary admin

        IControllerFull controller = IControllerFull(PAUDeploy.deploy(deployer)); // TODO : Handle the case where factory is already deployed and we just need to deploy a new controller

        console.log("Controller deployed at: ", address(controller));

        IAccessControls accessControls = IAccessControls(controller.accessControls());
        IALMProxy almProxy             = IALMProxy(controller.proxy());
        IRateLimits rateLimits         = IRateLimits(controller.rateLimits());

        // Step 2: Wire facets

        PAUWire.wireFacets(address(controller), facetAddresses);

        // Step 3: Grant roles to relayer and freezer on AccessControls

        accessControls.grantRole(accessControls.RELAYER_ROLE(), relayer);
        accessControls.grantRole(accessControls.FREEZER_ROLE(), freezer);

        // Step 4: Transfer DEFAULT_ADMIN_ROLE to final admin and revoke from deployer.
        //         For AccessControls, ALMProxy, and RateLimits.

        accessControls.grantRole(accessControls.DEFAULT_ADMIN_ROLE(), admin);
        almProxy.grantRole(almProxy.DEFAULT_ADMIN_ROLE(),             admin);
        rateLimits.grantRole(rateLimits.DEFAULT_ADMIN_ROLE(),         admin);


        accessControls.revokeRole(accessControls.DEFAULT_ADMIN_ROLE(), deployer);
        almProxy.revokeRole(almProxy.DEFAULT_ADMIN_ROLE(),             deployer);
        rateLimits.revokeRole(rateLimits.DEFAULT_ADMIN_ROLE(),         deployer);

        console.log("Admin transferred to: ", admin);

        vm.stopBroadcast();

        // Step 5: Export addresses

        ScriptTools.exportContract(fileSlug, "accessControls", address(accessControls));
        ScriptTools.exportContract(fileSlug, "almProxy",       address(almProxy));
        ScriptTools.exportContract(fileSlug, "controller",     address(controller));
        ScriptTools.exportContract(fileSlug, "rateLimits",     address(rateLimits));
    }

    function _readFacetAddresses(string memory config) internal pure returns (FacetAddresses memory f) {
        f.aaveFacet          = config.readAddress(".facetAddresses.aaveFacet");
        f.cctpFacet          = config.readAddress(".facetAddresses.cctpFacet");
        f.centrifugeFacet    = config.readAddress(".facetAddresses.centrifugeFacet");
        f.curveFacet         = config.readAddress(".facetAddresses.curveFacet");
        f.daiUsdsFacet       = config.readAddress(".facetAddresses.daiUsdsFacet");
        f.erc4626Facet       = config.readAddress(".facetAddresses.erc4626Facet");
        f.erc7540Facet       = config.readAddress(".facetAddresses.erc7540Facet");
        f.farmFacet          = config.readAddress(".facetAddresses.farmFacet");
        f.layerZeroFacet     = config.readAddress(".facetAddresses.layerZeroFacet");
        f.mapleFacet         = config.readAddress(".facetAddresses.mapleFacet");
        f.merklFacet         = config.readAddress(".facetAddresses.merklFacet");
        f.otcFacet           = config.readAddress(".facetAddresses.otcFacet");
        f.pendleFacet        = config.readAddress(".facetAddresses.pendleFacet");
        f.psmFacet           = config.readAddress(".facetAddresses.psmFacet");
        f.psm3Facet          = config.readAddress(".facetAddresses.psm3Facet");
        f.sparkVaultFacet    = config.readAddress(".facetAddresses.sparkVaultFacet");
        f.superstateFacet    = config.readAddress(".facetAddresses.superstateFacet");
        f.transferAssetFacet = config.readAddress(".facetAddresses.transferAssetFacet");
        f.uniswapV3Facet     = config.readAddress(".facetAddresses.uniswapV3Facet");
        f.uniswapV4Facet     = config.readAddress(".facetAddresses.uniswapV4Facet");
        f.usdeFacet          = config.readAddress(".facetAddresses.usdeFacet");
        f.usdsFacet          = config.readAddress(".facetAddresses.usdsFacet");
        f.weethFacet         = config.readAddress(".facetAddresses.weethFacet");
        f.wrapProxyETHFacet  = config.readAddress(".facetAddresses.wrapProxyETHFacet");
        f.wstethFacet        = config.readAddress(".facetAddresses.wstethFacet");
    }

}
