# Parallel Controller Deployment Review: Diamond PAU with CCTPFacet (Arbitrum)

This document scopes an external review of a deployment that is already on chain. A Diamond PAU `Controller` has been deployed on Arbitrum One next to the existing Spark `ForeignController`. Both will operate the same existing `ALMProxy`. The new controller is wired to one integration, `CCTP_FACET`, to bridge USDC from the Arbitrum `ALMProxy` to the Spark Ethereum `ALMProxy` through Circle's TokenMessengerV2.

**The code, the tests and the chain are the source of truth. This document is a map to them.** Where this document and the code disagree, the code is correct and the disagreement is worth reporting.

---

## 1. Scope

### In scope

Verify the following for the contracts deployed by this repository on Arbitrum One:

1. **Bytecode.** Each deployed contract matches the pinned source in section 3, differing only in immutables.
2. **Configuration.** The `Beacon` holds exactly one integration, `CCTP_FACET`. Its wiring matches the `CCTP_FACET` wiring on the Sky PAU Beacon on Ethereum mainnet. The `Controller` has synced exactly that integration and is bound to the existing `ALMProxy`, the new `AccessControls` and the new `RateLimits`. The facet's immutables are Arbitrum's TokenMessengerV2 and native USDC.
3. **Role state.** Every role on every new contract is held by the intended party and by no one else. The deployer retains nothing. The existing `ALMProxy` is unmodified.

### Out of scope

- The contract source itself. `diamond-pau` and `pau-administered-agent` are audited at the pinned releases.
- The legacy `ForeignController`, the existing `ALMProxy` and `RateLimits`, and Circle's contracts.
- The governance spell and the planned follow-ups in section 6. They are listed for context only.

### Addresses

Addresses are deliberately not repeated here. The source of truth is `spark-address-registry` at the pinned commit, [`src/Arbitrum.sol`](../lib/spark-address-registry/src/Arbitrum.sol): `SPARK_BEACON`, `SPARK_PAU_FACTORY`, `SPARK_ADMINISTERED_AGENT_FACTORY`, `CCTP_FACET`, `PAU_ACCESS_CONTROLS`, `PAU_ADMINISTERED_AGENT`, `PAU_CONTROLLER`, `PAU_RATELIMITS`, and the existing `ALM_PROXY`, `ALM_CONTROLLER`, `SPARK_EXECUTOR` and multisigs. [`deployments/parallel-controller/arbitrum-production.json`](../deployments/parallel-controller/arbitrum-production.json) and the deploy output under `script/output/42161/` must agree with it.

---

## 2. Trust assumptions

State after deployment and configuration, before the spell:

| Party | Authority |
| --- | --- |
| `SPARK_EXECUTOR` (Spark governance on Arbitrum) | Sole `DEFAULT_ADMIN_ROLE` on the new `Beacon`, `AccessControls` and `RateLimits`. Sole admin of the `AdministeredAgent`. Already admin of the existing `ALMProxy`. Controls facet registration, integration sync and removal, facet admin setters, rate limits and all role grants. |
| `AdministeredAgent` | Sole holder of `ALLOCATOR_ROLE` on the new `AccessControls`. The only address that can call allocator functions on the new controller. |
| `ALM_RELAYER_MULTISIG` | Actor on the agent. Can call wired allocator functions through it. |
| `PAU_GRANTOR_MULTISIG` | Grantor on the agent. Can add actors. |
| `ALM_FREEZER_MULTISIG` | Revoker on the agent. Can remove actors. |
| Deployer EOA | None. Held every admin role between the deploy and configure runs, then revoked itself from all four contracts. |
| New `Controller` | `CONTROLLER` on the new `RateLimits` only. **Not** `CONTROLLER` on the `ALMProxy` until the spell. |

Two properties a reviewer should hold in mind:

- **`CONTROLLER` on the `ALMProxy` is unrestricted.** The proxy exposes `doCall`, `doCallWithValue` and `doDelegateCall` to any `CONTROLLER`, with no allowlist, asset scoping or budget. Once the spell grants the role, containment is enforced entirely by the new controller: its `fallback` dispatches only selectors synced from the `Beacon` and reverts with `CallSelectorNotWired` otherwise. See `Controller.fallback`, `Controller.updateIntegrations` and `CCTPFacet.transfer` in `diamond-pau`. The CCTP facet reaches the proxy only through `doCall`.
- **Roles are external to the controller.** `Controller.onlyAdmin` and `Facet.onlyRole` both check the new `AccessControls`. Whoever holds `DEFAULT_ADMIN_ROLE` there governs the controller and every facet admin setter.

### Known finding on this topology

ChainSecurity's Diamond PAU v1.13 report reviews one `ALMProxy` backed by several controllers and raises CS-SKYDPAU-044 (Design, Low, risk accepted): the `nonReentrant` guard lives in each controller, not in the shared proxy, so an untrusted external call made by one controller can re-enter a sibling and corrupt balance-delta accounting. Its prerequisite is a re-entering call that reaches a sibling's state-changing function. With only `CCTP_FACET` wired, the new controller's external calls are `USDC.approve` and TokenMessengerV2 `depositForBurn`, and its only state-changing allocator function requires `ALLOCATOR_ROLE`. The finding must be reassessed if any facet that calls untrusted contracts is added. See `docs/ARCHITECTURE.md` in `diamond-pau`, "Multi-Controller Topology".

Rate limit budgets are per controller and additive. Total outbound CCTP capacity from the proxy is the legacy limit plus the new limit.

---

## 3. Source pins

| Dependency | Release | Commit |
| --- | --- | --- |
| `diamond-pau` | v1.14.0 | `cbf71b2ac840ca9288eb867d3dd354e08089e1d7` |
| `pau-administered-agent` | v1.0.0 | `bfaaf709a8664d74d12604455f0365a0a12439cf` |
| `spark-address-registry` | — | `1a801d712bd660e1632076019b3b0dd5ba8cbaa4` |
| `sky-pau-registry` | — | `7b4493a7800b355ef5c9cc43e569c5e8d6fd97f8` |

Compiler settings are in [`foundry.toml`](../foundry.toml): solc 0.8.34, optimizer on at 200 runs, EVM version cancun. Submodule commits are authoritative; run `git submodule status` to confirm them.

To check bytecode, run `forge build` at this commit and compare each artifact's `deployedBytecode` with `eth_getCode` at the registry address. `Beacon`, `AdministeredAgentFactory`, `AccessControls`, `RateLimits` and `AdministeredAgent` should match exactly. `PAUFactory`, `Controller` and `CCTPFacet` should match in length and differ only in immutable slots.

---

## 4. What was run

Two scripts, both broadcast by the deployer EOA:

- [`0-DeploySparkPAUParallel.s.sol`](../script/parallel-controller/0-DeploySparkPAUParallel.s.sol) deploys `Beacon`, `PAUFactory`, `AdministeredAgentFactory`, `CCTPFacet`, then `AccessControls`, `RateLimits`, `Controller` and one `AdministeredAgent`. The deployer is initial admin of all four role-bearing contracts.
- [`1-ConfigureSparkPAUParallel.s.sol`](../script/parallel-controller/1-ConfigureSparkPAUParallel.s.sol) wires `CCTP_FACET` on the `Beacon` ([`BeaconConfig`](../src/BeaconConfig.sol)), configures the agent, grants roles and syncs the integration ([`InitParallelPAU`](../src/InitParallelPAU.sol)), then hands admin to `SPARK_EXECUTOR` and revokes the deployer.

Inputs are under [`script/input/42161/`](../script/input/42161/). Neither script touches the existing `ALMProxy`.

### Transaction record

