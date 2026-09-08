// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IERC20 }   from "../../lib/forge-std/src/interfaces/IERC20.sol";
import { IERC4626 } from "../../lib/forge-std/src/interfaces/IERC4626.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { Bridge, BridgeType }    from "../../lib/diamond-pau/lib/grove-xchain-helpers/src/testing/Bridge.sol";
import { CCTPv2BridgeTesting }   from "../../lib/diamond-pau/lib/grove-xchain-helpers/src/testing/bridges/CCTPv2BridgeTesting.sol";
import { CCTPv2Forwarder }       from "../../lib/diamond-pau/lib/grove-xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";
import { Domain, DomainHelpers } from "../../lib/diamond-pau/lib/grove-xchain-helpers/src/testing/Domain.sol";

import { IRateLimits } from "../../lib/diamond-pau/src/interfaces/IRateLimits.sol";

import { IForeignControllerFull } from "../../lib/diamond-pau/test/interfaces/IForeignControllerFull.sol";
import { IMainnetControllerFull } from "../../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

import { IAdministeredAgent } from "../../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

interface ISparkVaultLike is IERC4626 {

    function TAKER_ROLE() external view returns (bytes32);

    function depositCap() external view returns (uint256);

    function hasRole(bytes32 role, address account) external view returns (bool);

    function setDepositCap(uint256 newCap) external;

}

