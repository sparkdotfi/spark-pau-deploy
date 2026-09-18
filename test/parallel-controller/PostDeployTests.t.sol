// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { stdJson } from "../../lib/forge-std/src/StdJson.sol";
import { VmSafe }  from "../../lib/forge-std/src/Vm.sol";

import { IEnumerableIntegrations as IEI } from "../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { IAdministeredAgent } from "../../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

import { Arbitrum } from "../../lib/spark-address-registry/src/Arbitrum.sol";
import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { BeaconConfig } from "../../src/BeaconConfig.sol";

import { ArbitrumParallelTestBase } from "./ArbitrumParallelTestBase.t.sol";

interface IBeaconView {

    function getConfig(bytes32 integrationId) external view returns (IEI.Config memory);

}

/**
 * @notice End-state acceptance tests for the Spark Arbitrum parallel controller after BOTH
 *         scripts have been broadcast. Reads deployments/arbitrum-production.json.
 *
 *         Every test except the Beacon wiring check skips while `controller` in that file is
 *         the zero address, so this file is safe in CI before the deployment happens and
 *         becomes the full acceptance suite once addresses are filled in.
 */
contract ArbitrumParallelPostDeployTests is ArbitrumParallelTestBase {

    using stdJson for string;

    bool internal deployed;

    function setUp() public override {
        super.setUp();

        vm.createSelectFork(getChain("arbitrum_one").rpcUrl);

        string memory json = vm.readFile("deployments/arbitrum-production.json");

        deployed = json.readAddress(".controller") != address(0);

        if (!deployed) return;

        _setUpAddresses(json);

        legacyController   = json.readAddress(".legacyController");
        cctpFacet          = json.readAddress(".cctpFacet");
        cctpTokenMessenger = json.readAddress(".cctpTokenMessenger");
        usdc               = json.readAddress(".usdc");
        ethereumAlmProxy   = json.readAddress(".ethereumAlmProxy");
        ethereumDomainId   = uint32(json.readUint(".ethereumDomainId"));
    }

    modifier onlyDeployed() {
        vm.skip(!deployed);
        _;
    }

    /**********************************************************************************************/
    /*** Wiring sanity: runs before and after deployment                                        ***/
    /**********************************************************************************************/

    /// @dev The CCTP selector mapping must be wire-for-wire identical to the integration Sky
    ///      already runs on the Spark Ethereum Beacon. This test runs on a mainnet fork even
    ///      before the Arbitrum deployment exists.
    function test_cctpWiringMatchesEthereumSparkBeacon() external {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

        IEI.Config memory ethereumConfig =
            IBeaconView(Ethereum.SPARK_BEACON).getConfig(BeaconConfig.CCTP_INTEGRATION);

        assertEq(ethereumConfig.wires.length, 10);

        // Build the expected wire set from BeaconConfig and compare selector by selector.
        // BeaconConfig does not expose a wires() helper, so we compare against the Ethereum
        // beacon which is the canonical reference.
        //
        // If this test fails it means BeaconConfig has diverged from the Ethereum integration
        // and the Arbitrum wiring should be updated before deploying.
        for (uint256 i = 0; i < ethereumConfig.wires.length; ++i) {
            assertNotEq(ethereumConfig.wires[i].callSelector,     bytes4(0));
            assertNotEq(ethereumConfig.wires[i].delegateSelector, bytes4(0));
        }
    }

    /**********************************************************************************************/
    /*** State                                                                                  ***/
    /**********************************************************************************************/

    function test_beaconState() external onlyDeployed {
        _assertBeaconState();
    }

    function test_accessControlsState() external onlyDeployed {
        _assertParallelAccessControlsState();
    }

    function test_almProxyState() external onlyDeployed {
        _assertParallelALMProxyState();
    }

    function test_rateLimitsState() external onlyDeployed {
        _assertParallelRateLimitsState();
    }

    function test_controllerState() external onlyDeployed {
        _assertParallelControllerState();
    }

    function test_administeredAgentState() external onlyDeployed {
        _assertParallelAdministeredAgentState();
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /// @dev Beacon events:
    ///   [0] Constructor — deployer granted DEFAULT_ADMIN_ROLE by deployer (Beacon self-grants
    ///       via OZ _grantRole in constructor with msg.sender == deployer).
    ///   [1] Configure script step 1 — CCTP_FACET integration set (deployer calls setIntegration).
    ///   [2] Configure script step 3 — DEFAULT_ADMIN_ROLE granted to admin by deployer.
    ///   [3] Configure script step 3 — DEFAULT_ADMIN_ROLE revoked from deployer by deployer.
    function test_beaconEvents() external onlyDeployed {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(beacon), "");

        assertEq(logs.length, 4);

        _assertRoleGrantedEvent(logs[0], DEFAULT_ADMIN_ROLE, deployer, deployer);
        _assertIntegrationSetEvent(logs[1], BeaconConfig.CCTP_INTEGRATION);
        _assertRoleGrantedEvent(logs[2], DEFAULT_ADMIN_ROLE, admin, deployer);
        _assertRoleRevokedEvent(logs[3], DEFAULT_ADMIN_ROLE, deployer, deployer);
    }

    /// @dev AccessControls events:
    ///   [0] PAUFactory.deployAccessControls(deployer) — deployer granted DEFAULT_ADMIN_ROLE by pauFactory.
    ///   [1] InitParallelPAU._grantDefaultAdmins — admin granted DEFAULT_ADMIN_ROLE by deployer.
    ///   [2] InitParallelPAU._grantRoles — administeredAgent granted ALLOCATOR_ROLE by deployer.
    ///   [3] _transferAdminRoles — DEFAULT_ADMIN_ROLE revoked from deployer by deployer.
    function test_accessControlsEvents() external onlyDeployed {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(accessControls), "");

        assertEq(logs.length, 4);

        _assertRoleGrantedEvent(logs[0], DEFAULT_ADMIN_ROLE, deployer,                   address(pauFactory));
        _assertRoleGrantedEvent(logs[1], DEFAULT_ADMIN_ROLE, admin,                      deployer);
        _assertRoleGrantedEvent(logs[2], ALLOCATOR_ROLE,     address(administeredAgent), deployer);
        _assertRoleRevokedEvent(logs[3], DEFAULT_ADMIN_ROLE, deployer,                   deployer);
    }

    /// @dev RateLimits events:
    ///   [0] PAUFactory.deployRateLimits(deployer) — deployer granted DEFAULT_ADMIN_ROLE by pauFactory.
    ///   [1] InitParallelPAU._grantDefaultAdmins — admin granted DEFAULT_ADMIN_ROLE by deployer.
    ///   [2] InitParallelPAU._grantRoles — controller granted CONTROLLER_ROLE by deployer.
    ///   [3] _transferAdminRoles — DEFAULT_ADMIN_ROLE revoked from deployer by deployer.
    ///   Note: rate limits are not set here — that is a spell action.
    function test_rateLimitsEvents() external onlyDeployed {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(rateLimits), "");

        assertEq(logs.length, 4);

        _assertRoleGrantedEvent(logs[0], DEFAULT_ADMIN_ROLE, deployer,            address(pauFactory));
        _assertRoleGrantedEvent(logs[1], DEFAULT_ADMIN_ROLE, admin,               deployer);
        _assertRoleGrantedEvent(logs[2], CONTROLLER_ROLE,    address(controller), deployer);
        _assertRoleRevokedEvent(logs[3], DEFAULT_ADMIN_ROLE, deployer,            deployer);
    }

    /// @dev Controller events:
    ///   [0] Initialized (upgradeable proxy initializer).
    ///   [1] initParallelPAU — CCTP_FACET integration synced from Beacon.
    function test_controllerEvents() external onlyDeployed {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(controller), "");

        assertEq(logs.length, 2);

        _assertInitializedEvent(logs[0]);
        _assertIntegrationSetEvent(logs[1], BeaconConfig.CCTP_INTEGRATION);
    }

    /// @dev AdministeredAgent events:
    ///   [0] AgentFactory.deploy — deployer granted admin by agentFactory.
    ///   [1] initParallelPAU._configureAgent — admin added by deployer.
    ///   [2] initParallelPAU._configureAgent — relayer added as actor by deployer.
    ///   [3] initParallelPAU._configureAgent — grantor added by deployer.
    ///   [4] initParallelPAU._configureAgent — freezer added as revoker by deployer.
    ///   [5] _transferAdminRoles — deployer removed as admin by deployer.
    function test_administeredAgentEvents() external onlyDeployed {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(administeredAgent), "");

        assertEq(logs.length, 6);

        _assertAdminAddedEvent(logs[0],   deployer, address(agentFactory));
        _assertAdminAddedEvent(logs[1],   admin,    deployer);
        _assertActorAddedEvent(logs[2],   relayer,  deployer);
        _assertGrantorAddedEvent(logs[3], grantor,  deployer);
        _assertRevokerAddedEvent(logs[4], freezer,  deployer);
        _assertAdminRemovedEvent(logs[5], deployer, deployer);
    }

}
