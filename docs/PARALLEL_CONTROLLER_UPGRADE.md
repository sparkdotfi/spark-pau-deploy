# Parallel Controller Upgrade: Diamond PAU with CCTPFacet (Arbitrum)

This document describes the staged deployment of the Diamond PAU system on Arbitrum alongside the existing (legacy) ALM Controller. Both controllers custody the same `ALMProxy` but point at different `RateLimits` contracts. The new Diamond PAU Controller is wired exclusively to a `CCTPFacet`, enabling USDC bridging from the Arbitrum `ALMProxy` to the Spark Ethereum `ALMProxy` via Circle's TokenMessengerV2.

The intent of the staged approach is to bring the Diamond PAU architecture into production behind a narrow, well-understood integration — cross-chain USDC transfers — without migrating funds, without redeploying the existing custody contract, and without changing how the legacy controller currently operates.

The central property this document needs to make explicit for risk planning:

> The Diamond PAU Controller holds the `CONTROLLER` role on the `ALMProxy`, alongside the existing legacy ALM Controller, which confers unrestricted authority over the full `ALMProxy` balance. It is constrained **not** by the proxy, but by the set of call selectors wired into it and by the rate limits attached to those specific functions.

---

## 1. Target topology

`ALLOCATOR_ROLE` is held by the `AdministeredAgent` on `AccessControls`, not on the Controller itself. The Controller and its facets hold no role state of their own: every `onlyRole` check, for both `ALLOCATOR_ROLE` and `DEFAULT_ADMIN_ROLE`, is an external call into `AccessControls`. This is the structural difference from the legacy controller, which stores `RELAYER` and `FREEZER` internally.

The `Beacon` is the canonical registry of integration configs (facet address plus selector wiring) for all PAU controllers that share the same beacon. The Controller syncs its local dispatch table from the Beacon via `updateIntegrations`, and the Beacon is the only place where facet addresses are registered.

Arbitrum has no existing Diamond PAU infrastructure. The deployment therefore creates every component from scratch — a fresh `Beacon`, `CCTPFacet`, `PAUFactory`, `AdministeredAgentFactory`, and the full controller stack — before pointing the controller stack at the existing `ALMProxy`.

---

## 2. Scope of authority of the Diamond PAU Controller

This section covers the central risk consideration of the proposal.

### 2.1 The proxy confers unrestricted authority

`ALMProxy` is intentionally minimal. Its entire authorization surface is:

```solidity
function doCall(address target, bytes calldata data) external onlyRole(CONTROLLER) returns (bytes memory);
function doCallWithValue(address target, bytes calldata data, uint256 value) external payable onlyRole(CONTROLLER) returns (bytes memory);
function doDelegateCall(address target, bytes calldata data) external onlyRole(CONTROLLER) returns (bytes memory);
```

There is no per-target allowlist, no per-asset scoping, and no notion of a budget. Any holder of `CONTROLLER` can direct the proxy to call any address with any calldata, spend its ETH, and `delegatecall` into arbitrary code. `doDelegateCall` in particular means a `CONTROLLER` can modify the proxy's own storage, including its role mappings.

Consequently, **granting `CONTROLLER` to the Diamond PAU Controller is, at the proxy level, equivalent to granting full authority over every asset the `ALMProxy` holds.** This is the same trust level the legacy controller already has, and no narrower grant is available.

### 2.2 Containment is enforced by the Controller's dispatch table

The Diamond PAU `Controller` has no interactive functions of its own beyond admin integration management. Every operational call reaches it through the fallback:

```solidity
fallback() external payable {
    require(msg.data.length >= 4, InvalidCallDataLength(msg.data.length));
    Dispatch storage dispatch = _getControllerStorage().dispatches[msg.sig];
    address facet = dispatch.facet;
    require(facet != address(0), CallSelectorNotWired(msg.sig));
    ...facet.delegatecall(abi.encodePacked(dispatch.delegateSelector, msg.data[4:]));
}
```

