// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test }   from "../lib/forge-std/src/Test.sol";
import { VmSafe } from "../lib/forge-std/src/Vm.sol";

import { IAccessControl }                            from "../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IAccessControls }                           from "../lib/diamond-pau/src/interfaces/IAccessControls.sol";
import { IALMProxy }                                 from "../lib/diamond-pau/src/interfaces/IALMProxy.sol";
import { IPAUFactory }                               from "../lib/diamond-pau/src/interfaces/IPAUFactory.sol";
import { IBeacon }                                   from "../lib/diamond-pau/src/interfaces/IBeacon.sol";
import { ICCTPFacet }                                from "../lib/diamond-pau/src/facets/cctp/ICCTPFacet.sol";
import { Initializable }                             from "../lib/diamond-pau/lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IEnumerableIntegrations as IEI }            from "../lib/diamond-pau/src/interfaces/IEnumerableIntegrations.sol";
import { IMainnetControllerFull as IControllerFull } from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";
import { IRateLimits }                               from "../lib/diamond-pau/src/interfaces/IRateLimits.sol";

import { IERC4626Facet } from "../lib/diamond-pau/src/facets/erc4626/IERC4626Facet.sol";

import { IAdministeredAgent }        from "../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";
import { IAdministeredAgentFactory } from "../lib/pau-administered-agent/src/interfaces/IAdministeredAgentFactory.sol";

interface IDefaultPAUAssemblerLike {

    function pauFactory() external view returns (address);

    function administeredAgentFactory() external view returns (address);

}

