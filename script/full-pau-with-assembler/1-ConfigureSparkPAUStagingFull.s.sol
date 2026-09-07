// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson } from "../../lib/forge-std/src/Script.sol";

import { console2 } from "../../lib/forge-std/src/console2.sol";

import { ScriptTools } from "../../lib/dss-test/src/ScriptTools.sol";

import { CCTPv2Forwarder } from "../../lib/diamond-pau/lib/grove-xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { IMainnetControllerFull as IControllerFull } from "../../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

interface IAccessControlsLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function revokeRole(bytes32 role, address account) external;

}

interface IAdministeredAgentLike {

    function removeAdmin(address admin) external;

}

interface IALMProxyLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function revokeRole(bytes32 role, address account) external;

}

interface IERC4626Like {

    function convertToShares(uint256 assets) external view returns (uint256 shares);

}

interface IRateLimitsLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function revokeRole(bytes32 role, address account) external;

    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;

}

abstract contract ConfigureSparkPAUStagingFullBase is Script {

    using stdJson     for string;
    using ScriptTools for string;

    IAccessControlsLike    internal accessControls;
    IALMProxyLike          internal almProxy;
    IControllerFull        internal controller;
    IRateLimitsLike        internal rateLimits;
    IAdministeredAgentLike internal administeredAgent;

    address internal admin;
    address internal deployer;

    function run() public virtual {
        _setXLayerAndRHChainForks();

        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory fileSlug = string(abi.encodePacked("config-pau-with-assembler-", chain, "-", "staging"));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "ConfigureSparkPAUStagingBase/invalid-chain-id");

        controller        = IControllerFull(config.readAddress(".controller"));
        almProxy          = IALMProxyLike(controller.proxy());
        rateLimits        = IRateLimitsLike(controller.rateLimits());
        accessControls    = IAccessControlsLike(controller.accessControls());
        administeredAgent = IAdministeredAgentLike(config.readAddress(".administeredAgent"));

        admin    = config.readAddress(".admin");
        deployer = config.readAddress(".deployer");

        require(admin != deployer, "ConfigureSparkPAUStagingFullBase/admin-is-deployer");

        vm.startBroadcast();

        require(msg.sender == deployer, "ConfigureSparkPAUStagingFullBase/sender-not-deployer");

        // Step 1: Onboard Facets

        _onboardFacets();

        // Step 2: Remove deployer as admin of AccessControls, AdministeredAgent and RateLimits.

        _removeDeployerAsAdmin();

        console2.log("Deployer removed as admin of AccessControls, AdministeredAgent, RateLimits and ALMProxy");

        vm.stopBroadcast();
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _onboardFacets() internal virtual { }

    function _removeDeployerAsAdmin() internal {
        accessControls.revokeRole(accessControls.DEFAULT_ADMIN_ROLE(), deployer);
        rateLimits.revokeRole(rateLimits.DEFAULT_ADMIN_ROLE(),         deployer);

        administeredAgent.removeAdmin(deployer);

        almProxy.revokeRole(almProxy.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _setXLayerAndRHChainForks() internal {
        setChain("xlayer", ChainData({
            name    : "XLayer",
            rpcUrl  : vm.envString("XLAYER_RPC_URL"),
            chainId : 196
        }));

        setChain("robinhood_chain", ChainData({
            name    : "Robinhood Chain",
            rpcUrl  : vm.envString("RH_RPC_URL"),
            chainId : 4663
        }));
    }

}

contract ConfigureSparkPAUStagingFullMainnet is ConfigureSparkPAUStagingFullBase {

    address internal constant XLAYER_ALM_PROXY = 0x4aeB3eA3cE2cF9ABaF8ED558C72A215743D7eb4F;

    uint32 internal constant XLAYER_DOMAIN_ID = 37;

    function _onboardFacets() internal override {
        _onboardCCTPFacet();
        _onboardPSMFacet();
        _onboardERC4626Facet();
    }

    function _onboardCCTPFacet() internal {
        // Set domain parameters
        controller.cctp_setDomainParameters(
            XLAYER_DOMAIN_ID,
            bytes32(uint256(uint160(XLAYER_ALM_PROXY))),
            0,
            100
        );

        // Set rate limits
        rateLimits.setRateLimitData(controller.cctp_toCCTPRateLimitKey(), 10e6, uint256(100e6) / 1 hours);

        rateLimits.setRateLimitData(
            controller.cctp_getToDomainRateLimitKey(XLAYER_DOMAIN_ID),
            10e6,
            uint256(100e6) / 1 hours
        );
    }

    function _onboardPSMFacet() internal {
        rateLimits.setRateLimitData(
            controller.psm_usdcToUSDSSwapRateLimitKey(),
            10e6,
            uint256(100e6) / 1 hours
        );

        rateLimits.setRateLimitData(
            controller.psm_usdsToUSDCSwapRateLimitKey(),
            10e6,
            uint256(100e6) / 1 hours
        );
    }

    function _onboardERC4626Facet() internal {
        bytes32 depositKey  = controller.erc4626_getDepositRateLimitKey(Ethereum.SUSDS, Ethereum.USDS);
        bytes32 withdrawKey = controller.erc4626_getWithdrawRateLimitKey(Ethereum.SUSDS);

        rateLimits.setRateLimitData(depositKey,  10e18, uint256(100e18) / 1 hours);
        rateLimits.setRateLimitData(withdrawKey, 10e18, uint256(100e18) / 1 hours);

        controller.erc4626_setMaxExchangeRate(
            Ethereum.SUSDS,
            IERC4626Like(Ethereum.SUSDS).convertToShares(1e18),
            1.2e18
        );
    }

}

contract ConfigureSparkPAUStagingFullXLayer is ConfigureSparkPAUStagingFullBase {

    address internal constant ETHEREUM_ALM_PROXY = 0xFB2252689E3a9c5d89cBBb65a174dba1163a8f19;
    address internal constant SPUSDC             = 0xaAd950768f584Bc31501bf6357f9205D4F3f2BE3;
    address internal constant USDC               = 0x74b7F16337b8972027F6196A17a631aC6dE26d22;

    function _onboardFacets() internal override {
        _onboardCCTPFacet();
        _onboardTransferAssetFacet();
        _onboardSparkVaultFacet();
    }

    function _onboardCCTPFacet() internal {
        // Set domain parameters
        controller.cctp_setDomainParameters(
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(uint256(uint160(ETHEREUM_ALM_PROXY))),
            0,
            100
        );

        // Set rate limits
        rateLimits.setRateLimitData(controller.cctp_toCCTPRateLimitKey(), 10e6, uint256(100e6) / 1 hours);

        rateLimits.setRateLimitData(
            controller.cctp_getToDomainRateLimitKey(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            10e6,
            uint256(100e6) / 1 hours
        );
    }

    function _onboardTransferAssetFacet() internal {
        rateLimits.setRateLimitData(
            controller.transferAsset_getTransferRateLimitKey(USDC, SPUSDC),
            10e6,
            uint256(100e6) / 1 hours
        );
    }

    function _onboardSparkVaultFacet() internal {
        rateLimits.setRateLimitData(
            controller.sparkVault_getTakeRateLimitKey(Ethereum.SUSDS),
            10e18,
            uint256(100e18) / 1 hours
        );
    }

}
