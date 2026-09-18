// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { stdJson } from "../../../lib/forge-std/src/StdJson.sol";
import { VmSafe }  from "../../../lib/forge-std/src/Vm.sol";

import { IEnumerableIntegrations as IEI } from "../../../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";

import { Ethereum } from "../../../lib/spark-address-registry/src/Ethereum.sol";

import { CCTPFacetWiring } from "../../../src/CCTPFacetWiring.sol";

import { IBeacon } from "../../PostDeployTestBase.t.sol";

import { ArbitrumParallelTestBase } from "./ArbitrumParallelTestBase.t.sol";

/**
 * @notice End state of the Spark Arbitrum parallel controller on chain, after BOTH scripts have
 *         run. Reads deployments/arbitrum-production.json.
 *
 *         Every test except the wiring diff skips while `controller` in that file is the zero
 *         address, so this file is safe in CI before the deployment happens and becomes the
 *         acceptance test once the addresses are filled in.
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
        backstopRelayer    = json.readAddress(".backstopRelayer");
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
    /*** Wiring: runs before and after deployment                                               ***/
    /**********************************************************************************************/

    /// @dev The wiring this repo deploys on Arbitrum must be identical, wire for wire, to the
    ///      CCTP_FACET integration Sky already runs on the Spark Ethereum Beacon.
    function test_cctpWiringMatchesEthereumSparkBeacon() external {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

        IEI.Config memory ethereumConfig = IBeacon(Ethereum.SPARK_BEACON).getConfig(CCTPFacetWiring.INTEGRATION_ID);

        _assertWiresEqual(ethereumConfig.wires, CCTPFacetWiring.wires());
    }

    /**********************************************************************************************/
    /*** State                                                                                  ***/
    /**********************************************************************************************/

    function test_beaconState()            external onlyDeployed { _assertBeaconState(); }
    function test_accessControlsState()    external onlyDeployed { _assertAccessControlsState(); }
    function test_almProxyState()          external onlyDeployed { _assertParallelALMProxyState(); }
    function test_rateLimitsState()        external onlyDeployed { _assertParallelRateLimitsState(); }
    function test_controllerState()        external onlyDeployed { _assertParallelControllerState(); }
    function test_administeredAgentState() external onlyDeployed { _assertParallelAdministeredAgentState(); }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    function test_beaconEvents() external onlyDeployed {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(beacon), "");

        assertEq(logs.length, 4);

        // Constructor: deployer is admin.
        _assertRoleGrantedEvent(logs[0], DEFAULT_ADMIN_ROLE, deployer, deployer);

        // Deploy script: CCTP_FACET wired.
        _assertIntegrationSetEvent(logs[1], CCTPFacetWiring.INTEGRATION_ID);

        // Configure script: hand over to admin, drop deployer.
        _assertRoleGrantedEvent(logs[2], DEFAULT_ADMIN_ROLE, admin,    deployer);
        _assertRoleRevokedEvent(logs[3], DEFAULT_ADMIN_ROLE, deployer, deployer);
    }

    function test_accessControlsEvents() external onlyDeployed {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(accessControls), "");

        assertEq(logs.length, 4);

        // Constructor via PAUFactory: deployer is admin.
        _assertRoleGrantedEvent(logs[0], DEFAULT_ADMIN_ROLE, deployer, address(pauFactory));

        // Configure script.
        _assertRoleGrantedEvent(logs[1], ALLOCATOR_ROLE,     address(administeredAgent), deployer);
        _assertRoleGrantedEvent(logs[2], DEFAULT_ADMIN_ROLE, admin,                      deployer);
        _assertRoleRevokedEvent(logs[3], DEFAULT_ADMIN_ROLE, deployer,                   deployer);
    }

    function test_rateLimitsEvents() external onlyDeployed {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(rateLimits), "");

        assertEq(logs.length, 4); // No RateLimitDataSet: rate limits are set by the spell.

        // Constructor via PAUFactory: deployer is admin.
        _assertRoleGrantedEvent(logs[0], DEFAULT_ADMIN_ROLE, deployer, address(pauFactory));

        // Configure script.
        _assertRoleGrantedEvent(logs[1], CONTROLLER_ROLE,    address(controller), deployer);
        _assertRoleGrantedEvent(logs[2], DEFAULT_ADMIN_ROLE, admin,               deployer);
        _assertRoleRevokedEvent(logs[3], DEFAULT_ADMIN_ROLE, deployer,            deployer);
    }

    function test_controllerEvents() external onlyDeployed {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(controller), "");

        assertEq(logs.length, 3);

        _assertInitializedEvent(logs[0]);
        _assertIntegrationSetEvent(logs[1], CCTPFacetWiring.INTEGRATION_ID);
        _assertCCTPDomainParametersSetEvent(logs[2], ethereumDomainId, ethereumAlmProxy, 0, 0);
    }

    function test_administeredAgentEvents() external onlyDeployed {
        VmSafe.EthGetLogs[] memory logs = _getEvents(block.chainid, address(administeredAgent), "");

        assertEq(logs.length, 7);

        // Constructor via AdministeredAgentFactory: deployer is admin.
        _assertAdminAddedEvent(logs[0], deployer, address(agentFactory));

        // Configure script.
        _assertActorAddedEvent(logs[1],   relayer,         deployer);
        _assertActorAddedEvent(logs[2],   backstopRelayer, deployer);
        _assertGrantorAddedEvent(logs[3], grantor,         deployer);
        _assertRevokerAddedEvent(logs[4], freezer,         deployer);
        _assertAdminAddedEvent(logs[5],   admin,           deployer);
        _assertAdminRemovedEvent(logs[6], deployer,        deployer);
    }

}
