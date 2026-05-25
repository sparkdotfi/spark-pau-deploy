// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { VmSafe } from "../../lib/forge-std/src/Vm.sol";

import { IAccessControl }                 from "../../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { Initializable }                  from "../../lib/diamond-pau/lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IEnumerableIntegrations as IEI } from "../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";
import { IMainnetControllerFull }         from "../../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";

import { AccessControls } from "../../lib/diamond-pau/src/AccessControls.sol";
import { Beacon }         from "../../lib/diamond-pau/src/Beacon.sol";

import { IERC4626Facet }   from "../../lib/diamond-pau/src/facets/erc4626/IERC4626Facet.sol";
import { IAaveFacet }      from "../../lib/diamond-pau/src/facets/aave/IAaveFacet.sol";
import { ICurveFacet }     from "../../lib/diamond-pau/src/facets/curve/ICurveFacet.sol";
import { IUniswapV4Facet } from "../../lib/diamond-pau/src/facets/uniswap-v4/IUniswapV4Facet.sol";

import { Ethereum }  from "../../lib/spark-address-registry/src/Ethereum.sol";
import { SparkLend } from "../../lib/spark-address-registry/src/SparkLend.sol";

import { PostDeployTestBase } from "../PostDeployTestBase.t.sol";

interface IOldMainnetControllerLike {

    function uniswapV4TickLimits(bytes32 poolId) external view returns (int24 tickLower, int24 tickUpper, uint24 maxTickSpacing);

    function maxSlippages(address pool) external view returns (uint256 maxSlippage);

    function maxExchangeRates(address vault) external view returns (uint256 maxExchangeRate);

}

