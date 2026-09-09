# spark-pau-deploy Makefile
#
# Prerequisites:
#   - ETH_FROM: deployer address
#   - MAINNET_RPC_URL, XLAYER_RPC_URL, RH_RPC_URL: chain RPC URLs
#   - MAINNET_API_KEY: Etherscan key, used by --verify on mainnet
#   - ETHERSCAN_API_KEY: used by the post-deploy event tests
#   - foundry keystore account named "deployer" (cast wallet import deployer --interactive)
#
# Deployment variants:
#   full: the default PAU assembler deploys the whole stack (ALMProxy, AccessControls, RateLimits,
#         Controller, AdministeredAgent) in a single call and wires the integrations
#
# Deployment order (per chain + env):
#   1. deploy    — calls DefaultPAUAssembler.deploy with the integration ids, admin config and
#                  allocator agent config. The `admin` in the deploy input is the same address as
#                  `deployer`, so that the configure step below can still run; `deployer` is the
#                  broadcaster and must match --sender.
#                  Input:  script/input/{chainId}/deploy-pau-with-assembler-{chain}-{env}.json
#                  Output: script/output/{chainId}/deploy-pau-with-assembler-{chain}-{env}-{ts}.json
#   2. configure — onboards each facet (rate limits, CCTP domain parameters, ERC4626 max exchange
#                  rate), then grants the admin roles to `admin` and revokes them from `deployer`.
#                  Input: script/input/{chainId}/config-pau-with-assembler-{chain}-{env}.json
#
# Both scripts are selected by CHAIN and ENV. Every value they write is read from the input files;
# keys prefixed with an underscore in those files are documentation only.
#
# Testing a deployment (see "Fork deploy tests" and "Post deploy tests" below):
#   - before broadcasting, `make test-forkdeploy` runs both scripts unchanged on a fork of the target
#     chain and asserts the resulting state and events with the post-deploy assertions;
#   - after broadcasting, `make test-postdeploy` asserts the same things against the real chain,
#     reading the addresses from deployments/*.json and the events from Etherscan.

# --------------------------------------------------------------------------------------------------
# Build & Test                                                                                     #
# --------------------------------------------------------------------------------------------------

build:
	forge build

test:
	forge test

clean:
	forge clean

# --------------------------------------------------------------------------------------------------
# Fork deploy tests                                                                                #
# --------------------------------------------------------------------------------------------------
# Run the real deploy and configure scripts on a fork of the target chain, pinned at the same block
# as the post-deploy tests, then assert the result with the post-deploy assertions. The addresses
# come from the deploy script's return value and the events from the recorded logs, so nothing is
# read from Etherscan and nothing is written to script/output/. Run BEFORE broadcasting: a config
# mistake fails here instead of after the deployment is spent.
#
# Both chains assert state and events.

test-forkdeploy: test-forkdeploy-mainnet-full test-forkdeploy-xlayer-full

test-forkdeploy-mainnet-full:
	forge test --match-path "test/full-pau/mainnet/ForkDeployTests.t.sol" -vvv

test-forkdeploy-mainnet-full-staging:
	forge test --match-contract "MainnetForkDeployTests" -vvv

test-forkdeploy-xlayer-full:
	forge test --match-path "test/full-pau/xlayer/ForkDeployTests.t.sol" -vvv

test-forkdeploy-xlayer-full-staging:
	forge test --match-contract "XLayerForkDeployTests" -vvv

# --------------------------------------------------------------------------------------------------
# Post deploy tests                                                                                #
# --------------------------------------------------------------------------------------------------
# Assert the end state of a deployment that has already been deployed AND configured. There is one
# file per chain, holding one contract per environment; adding an environment or a chain means
# adding a contract or a file, never a new assertion.
#
# Mainnet asserts state and events. X Layer asserts state only, the Etherscan v2 log endpoint does
# not cover chain 196 (its events are asserted by the fork deploy tests instead).

test-postdeploy: test-postdeploy-mainnet-full test-postdeploy-xlayer-full

test-postdeploy-mainnet-full:
	forge test --match-path "test/full-pau/mainnet/PostDeployTests.t.sol" -vvv

test-postdeploy-mainnet-full-staging:
	forge test --match-contract "MainnetPostDeployTestsStaging" -vvv

test-postdeploy-xlayer-full:
	forge test --match-path "test/full-pau/xlayer/PostDeployTests.t.sol" -vvv

test-postdeploy-xlayer-full-staging:
	forge test --match-contract "XLayerPostDeployTestsStaging" -vvv

# --------------------------------------------------------------------------------------------------
# Deploy: ALMProxy + AccessControls + RateLimits + Controller + AdministeredAgent                  #
# --------------------------------------------------------------------------------------------------

# Mainnet

deploy-mainnet-full-staging:
	CHAIN=mainnet ENV=staging forge script \
		script/full-pau/0-DeploySparkPAUFull.s.sol:DeploySparkPAUFullMainnet \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

deploy-mainnet-full-production:
	CHAIN=mainnet ENV=production forge script \
		script/full-pau/0-DeploySparkPAUFull.s.sol:DeploySparkPAUFullMainnet \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

# X Layer
# No --verify: foundry.toml has no Etherscan configuration for chain 196.

deploy-xlayer-full-staging:
	CHAIN=xlayer ENV=staging forge script \
		script/full-pau/0-DeploySparkPAUFull.s.sol:DeploySparkPAUFullXLayer \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(XLAYER_RPC_URL)

deploy-xlayer-full-production:
	CHAIN=xlayer ENV=production forge script \
		script/full-pau/0-DeploySparkPAUFull.s.sol:DeploySparkPAUFullXLayer \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(XLAYER_RPC_URL)

# --------------------------------------------------------------------------------------------------
# Configure: Controller + AccessControls + AdministeredAgent + RateLimits                          #
# --------------------------------------------------------------------------------------------------
# Onboards the facets and hands the stack from the deployer to `admin`. Needs the deployed
# controller and allocator agent pasted into the config input first.
#
# Run AFTER deploy. Staging only: production is configured by a governance spell.

configure-mainnet-full-staging:
	CHAIN=mainnet ENV=staging forge script \
		script/full-pau/1-ConfigureSparkPAUFull.s.sol:ConfigureSparkPAUFullMainnet \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(MAINNET_RPC_URL)

configure-xlayer-full-staging:
	CHAIN=xlayer ENV=staging forge script \
		script/full-pau/1-ConfigureSparkPAUFull.s.sol:ConfigureSparkPAUFullXLayer \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(XLAYER_RPC_URL)

.PHONY: build test clean \
	test-forkdeploy test-forkdeploy-mainnet-full test-forkdeploy-mainnet-full-staging \
	test-forkdeploy-xlayer-full test-forkdeploy-xlayer-full-staging \
	test-postdeploy test-postdeploy-mainnet-full test-postdeploy-mainnet-full-staging \
	test-postdeploy-xlayer-full test-postdeploy-xlayer-full-staging \
	deploy-mainnet-full-staging deploy-mainnet-full-production \
	deploy-xlayer-full-staging deploy-xlayer-full-production \
	configure-mainnet-full-staging configure-xlayer-full-staging
