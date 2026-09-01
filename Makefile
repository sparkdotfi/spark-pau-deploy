# spark-pau-deploy Makefile
#
# Prerequisites:
#   - ETH_FROM: deployer address
#   - {MAINNET,BASE,AVALANCHE}_RPC_URL: chain RPC URLs
#   - {MAINNET,BASESCAN,SNOWTRACE}_API_KEY: per-chain Etherscan keys (for --verify)
#   - ETHERSCAN_API_KEY: used by the post-deploy event tests
#   - foundry keystore account named "deployer" (cast wallet import deployer --interactive)
#
# Deployment order (per chain + env):
#   1. deploy    — deploys AccessControls, RateLimits (both with the `admin` from the deploy input
#                  as admin), Controller and AdministeredAgent
#   2. configure — staging only; needs controller + administeredAgent pasted into
#                  script/input/{chainId}/config-mainnet-staging.json.
#                  Production is configured by a governance spell, not by this repo, so the deploy
#                  input for production sets `admin` to SPARK_PROXY directly.

# --------------------------------------------------------------------------------------------------
# Build & Test                                                                                     #
# --------------------------------------------------------------------------------------------------

build:
	forge build

test:
	forge test

clean:
	forge clean

test-postdeploy-mainnet-production:
	forge test --match-path "test/PostProductionDeployTests.t.sol" -vvv

test-postdeploy-mainnet-staging:
	forge test --match-path "test/PostStagingDeployTests.t.sol" -vvv

# --------------------------------------------------------------------------------------------------
# Deploy: AccessControls + RateLimits + Controller + AdministeredAgent                             #
# --------------------------------------------------------------------------------------------------
# Deploys AccessControls, RateLimits and AdministeredAgent (with `admin` as admin on all three) and
# a Controller wired to the Sky PAU beacon and the new RateLimits plus the Spark ALMProxy from
# spark-address-registry.
# For staging, `admin` is the deployer so that the configure script below can still run; for
# production, `admin` is SPARK_PROXY.
# Input:  script/input/{chainId}/deploy-{chain}-{env}.json (chainId, admin, deployer)
# Output: script/output/{chainId}/deploy-{chain}-{env}-{timestamp}.json
#         (accessControls, administeredAgent, controller, rateLimits)

# Mainnet

deploy-mainnet-production:
	CHAIN=mainnet ENV=production forge script script/0-DeploySparkPAU.s.sol:DeploySparkPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

deploy-mainnet-staging:
	CHAIN=mainnet ENV=staging forge script script/0-DeploySparkPAU.s.sol:DeploySparkPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

# --------------------------------------------------------------------------------------------------
# Configure: Controller + AccessControls + AdministeredAgent + RateLimits                          #
# --------------------------------------------------------------------------------------------------
# Registers the CCTP integration on the controller, grants ALLOCATOR_ROLE to the AdministeredAgent,
# wires the relayer / backstop relayer / freezer multisigs onto the AdministeredAgent, grants the
# CONTROLLER role on RateLimits to the controller, then hands AccessControls, the AdministeredAgent
# and RateLimits over to `admin` and drops the deployer.
# RateLimits and AccessControls are read from the controller, so they need no config entry.
# Input: script/input/{chainId}/config-mainnet-staging.json
#        (chainId, admin, administeredAgent, controller, deployer)
#
# Staging only - production is configured by a governance spell.
# Run AFTER deploy.
# Mainnet

configure-mainnet-staging:
	CHAIN=mainnet forge script \
		script/1-ConfigureSparkPAUStaging.s.sol:ConfigureSparkPAUStaging \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(MAINNET_RPC_URL)