contract PostDeployTests is PostDeployTestBase {

    // Paste from script output.
    address internal constant ACCESS_CONTROLS = 0xD63f44D65180bCEbb1EB3D52858FbE65eE8162A3;
    address internal constant CONTROLLER      = 0x0DCeDfBDb225F0D0973cf05de08c051A663F463c;
    address internal constant DEPLOYER        = 0x1ca4ECaF0E13ca833c80dA835DEEa15e1684361d;

    // Get from SKY
    address internal constant BEACON = 0x9EA465978500399C6b4b9A356b14b00e6597e705;

    address internal constant ADMIN              = Ethereum.SPARK_PROXY;
    address internal constant ALLOCATOR          = Ethereum.ALM_RELAYER_MULTISIG;
    address internal constant ALLOCATOR_ADMIN    = Ethereum.ALM_FREEZER_MULTISIG;
    address internal constant ALM_PROXY          = Ethereum.ALM_PROXY;
    address internal constant BACKSTOP_ALLOCATOR = Ethereum.ALM_BACKSTOP_RELAYER_MULTISIG;
    address internal constant RATE_LIMITS        = Ethereum.ALM_RATE_LIMITS;

    bytes32 internal constant PYUSD_USDS_POOL_ID = 0xe63e32b2ae40601662f760d6bf5d771057324fbd97784fe1d3717069f7b75d45;
    bytes32 internal constant USDT_USDS_POOL_ID  = 0x3b1b1f2e775a6db1664f8e7d59ad568605ea2406312c11aef03146c0cf89d5b9;

    AccessControls         internal accessControls;
    Beacon                 internal beacon;
    IMainnetControllerFull internal controller;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        accessControls = AccessControls(ACCESS_CONTROLS);
        beacon         = Beacon(BEACON);
        controller     = IMainnetControllerFull(CONTROLLER);
    }

    function _getBlock() internal pure returns (uint256) {
        return 25170722; // May-25-2026 07:07:47 AM +UTC : After all scripts are run.
    }

    function test_deployState() external view {

       /*******************************************************************************************/
       /*** AccessControls post deploy state                                                    ***/
       /*******************************************************************************************/

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,       ALLOCATOR),          true);
        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,       BACKSTOP_ALLOCATOR), true);
        assertEq(accessControls.hasRole(ALLOCATOR_ADMIN_ROLE, ALLOCATOR_ADMIN),    true);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE,   ADMIN),              true);

        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE),   1);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ROLE),       2);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ADMIN_ROLE), 1);

        assertEq(accessControls.getRoleAdmin(ALLOCATOR_ROLE), ALLOCATOR_ADMIN_ROLE); // via setRoleAdmin.

        // DEPLOYER has no roles on AccessControls
        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,       DEPLOYER), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE,   DEPLOYER), false);
        assertEq(accessControls.hasRole(ALLOCATOR_ADMIN_ROLE, DEPLOYER), false);

       /*******************************************************************************************/
       /*** Controller post deploy state                                                        ***/
       /*******************************************************************************************/

        // Constructor initializes with the correct state.
        assertEq(controller.accessControls(), ACCESS_CONTROLS);
        assertEq(controller.beacon(),         BEACON);
        assertEq(controller.proxy(),          ALM_PROXY);
        assertEq(controller.rateLimits(),     RATE_LIMITS);


        // Configurations: updateIntegrations.

        IEI.Integration[] memory integrations = controller.integrations();

        assertEq(integrations.length, 24);

        assertEq(integrations[0].id,  bytes32(abi.encodePacked("AAVE_FACET")));
        assertEq(integrations[1].id,  bytes32(abi.encodePacked("CCTP_FACET")));
        assertEq(integrations[2].id,  bytes32(abi.encodePacked("CENTRIFUGE_FACET")));
        assertEq(integrations[3].id,  bytes32(abi.encodePacked("CURVE_FACET")));
        assertEq(integrations[4].id,  bytes32(abi.encodePacked("DAIUSDS_FACET")));
        assertEq(integrations[5].id,  bytes32(abi.encodePacked("ERC4626_FACET")));
        assertEq(integrations[6].id,  bytes32(abi.encodePacked("ERC7540_FACET")));
        assertEq(integrations[7].id,  bytes32(abi.encodePacked("ETHENA_FACET")));
        assertEq(integrations[8].id,  bytes32(abi.encodePacked("FARM_FACET")));
        assertEq(integrations[9].id,  bytes32(abi.encodePacked("LAYER_ZERO_FACET")));
        assertEq(integrations[10].id, bytes32(abi.encodePacked("MAPLE_FACET")));
        assertEq(integrations[11].id, bytes32(abi.encodePacked("MERKL_FACET")));
        assertEq(integrations[12].id, bytes32(abi.encodePacked("OTC_FACET")));
        assertEq(integrations[13].id, bytes32(abi.encodePacked("PENDLE_FACET")));
        assertEq(integrations[14].id, bytes32(abi.encodePacked("PSM_FACET")));
        assertEq(integrations[15].id, bytes32(abi.encodePacked("SPARK_VAULT_FACET")));
        assertEq(integrations[16].id, bytes32(abi.encodePacked("SUPERSTATE_FACET")));
        assertEq(integrations[17].id, bytes32(abi.encodePacked("TRANSFER_ASSET_FACET")));
        assertEq(integrations[18].id, bytes32(abi.encodePacked("UNISWAP_V3_FACET")));
        assertEq(integrations[19].id, bytes32(abi.encodePacked("UNISWAP_V4_FACET")));
        assertEq(integrations[20].id, bytes32(abi.encodePacked("USDS_FACET")));
        assertEq(integrations[21].id, bytes32(abi.encodePacked("WEETH_FACET")));
        assertEq(integrations[22].id, bytes32(abi.encodePacked("WRAP_PROXY_ETH_FACET")));
        assertEq(integrations[23].id, bytes32(abi.encodePacked("WSTETH_FACET")));

        for (uint256 i = 0; i < integrations.length; i++) {
            _assertIntegration(integrations[i].id);
        }

        // Configurations: migrate erc4626 max exchange rates.

        _assertERC4626MaxExchangeRate(Ethereum.MORPHO_VAULT_USDC_BC);
        _assertERC4626MaxExchangeRate(Ethereum.MORPHO_VAULT_DAI_1);
        _assertERC4626MaxExchangeRate(Ethereum.MORPHO_VAULT_USDS);
        _assertERC4626MaxExchangeRate(Ethereum.MORPHO_VAULT_V2_USDT);
        _assertERC4626MaxExchangeRate(Ethereum.SUSDS);
        _assertERC4626MaxExchangeRate(Ethereum.FLUID_SUSDS);
        _assertERC4626MaxExchangeRate(Ethereum.SUSDE);
        _assertERC4626MaxExchangeRate(Ethereum.SYRUP_USDC);
        _assertERC4626MaxExchangeRate(Ethereum.SYRUP_USDT);
        _assertERC4626MaxExchangeRate(Ethereum.ARKIS_VAULT);

        // Configurations: migrate curve max slippage.

        _assertCurveMaxSlippage(Ethereum.CURVE_SUSDSUSDT);
        _assertCurveMaxSlippage(Ethereum.CURVE_PYUSDUSDC);
        _assertCurveMaxSlippage(Ethereum.CURVE_USDCUSDT);
        _assertCurveMaxSlippage(Ethereum.CURVE_PYUSDUSDS);
        _assertCurveMaxSlippage(Ethereum.CURVE_WEETHWETHNG);

        // Configurations: migrate aave max slippage.

        _assertAaveMaxSlippage(Ethereum.ATOKEN_CORE_USDC);
        _assertAaveMaxSlippage(Ethereum.ATOKEN_CORE_USDE);
        _assertAaveMaxSlippage(Ethereum.ATOKEN_CORE_USDS);
        _assertAaveMaxSlippage(Ethereum.ATOKEN_CORE_USDT);
        _assertAaveMaxSlippage(Ethereum.ATOKEN_PRIME_USDS);
        _assertAaveMaxSlippage(SparkLend.DAI_SPTOKEN);
        _assertAaveMaxSlippage(SparkLend.USDC_SPTOKEN);
        _assertAaveMaxSlippage(SparkLend.USDS_SPTOKEN);
        _assertAaveMaxSlippage(SparkLend.USDT_SPTOKEN);
        _assertAaveMaxSlippage(SparkLend.PYUSD_SPTOKEN);
        _assertAaveMaxSlippage(SparkLend.WETH_SPTOKEN);

        // Configurations: migrate uniswapV4 pools.

        _assertUniswapV4Migration(PYUSD_USDS_POOL_ID);
        _assertUniswapV4Migration(USDT_USDS_POOL_ID);
    }

    function test_postDeployEvents() external {

       /*******************************************************************************************/
       /*** AccessControls events                                                               ***/
       /*******************************************************************************************/

        VmSafe.EthGetLogs[] memory accessControlsAllLogs = _getEvents(block.chainid, ACCESS_CONTROLS, "");

        assertEq(accessControlsAllLogs.length, 7);

        // RoleGranted(DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER) from Deploy: AccessControls constructor.
        assertEq(accessControlsAllLogs[0].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[0].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[0].topics[2]), DEPLOYER);
        assertEq(_toAddress(accessControlsAllLogs[0].topics[3]), DEPLOYER);

        // RoleGranted(ALLOCATOR_ROLE, ALLOCATOR, DEPLOYER) from TransferRoles: ALLOCATOR_ROLE grant.
        assertEq(accessControlsAllLogs[1].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[1].topics[1],             ALLOCATOR_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[1].topics[2]), ALLOCATOR);
        assertEq(_toAddress(accessControlsAllLogs[1].topics[3]), DEPLOYER);

        // RoleGranted(ALLOCATOR_ROLE, BACKSTOP_ALLOCATOR, DEPLOYER) from TransferRoles: ALLOCATOR_ROLE grant.
        assertEq(accessControlsAllLogs[2].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[2].topics[1],             ALLOCATOR_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[2].topics[2]), BACKSTOP_ALLOCATOR);
        assertEq(_toAddress(accessControlsAllLogs[2].topics[3]), DEPLOYER);

        // RoleGranted(ALLOCATOR_ADMIN_ROLE, ALLOCATOR_ADMIN, DEPLOYER) from TransferRoles: ALLOCATOR_ADMIN_ROLE grant.
        assertEq(accessControlsAllLogs[3].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[3].topics[1],             ALLOCATOR_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[3].topics[2]), ALLOCATOR_ADMIN);
        assertEq(_toAddress(accessControlsAllLogs[3].topics[3]), DEPLOYER);

        // RoleAdminChanged(ALLOCATOR_ROLE, DEFAULT_ADMIN_ROLE, ALLOCATOR_ADMIN_ROLE) from TransferRoles: setRoleAdmin.
        // From AccessControls.setRoleAdmin.
        assertEq(accessControlsAllLogs[4].topics[0], IAccessControl.RoleAdminChanged.selector);
        assertEq(accessControlsAllLogs[4].topics[1], ALLOCATOR_ROLE);
        assertEq(accessControlsAllLogs[4].topics[2], DEFAULT_ADMIN_ROLE);
        assertEq(accessControlsAllLogs[4].topics[3], ALLOCATOR_ADMIN_ROLE);

        // RoleGranted(DEFAULT_ADMIN_ROLE, ADMIN, DEPLOYER) from TransferRoles: DEFAULT_ADMIN_ROLE grant.
        // Role transfers from deployer to admin.
        assertEq(accessControlsAllLogs[5].topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(accessControlsAllLogs[5].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[5].topics[2]), ADMIN);
        assertEq(_toAddress(accessControlsAllLogs[5].topics[3]), DEPLOYER);

        // RoleRevoked(DEFAULT_ADMIN_ROLE, DEPLOYER, DEPLOYER) from TransferRoles: DEFAULT_ADMIN_ROLE revoke.
        // Role revoked from deployer.
        assertEq(accessControlsAllLogs[6].topics[0],             IAccessControl.RoleRevoked.selector);
        assertEq(accessControlsAllLogs[6].topics[1],             DEFAULT_ADMIN_ROLE);
        assertEq(_toAddress(accessControlsAllLogs[6].topics[2]), DEPLOYER);
        assertEq(_toAddress(accessControlsAllLogs[6].topics[3]), DEPLOYER);

       /*******************************************************************************************/
       /*** Controller events                                                                   ***/
       /*******************************************************************************************/

        VmSafe.EthGetLogs[] memory controllerAllLogs = _getEvents(block.chainid, CONTROLLER, "");

        assertEq(controllerAllLogs.length, 55);

        // Initialized(1) from Controller constructor.
        _assertInitializedEvent(controllerAllLogs[0]);

        // IntegrationSet(integrationId, config) from ConfigureController: updateIntegrations.
        _assertIntegrationSetEvent(controllerAllLogs[1],  bytes32(abi.encodePacked("AAVE_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[2],  bytes32(abi.encodePacked("CCTP_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[3],  bytes32(abi.encodePacked("CENTRIFUGE_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[4],  bytes32(abi.encodePacked("CURVE_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[5],  bytes32(abi.encodePacked("DAIUSDS_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[6],  bytes32(abi.encodePacked("ERC4626_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[7],  bytes32(abi.encodePacked("ERC7540_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[8],  bytes32(abi.encodePacked("ETHENA_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[9],  bytes32(abi.encodePacked("FARM_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[10], bytes32(abi.encodePacked("LAYER_ZERO_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[11], bytes32(abi.encodePacked("MAPLE_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[12], bytes32(abi.encodePacked("MERKL_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[13], bytes32(abi.encodePacked("OTC_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[14], bytes32(abi.encodePacked("PENDLE_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[15], bytes32(abi.encodePacked("PSM_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[16], bytes32(abi.encodePacked("SPARK_VAULT_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[17], bytes32(abi.encodePacked("SUPERSTATE_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[18], bytes32(abi.encodePacked("TRANSFER_ASSET_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[19], bytes32(abi.encodePacked("UNISWAP_V3_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[20], bytes32(abi.encodePacked("UNISWAP_V4_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[21], bytes32(abi.encodePacked("USDS_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[22], bytes32(abi.encodePacked("WEETH_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[23], bytes32(abi.encodePacked("WRAP_PROXY_ETH_FACET")));
        _assertIntegrationSetEvent(controllerAllLogs[24], bytes32(abi.encodePacked("WSTETH_FACET")));

        // ERC4626MaxExchangeRateSet(token, maxExchangeRate) from ConfigureController: setMaxExchangeRate.
        _assertERC4626MaxExchangeRateSetEvent(controllerAllLogs[25], Ethereum.MORPHO_VAULT_USDC_BC);
        _assertERC4626MaxExchangeRateSetEvent(controllerAllLogs[26], Ethereum.MORPHO_VAULT_DAI_1);
        _assertERC4626MaxExchangeRateSetEvent(controllerAllLogs[27], Ethereum.MORPHO_VAULT_USDS);
        _assertERC4626MaxExchangeRateSetEvent(controllerAllLogs[28], Ethereum.MORPHO_VAULT_V2_USDT);
        _assertERC4626MaxExchangeRateSetEvent(controllerAllLogs[29], Ethereum.SUSDS);
        _assertERC4626MaxExchangeRateSetEvent(controllerAllLogs[30], Ethereum.FLUID_SUSDS);
        _assertERC4626MaxExchangeRateSetEvent(controllerAllLogs[31], Ethereum.SUSDE);
        _assertERC4626MaxExchangeRateSetEvent(controllerAllLogs[32], Ethereum.SYRUP_USDC);
        _assertERC4626MaxExchangeRateSetEvent(controllerAllLogs[33], Ethereum.SYRUP_USDT);
        _assertERC4626MaxExchangeRateSetEvent(controllerAllLogs[34], Ethereum.ARKIS_VAULT);

        // CurveMaxSlippageSet(pool, maxSlippage) from ConfigureController: setMaxSlippage.
        _assertCurveMaxSlippageSetEvent(controllerAllLogs[35], Ethereum.CURVE_SUSDSUSDT);
        _assertCurveMaxSlippageSetEvent(controllerAllLogs[36], Ethereum.CURVE_PYUSDUSDC);
        _assertCurveMaxSlippageSetEvent(controllerAllLogs[37], Ethereum.CURVE_USDCUSDT);
        _assertCurveMaxSlippageSetEvent(controllerAllLogs[38], Ethereum.CURVE_PYUSDUSDS);
        _assertCurveMaxSlippageSetEvent(controllerAllLogs[39], Ethereum.CURVE_WEETHWETHNG);

        // AaveMaxSlippageSet(aToken, maxSlippage) from ConfigureController: setMaxSlippage.
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[40], Ethereum.ATOKEN_CORE_USDC);
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[41], Ethereum.ATOKEN_CORE_USDE);
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[42], Ethereum.ATOKEN_CORE_USDS);
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[43], Ethereum.ATOKEN_CORE_USDT);
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[44], Ethereum.ATOKEN_PRIME_USDS);
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[45], SparkLend.DAI_SPTOKEN);
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[46], SparkLend.USDC_SPTOKEN);
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[47], SparkLend.USDS_SPTOKEN);
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[48], SparkLend.USDT_SPTOKEN);
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[49], SparkLend.PYUSD_SPTOKEN);
        _assertAaveMaxSlippageSetEvent(controllerAllLogs[50], SparkLend.WETH_SPTOKEN);

        // UniswapV4 Migration events.
        _assertUniswapV4MaxSlippageSetEvent(controllerAllLogs[51], PYUSD_USDS_POOL_ID);
        _assertUniswapV4TickLimitsSetEvent(controllerAllLogs[52],  PYUSD_USDS_POOL_ID);

        _assertUniswapV4MaxSlippageSetEvent(controllerAllLogs[53], USDT_USDS_POOL_ID);
        _assertUniswapV4TickLimitsSetEvent(controllerAllLogs[54],  USDT_USDS_POOL_ID);
    }

    /*******************************************************************************************/
    /*** Helper functions                                                                    ***/
    /*******************************************************************************************/

    function _assertIntegration(bytes32 integrationId) internal view{
        IEI.Config memory beaconConfig     = beacon.getConfig(integrationId);
        IEI.Config memory controllerConfig = controller.getConfig(integrationId);

        assertEq(controllerConfig.facet,        beaconConfig.facet);
        assertEq(controllerConfig.wires.length, beaconConfig.wires.length);

        for (uint256 i = 0; i < controllerConfig.wires.length; ++i) {
            assertEq(controllerConfig.wires[i].callSelector,     beaconConfig.wires[i].callSelector);
            assertEq(controllerConfig.wires[i].delegateSelector, beaconConfig.wires[i].delegateSelector);
        }
    }

    function _assertERC4626MaxExchangeRate(address token) internal view {
        uint256 oldMaxExchangeRate = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxExchangeRates(token);

        assertEq(controller.erc4626_getMaxExchangeRate(token), oldMaxExchangeRate);
    }

    function _assertCurveMaxSlippage(address pool) internal view {
        uint256 oldMaxSlippage = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxSlippages(pool);

        assertEq(controller.curve_getMaxSlippage(pool), oldMaxSlippage);
    }

    function _assertAaveMaxSlippage(address aToken) internal view {
        uint256 oldMaxSlippage = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxSlippages(aToken);

        assertEq(controller.aave_getMaxSlippage(aToken), oldMaxSlippage);
    }

    function _assertUniswapV4Migration(bytes32 poolId) internal view {
        uint256 oldMaxSlippage = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxSlippages(address(uint160(uint256(poolId))));

        assertEq(controller.uniswapV4_getMaxSlippage(poolId), oldMaxSlippage);

        (int24 oldTickLower, int24 oldTickUpper, uint24 oldMaxTickSpacing) = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).uniswapV4TickLimits(poolId);
        (int24 newTickLower, int24 newTickUpper, uint24 newMaxTickSpacing) = controller.uniswapV4_getTickLimits(poolId);

        assertEq(newTickLower,      oldTickLower);
        assertEq(newTickUpper,      oldTickUpper);
        assertEq(newMaxTickSpacing, oldMaxTickSpacing);
    }

    /*******************************************************************************************/
    /*** Event test helpers                                                                  ***/
    /*******************************************************************************************/

    function _assertInitializedEvent(VmSafe.EthGetLogs memory log) internal pure {
        assertEq(log.topics[0], Initializable.Initialized.selector);
        assertEq(log.data,      abi.encode(1));
    }

    function _assertIntegrationSetEvent(VmSafe.EthGetLogs memory log, bytes32 integrationId) internal view {
        IEI.Config memory controllerConfig = abi.decode(log.data, (IEI.Config));
        IEI.Config memory beaconConfig     = beacon.getConfig(integrationId);

        assertEq(log.topics[0], IEI.IntegrationSet.selector);
        assertEq(log.topics[1], integrationId);

        assertEq(controllerConfig.facet,        beaconConfig.facet);
        assertEq(controllerConfig.wires.length, beaconConfig.wires.length);

        for (uint256 i = 0; i < controllerConfig.wires.length; ++i) {
            assertEq(controllerConfig.wires[i].callSelector,     beaconConfig.wires[i].callSelector);
            assertEq(controllerConfig.wires[i].delegateSelector, beaconConfig.wires[i].delegateSelector);
        }
    }

    function _assertERC4626MaxExchangeRateSetEvent(VmSafe.EthGetLogs memory log, address token) internal view {
        uint256 oldMaxExchangeRate = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxExchangeRates(token);

        assertEq(log.topics[0],             IERC4626Facet.ERC4626MaxExchangeRateSet.selector);
        assertEq(_toAddress(log.topics[1]), token);
        assertEq(log.data,                  abi.encode(oldMaxExchangeRate));
    }

    function _assertCurveMaxSlippageSetEvent(VmSafe.EthGetLogs memory log, address pool) internal view {
        uint256 oldMaxSlippage = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxSlippages(pool);

        assertEq(log.topics[0],             ICurveFacet.CurveMaxSlippageSet.selector);
        assertEq(_toAddress(log.topics[1]), pool);
        assertEq(log.data,                  abi.encode(oldMaxSlippage));
    }

    function _assertAaveMaxSlippageSetEvent(VmSafe.EthGetLogs memory log, address aToken) internal view {
        uint256 oldMaxSlippage = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxSlippages(aToken);

        assertEq(log.topics[0],             IAaveFacet.AaveMaxSlippageSet.selector);
        assertEq(_toAddress(log.topics[1]), aToken);
        assertEq(log.data,                  abi.encode(oldMaxSlippage));
    }

    function _assertUniswapV4MaxSlippageSetEvent(VmSafe.EthGetLogs memory log, bytes32 poolId) internal view {
        uint256 oldMaxSlippage = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).maxSlippages(address(uint160(uint256(poolId))));

        assertEq(log.topics[0], IUniswapV4Facet.UniswapV4MaxSlippageSet.selector);
        assertEq(log.topics[1], poolId);
        assertEq(log.data,      abi.encode(oldMaxSlippage));
    }
    
    function _assertUniswapV4TickLimitsSetEvent(VmSafe.EthGetLogs memory log, bytes32 poolId) internal view {
        (int24 tickLower, int24 tickUpper, uint24 maxTickSpacing) = IOldMainnetControllerLike(Ethereum.ALM_CONTROLLER).uniswapV4TickLimits(poolId);

        assertEq(log.topics[0], IUniswapV4Facet.UniswapV4TickLimitsSet.selector);
        assertEq(log.topics[1], poolId);
        assertEq(log.data,      abi.encode(tickLower, tickUpper, maxTickSpacing));
    }

}