Deployer `0xC758519Ace14E884fdbA9ccE25F2DbE81b7e136f`, Arbitrum One, 2026-09-18 UTC. Every transaction succeeded.

**Deploy, nonces 12 to 19, blocks 506440757 to 506440788**

| Nonce | Action | Transaction |
| --- | --- | --- |
| 12 | create `Beacon` | `0xa95c2718c76e154ffe608c3df774ec0f81acd2658c4aef753b02fdd68c7745ec` |
| 13 | create `PAUFactory` | `0xd8fc73ce8b186ce2fe143dbc82f89e6928be8fc5a7205fcd764b0ba239c251a3` |
| 14 | create `AdministeredAgentFactory` | `0xf6234c9b8c863f95e32b65f38e85cef34050f7ad4f36a384aefeb6e4e92a0c20` |
| 15 | create `CCTPFacet` | `0xe88d5b64c53cb205563a77c99a46ed27edb08ad360fe38245ef160e3d927cb13` |
| 16 | `PAUFactory.deployAccessControls` | `0xeb410a03bad6c4084807f43dfb3b523ee6a8566e130bfecb3e356714dc684f22` |
| 17 | `PAUFactory.deployRateLimits` | `0x7bfc18fef9d27b3fb973141d41942cc818ca21fd1ae4da5d2e4f182a3dc81b6d` |
| 18 | `PAUFactory.deployController` | `0x73bf66b91491dcee12e53723b19a7622e6d7b29ca54d9fe80a45db5971434371` |
| 19 | `AdministeredAgentFactory.deploy` | `0x08a393425c2492d9de42391a23ed0b6a8eb1a80ce45aabb89708235650608f76` |

**Configure, nonces 20 to 34, blocks 506469661 to 506469723**

| Nonce | Action | Transaction |
| --- | --- | --- |
| 20 | `Beacon.setIntegration` | `0x0c2759fd705494c91f3abb6e6263f00d068d8a553f7da315fa48899e2347f136` |
| 21 | `AdministeredAgent.addAdmin` | `0xa6628fbc2ada1cb08d32dd027deed34df4dab6a11e68f8edf814d5fade1816e3` |
| 22 | `AdministeredAgent.addActor` | `0x4390fc160b62af01fbe6b8f4ae7dd34d5222cf91f2b27995aa1ff4a6b4e1293c` |
| 23 | `AdministeredAgent.addGrantor` | `0xa5715a585a0e0a3d3e05dff5c0aa3478226de794b4437c275091f0e4ed3b344f` |
| 24 | `AdministeredAgent.addRevoker` | `0x484b970d8f7572cb66148e8b2229bfc529b753255807e5143ac1bc9c7008ac72` |
| 25 | `AccessControls.grantRole` | `0x89fcec0c18d7155fb32c77f9bc3647d395a6bcb475a7a09ebeea1538c9f78832` |
| 26 | `AccessControls.grantRole` | `0x3cce4325299746c2babdc4c5f7187eef6ce91d80f7b05ab83ce940041a5e6afa` |
| 27 | `RateLimits.grantRole` | `0xbaf94b789dd3f628a59c0ecda8a88e395fc6cb8d19c47ca1778d9fcd4660c62f` |
| 28 | `RateLimits.grantRole` | `0x52216fa6f509a4921e9d9ede6541bd2e276214749a1f3ca4ca66d4429524e76f` |
| 29 | `Controller.updateIntegrations` | `0x9d9fca1d553ce55bbad97e96f04db2c3535e91ab2ae84e319da3e05e28043a6f` |
| 30 | `Beacon.grantRole` | `0x68c31e2e6649b6bfc5e6fef7b3851c151089023bdab38258e4fd677484a178f5` |
| 31 | `Beacon.revokeRole` | `0xfeb8667ee25a3002cea59c6e1620edd7f266751ca594aa0dc5cef9ccd8c01662` |
| 32 | `AccessControls.revokeRole` | `0x2ebd039094c7ef7b3be1b0b96fb40628ac02882b9d11c400b163507d0083b70e` |
| 33 | `RateLimits.revokeRole` | `0xa8eb0fa2ae0e20549dec53c7c2daaef6320567fe9003e712474e1a94461c681a` |
| 34 | `AdministeredAgent.removeAdmin` | `0x79e0a575024aea2d3d33e40d62c2011e40586c85c4046540d0a61b9b6ff21f45` |

