// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test }   from "../lib/forge-std/src/Test.sol";
import { VmSafe } from "../lib/forge-std/src/Vm.sol";

import { IAccessControl }                            from "../lib/diamond-pau/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IAccessControls }                           from "../lib/diamond-pau/src/interfaces/IAccessControls.sol";
import { IALMProxy }                                 from "../lib/diamond-pau/src/interfaces/IALMProxy.sol";
import { IBeacon }                                   from "../lib/diamond-pau/src/interfaces/IBeacon.sol";
import { Initializable }                             from "../lib/diamond-pau/lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IMainnetControllerFull as IControllerFull } from "../lib/diamond-pau/test/interfaces/IMainnetControllerFull.sol";
import { IRateLimits }                               from "../lib/diamond-pau/src/interfaces/IRateLimits.sol";

import { Ethereum as SkyEthereum }   from "../lib/sky-pau-registry/src/Ethereum.sol";
import { Ethereum as SparkEthereum } from "../lib/spark-address-registry/src/Ethereum.sol";

import { IAdministeredAgent } from "../lib/pau-administered-agent/src/interfaces/IAdministeredAgent.sol";

abstract contract PostDeployTestBase is Test {

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant ALLOCATOR_ROLE     = keccak256("ALLOCATOR_ROLE");
    bytes32 internal constant CONTROLLER_ROLE    = keccak256("CONTROLLER");

    address internal constant ADMINISTERED_AGENT_FACTORY = SkyEthereum.ADMINISTERED_AGENT_FACTORY;
    address internal constant BEACON                     = SkyEthereum.BEACON;
    address internal constant PAU_FACTORY                = SkyEthereum.PAU_FACTORY;

    address internal constant ALLOCATOR          = SparkEthereum.ALM_RELAYER_MULTISIG;
    address internal constant BACKSTOP_ALLOCATOR = SparkEthereum.ALM_BACKSTOP_RELAYER_MULTISIG;
    address internal constant REVOKER            = SparkEthereum.ALM_FREEZER_MULTISIG;

    // The ALMProxy a parallel deployment attaches to, instead of deploying its own.
    address internal constant EXISTING_ALM_PROXY = SparkEthereum.ALM_PROXY;

    // Deployment specific addresses, assigned by _setDeploymentAddresses in the inheriting test.
    address internal ACCESS_CONTROLS;
    address internal ADMIN;
    address internal ADMINISTERED_AGENT;
    address internal ALM_PROXY;
    address internal CONTROLLER;
    address internal DEPLOYER;
    address internal RATE_LIMITS;

    IAccessControls    internal accessControls;
    IAdministeredAgent internal administeredAgent;
    IALMProxy          internal almProxy;
    IBeacon            internal beacon;
    IControllerFull    internal controller;
    IRateLimits        internal rateLimits;

    function setUp() public virtual {
        _setDeploymentAddresses();

        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        accessControls    = IAccessControls(ACCESS_CONTROLS);
        administeredAgent = IAdministeredAgent(ADMINISTERED_AGENT);
        almProxy          = IALMProxy(ALM_PROXY);
        beacon            = IBeacon(BEACON);
        controller        = IControllerFull(CONTROLLER);
        rateLimits        = IRateLimits(RATE_LIMITS);
    }

    /**********************************************************************************************/
    /*** Deployment specific hooks                                                              ***/
    /**********************************************************************************************/

    /// @dev Block to fork at, after the deployment scripts have been executed.
    function _getBlock() internal pure virtual returns (uint256);

    /// @dev True when the deployment brought up its own ALMProxy, false when it attached to the
    ///      existing one. Only the ALMProxy assertions differ between the two.
    function _isFullDeployment() internal pure virtual returns (bool);

    /// @dev Assigns every deployment specific address, pasted from the script output.
    function _setDeploymentAddresses() internal virtual;

    /**********************************************************************************************/
    /*** Get events helpers                                                                     ***/
    /**********************************************************************************************/

    function _getEvents(uint256 chainId, address target, bytes32 topic0)
        internal
        returns (VmSafe.EthGetLogs[] memory logs)
    {
        return _getEvents(chainId, target, topic0, 0);
    }

    function _getEvents(uint256 chainId, address target, bytes32 topic0, uint256 retryCount)
        internal
        returns (VmSafe.EthGetLogs[] memory logs)
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
                logs = new VmSafe.EthGetLogs[](i);
                break;
            }
        }

        for(uint256 j; j < i; ++j) {
            logs[j] = VmSafe.EthGetLogs({
                emitter:          vm.parseJsonAddress(response,      string(abi.encodePacked(".result[", vm.toString(j), "].address"))),
                topics:           vm.parseJsonBytes32Array(response, string(abi.encodePacked(".result[", vm.toString(j), "].topics"))),
                data:             vm.parseJsonBytes(response,        string(abi.encodePacked(".result[", vm.toString(j), "].data"))),
                blockNumber:      uint64(0),
                blockHash:        bytes32(0),
                transactionHash:  bytes32(0),
                transactionIndex: uint64(0),
                logIndex:         uint8(0),
                removed:          false
            });
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
    /*** Event test helpers                                                                     ***/
    /**********************************************************************************************/

    function _assertInitializedEvent(VmSafe.EthGetLogs memory log) internal pure {
        assertEq(log.topics[0], Initializable.Initialized.selector);
        assertEq(log.data,      abi.encode(1));
    }

    function _assertRoleGrantedEvent(
        VmSafe.EthGetLogs memory log,
        bytes32                  role,
        address                  account,
        address                  sender
    ) internal pure {
        assertEq(log.topics[0],             IAccessControl.RoleGranted.selector);
        assertEq(log.topics[1],             role);
        assertEq(_toAddress(log.topics[2]), account);
        assertEq(_toAddress(log.topics[3]), sender);
    }

    function _assertRoleRevokedEvent(
        VmSafe.EthGetLogs memory log,
        bytes32                  role,
        address                  account,
        address                  sender
    ) internal pure {
        assertEq(log.topics[0],             IAccessControl.RoleRevoked.selector);
        assertEq(log.topics[1],             role);
        assertEq(_toAddress(log.topics[2]), account);
        assertEq(_toAddress(log.topics[3]), sender);
    }

}
