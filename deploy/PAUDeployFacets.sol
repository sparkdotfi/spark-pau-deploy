// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { AaveFacet }          from "../lib/diamond-pau/src/facets/aave/AaveFacet.sol";
import { CCTPFacet }          from "../lib/diamond-pau/src/facets/cctp/CCTPFacet.sol";
import { CentrifugeFacet }    from "../lib/diamond-pau/src/facets/centrifuge/CentrifugeFacet.sol";
import { CurveFacet }         from "../lib/diamond-pau/src/facets/curve/CurveFacet.sol";
import { DAIUSDSFacet }       from "../lib/diamond-pau/src/facets/dai-usds/DAIUSDSFacet.sol";
import { ERC4626Facet }       from "../lib/diamond-pau/src/facets/erc4626/ERC4626Facet.sol";
import { ERC7540Facet }       from "../lib/diamond-pau/src/facets/erc7540/ERC7540Facet.sol";
import { FarmFacet }          from "../lib/diamond-pau/src/facets/farm/FarmFacet.sol";
import { LayerZeroFacet }     from "../lib/diamond-pau/src/facets/layer-zero/LayerZeroFacet.sol";
import { MapleFacet }         from "../lib/diamond-pau/src/facets/maple/MapleFacet.sol";
import { MerklFacet }         from "../lib/diamond-pau/src/facets/merkl/MerklFacet.sol";
import { OTCFacet }           from "../lib/diamond-pau/src/facets/otc/OTCFacet.sol";
import { PendleFacet }        from "../lib/diamond-pau/src/facets/pendle/PendleFacet.sol";
import { PSMFacet }           from "../lib/diamond-pau/src/facets/psm/PSMFacet.sol";
import { PSM3Facet }          from "../lib/diamond-pau/src/facets/psm3/PSM3Facet.sol";
import { SparkVaultFacet }    from "../lib/diamond-pau/src/facets/spark-vault/SparkVaultFacet.sol";
import { SuperstateFacet }    from "../lib/diamond-pau/src/facets/superstate/SuperstateFacet.sol";
import { TransferAssetFacet } from "../lib/diamond-pau/src/facets/transfer-asset/TransferAssetFacet.sol";
import { UniswapV3Facet }     from "../lib/diamond-pau/src/facets/uniswap-v3/UniswapV3Facet.sol";
import { UniswapV4Facet }     from "../lib/diamond-pau/src/facets/uniswap-v4/UniswapV4Facet.sol";
import { USDEFacet }          from "../lib/diamond-pau/src/facets/usde/USDEFacet.sol";
import { USDSFacet }          from "../lib/diamond-pau/src/facets/usds/USDSFacet.sol";
import { WEETHFacet }         from "../lib/diamond-pau/src/facets/weeth/WEETHFacet.sol";
import { WrapProxyETHFacet }  from "../lib/diamond-pau/src/facets/wrap-proxy-eth/WrapProxyETHFacet.sol";
import { WSTETHFacet }        from "../lib/diamond-pau/src/facets/wsteth/WSTETHFacet.sol";

library PAUDeployFacets {

    function deployAaveFacet() internal returns (address) {
        return address(new AaveFacet());
    }

    function deployCCTPFacet(address cctpMessenger, address usdc) internal returns (address) {
        return address(new CCTPFacet(cctpMessenger, usdc));
    }

    function deployCentrifugeFacet() internal returns (address) {
        return address(new CentrifugeFacet());
    }

    function deployCurveFacet() internal returns (address) {
        return address(new CurveFacet());
    }

    function deployDAIUSDSFacet(
        address dai,
        address daiUSDS,
        address usds
    ) internal returns (address) {
        return address(new DAIUSDSFacet(dai, daiUSDS, usds));
    }

    function deployERC4626Facet() internal returns (address) {
        return address(new ERC4626Facet());
    }

    function deployERC7540Facet() internal returns (address) {
        return address(new ERC7540Facet());
    }

    function deployFarmFacet() internal returns (address) {
        return address(new FarmFacet());
    }

    function deployLayerZeroFacet() internal returns (address) {
        return address(new LayerZeroFacet());
    }

    function deployMapleFacet() internal returns (address) {
        return address(new MapleFacet());
    }

    function deployMerklFacet(address merklDistributor) internal returns (address) {
        return address(new MerklFacet(merklDistributor));
    }

    function deployOTCFacet() internal returns (address) {
        return address(new OTCFacet());
    }

    function deployPendleFacet(address pendleRouter) internal returns (address) {
        return address(new PendleFacet(pendleRouter));
    }

    function deployPSMFacet(
        address dai,
        address daiUSDS,
        address psm,
        address usdc,
        address usds
    ) internal returns (address) {
        return address(new PSMFacet(dai, daiUSDS, psm, usdc, usds));
    }

    function deployPSM3Facet(address psm3) internal returns (address) {
        return address(new PSM3Facet(psm3));
    }

    function deploySparkVaultFacet() internal returns (address) {
        return address(new SparkVaultFacet());
    }

    function deploySuperstateFacet(address usdc, address ustb) internal returns (address) {
        return address(new SuperstateFacet(usdc, ustb));
    }

    function deployTransferAssetFacet() internal returns (address) {
        return address(new TransferAssetFacet());
    }

    function deployUniswapV3Facet(
        address positionManager,
        address router
    ) internal returns (address) {
        return address(new UniswapV3Facet(positionManager, router));
    }

    function deployUniswapV4Facet(
        address permit2,
        address positionManager,
        address router
    ) internal returns (address) {
        return address(new UniswapV4Facet(permit2, positionManager, router));
    }

    function deployUSDEFacet(
        address ethenaMinter,
        address susde,
        address usdc,
        address usde
    ) internal returns (address) {
        return address(new USDEFacet(ethenaMinter, susde, usdc, usde));
    }

    function deployUSDSFacet(address vault, address usds) internal returns (address) {
        return address(new USDSFacet(vault, usds));
    }

    function deployWEETHFacet(address weth, address weeth) internal returns (address) {
        return address(new WEETHFacet(weth, weeth));
    }

    function deployWrapProxyETHFacet(address weth) internal returns (address) {
        return address(new WrapProxyETHFacet(weth));
    }

    function deployWSTETHFacet(
        address weth,
        address withdrawQueue,
        address wsteth
    ) internal returns (address) {
        return address(new WSTETHFacet(weth, withdrawQueue, wsteth));
    }

}