If a selector is not present in `dispatches`, the call reverts with `CallSelectorNotWired`. There is no generic passthrough, no `execute(target, data)`, and no path for an allocator to reach `doCall` with arbitrary calldata. The Controller can only ever issue calls into the proxy that a wired facet constructs.

### 2.3 The single wired integration: CCTPFacet

The only integration registered on the Beacon and synced into the Controller is `CCTP_FACET`. It exposes ten selectors through the Controller:

| Selector (via Controller)                                                                          | Purpose                                  |
| -------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| `cctp_transfer`                                                                                    | Approve + burn USDC via TokenMessengerV2 |
| `cctp_setDomainParameters`                                                                         | Admin: configure a destination domain    |
| `cctp_getDomainParameters`                                                                         | View: read domain config                 |
| `cctp_toCCTPRateLimitKey`                                                                          | View: aggregate CCTP rate limit key      |
| `cctp_getToDomainRateLimitKey`                                                                     | View: per-domain rate limit key          |
| `cctp_VERSION`, `cctp_DESTINATION_CALLER`, `cctp_MIN_FINALITY_THRESHOLD`, `cctp_cctp`, `cctp_usdc` | View: facet metadata and immutables      |

The only destination domain configured at deployment is Ethereum (domain id `0`), with the Spark Ethereum `ALMProxy` as the mint recipient and zero fee caps (standard finality, fee-free).

---

## 3. Access control layout after the upgrade

| Contract                    | Role                 | Holder(s)                                                                                 |
| --------------------------- | -------------------- | ----------------------------------------------------------------------------------------- |
| `ALMProxy` (existing)       | `DEFAULT_ADMIN_ROLE` | `SPARK_EXECUTOR`                                                                          |
| `ALMProxy` (existing)       | `CONTROLLER`         | legacy `ArbitrumController`, **new Diamond PAU `Controller`** (spell)                     |
| `RateLimits` (existing)     | `DEFAULT_ADMIN_ROLE` | `SPARK_EXECUTOR`                                                                          |
| `RateLimits` (existing)     | `CONTROLLER`         | legacy `ArbitrumController`                                                               |
| new `RateLimits`            | `DEFAULT_ADMIN_ROLE` | `SPARK_EXECUTOR` (set in deploy script)                                                   |
| new `RateLimits`            | `CONTROLLER`         | **new Diamond PAU `Controller`** (configure script)                                       |
| legacy `ArbitrumController` | `DEFAULT_ADMIN_ROLE` | `SPARK_EXECUTOR`                                                                          |
| legacy `ArbitrumController` | `RELAYER`            | `ALM_RELAYER_MULTISIG`                                                                    |
| legacy `ArbitrumController` | `FREEZER`            | `ALM_FREEZER_MULTISIG`                                                                    |
| new `Beacon`                | `DEFAULT_ADMIN_ROLE` | `SPARK_EXECUTOR` (handed over from `deployer` in configure; `deployer` was initial owner) |
| new `AccessControls`        | `DEFAULT_ADMIN_ROLE` | `SPARK_EXECUTOR` (handed over from `deployer` in configure; `deployer` was initial owner) |
| new `AccessControls`        | `ALLOCATOR_ROLE`     | `AdministeredAgent` (configure script)                                                    |
| `AdministeredAgent`         | admin                | `SPARK_EXECUTOR` (configure script; deployer then removed)                                |
| `AdministeredAgent`         | actor                | `ALM_RELAYER_MULTISIG`                                                                    |
| `AdministeredAgent`         | revoker              | `ALM_FREEZER_MULTISIG`                                                                    |
| `AdministeredAgent`         | grantor              | `PAU_GRANTOR_MULTISIG`                                                                    |

Notes:

