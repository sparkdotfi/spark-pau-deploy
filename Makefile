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
#   1. deploy    — deploys AccessControls (deployer as temporary admin), Controller and
#                  AdministeredAgent
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
# Deploy: AccessControls + Controller + AdministeredAgent                                          #
# --------------------------------------------------------------------------------------------------
# Deploys AccessControls and AdministeredAgent (with the deployer as temporary admin on both) and a
# Controller wired to the Sky PAU beacon plus the Spark ALMProxy and RateLimits from
# spark-address-registry.
# Input:  script/input/{chainId}/deploy-{chain}-{env}.json (chainId, deployer)
# Output: script/output/{chainId}/deploy-{chain}-{env}-{timestamp}.json
#         (accessControls, administeredAgent, controller)

# Mainnet

deploy-mainnet-production:
	CHAIN=mainnet ENV=production forge script script/0-DeploySparkPAU.s.sol:DeploySparkPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

deploy-mainnet-staging:
	CHAIN=mainnet ENV=staging forge script script/0-DeploySparkPAU.s.sol:DeploySparkPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

# --------------------------------------------------------------------------------------------------
# Configure: Controller + AccessControls + AdministeredAgent                                       #
# --------------------------------------------------------------------------------------------------
# Registers the UniswapV4 integration on the controller and copies the UniswapV4 pool config from
# the legacy ALM_CONTROLLER, grants ALLOCATOR_ROLE to the AdministeredAgent, wires the relayer /
# backstop relayer / freezer multisigs onto the AdministeredAgent, then hands both AccessControls
# and the AdministeredAgent over to SPARK_PROXY and drops the deployer.
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
