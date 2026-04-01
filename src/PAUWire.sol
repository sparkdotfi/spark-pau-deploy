// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IControllerFull } from "./interfaces/IControllerFull.sol";

import { IAaveFacet }          from "../lib/diamond-pau/src/facets/aave/IAaveFacet.sol";
import { ICCTPFacet }          from "../lib/diamond-pau/src/facets/cctp/ICCTPFacet.sol";
import { ICentrifugeFacet }    from "../lib/diamond-pau/src/facets/centrifuge/ICentrifugeFacet.sol";
import { ICurveFacet }         from "../lib/diamond-pau/src/facets/curve/ICurveFacet.sol";
import { IDAIUSDSFacet }       from "../lib/diamond-pau/src/facets/dai-usds/IDAIUSDSFacet.sol";
import { IERC4626Facet }       from "../lib/diamond-pau/src/facets/erc4626/IERC4626Facet.sol";
import { IERC7540Facet }       from "../lib/diamond-pau/src/facets/erc7540/IERC7540Facet.sol";
import { IFarmFacet }          from "../lib/diamond-pau/src/facets/farm/IFarmFacet.sol";
import { ILayerZeroFacet }     from "../lib/diamond-pau/src/facets/layer-zero/ILayerZeroFacet.sol";
import { IMapleFacet }         from "../lib/diamond-pau/src/facets/maple/IMapleFacet.sol";
import { IMerklFacet }         from "../lib/diamond-pau/src/facets/merkl/IMerklFacet.sol";
import { IOTCFacet }           from "../lib/diamond-pau/src/facets/otc/IOTCFacet.sol";
import { IPendleFacet }        from "../lib/diamond-pau/src/facets/pendle/IPendleFacet.sol";
import { IPSMFacet }           from "../lib/diamond-pau/src/facets/psm/IPSMFacet.sol";
import { IPSM3Facet }          from "../lib/diamond-pau/src/facets/psm3/IPSM3Facet.sol";
import { ISparkVaultFacet }    from "../lib/diamond-pau/src/facets/spark-vault/ISparkVaultFacet.sol";
import { ISuperstateFacet }    from "../lib/diamond-pau/src/facets/superstate/ISuperstateFacet.sol";
import { ITransferAssetFacet } from "../lib/diamond-pau/src/facets/transfer-asset/ITransferAssetFacet.sol";
import { IUniswapV3Facet }     from "../lib/diamond-pau/src/facets/uniswap-v3/IUniswapV3Facet.sol";
import { IUniswapV4Facet }     from "../lib/diamond-pau/src/facets/uniswap-v4/IUniswapV4Facet.sol";
import { IUSDEFacet }          from "../lib/diamond-pau/src/facets/usde/IUSDEFacet.sol";
import { IUSDSFacet }          from "../lib/diamond-pau/src/facets/usds/IUSDSFacet.sol";
import { IWEETHFacet }         from "../lib/diamond-pau/src/facets/weeth/IWEETHFacet.sol";
import { IWrapProxyETHFacet }  from "../lib/diamond-pau/src/facets/wrap-proxy-eth/IWrapProxyETHFacet.sol";
import { IWSTETHFacet }        from "../lib/diamond-pau/src/facets/wsteth/IWSTETHFacet.sol";

