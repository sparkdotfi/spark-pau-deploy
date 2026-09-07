// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson } from "../../lib/forge-std/src/Script.sol";

import { console2 } from "../../lib/forge-std/src/console2.sol";

import { ScriptTools } from "../../lib/dss-test/src/ScriptTools.sol";

import { IMainnetControllerFull as IControllerFull } from "../../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

interface IAccessControlsLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

}

interface IAdministeredAgentLike {

    function addAdmin(address admin) external;

    function removeAdmin(address admin) external;

}

interface IALMProxyLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

}

interface IBeaconLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

}

interface ISparkVaultLike {

    function TAKER_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function convertToShares(uint256 assets) external view returns (uint256 shares);

}

interface IRateLimitsLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;

}

abstract contract ConfigureSparkPAUFullBase is Script {

    using stdJson     for string;
    using ScriptTools for string;

    IBeaconLike internal beacon;

    IAccessControlsLike    internal accessControls;
    IALMProxyLike          internal almProxy;
    IControllerFull        internal controller;
    IRateLimitsLike        internal rateLimits;
    IAdministeredAgentLike internal administeredAgent;

    address internal admin;
    address internal deployer;

    string internal config;

    function run() public virtual {
        _setXLayerAndRHChainForks();

        string memory chain = vm.envOr("CHAIN", string("mainnet"));

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("config-pau-with-assembler-", chain, "-", env));

        config = ScriptTools.loadConfig(fileSlug);

        require(block.chainid == config.readUint(".chainId"), "ConfigureSparkPAUFullBase/invalid-chain-id");

        controller        = IControllerFull(config.readAddress(".controller"));
        almProxy          = IALMProxyLike(controller.proxy());
        rateLimits        = IRateLimitsLike(controller.rateLimits());
        accessControls    = IAccessControlsLike(controller.accessControls());
        administeredAgent = IAdministeredAgentLike(config.readAddress(".administeredAgent"));

        beacon = IBeaconLike(config.readAddress(".beacon"));

        admin    = config.readAddress(".admin");
        deployer = config.readAddress(".deployer");

        require(admin != deployer, "ConfigureSparkPAUFullBase/admin-is-deployer");

        vm.startBroadcast();

        require(msg.sender == deployer, "ConfigureSparkPAUFullBase/sender-not-deployer");

        // Step 1: Onboard Facets

        _onboardFacets();

        // Step 2: Remove deployer as admin of AccessControls, AdministeredAgent and RateLimits.

        _transferAdminRoles();

        console2.log("Deployer removed as admin of AccessControls, AdministeredAgent, RateLimits and ALMProxy");

        vm.stopBroadcast();
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _onboardFacets() internal virtual { }

    function _transferAdminRoles() internal {
        // Grant admin roles to admin
        beacon.grantRole(beacon.DEFAULT_ADMIN_ROLE(), admin);

        accessControls.grantRole(accessControls.DEFAULT_ADMIN_ROLE(), admin);
        almProxy.grantRole(almProxy.DEFAULT_ADMIN_ROLE(),             admin);
        rateLimits.grantRole(rateLimits.DEFAULT_ADMIN_ROLE(),         admin);

        administeredAgent.addAdmin(admin);

        // Revoke admin roles from deployer
        beacon.revokeRole(beacon.DEFAULT_ADMIN_ROLE(), deployer);

        accessControls.revokeRole(accessControls.DEFAULT_ADMIN_ROLE(), deployer);
        almProxy.revokeRole(almProxy.DEFAULT_ADMIN_ROLE(),             deployer);
        rateLimits.revokeRole(rateLimits.DEFAULT_ADMIN_ROLE(),         deployer);

        administeredAgent.removeAdmin(deployer);
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

contract ConfigureSparkPAUFullMainnet is ConfigureSparkPAUFullBase {

    using stdJson for string;

    address internal xlayerAlmProxy;
    uint32  internal xlayerDomainId;

    address internal usdc;
    address internal susdc;

    function _onboardFacets() internal override {
        xlayerAlmProxy = config.readAddress(".xlayerAlmProxy");
        xlayerDomainId = uint32(config.readUint(".xlayerDomainId"));

        usdc  = config.readAddress(".usdc");
        susdc = config.readAddress(".susdc");

        _onboardCCTPFacet();
        _onboardPSMFacet();
        _onboardERC4626Facet();
    }

    function _onboardCCTPFacet() internal {
        // Set domain parameters
        controller.cctp_setDomainParameters(
            xlayerDomainId,
            bytes32(uint256(uint160(xlayerAlmProxy))),
            0,
            100
        );

        // Set rate limits
        rateLimits.setRateLimitData(controller.cctp_toCCTPRateLimitKey(), 10e6, uint256(100e6) / 1 hours);

        rateLimits.setRateLimitData(
            controller.cctp_getToDomainRateLimitKey(xlayerDomainId),
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
        bytes32 depositKey  = controller.erc4626_getDepositRateLimitKey(susdc, usdc);
        bytes32 withdrawKey = controller.erc4626_getWithdrawRateLimitKey(susdc);

        rateLimits.setRateLimitData(depositKey,  10e18, uint256(100e18) / 1 hours);
        rateLimits.setRateLimitData(withdrawKey, 10e18, uint256(100e18) / 1 hours);

        controller.erc4626_setMaxExchangeRate(
            susdc,
            ISparkVaultLike(susdc).convertToShares(1e18),
            1.2e18
        );
    }

}

contract ConfigureSparkPAUFullXLayer is ConfigureSparkPAUFullBase {

    using stdJson for string;

    address internal ethereumAlmProxy;
    uint32  internal ethereumDomainId;

    address internal usdc;
    address internal spusdc;

    function _onboardFacets() internal override {
        ethereumAlmProxy = config.readAddress(".ethereumAlmProxy");
        ethereumDomainId = uint32(config.readUint(".ethereumDomainId"));

        usdc   = config.readAddress(".usdc");
        spusdc = config.readAddress(".spusdc");

        _onboardCCTPFacet();
        _onboardTransferAssetFacet();
        _onboardSparkVaultFacet();
    }

    function _onboardCCTPFacet() internal {
        // Set domain parameters
        controller.cctp_setDomainParameters(
            ethereumDomainId,
            bytes32(uint256(uint160(ethereumAlmProxy))),
            0,
            100
        );

        // Set rate limits
        rateLimits.setRateLimitData(controller.cctp_toCCTPRateLimitKey(), 10e6, uint256(100e6) / 1 hours);

        rateLimits.setRateLimitData(
            controller.cctp_getToDomainRateLimitKey(ethereumDomainId),
            10e6,
            uint256(100e6) / 1 hours
        );
    }

    function _onboardTransferAssetFacet() internal {
        rateLimits.setRateLimitData(
            controller.transferAsset_getTransferRateLimitKey(usdc, spusdc),
            10e6,
            uint256(100e6) / 1 hours
        );
    }

    function _onboardSparkVaultFacet() internal {
        ISparkVaultLike(spusdc).grantRole(ISparkVaultLike(spusdc).TAKER_ROLE(), address(almProxy));

        rateLimits.setRateLimitData(
            controller.sparkVault_getTakeRateLimitKey(spusdc),
            10e6,
            uint256(100e6) / 1 hours
        );
    }

}