abstract contract PostDeployTestBase is Test {

    // A log stripped down to what the event assertions read, so that logs fetched from Etherscan
    // and logs recorded on a fork can be asserted by the same helpers.
    struct RawLog {
        address   emitter;
        bytes32[] topics;
        bytes     data;
    }

    struct Addresses {
        address agentFactory;
        address assembler;
        address beacon;
        address pauFactory;
        address accessControls;
        address administeredAgent;
        address almProxy;
        address controller;
        address rateLimits;
        address admin;
        address deployer;
        address relayer;
        address freezer;
    }

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant ALLOCATOR_ROLE     = keccak256("ALLOCATOR_ROLE");
    bytes32 internal constant CONTROLLER_ROLE    = keccak256("CONTROLLER");

    IDefaultPAUAssemblerLike  internal assembler;
    IAdministeredAgentFactory internal agentFactory;
    IBeacon                   internal beacon;
    IPAUFactory               internal pauFactory;

    IAccessControls    internal accessControls;
    IAdministeredAgent internal administeredAgent;
    IALMProxy          internal almProxy;
    IControllerFull    internal controller;
    IRateLimits        internal rateLimits;

    address internal admin;
    address internal deployer;
    address internal relayer;
    address internal freezer;

    // Copy of the logs recorded while a fork deployment ran, see `_storeRecordedLogs`.
    RawLog[] internal recordedLogs;

    function setUp() public virtual {
        _setUpXLayerAndRobinhoodForks();
    }

    /**********************************************************************************************/
    /*** Seams implemented by the concrete test contracts                                       ***/
    /**********************************************************************************************/

    // Sets up the deployment under test (addresses and expected values) on the selected fork.
    function _setUpDeployment() internal virtual;

    // Returns every log emitted by `emitter` since the deployment started, in emission order.
    function _logsFor(address emitter) internal virtual returns (RawLog[] memory logs);

    /**********************************************************************************************/
    /*** Set up helpers                                                                         ***/
    /**********************************************************************************************/

    function _setUpAddresses(Addresses memory addresses) internal {
        agentFactory = IAdministeredAgentFactory(addresses.agentFactory);
        assembler    = IDefaultPAUAssemblerLike(addresses.assembler);
        beacon       = IBeacon(addresses.beacon);
        pauFactory   = IPAUFactory(addresses.pauFactory);

        accessControls    = IAccessControls(addresses.accessControls);
        administeredAgent = IAdministeredAgent(addresses.administeredAgent);
        almProxy          = IALMProxy(addresses.almProxy);
        controller        = IControllerFull(addresses.controller);
        rateLimits        = IRateLimits(addresses.rateLimits);

        admin    = addresses.admin;
        deployer = addresses.deployer;
        relayer  = addresses.relayer;
        freezer  = addresses.freezer;
    }

    function _setUpXLayerAndRobinhoodForks() internal {
        setChain("xlayer", ChainData({
            name    : "XLayer",
            rpcUrl  : vm.envOr("XLAYER_RPC_URL", string("https://rpc.xlayer.tech")),
            chainId : 196
        }));

        setChain("robinhood_chain", ChainData({
            name    : "Robinhood Chain",
            rpcUrl  : vm.envOr("RH_RPC_URL", string("")),
            chainId : 4663
        }));
    }

    /**********************************************************************************************/
    /*** State Assertions                                                                       ***/
    /**********************************************************************************************/

    function _assertAdministeredAgentState() internal view {
        assertEq(administeredAgent.adminCount(),   1);
        assertEq(administeredAgent.actorCount(),   1);
        assertEq(administeredAgent.grantorCount(), 0);
        assertEq(administeredAgent.revokerCount(), 1);

        assertEq(administeredAgent.getAdmin(0),   admin);
        assertEq(administeredAgent.getActor(0),   relayer);
        assertEq(administeredAgent.getRevoker(0), freezer);

        assertEq(administeredAgent.getIsAdmin(deployer),              false);
        assertEq(administeredAgent.getIsAdmin(address(assembler)),    false);
        assertEq(administeredAgent.getIsAdmin(address(agentFactory)), false);
    }

    function _assertAccessControlsState() internal view {
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, admin),     true);
        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE, address(administeredAgent)), true);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ROLE),                  1);

        // Neither the deployer nor the deploy infrastructure retains any role.

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     deployer), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, deployer), false);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     address(assembler)), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, address(assembler)), false);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,     address(pauFactory)), false);
        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, address(pauFactory)), false);
    }

    function _assertALMProxyState() internal view {
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),               true);
        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    address(controller)), true);

        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    deployer), false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, deployer), false);

        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    address(assembler)), false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, address(assembler)), false);

        assertEq(almProxy.hasRole(CONTROLLER_ROLE,    address(pauFactory)), false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, address(pauFactory)), false);
    }

    function _assertRateLimitsInitializationState() internal view {
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin),               true);
        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    address(controller)), true);

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    deployer), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, deployer), false);

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    address(assembler)), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, address(assembler)), false);

        assertEq(rateLimits.hasRole(CONTROLLER_ROLE,    address(pauFactory)), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, address(pauFactory)), false);
    }

    function _assertControllerInitializationState() internal view {
        assertEq(controller.accessControls(), address(accessControls));
        assertEq(controller.beacon(),         address(beacon));
        assertEq(controller.proxy(),          address(almProxy));
        assertEq(controller.rateLimits(),     address(rateLimits));
    }

    /**********************************************************************************************/
    /*** Event Assertions                                                                       ***/
    /**********************************************************************************************/

    function _assertAccessControlsEvents() internal {
        RawLog[] memory logs = _logsFor(address(accessControls));

        assertEq(logs.length, 6);

        // Grant assembler DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[0],
            role    : DEFAULT_ADMIN_ROLE,
            account : address(assembler),
            sender  : address(pauFactory)
        });

        // Grant deployer DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[1],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : address(assembler)
        });

        // Grant administeredAgent ALLOCATOR_ROLE
        _assertRoleGrantedEvent({
            log     : logs[2],
            role    : ALLOCATOR_ROLE,
            account : address(administeredAgent),
            sender  : address(assembler)
        });

        // Revoke assembler DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[3],
            role    : DEFAULT_ADMIN_ROLE,
            account : address(assembler),
            sender  : address(assembler)
        });

        // Grant admin DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[4],
            role    : DEFAULT_ADMIN_ROLE,
            account : admin,
            sender  : deployer
        });

        // Revoke deployer DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[5],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : deployer
        });
    }

    function _assertALMProxyEvents() internal {
        RawLog[] memory logs = _logsFor(address(almProxy));

        assertEq(logs.length, 6);

        // Grant assembler DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[0],
            role    : DEFAULT_ADMIN_ROLE,
            account : address(assembler),
            sender  : address(pauFactory)
        });

        // Grant deployer DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[1],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : address(assembler)
        });

        // Grant controller CONTROLLER_ROLE
        _assertRoleGrantedEvent({
            log     : logs[2],
            role    : CONTROLLER_ROLE,
            account : address(controller),
            sender  : address(assembler)
        });

        // Revoke assembler DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[3],
            role    : DEFAULT_ADMIN_ROLE,
            account : address(assembler),
            sender  : address(assembler)
        });

        // Grant admin DEFAULT_ADMIN_ROLE
        _assertRoleGrantedEvent({
            log     : logs[4],
            role    : DEFAULT_ADMIN_ROLE,
            account : admin,
            sender  : deployer
        });

        // Revoke deployer DEFAULT_ADMIN_ROLE
        _assertRoleRevokedEvent({
            log     : logs[5],
            role    : DEFAULT_ADMIN_ROLE,
            account : deployer,
            sender  : deployer
        });
    }

    function _assertAdministeredAgentEvents() internal {
        RawLog[] memory logs = _logsFor(address(administeredAgent));

        assertEq(logs.length, 7);

        // Add assembler as admin
        _assertAdminAddedEvent({
            log     : logs[0],
            account : address(assembler),
            caller  : address(agentFactory)
        });

        // Add deployer as admin
        _assertAdminAddedEvent({
            log     : logs[1],
            account : deployer,
            caller  : address(assembler)
        });

        // Add relayer as actor
        _assertActorAddedEvent({
            log     : logs[2],
            account : relayer,
            caller  : address(assembler)
        });

        // Add freezer as revoker
        _assertRevokerAddedEvent({
            log     : logs[3],
            account : freezer,
            caller  : address(assembler)
        });

        // Remove assembler as admin
        _assertAdminRemovedEvent({
            log     : logs[4],
            account : address(assembler),
            caller  : address(assembler)
        });

        // Add admin as admin
        _assertAdminAddedEvent({
            log     : logs[5],
            account : admin,
            caller  : deployer
        });

        // Remove deployer as admin
        _assertAdminRemovedEvent({
            log     : logs[6],
            account : deployer,
            caller  : deployer
        });
    }

    /**********************************************************************************************/
    /*** Get events helpers                                                                     ***/
    /**********************************************************************************************/

    // Etherscan source: the logs of `target` on the real chain.

    function _getEvents(uint256 chainId, address target, bytes32 topic0)
        internal
        returns (RawLog[] memory logs)
    {
        return _getEvents(chainId, target, topic0, 0);
    }

    function _getEvents(uint256 chainId, address target, bytes32 topic0, uint256 retryCount)
        internal
        returns (RawLog[] memory logs)
    {
        string memory apiKey = vm.envString("ETHERSCAN_API_KEY");

        require(retryCount < 4, "Etherscan API returned non-success status");

        string memory url = string(
            abi.encodePacked(
                "https://api.etherscan.io/v2/api?",
                "chainid=",
                vm.toString(chainId),
                "&module=logs&action=getLogs",
                "&fromBlock=0",
                "&toBlock=latest",
                "&address=",
                vm.toString(target),
                "&page=1",
                "&offset=1000",
                "&apikey=",
                apiKey
            )
        );

        if (topic0 != 0) {
            url = string(abi.encodePacked(url, "&topic0=", vm.toString(topic0)));
        }

        string[] memory inputs = new string[](8);
        inputs[0] = "curl";
        inputs[1] = "-s";
        inputs[2] = "--request";
        inputs[3] = "GET";
        inputs[4] = "--url";
        inputs[5] = url;
        inputs[6] = "--header";
        inputs[7] = "accept: application/json";

        string memory response;

        for (uint256 attempt; attempt < 10; attempt++) {
            response = string(vm.ffi(inputs));

            if (_isEqual(vm.parseJsonString(response, string(abi.encodePacked(".message"))), "NOTOK")) {
                vm.sleep(1000);  // Prevent rate limiting from Etherscan (5 calls/second)
                continue;
            }

            break;
        }

        uint256 i = 0;
        for(; i < 1000; i++) {
            try vm.parseJsonAddress(response, string(abi.encodePacked(".result[", vm.toString(i), "].address"))) {
            } catch {
                logs = new RawLog[](i);
                break;
            }
        }

        for(uint256 j; j < i; ++j) {
            logs[j] = RawLog({
                emitter: vm.parseJsonAddress(response,      string(abi.encodePacked(".result[", vm.toString(j), "].address"))),
                topics:  vm.parseJsonBytes32Array(response, string(abi.encodePacked(".result[", vm.toString(j), "].topics"))),
                data:    vm.parseJsonBytes(response,        string(abi.encodePacked(".result[", vm.toString(j), "].data")))
            });
        }
    }

    // Recorded source: the logs recorded with `vm.recordLogs()` while the scripts ran on a fork.

    // `vm.getRecordedLogs()` drains the buffer, so it is read once and kept in storage; the tests
    // then filter the stored copy per emitter.
    function _storeRecordedLogs() internal {
        VmSafe.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i; i < logs.length; ++i) {
            recordedLogs.push(RawLog({
                emitter: logs[i].emitter,
                topics:  logs[i].topics,
                data:    logs[i].data
            }));
        }
    }

    function _recordedLogsFor(address emitter) internal view returns (RawLog[] memory logs) {
        uint256 count;

        for (uint256 i; i < recordedLogs.length; ++i) {
            if (recordedLogs[i].emitter == emitter) count++;
        }

        logs = new RawLog[](count);

        uint256 j;

        for (uint256 i; i < recordedLogs.length; ++i) {
            if (recordedLogs[i].emitter == emitter) logs[j++] = recordedLogs[i];
        }
    }

    function _isEqual(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function _toAddress(bytes32 b) internal pure returns (address) {
        return address(uint160(uint256(b)));
    }

    function _toBool(bytes32 b) internal pure returns (bool) {
        require(uint256(b) <= 1, "PostDeployTestBase/to-bool-failed");

        return uint256(b) == uint256(1);
    }

    /**********************************************************************************************/
    /*** State test helpers                                                                     ***/
    /**********************************************************************************************/

    function _assertIntegration(bytes32 integrationId) internal view {
        IEI.Config memory beaconConfig     = beacon.getConfig(integrationId);
        IEI.Config memory controllerConfig = controller.getConfig(integrationId);

        assertEq(controllerConfig.facet,        beaconConfig.facet);
        assertEq(controllerConfig.wires.length, beaconConfig.wires.length);

        for (uint256 i = 0; i < controllerConfig.wires.length; ++i) {
            assertEq(controllerConfig.wires[i].callSelector,     beaconConfig.wires[i].callSelector);
            assertEq(controllerConfig.wires[i].delegateSelector, beaconConfig.wires[i].delegateSelector);
        }
    }

    function _assertRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) internal view {
        IRateLimits.RateLimitData memory data = rateLimits.getRateLimitData(key);

        assertEq(data.maxAmount, maxAmount);
        assertEq(data.slope,     slope);
    }

    /**********************************************************************************************/
    /*** Event test helpers                                                                     ***/
    /**********************************************************************************************/

    function _assertInitializedEvent(RawLog memory log) internal pure {
        assertEq(log.topics[0], Initializable.Initialized.selector);
        assertEq(log.data,      abi.encode(1));
    }

    function _assertIntegrationSetEvent(RawLog memory log, bytes32 integrationId) internal view {
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

    function _assertRateLimitDataSetEvent(
        RawLog  memory log,
        bytes32        key,
        uint256        maxAmount,
        uint256        slope
    ) internal pure {
        (
            uint256 loggedMaxAmount,
            uint256 loggedSlope,
            uint256 loggedLastAmount,
        ) = abi.decode(log.data, (uint256, uint256, uint256, uint256));

        assertEq(log.topics[0], IRateLimits.RateLimitDataSet.selector);
        assertEq(log.topics[1], key);

        assertEq(loggedMaxAmount,  maxAmount);
        assertEq(loggedSlope,      slope);
        assertEq(loggedLastAmount, maxAmount);
    }

    function _assertRoleGrantedEvent(
        RawLog  memory log,
        bytes32        role,
        address        account,
        address        sender
    ) internal pure {
        assertEq(log.topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(log.topics[1],             role);
        assertEq(_toAddress(log.topics[2]), account);
        assertEq(_toAddress(log.topics[3]), sender);
    }

    function _assertRoleRevokedEvent(
        RawLog  memory log,
        bytes32        role,
        address        account,
        address        sender
    ) internal pure {
        assertEq(log.topics[0],             IAccessControl.RoleRevoked.selector);
        assertEq(log.topics[1],             role);
        assertEq(_toAddress(log.topics[2]), account);
        assertEq(_toAddress(log.topics[3]), sender);
    }

    function _assertAdminAddedEvent(
        RawLog  memory log,
        address        account,
        address        caller
    ) internal pure {
        assertEq(log.topics[0],             IAdministeredAgent.AdminAdded.selector);
        assertEq(_toAddress(log.topics[1]), account);
        assertEq(_toAddress(log.topics[2]), caller);
    }

    function _assertAdminRemovedEvent(
        RawLog  memory log,
        address        account,
        address        caller
    ) internal pure {
        assertEq(log.topics[0],             IAdministeredAgent.AdminRemoved.selector);
        assertEq(_toAddress(log.topics[1]), account);
        assertEq(_toAddress(log.topics[2]), caller);
    }

    function _assertActorAddedEvent(
        RawLog  memory log,
        address        account,
        address        caller
    ) internal pure {
        assertEq(log.topics[0],             IAdministeredAgent.ActorAdded.selector);
        assertEq(_toAddress(log.topics[1]), account);
        assertEq(_toAddress(log.topics[2]), caller);
    }

    function _assertActorRemovedEvent(
        RawLog  memory log,
        address        account,
        address        caller
    ) internal pure {
        assertEq(log.topics[0],             IAdministeredAgent.ActorRemoved.selector);
        assertEq(_toAddress(log.topics[1]), account);
        assertEq(_toAddress(log.topics[2]), caller);
    }

    function _assertGrantorAddedEvent(
        RawLog  memory log,
        address        account,
        address        caller
    ) internal pure {
        assertEq(log.topics[0],             IAdministeredAgent.GrantorAdded.selector);
        assertEq(_toAddress(log.topics[1]), account);
        assertEq(_toAddress(log.topics[2]), caller);
    }

    function _assertGrantorRemovedEvent(
        RawLog  memory log,
        address        account,
        address        caller
    ) internal pure {
        assertEq(log.topics[0],             IAdministeredAgent.GrantorRemoved.selector);
        assertEq(_toAddress(log.topics[1]), account);
        assertEq(_toAddress(log.topics[2]), caller);
    }

    function _assertRevokerAddedEvent(
        RawLog  memory log,
        address        account,
        address        caller
    ) internal pure {
        assertEq(log.topics[0],             IAdministeredAgent.RevokerAdded.selector);
        assertEq(_toAddress(log.topics[1]), account);
        assertEq(_toAddress(log.topics[2]), caller);
    }

    function _assertRevokerRemovedEvent(
        RawLog  memory log,
        address        account,
        address        caller
    ) internal pure {
        assertEq(log.topics[0],             IAdministeredAgent.RevokerRemoved.selector);
        assertEq(_toAddress(log.topics[1]), account);
        assertEq(_toAddress(log.topics[2]), caller);
    }

    // Facet onboarding event helpers

    function _assertCCTPDomainParametersSetEvent(
        RawLog  memory log,
        uint32         destinationDomain,
        address        mintRecipient,
        uint32         minFeeCapRate,
        uint32         maxFeeCapRate
    ) internal pure {
        ( uint32 loggedMinFeeCapRate, uint32 loggedMaxFeeCapRate ) = abi.decode(log.data, (uint32, uint32));

        assertEq(log.topics[0],          ICCTPFacet.CCTPDomainParametersSet.selector);
        assertEq(uint256(log.topics[1]), uint256(destinationDomain));
        assertEq(log.topics[2],          bytes32(uint256(uint160(mintRecipient))));

        assertEq(loggedMinFeeCapRate, minFeeCapRate);
        assertEq(loggedMaxFeeCapRate, maxFeeCapRate);
    }

    function _assertERC4626MaxExchangeRateSetEvent(
        RawLog  memory log,
        address        token,
        uint256        maxExchangeRate
    ) internal pure {
        assertEq(log.topics[0],             IERC4626Facet.ERC4626MaxExchangeRateSet.selector);
        assertEq(_toAddress(log.topics[1]), token);

        assertEq(abi.decode(log.data, (uint256)), maxExchangeRate);
    }

}