contract CrossChainE2ETestStaging is Test {

    using DomainHelpers       for *;
    using CCTPv2BridgeTesting for Bridge;

    uint256 internal constant DEPOSIT_AMOUNT                = 5e6;
    uint256 internal constant STAGING_RATE_LIMIT_MAX_AMOUNT = 10e6;

    address internal constant ADMIN                    = 0xb52991d5d29f371f493910c36f5A849b3748Cc28;  // On both chains same address.
    address internal constant CCTP_MESSAGE_TRANSMITTER = CCTPv2Forwarder.MESSAGE_TRANSMITTER_CIRCLE_ETHEREUM;

    uint32 internal constant ETHEREUM_CCTP_DOMAIN = CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM;
    uint32 internal constant XLAYER_CCTP_DOMAIN   = 37;

    address internal constant XLAYER_RELAYER            = 0xE4FB2B5B40EE539f5b9551cf699674d3082eD39b;
    address internal constant XLAYER_SPUSDC             = 0xf593142283736439d7F0B93ddB3B10E780Ba3074;
    address internal constant XLAYER_USDC               = 0xB6CEceAB302E2E4948951eE7843FC24E92933061;
    address internal constant XLAYER_ADMINISTERED_AGENT = 0xcF9F6Cb0a94aAfe367F2F0Dac0EE86e033abc4E0;
    address internal constant XLAYER_ALM_PROXY          = 0x4aeB3eA3cE2cF9ABaF8ED558C72A215743D7eb4F;
    address internal constant XLAYER_CONTROLLER         = 0x32b845F472f61b023b1bd77f2E0fb2b3F9db2053;
    address internal constant XLAYER_RATE_LIMITS        = 0x2D66F6C219d19b9E546Af7Ff02fFcCE145F95767;

    address internal constant MAINNET_RELAYER            = 0x611C7c37F296240c2fF5a92f0B4a398B01B237c4;
    address internal constant MAINNET_ADMINISTERED_AGENT = 0x8d165c44a8043C578fAA9fb35B99d324A7F83943;
    address internal constant MAINNET_ALM_PROXY          = 0xFB2252689E3a9c5d89cBBb65a174dba1163a8f19;
    address internal constant MAINNET_CONTROLLER         = 0xB87A3680f5957AB3dC5F26d77b59326C267683a4;
    address internal constant MAINNET_RATE_LIMITS        = 0xD9874309494f3E6901999AF225cb8a70ff7aE1cE;

    Bridge internal bridge;
    Domain internal mainnet;
    Domain internal xlayer;

    IAdministeredAgent     internal xlayerAgent;
    IForeignControllerFull internal xlayerController;
    IRateLimits            internal xlayerRateLimits;
    ISparkVaultLike        internal spusdc;
    IERC20                 internal xlayerUsdc;

    IAdministeredAgent     internal mainnetAgent;
    IMainnetControllerFull internal mainnetController;
    IRateLimits            internal mainnetRateLimits;
    IERC4626               internal susdc;
    IERC20                 internal usdc;

    address internal user = makeAddr("user");

    /**********************************************************************************************/
    /*** Setup                                                                                  ***/
    /**********************************************************************************************/

    function setUp() public {
        setChain("xlayer", ChainData({
            name    : "XLayer",
            rpcUrl  : vm.envString("XLAYER_RPC_URL"),
            chainId : 196
        }));

        mainnet = getChain("mainnet").createFork(25930847);       // September 8, 2026
        xlayer  = getChain("xlayer").createSelectFork(70079681);  // September 8, 2026

        bridge = CCTPv2BridgeTesting.init(Bridge({
            bridgeType                     : BridgeType.CCTP_V2,
            source                         : xlayer,
            destination                    : mainnet,
            sourceCrossChainMessenger      : CCTP_MESSAGE_TRANSMITTER,
            destinationCrossChainMessenger : CCTP_MESSAGE_TRANSMITTER,
            lastSourceLogIndex             : 0,
            lastDestinationLogIndex        : 0,
            extraData                      : ""
        }));

        // Setup X Layer.

        xlayer.selectFork();

        xlayerAgent      = IAdministeredAgent(XLAYER_ADMINISTERED_AGENT);
        xlayerController = IForeignControllerFull(XLAYER_CONTROLLER);
        xlayerRateLimits = IRateLimits(XLAYER_RATE_LIMITS);
        spusdc           = ISparkVaultLike(XLAYER_SPUSDC);
        xlayerUsdc       = IERC20(XLAYER_USDC);

        vm.prank(ADMIN);
        spusdc.setDepositCap(1_000_000e6);

        // Setup Mainnet.

        mainnet.selectFork();

        mainnetAgent      = IAdministeredAgent(MAINNET_ADMINISTERED_AGENT);
        mainnetController = IMainnetControllerFull(MAINNET_CONTROLLER);
        mainnetRateLimits = IRateLimits(MAINNET_RATE_LIMITS);
        susdc             = IERC4626(Ethereum.SUSDC);
        usdc              = IERC20(Ethereum.USDC);

        xlayer.selectFork();
    }

    function test_e2e_roundTrip() external {
        // Step 1: User deposits USDC into spUSDC on X Layer.

        deal(XLAYER_USDC, user, DEPOSIT_AMOUNT);

        assertEq(xlayerUsdc.balanceOf(user),          DEPOSIT_AMOUNT);
        assertEq(xlayerUsdc.balanceOf(XLAYER_SPUSDC), 0);

        assertEq(spusdc.totalAssets(),   0);
        assertEq(spusdc.totalSupply(),   0);
        assertEq(spusdc.balanceOf(user), 0);

        vm.startPrank(user);
        xlayerUsdc.approve(XLAYER_SPUSDC, DEPOSIT_AMOUNT);
        spusdc.deposit(DEPOSIT_AMOUNT, user);
        vm.stopPrank();

        assertEq(xlayerUsdc.balanceOf(user),          0);
        assertEq(xlayerUsdc.balanceOf(XLAYER_SPUSDC), DEPOSIT_AMOUNT);

        assertEq(spusdc.totalAssets(),   DEPOSIT_AMOUNT);
        assertEq(spusdc.totalSupply(),   DEPOSIT_AMOUNT);
        assertEq(spusdc.balanceOf(user), DEPOSIT_AMOUNT);

        // Step 2: Relayer takes the USDC out of spUSDC into the ALMProxy on X Layer.

        bytes32 takeKey = xlayerController.sparkVault_getTakeRateLimitKey(XLAYER_SPUSDC);

        assertEq(xlayerRateLimits.getCurrentRateLimit(takeKey), STAGING_RATE_LIMIT_MAX_AMOUNT);

        assertEq(xlayerUsdc.balanceOf(XLAYER_ALM_PROXY), 0);

        vm.prank(XLAYER_RELAYER);
        xlayerAgent.call(XLAYER_CONTROLLER, abi.encodeCall(xlayerController.sparkVault_take, (XLAYER_SPUSDC, DEPOSIT_AMOUNT)));

        assertEq(xlayerRateLimits.getCurrentRateLimit(takeKey), STAGING_RATE_LIMIT_MAX_AMOUNT - DEPOSIT_AMOUNT);

        assertEq(xlayerUsdc.balanceOf(XLAYER_SPUSDC),    0);
        assertEq(xlayerUsdc.balanceOf(XLAYER_ALM_PROXY), DEPOSIT_AMOUNT);

        // Step 3: Relayer bridges the USDC to Ethereum with CCTP V2 (burn on X Layer).

        bytes32 xlayerCctpKey       = xlayerController.cctp_toCCTPRateLimitKey();
        bytes32 xlayerCctpDomainKey = xlayerController.cctp_getToDomainRateLimitKey(ETHEREUM_CCTP_DOMAIN);

        assertEq(xlayerRateLimits.getCurrentRateLimit(xlayerCctpKey),       STAGING_RATE_LIMIT_MAX_AMOUNT);
        assertEq(xlayerRateLimits.getCurrentRateLimit(xlayerCctpDomainKey), STAGING_RATE_LIMIT_MAX_AMOUNT);

        uint256 xlayerUsdcSupply = xlayerUsdc.totalSupply();

        vm.prank(XLAYER_RELAYER);
        xlayerAgent.call(XLAYER_CONTROLLER, abi.encodeCall(xlayerController.cctp_transfer, (DEPOSIT_AMOUNT, ETHEREUM_CCTP_DOMAIN, 0)));

        assertEq(xlayerRateLimits.getCurrentRateLimit(xlayerCctpKey),       STAGING_RATE_LIMIT_MAX_AMOUNT - DEPOSIT_AMOUNT);
        assertEq(xlayerRateLimits.getCurrentRateLimit(xlayerCctpDomainKey), STAGING_RATE_LIMIT_MAX_AMOUNT - DEPOSIT_AMOUNT);

        assertEq(xlayerUsdc.balanceOf(XLAYER_ALM_PROXY), 0);
        assertEq(xlayerUsdc.totalSupply(),               xlayerUsdcSupply - DEPOSIT_AMOUNT);

        // Step 4: Relay the message to Ethereum.

        mainnet.selectFork();

        uint256 mainnetUsdcSupply = usdc.totalSupply();

        assertEq(usdc.balanceOf(MAINNET_ALM_PROXY), 0);

        bridge.relayMessagesToDestination(true);

        assertEq(usdc.balanceOf(MAINNET_ALM_PROXY), DEPOSIT_AMOUNT);
        assertEq(usdc.totalSupply(),                mainnetUsdcSupply + DEPOSIT_AMOUNT);

        // Step 5: Relayer deposits the USDC into sUSDC.

        bytes32 depositKey  = mainnetController.erc4626_getDepositRateLimitKey(Ethereum.SUSDC, Ethereum.USDC);
        bytes32 withdrawKey = mainnetController.erc4626_getWithdrawRateLimitKey(Ethereum.SUSDC);

        assertEq(mainnetRateLimits.getCurrentRateLimit(depositKey),  STAGING_RATE_LIMIT_MAX_AMOUNT);
        assertEq(mainnetRateLimits.getCurrentRateLimit(withdrawKey), STAGING_RATE_LIMIT_MAX_AMOUNT);

        uint256 expectedShares = susdc.convertToShares(DEPOSIT_AMOUNT);

        assertEq(susdc.balanceOf(MAINNET_ALM_PROXY), 0);

        vm.prank(MAINNET_RELAYER);
        mainnetAgent.call(MAINNET_CONTROLLER, abi.encodeCall(mainnetController.erc4626_deposit, (Ethereum.SUSDC, DEPOSIT_AMOUNT, expectedShares)));

        assertEq(mainnetRateLimits.getCurrentRateLimit(depositKey),  STAGING_RATE_LIMIT_MAX_AMOUNT - DEPOSIT_AMOUNT);
        assertEq(mainnetRateLimits.getCurrentRateLimit(withdrawKey), STAGING_RATE_LIMIT_MAX_AMOUNT);

        assertEq(usdc.balanceOf(MAINNET_ALM_PROXY),  0);
        assertEq(susdc.balanceOf(MAINNET_ALM_PROXY), expectedShares);

        assertApproxEqAbs(susdc.convertToAssets(expectedShares), DEPOSIT_AMOUNT, 1);  // Share rounding

        // Step 6: Yield accrues in sUSDC.

        skip(1 days);

        uint256 usdcWithYield = susdc.convertToAssets(expectedShares);

        assertGt(usdcWithYield, DEPOSIT_AMOUNT);
        assertLt(usdcWithYield, STAGING_RATE_LIMIT_MAX_AMOUNT);

        // Step 7: Relayer withdraws from sUSDC by redeeming every share.

        vm.prank(MAINNET_RELAYER);
        mainnetAgent.call(MAINNET_CONTROLLER, abi.encodeCall(mainnetController.erc4626_redeem, (Ethereum.SUSDC, expectedShares, usdcWithYield)));

        assertEq(mainnetRateLimits.getCurrentRateLimit(depositKey),  STAGING_RATE_LIMIT_MAX_AMOUNT);
        assertEq(mainnetRateLimits.getCurrentRateLimit(withdrawKey), STAGING_RATE_LIMIT_MAX_AMOUNT - usdcWithYield);

        assertEq(susdc.balanceOf(MAINNET_ALM_PROXY), 0);
        assertEq(usdc.balanceOf(MAINNET_ALM_PROXY),  usdcWithYield);

        // Step 8: Relayer bridges the USDC back to X Layer with CCTP V2 (burn on Ethereum).

        bytes32 mainnetCctpKey       = mainnetController.cctp_toCCTPRateLimitKey();
        bytes32 mainnetCctpDomainKey = mainnetController.cctp_getToDomainRateLimitKey(XLAYER_CCTP_DOMAIN);

        assertEq(mainnetRateLimits.getCurrentRateLimit(mainnetCctpKey),       STAGING_RATE_LIMIT_MAX_AMOUNT);
        assertEq(mainnetRateLimits.getCurrentRateLimit(mainnetCctpDomainKey), STAGING_RATE_LIMIT_MAX_AMOUNT);

        vm.prank(MAINNET_RELAYER);
        mainnetAgent.call(MAINNET_CONTROLLER, abi.encodeCall(mainnetController.cctp_transfer, (usdcWithYield, XLAYER_CCTP_DOMAIN, 0)));

        assertEq(mainnetRateLimits.getCurrentRateLimit(mainnetCctpKey),       STAGING_RATE_LIMIT_MAX_AMOUNT - usdcWithYield);
        assertEq(mainnetRateLimits.getCurrentRateLimit(mainnetCctpDomainKey), STAGING_RATE_LIMIT_MAX_AMOUNT - usdcWithYield);

        assertEq(usdc.balanceOf(MAINNET_ALM_PROXY), 0);
        assertEq(usdc.totalSupply(),                mainnetUsdcSupply + DEPOSIT_AMOUNT - usdcWithYield);

        // Step 9: Relay the message to X Layer.

        xlayer.selectFork();

        assertEq(xlayerUsdc.balanceOf(XLAYER_ALM_PROXY), 0);

        bridge.relayMessagesToSource(true);

        assertEq(xlayerUsdc.balanceOf(XLAYER_ALM_PROXY), usdcWithYield);
        assertEq(xlayerUsdc.totalSupply(),               xlayerUsdcSupply - DEPOSIT_AMOUNT + usdcWithYield);

        // Step 10: Relayer transfers the USDC, yield included, back into spUSDC.

        bytes32 transferKey = xlayerController.transferAsset_getTransferRateLimitKey(XLAYER_USDC, XLAYER_SPUSDC);

        assertEq(xlayerRateLimits.getCurrentRateLimit(transferKey), STAGING_RATE_LIMIT_MAX_AMOUNT);

        vm.prank(XLAYER_RELAYER);
        xlayerAgent.call(XLAYER_CONTROLLER, abi.encodeCall(xlayerController.transferAsset_transfer, (XLAYER_USDC, XLAYER_SPUSDC, usdcWithYield)));

        assertEq(xlayerRateLimits.getCurrentRateLimit(transferKey), STAGING_RATE_LIMIT_MAX_AMOUNT - usdcWithYield);

        assertEq(xlayerUsdc.balanceOf(XLAYER_ALM_PROXY), 0);
        assertEq(xlayerUsdc.balanceOf(XLAYER_SPUSDC),    usdcWithYield);

        // Step 11: User redeems.
        assertEq(spusdc.totalAssets(), DEPOSIT_AMOUNT);

        vm.prank(user);
        spusdc.redeem(DEPOSIT_AMOUNT, user, user);

        assertEq(xlayerUsdc.balanceOf(user),          DEPOSIT_AMOUNT);
        assertEq(xlayerUsdc.balanceOf(XLAYER_SPUSDC), usdcWithYield - DEPOSIT_AMOUNT);

        assertEq(spusdc.totalAssets(),   0);
        assertEq(spusdc.totalSupply(),   0);
        assertEq(spusdc.balanceOf(user), 0);
    }

}