library PAUWire {

    struct FacetAddresses {
        address aaveFacet;
        address cctpFacet;
        address centrifugeFacet;
        address curveFacet;
        address daiUsdsFacet;
        address erc4626Facet;
        address erc7540Facet;
        address farmFacet;
        address layerZeroFacet;
        address mapleFacet;
        address merklFacet;
        address otcFacet;
        address pendleFacet;
        address psmFacet;
        address psm3Facet;
        address sparkVaultFacet;
        address superstateFacet;
        address transferAssetFacet;
        address uniswapV3Facet;
        address uniswapV4Facet;
        address usdeFacet;
        address usdsFacet;
        address weethFacet;
        address wrapProxyETHFacet;
        address wstethFacet;
    }

    function wireFacets(address controller, FacetAddresses memory facets) internal {
        IControllerFull c = IControllerFull(payable(controller));

        if (facets.aaveFacet          != address(0)) _wireAave(c, facets.aaveFacet);
        if (facets.cctpFacet          != address(0)) _wireCCTP(c, facets.cctpFacet);
        if (facets.centrifugeFacet    != address(0)) _wireCentrifuge(c, facets.centrifugeFacet);
        if (facets.curveFacet         != address(0)) _wireCurve(c, facets.curveFacet);
        if (facets.daiUsdsFacet       != address(0)) _wireDAIUSDS(c, facets.daiUsdsFacet);
        if (facets.erc4626Facet       != address(0)) _wireERC4626(c, facets.erc4626Facet);
        if (facets.erc7540Facet       != address(0)) _wireERC7540(c, facets.erc7540Facet);
        if (facets.farmFacet          != address(0)) _wireFarm(c, facets.farmFacet);
        if (facets.layerZeroFacet     != address(0)) _wireLayerZero(c, facets.layerZeroFacet);
        if (facets.mapleFacet         != address(0)) _wireMaple(c, facets.mapleFacet);
        if (facets.merklFacet         != address(0)) _wireMerkl(c, facets.merklFacet);
        if (facets.otcFacet           != address(0)) _wireOTC(c, facets.otcFacet);
        if (facets.pendleFacet        != address(0)) _wirePendle(c, facets.pendleFacet);
        if (facets.psmFacet           != address(0)) _wirePSM(c, facets.psmFacet);
        if (facets.psm3Facet          != address(0)) _wirePSM3(c, facets.psm3Facet);
        if (facets.sparkVaultFacet    != address(0)) _wireSparkVault(c, facets.sparkVaultFacet);
        if (facets.superstateFacet    != address(0)) _wireSuperstate(c, facets.superstateFacet);
        if (facets.transferAssetFacet != address(0)) _wireTransferAsset(c, facets.transferAssetFacet);
        if (facets.uniswapV3Facet     != address(0)) _wireUniswapV3(c, facets.uniswapV3Facet);
        if (facets.uniswapV4Facet     != address(0)) _wireUniswapV4(c, facets.uniswapV4Facet);
        if (facets.usdeFacet          != address(0)) _wireUSDE(c, facets.usdeFacet);
        if (facets.usdsFacet          != address(0)) _wireUSDS(c, facets.usdsFacet);
        if (facets.weethFacet         != address(0)) _wireWEETH(c, facets.weethFacet);
        if (facets.wrapProxyETHFacet  != address(0)) _wireWrapProxyETH(c, facets.wrapProxyETHFacet);
        if (facets.wstethFacet        != address(0)) _wireWSTETH(c, facets.wstethFacet);
    }

    /**********************************************************************************************/
    /*** Internal wire functions                                                                ***/
    /**********************************************************************************************/

    function _wireAave(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.setAaveMaxSlippage.selector,  facet, IAaveFacet.setMaxSlippage.selector);
        controller.setDispatch(IControllerFull.getAaveMaxSlippage.selector,  facet, IAaveFacet.getMaxSlippage.selector);
        controller.setDispatch(IControllerFull.depositAave.selector,         facet, IAaveFacet.deposit.selector);
        controller.setDispatch(IControllerFull.withdrawAave.selector,        facet, IAaveFacet.withdraw.selector);
        controller.setDispatch(IControllerFull.LIMIT_AAVE_DEPOSIT.selector,  facet, IAaveFacet.LIMIT_DEPOSIT.selector);
        controller.setDispatch(IControllerFull.LIMIT_AAVE_WITHDRAW.selector, facet, IAaveFacet.LIMIT_WITHDRAW.selector);
    }

    function _wireCCTP(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.setCCTPMaxFeeCap.selector,          facet, ICCTPFacet.setMaxFeeCap.selector);
        controller.setDispatch(IControllerFull.setCCTPMintRecipient.selector,      facet, ICCTPFacet.setMintRecipient.selector);
        controller.setDispatch(IControllerFull.getCCTPMaxFeeCap.selector,          facet, ICCTPFacet.maxFeeCap.selector);
        controller.setDispatch(IControllerFull.getCCTPMintRecipient.selector,      facet, ICCTPFacet.getMintRecipient.selector);
        controller.setDispatch(IControllerFull.transferUSDCToCCTP.selector,        facet, ICCTPFacet.transfer.selector);
        controller.setDispatch(IControllerFull.transferUSDCToCCTPWithFee.selector, facet, ICCTPFacet.transferWithFee.selector);
        controller.setDispatch(IControllerFull.LIMIT_USDC_TO_CCTP.selector,        facet, ICCTPFacet.LIMIT_TO_CCTP.selector);
        controller.setDispatch(IControllerFull.LIMIT_USDC_TO_DOMAIN.selector,      facet, ICCTPFacet.LIMIT_TO_DOMAIN.selector);
    }

    function _wireCentrifuge(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.setCentrifugeRecipient.selector,              facet, ICentrifugeFacet.setRecipient.selector);
        controller.setDispatch(IControllerFull.cancelCentrifugeDepositRequest.selector,      facet, ICentrifugeFacet.cancelDepositRequest.selector);
        controller.setDispatch(IControllerFull.claimCentrifugeCancelDepositRequest.selector, facet, ICentrifugeFacet.claimCancelDepositRequest.selector);
        controller.setDispatch(IControllerFull.cancelCentrifugeRedeemRequest.selector,       facet, ICentrifugeFacet.cancelRedeemRequest.selector);
        controller.setDispatch(IControllerFull.claimCentrifugeCancelRedeemRequest.selector,  facet, ICentrifugeFacet.claimCancelRedeemRequest.selector);
        controller.setDispatch(IControllerFull.transferSharesCentrifuge.selector,            facet, ICentrifugeFacet.transferShares.selector);
        controller.setDispatch(IControllerFull.LIMIT_CENTRIFUGE_TRANSFER.selector,           facet, ICentrifugeFacet.LIMIT_TRANSFER.selector);
        controller.setDispatch(IControllerFull.getCentrifugeRecipient.selector,              facet, ICentrifugeFacet.getRecipient.selector);
    }

    function _wireCurve(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.setCurveMaxSlippage.selector,  facet, ICurveFacet.setMaxSlippage.selector);
        controller.setDispatch(IControllerFull.getCurveMaxSlippage.selector,  facet, ICurveFacet.getMaxSlippage.selector);
        controller.setDispatch(IControllerFull.swapCurve.selector,            facet, ICurveFacet.swap.selector);
        controller.setDispatch(IControllerFull.addLiquidityCurve.selector,    facet, ICurveFacet.addLiquidity.selector);
        controller.setDispatch(IControllerFull.removeLiquidityCurve.selector, facet, ICurveFacet.removeLiquidity.selector);
        controller.setDispatch(IControllerFull.LIMIT_CURVE_DEPOSIT.selector,  facet, ICurveFacet.LIMIT_DEPOSIT.selector);
        controller.setDispatch(IControllerFull.LIMIT_CURVE_SWAP.selector,     facet, ICurveFacet.LIMIT_SWAP.selector);
        controller.setDispatch(IControllerFull.LIMIT_CURVE_WITHDRAW.selector, facet, ICurveFacet.LIMIT_WITHDRAW.selector);
    }

    function _wireDAIUSDS(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.swapUSDSToDAI.selector, facet, IDAIUSDSFacet.swapUSDSToDAI.selector);
        controller.setDispatch(IControllerFull.swapDAIToUSDS.selector, facet, IDAIUSDSFacet.swapDAIToUSDS.selector);
    }

    function _wireERC4626(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.setMaxExchangeRate.selector,      facet, IERC4626Facet.setMaxExchangeRate.selector);
        controller.setDispatch(IControllerFull.maxExchangeRates.selector,        facet, IERC4626Facet.getMaxExchangeRate.selector);
        controller.setDispatch(IControllerFull.depositERC4626.selector,          facet, IERC4626Facet.deposit.selector);
        controller.setDispatch(IControllerFull.withdrawERC4626.selector,         facet, IERC4626Facet.withdraw.selector);
        controller.setDispatch(IControllerFull.redeemERC4626.selector,           facet, IERC4626Facet.redeem.selector);
        controller.setDispatch(IControllerFull.LIMIT_4626_DEPOSIT.selector,      facet, IERC4626Facet.LIMIT_DEPOSIT.selector);
        controller.setDispatch(IControllerFull.LIMIT_4626_WITHDRAW.selector,     facet, IERC4626Facet.LIMIT_WITHDRAW.selector);
        controller.setDispatch(IControllerFull.EXCHANGE_RATE_PRECISION.selector, facet, IERC4626Facet.EXCHANGE_RATE_PRECISION.selector);
    }

    function _wireERC7540(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.requestDepositERC7540.selector, facet, IERC7540Facet.requestDeposit.selector);
        controller.setDispatch(IControllerFull.claimDepositERC7540.selector,   facet, IERC7540Facet.claimDeposit.selector);
        controller.setDispatch(IControllerFull.requestRedeemERC7540.selector,  facet, IERC7540Facet.requestRedeem.selector);
        controller.setDispatch(IControllerFull.claimRedeemERC7540.selector,    facet, IERC7540Facet.claimRedeem.selector);
        controller.setDispatch(IControllerFull.LIMIT_7540_DEPOSIT.selector,    facet, IERC7540Facet.LIMIT_DEPOSIT.selector);
        controller.setDispatch(IControllerFull.LIMIT_7540_REDEEM.selector,     facet, IERC7540Facet.LIMIT_REDEEM.selector);
    }

    function _wireFarm(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.depositToFarm.selector,       facet, IFarmFacet.deposit.selector);
        controller.setDispatch(IControllerFull.withdrawFromFarm.selector,    facet, IFarmFacet.withdraw.selector);
        controller.setDispatch(IControllerFull.LIMIT_FARM_DEPOSIT.selector,  facet, IFarmFacet.LIMIT_DEPOSIT.selector);
        controller.setDispatch(IControllerFull.LIMIT_FARM_WITHDRAW.selector, facet, IFarmFacet.LIMIT_WITHDRAW.selector);
    }

    function _wireLayerZero(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.setLayerZeroRecipient.selector,      facet, ILayerZeroFacet.setRecipient.selector);
        controller.setDispatch(IControllerFull.transferTokenLayerZero.selector,     facet, ILayerZeroFacet.transfer.selector);
        controller.setDispatch(IControllerFull.LIMIT_LAYERZERO_TRANSFER.selector,   facet, ILayerZeroFacet.LIMIT_TRANSFER.selector);
        controller.setDispatch(IControllerFull.getLayerZeroRecipients.selector,     facet, ILayerZeroFacet.getRecipient.selector);
    }

    function _wireMaple(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.requestMapleRedemption.selector, facet, IMapleFacet.requestRedemption.selector);
        controller.setDispatch(IControllerFull.cancelMapleRedemption.selector,  facet, IMapleFacet.cancelRedemption.selector);
        controller.setDispatch(IControllerFull.LIMIT_MAPLE_REDEEM.selector,     facet, IMapleFacet.LIMIT_REDEEM.selector);
    }

    function _wireMerkl(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.toggleOperatorMerkl.selector, facet, IMerklFacet.toggleOperator.selector);
    }

    function _wireOTC(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.setOTCMaxSlippage.selector,       facet, IOTCFacet.setMaxSlippage.selector);
        controller.setDispatch(IControllerFull.setOTCBuffer.selector,            facet, IOTCFacet.setBuffer.selector);
        controller.setDispatch(IControllerFull.setOTCRechargeRate.selector,      facet, IOTCFacet.setRechargeRate.selector);
        controller.setDispatch(IControllerFull.setOTCWhitelistedAsset.selector,  facet, IOTCFacet.setIsWhitelisted.selector);
        controller.setDispatch(IControllerFull.otcSend.selector,                 facet, IOTCFacet.send.selector);
        controller.setDispatch(IControllerFull.otcClaim.selector,                facet, IOTCFacet.claim.selector);
        controller.setDispatch(IControllerFull.LIMIT_OTC_SWAP.selector,          facet, IOTCFacet.LIMIT_SWAP.selector);
        controller.setDispatch(IControllerFull.getOtcClaimWithRecharge.selector, facet, IOTCFacet.getClaimWithRecharge.selector);
        controller.setDispatch(IControllerFull.isOtcSwapReady.selector,          facet, IOTCFacet.isSwapReady.selector);
        controller.setDispatch(IControllerFull.otcs.selector,                    facet, IOTCFacet.getState.selector);
        controller.setDispatch(IControllerFull.otcWhitelistedAssets.selector,    facet, IOTCFacet.getIsWhitelisted.selector);
    }

    function _wirePendle(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.redeemPendlePT.selector,         facet, IPendleFacet.redeem.selector);
        controller.setDispatch(IControllerFull.LIMIT_PENDLE_PT_REDEEM.selector, facet, IPendleFacet.LIMIT_REDEEM.selector);
    }

    function _wirePSM(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.swapUSDSToUSDC.selector,          facet, IPSMFacet.swapUSDSToUSDC.selector);
        controller.setDispatch(IControllerFull.swapUSDCToUSDS.selector,          facet, IPSMFacet.swapUSDCToUSDS.selector);
        controller.setDispatch(IControllerFull.psmTo18ConversionFactor.selector, facet, IPSMFacet.to18ConversionFactor.selector);
        controller.setDispatch(IControllerFull.LIMIT_USDS_TO_USDC.selector,      facet, IPSMFacet.LIMIT_USDS_TO_USDC.selector);
    }

    function _wirePSM3(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.depositPSM.selector,         facet, IPSM3Facet.deposit.selector);
        controller.setDispatch(IControllerFull.withdrawPSM.selector,        facet, IPSM3Facet.withdraw.selector);
        controller.setDispatch(IControllerFull.LIMIT_PSM_DEPOSIT.selector,  facet, IPSM3Facet.LIMIT_DEPOSIT.selector);
        controller.setDispatch(IControllerFull.LIMIT_PSM_WITHDRAW.selector, facet, IPSM3Facet.LIMIT_WITHDRAW.selector);
    }

    function _wireSparkVault(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.takeFromSparkVault.selector,     facet, ISparkVaultFacet.take.selector);
        controller.setDispatch(IControllerFull.LIMIT_SPARK_VAULT_TAKE.selector, facet, ISparkVaultFacet.LIMIT_TAKE.selector);
    }

    function _wireSuperstate(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.subscribeSuperstate.selector,        facet, ISuperstateFacet.subscribe.selector);
        controller.setDispatch(IControllerFull.LIMIT_SUPERSTATE_SUBSCRIBE.selector, facet, ISuperstateFacet.LIMIT_SUBSCRIBE.selector);
    }

    function _wireTransferAsset(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.transferAsset.selector,        facet, ITransferAssetFacet.transfer.selector);
        controller.setDispatch(IControllerFull.LIMIT_ASSET_TRANSFER.selector, facet, ITransferAssetFacet.LIMIT_TRANSFER.selector);
    }

    function _wireUniswapV3(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.addLiquidityUniswapV3.selector,                  facet, IUniswapV3Facet.addLiquidity.selector);
        controller.setDispatch(IControllerFull.removeLiquidityUniswapV3.selector,               facet, IUniswapV3Facet.removeLiquidity.selector);
        controller.setDispatch(IControllerFull.swapUniswapV3.selector,                          facet, IUniswapV3Facet.swap.selector);
        controller.setDispatch(IControllerFull.setUniswapV3MaxSlippage.selector,                facet, IUniswapV3Facet.setMaxSlippage.selector);
        controller.setDispatch(IControllerFull.setUniswapV3PoolMaxTickDelta.selector,           facet, IUniswapV3Facet.setMaxTickDelta.selector);
        controller.setDispatch(IControllerFull.setUniswapV3AddLiquidityLowerTickBound.selector, facet, IUniswapV3Facet.setLiquidityLowerTickBound.selector);
        controller.setDispatch(IControllerFull.setUniswapV3AddLiquidityUpperTickBound.selector, facet, IUniswapV3Facet.setLiquidityUpperTickBound.selector);
        controller.setDispatch(IControllerFull.setUniswapV3TWAPSecondsAgo.selector,             facet, IUniswapV3Facet.setTWAPSecondsAgo.selector);
        controller.setDispatch(IControllerFull.LIMIT_UNISWAP_V3_DEPOSIT.selector,               facet, IUniswapV3Facet.LIMIT_DEPOSIT.selector);
        controller.setDispatch(IControllerFull.LIMIT_UNISWAP_V3_SWAP.selector,                  facet, IUniswapV3Facet.LIMIT_SWAP.selector);
        controller.setDispatch(IControllerFull.LIMIT_UNISWAP_V3_WITHDRAW.selector,              facet, IUniswapV3Facet.LIMIT_WITHDRAW.selector);
        controller.setDispatch(IControllerFull.getUniswapV3MaxSlippage.selector,                facet, IUniswapV3Facet.getMaxSlippage.selector);
        controller.setDispatch(IControllerFull.getUniswapV3PoolMaxTickDelta.selector,           facet, IUniswapV3Facet.getMaxTickDelta.selector);
        controller.setDispatch(IControllerFull.getUniswapV3AddLiquidityTickBounds.selector,     facet, IUniswapV3Facet.getLiquidityTickBounds.selector);
        controller.setDispatch(IControllerFull.getUniswapV3TWAPSecondsAgo.selector,             facet, IUniswapV3Facet.getTWAPSecondsAgo.selector);
    }

    function _wireUniswapV4(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.decreaseLiquidityUniswapV4.selector, facet, IUniswapV4Facet.decreasePosition.selector);
        controller.setDispatch(IControllerFull.increaseLiquidityUniswapV4.selector, facet, IUniswapV4Facet.increasePosition.selector);
        controller.setDispatch(IControllerFull.mintPositionUniswapV4.selector,      facet, IUniswapV4Facet.mintPosition.selector);
        controller.setDispatch(IControllerFull.setUniswapV4MaxSlippage.selector,    facet, IUniswapV4Facet.setMaxSlippage.selector);
        controller.setDispatch(IControllerFull.setUniswapV4TickLimits.selector,     facet, IUniswapV4Facet.setTickLimits.selector);
        controller.setDispatch(IControllerFull.swapUniswapV4.selector,              facet, IUniswapV4Facet.swap.selector);
        controller.setDispatch(IControllerFull.LIMIT_UNISWAP_V4_DEPOSIT.selector,   facet, IUniswapV4Facet.LIMIT_DEPOSIT.selector);
        controller.setDispatch(IControllerFull.LIMIT_UNISWAP_V4_WITHDRAW.selector,  facet, IUniswapV4Facet.LIMIT_WITHDRAW.selector);
        controller.setDispatch(IControllerFull.LIMIT_UNISWAP_V4_SWAP.selector,      facet, IUniswapV4Facet.LIMIT_SWAP.selector);
        controller.setDispatch(IControllerFull.uniswapV4MaxSlippages.selector,      facet, IUniswapV4Facet.getMaxSlippage.selector);
        controller.setDispatch(IControllerFull.uniswapV4TickLimits.selector,        facet, IUniswapV4Facet.getTickLimits.selector);
    }

    function _wireUSDE(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.cooldownAssetsSUSDe.selector,    facet, IUSDEFacet.cooldownAssets.selector);
        controller.setDispatch(IControllerFull.cooldownSharesSUSDe.selector,    facet, IUSDEFacet.cooldownShares.selector);
        controller.setDispatch(IControllerFull.prepareUSDeMint.selector,        facet, IUSDEFacet.prepareMint.selector);
        controller.setDispatch(IControllerFull.prepareUSDeBurn.selector,        facet, IUSDEFacet.prepareBurn.selector);
        controller.setDispatch(IControllerFull.removeDelegatedSigner.selector,  facet, IUSDEFacet.removeDelegatedSigner.selector);
        controller.setDispatch(IControllerFull.setDelegatedSigner.selector,     facet, IUSDEFacet.setDelegatedSigner.selector);
        controller.setDispatch(IControllerFull.unstakeSUSDe.selector,           facet, IUSDEFacet.unstakeSUSDE.selector);
        controller.setDispatch(IControllerFull.LIMIT_USDE_BURN.selector,        facet, IUSDEFacet.LIMIT_USDE_BURN.selector);
        controller.setDispatch(IControllerFull.LIMIT_USDE_MINT.selector,        facet, IUSDEFacet.LIMIT_USDE_MINT.selector);
        controller.setDispatch(IControllerFull.LIMIT_SUSDE_COOLDOWN.selector,   facet, IUSDEFacet.LIMIT_SUSDE_COOLDOWN.selector);
    }

    function _wireUSDS(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.mintUSDS.selector,        facet, IUSDSFacet.mint.selector);
        controller.setDispatch(IControllerFull.burnUSDS.selector,        facet, IUSDSFacet.burn.selector);
        controller.setDispatch(IControllerFull.LIMIT_USDS_MINT.selector, facet, IUSDSFacet.LIMIT_MINT.selector);
    }

    function _wireWEETH(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.depositToWeETH.selector,               facet, IWEETHFacet.deposit.selector);
        controller.setDispatch(IControllerFull.requestWithdrawFromWeETH.selector,     facet, IWEETHFacet.requestWithdraw.selector);
        controller.setDispatch(IControllerFull.claimWithdrawalFromWeETH.selector,     facet, IWEETHFacet.claimWithdrawal.selector);
        controller.setDispatch(IControllerFull.LIMIT_WEETH_DEPOSIT.selector,          facet, IWEETHFacet.LIMIT_DEPOSIT.selector);
        controller.setDispatch(IControllerFull.LIMIT_WEETH_REQUEST_WITHDRAW.selector, facet, IWEETHFacet.LIMIT_REQUEST_WITHDRAW.selector);
    }

    function _wireWrapProxyETH(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.wrapAllProxyETH.selector, facet, IWrapProxyETHFacet.wrapAll.selector);
    }

    function _wireWSTETH(IControllerFull controller, address facet) internal {
        controller.setDispatch(IControllerFull.depositToWstETH.selector,               facet, IWSTETHFacet.deposit.selector);
        controller.setDispatch(IControllerFull.requestWithdrawFromWstETH.selector,     facet, IWSTETHFacet.requestWithdraw.selector);
        controller.setDispatch(IControllerFull.claimWithdrawalFromWstETH.selector,     facet, IWSTETHFacet.claimWithdrawal.selector);
        controller.setDispatch(IControllerFull.LIMIT_WSTETH_DEPOSIT.selector,          facet, IWSTETHFacet.LIMIT_DEPOSIT.selector);
        controller.setDispatch(IControllerFull.LIMIT_WSTETH_REQUEST_WITHDRAW.selector, facet, IWSTETHFacet.LIMIT_REQUEST_WITHDRAW.selector);
    }

}