- The Diamond PAU `Controller` does not itself manage roles. Its admin functions (`updateIntegrations`, `removeIntegrations`) authorize against `DEFAULT_ADMIN_ROLE` on the external `AccessControls`. Facets do the same via the `Facet.onlyRole` modifier. Whoever holds `DEFAULT_ADMIN_ROLE` on `AccessControls` therefore governs the Controller and every facet's admin setters.
- The relayer multisig does not hold `ALLOCATOR_ROLE` directly. It acts as an Actor on the `AdministeredAgent`, which forwards `call` and `batchCall` into the Controller. The Controller observes `msg.sender == AdministeredAgent`, so the rate limits are shared across all actors on the same agent.
- `CONTROLLER` is `keccak256("CONTROLLER")` in both codebases, and both `ALMProxy` implementations use the identical role constant, so the grant is a standard `grantRole` from `SPARK_EXECUTOR`.
- `admin` (`SPARK_EXECUTOR`) is set as the initial admin of `Beacon`, `AccessControls`, and `RateLimits` at deploy time by the deploy script. The configure script then hands the `AdministeredAgent` admin to `SPARK_EXECUTOR` and revokes the deployer from all four contracts.

### 3.1 Freeze and revocation paths

The two controllers have structurally different emergency paths, which the operations runbook needs to reflect.

| Scenario                | Legacy controller                                                        | Diamond PAU controller                                                                                         |
| ----------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| Compromised relayer key | `ALM_FREEZER_MULTISIG` calls `ArbitrumController.removeRelayer(relayer)` | `ALM_FREEZER_MULTISIG` calls `AdministeredAgent.removeActor(relayer)`                                          |
| Disable CCTP transfers  | not applicable, monolithic                                               | `SPARK_EXECUTOR` calls `Controller.removeIntegrations(["CCTP_FACET"])`, or zeroes the relevant rate limit keys |
| Full revocation         | `SPARK_EXECUTOR` revokes `CONTROLLER` on `ALMProxy`                      | `SPARK_EXECUTOR` revokes `CONTROLLER` on `ALMProxy`, or revokes `ALLOCATOR_ROLE` from the agent                |

A single freezer action does **not** halt both controllers. Two separate transactions from the freezer multisig are required to stop allocator activity across the pair, and the runbook should state this explicitly.

---

## 4. Rate limits

Both controllers point at different `RateLimits` contracts. This is supported by the architecture; no rate limit collision can occur.

The Diamond PAU Controller's `CCTPFacet` meters two keys on the new `RateLimits` contract:

| Key                                                 | Purpose                                        |
| --------------------------------------------------- | ---------------------------------------------- |
| `cctp_toCCTPRateLimitKey()`                         | Aggregate cap across all destination domains   |
| `cctp_getToDomainRateLimitKey(destinationDomainId)` | Per-domain cap (one key per configured domain) |

For the Arbitrum deployment a single destination domain (Ethereum, id `0`) is configured. Both the aggregate key and the per-Ethereum-domain key must be set by the governance spell before any CCTP transfer can succeed. Until then the `CCTPFacet` reverts with `RateLimits/zero-maxAmount`.

---

## 5. Deployment and configuration sequence

Execution is split into two scripts run by the same permissionless `deployer` EOA:

- **Script 0 — Deploy** (`0-DeploySparkPAUParallel.s.sol`): Deploys all contracts. `admin` (`SPARK_EXECUTOR`) is set as the initial owner of `Beacon`, `AccessControls`, and `RateLimits` directly at deploy time. The `deployer` EOA is not a permanent owner; it acts as the broadcaster only.
- **Script 1 — Configure** (`1-ConfigureSparkPAUParallel.s.sol`): Wires the CCTP facet on the Beacon, initializes the controller stack (roles, integrations), adds `admin` to the `AdministeredAgent`, and revokes the `deployer` from every contract it touched.

Nothing in either script touches the existing `ALMProxy`. Granting `CONTROLLER` on the proxy and setting rate limits are governance spell actions that happen afterward.

### 5.1 Deploy script: shared PAU infrastructure

The deploy script creates the shared Diamond PAU infrastructure from scratch, since Arbitrum has none. These contracts are chain-wide resources — other controllers deployed later on the same chain can reuse the same `Beacon`, `PAUFactory`, and `AdministeredAgentFactory`.

