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
#   1. deploy    — deploys AccessControls and RateLimits (deployer as temporary admin on both),
#                  Controller and AdministeredAgent
#   2. configure — needs controller + administeredAgent pasted into
#                  script/input/{chainId}/config-{chain}-{env}.json

# --------------------------------------------------------------------------------------------------
# Build & Test                                                                                     #
# --------------------------------------------------------------------------------------------------

build:
	forge build

test:
	forge test

clean:
	forge clean

test-postdeploy-mainnet:
	forge test --match-path "test/PostDeployTests.t.sol" -vvv

# --------------------------------------------------------------------------------------------------
# Deploy: AccessControls + RateLimits + Controller + AdministeredAgent                             #
# --------------------------------------------------------------------------------------------------
# Deploys AccessControls, RateLimits and AdministeredAgent (with the deployer as temporary admin on
# all three) and a Controller wired to the Sky PAU beacon and the new RateLimits plus the Spark
# ALMProxy from spark-address-registry.
# Input:  script/input/{chainId}/deploy-{chain}-{env}.json (chainId, deployer)
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
# and RateLimits over to SPARK_PROXY and drops the deployer.
# RateLimits is read from controller.rateLimits(), so it needs no config entry.
# Input: script/input/{chainId}/config-{chain}-{env}.json
#        (chainId, administeredAgent, controller, deployer)
#
# Run AFTER deploy.
# Mainnet

configure-mainnet-production:
	CHAIN=mainnet ENV=production forge script script/1-Configure.s.sol:ConfigureController \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(MAINNET_RPC_URL)

configure-mainnet-staging:
	CHAIN=mainnet ENV=staging forge script script/1-Configure.s.sol:ConfigureController \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(MAINNET_RPC_URL)