The deployer's earlier Arbitrum transactions, nonces 0 to 11, are unrelated to this deployment.

---

## 5. Where each in-scope property is asserted

All tests fork Arbitrum One at block 506472875, after the last configure transaction.

| Property | Test |
| --- | --- |
| Role state, configuration and the full event history of every new contract, against the live deployment | `ArbitrumPostDeployTestsProduction` in [`PostDeployTests.t.sol`](../test/parallel-controller/arbitrum/PostDeployTests.t.sol) |
| `Beacon` wiring equals the `CCTP_FACET` wiring on the Sky PAU Beacon on Ethereum mainnet, wire for wire | `test_beaconState` in the same file. It forks mainnet and compares each call selector and delegate selector. Facet addresses differ per chain by design. |
| Facet constructor arguments | `test_facets_constructors` |
| Existing `ALMProxy` unmodified: legacy controller holds `CONTROLLER`, new controller and deployer do not | `test_almProxyState_unchanged` |
| Deployer retains no authority | `test_deployerCannotAdministerAfterConfigure` in [`E2E.t.sol`](../test/parallel-controller/arbitrum/E2E.t.sol) |
| Transfers fail closed before the spell. After a simulated spell, a relayer bridges USDC through Circle on the fork. `removeIntegrations` disables the facet without affecting the legacy controller. | `ArbitrumParallelE2ETestLive` against the registry addresses, and `ArbitrumParallelE2ETestLocal` against a fresh fork deployment |

Run them with `forge test --match-path "test/parallel-controller/**"`. The event tests need `ETHERSCAN_API_KEY`.

Note for reviewers: `ArbitrumParallelE2ETestLocal` re-implements the script steps rather than executing the scripts. The production tests and the transaction record above are the evidence for what the scripts did on chain.

---

## 6. Planned follow-ups, out of scope

Listed so reviewers know the current state is intentionally incomplete. Until the spell, `cctp_transfer` reverts with `RateLimits/zero-maxAmount`, no CCTP domain is configured, and the new controller cannot call the proxy.

The Spark governance spell, executed by `SPARK_EXECUTOR`, is planned to:

1. Grant `CONTROLLER` on the existing `ALMProxy` to the new `Controller`.
2. Set CCTP domain parameters for Ethereum (domain `0`): mint recipient the Spark Ethereum `ALMProxy`, fee caps `0` and `0`.
3. Set the aggregate and per-domain CCTP rate limits on the new `RateLimits`.
4. Add `ALM_BACKSTOP_RELAYER_MULTISIG` as an actor on the `AdministeredAgent`.
5. Grant `DEFAULT_ADMIN_ROLE` on the new `AccessControls` to the PAS Configurator, so that a pre-approved `removeIntegrations` call can disable the facet during incident response without waiting for a spell.

### Emergency paths once live

| Scenario | Legacy controller | Diamond PAU controller |
| --- | --- | --- |
| Compromised relayer key | Freezer calls `ForeignController.removeRelayer` | Freezer calls `AdministeredAgent.removeActor` |
| Disable CCTP on the new controller | n/a | Admin calls `Controller.removeIntegrations(["CCTP_FACET"])` |
| Full revocation | `SPARK_EXECUTOR` revokes `CONTROLLER` on the `ALMProxy` | Same |

One freezer action does not halt both controllers. Stopping allocator activity on both takes two transactions. Removing the integration or revoking the role stops later calls only; CCTP burns already submitted complete on the destination chain.