**Step 1. Deploy `Beacon`**, with `deployer` as the temporary initial owner. The configure script will transfer ownership to `admin` and revoke `deployer`.

```solidity
Beacon beacon = new Beacon(deployer);
```

**Step 2. Deploy `PAUFactory`**, pointed at the new `Beacon`.

```solidity
PAUFactory pauFactory = new PAUFactory(address(beacon));
```

**Step 3. Deploy `AdministeredAgentFactory`**.

```solidity
AdministeredAgentFactory agentFactory = new AdministeredAgentFactory();
```

**Step 4. Deploy facets** (chain-specific). For Arbitrum the only facet is `CCTPFacet`, with the Arbitrum TokenMessengerV2 and native USDC as immutables.

```solidity
CCTPFacet cctpFacet = new CCTPFacet({
    cctp_ : CCTP_TOKEN_MESSENGER,
    usdc_ : USDC
});
```

### 5.2 Deploy script: controller stack

These contracts are specific to this parallel controller instance and are pointed at the existing Arbitrum `ALMProxy`. `deployer` is the temporary initial `DEFAULT_ADMIN_ROLE` holder on `Beacon`, `AccessControls`, `RateLimits`, and `AdministeredAgent`; the configure script hands all roles over to `admin` and then revokes `deployer`.

**Step 5. Deploy `AccessControls`** via the factory (`deployer` is initial admin; configure script hands over to `admin` and revokes `deployer`).

```solidity
address accessControls = pauFactory.deployAccessControls(deployer);
```

**Step 6. Deploy `RateLimits`** via the factory (same pattern — `deployer` is initial admin).

```solidity
address rateLimits = pauFactory.deployRateLimits(deployer);
```

**Step 7. Deploy `Controller`**, bound at construction to the existing `ALMProxy` and the new `AccessControls` / `RateLimits`.

```solidity
address controller = pauFactory.deployController(accessControls, ALM_PROXY, rateLimits);
```

`proxy` is written to shared storage at construction with no setter, so it is permanently bound at deploy time.

**Step 8. Deploy `AdministeredAgent`** via the factory (`deployer` is initial admin — corrected to `admin` in the configure script).

```solidity
address administeredAgent = agentFactory.deploy(deployer);
```

### 5.3 Configure script: wire facets, initialize stack, and hand over admin

The configure script must be run by the same `deployer` EOA and must be broadcast before any governance spell.

**Step 1. Wire the `CCTPFacet` on the `Beacon`** under the `"CCTP_FACET"` integration id with the canonical ten-wire selector mapping (`BeaconConfig.setCCTPIntegration`).

```solidity
BeaconConfig.setCCTPIntegration(address(beacon), cctpFacet);
```

**Step 2. Initialize the parallel PAU stack** via `InitParallelPAU.initParallelPAU`. This single call performs four sub-steps in order:

- **2a. Configure `AdministeredAgent`**: add `admin` as agent admin, add `ALM_RELAYER_MULTISIG` as actor, add `PAU_GRANTOR_MULTISIG` as grantor, add `ALM_FREEZER_MULTISIG` as revoker.
- **2b. Grant roles**: grant `DEFAULT_ADMIN_ROLE` on `AccessControls` (already held by `admin` from deploy, this is a no-op for admin but grants may cover additional admins); grant `ALLOCATOR_ROLE` on `AccessControls` to the `AdministeredAgent`; grant `DEFAULT_ADMIN_ROLE` on `RateLimits` (same note); grant `CONTROLLER` on `RateLimits` to the `Controller`.
- **2c. Sync integrations**: call `controller.updateIntegrations(["CCTP_FACET"])` to pull the CCTP wiring from the Beacon.
- **2d. Emit `InitParallelPAU` event**.

**Step 3. Hand admin of `Beacon` to `admin`, then revoke `deployer` from all four contracts.**

```solidity
// Grant SPARK_EXECUTOR admin on the Beacon (the other three already have it from deploy).
beacon.grantRole(DEFAULT_ADMIN_ROLE, admin);

// Revoke deployer from Beacon, AccessControls, and RateLimits.
beacon.revokeRole(DEFAULT_ADMIN_ROLE,         deployer);
accessControls.revokeRole(DEFAULT_ADMIN_ROLE, deployer);
rateLimits.revokeRole(DEFAULT_ADMIN_ROLE,     deployer);

// Remove deployer as admin of the AdministeredAgent.
administeredAgent.removeAdmin(deployer);
```

After this point the `deployer` retains no authority over any contract in the stack.

### 5.4 Governance spell (Spark Executor)

These two actions are not part of either script and require a Spark governance spell executed by `SPARK_EXECUTOR`.

**Spell action 1. Grant `CONTROLLER` on the existing `ALMProxy`.**

```solidity
almProxy.grantRole(almProxy.CONTROLLER(), diamondController);
```

**Spell action 2. Configure CCTP domain parameters.** For each destination domain (initially Ethereum only), set the mint recipient and fee cap range on the Controller. Note that `cctp_setDomainParameters` goes through the diamond dispatch into the `CCTPFacet` and requires `DEFAULT_ADMIN_ROLE` on `AccessControls`.

```solidity
controller.cctp_setDomainParameters(
    ethereumDomain,
    bytes32(uint256(uint160(ETHEREUM_ALM_PROXY))),
    0,  // minFeeCapRate: standard finality, fee-free
    0   // maxFeeCapRate: fee-free
);
```

**Spell action 3. Set CCTP rate limits** on the new `RateLimits` contract.

```solidity
rateLimits.setRateLimitData(controller.cctp_toCCTPRateLimitKey(),                   maxAmount, slope);
rateLimits.setRateLimitData(controller.cctp_getToDomainRateLimitKey(ethereumDomain), maxAmount, slope);
```

Until both spell actions are executed the Controller is fully deployed and configured but cannot move funds: calling `cctp_transfer` reverts with `RateLimits/zero-maxAmount` before it ever reaches the proxy.

### 5.5 Post-configure verification (pre-spell)

Run immediately after the configure script, before the governance spell:

- `controller.proxy()` returns the existing Arbitrum `ALMProxy`.
- `controller.beacon()` returns the newly deployed `Beacon`.
- `controller.integrations()` has exactly one entry: `"CCTP_FACET"`.
- `beacon.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR) == true`; deployer has no role on `Beacon`, `AccessControls`, `RateLimits`, or `AdministeredAgent`.
- `accessControls.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR) == true`.
- `accessControls.hasRole(ALLOCATOR_ROLE, administeredAgent) == true`.
- `rateLimits.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR) == true`.
- `rateLimits.hasRole(CONTROLLER, controller) == true`.
- `administeredAgent.getIsAdmin(SPARK_EXECUTOR) == true`; deployer is not admin.
- `almProxy.getRoleMemberCount(CONTROLLER) == 1` (legacy controller only); the Diamond PAU `Controller` is **not** yet a member — that is correct pre-spell.

### 5.6 Post-spell verification

- `almProxy.getRoleMemberCount(CONTROLLER) == 2`, members are the legacy `ArbitrumController` and the new Diamond PAU `Controller`.
- `rateLimits.getCurrentRateLimit(cctp_toCCTPRateLimitKey()) == maxAmount`.
- A test CCTP transfer through the `AdministeredAgent` succeeds and burns USDC from the proxy.

---

## 6. Rollback

Reverting the upgrade is a single governance transaction:

```solidity
almProxy.revokeRole(CONTROLLER, diamondController);
```

After this the Diamond PAU Controller retains no authority on the existing `ALMProxy`. The `Beacon`, `CCTPFacet`, `PAUFactory`, and `AdministeredAgentFactory` remain deployed and can be reused for future controllers.

---

## 7. Open questions

**1. Who holds the `AdministeredAgent` grantor role?**

Resolved: `PAU_GRANTOR_MULTISIG` is assigned as grantor in the configure script. Only the agent admin (`SPARK_EXECUTOR`) can add further grantors after that point.
