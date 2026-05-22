# spark-pau-deploy Makefile
#
# Prerequisites:
#   - ETH_FROM: deployer address
#   - {MAINNET,BASE,AVALANCHE}_RPC_URL: chain RPC URLs
#   - {MAINNET,BASESCAN,SNOWTRACE}_API_KEY: per-chain Etherscan keys (for --verify)
#   - foundry keystore account named "deployer" (cast wallet import deployer --interactive)
#
# Deployment order (per chain + env):
#   1. deploy         — deploys AccessControls (deployer as temporary admin) + Controller
#   2. configure      — needs controller pasted into script/input/{chainId}/config-{chain}-{env}.json
#   3. transfer-roles — needs accessControls pasted into script/input/{chainId}/transfer-{chain}-{env}.json

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
	forge test --match-path "test/mainnet-fork/PostDeploy*" -vvv

# --------------------------------------------------------------------------------------------------
# Deploy: AccessControls + Controller                                                              #
# --------------------------------------------------------------------------------------------------
# Deploys AccessControls (with deployer as temporary admin) and Controller wired to the beacon,
# ALMProxy and RateLimits provided in the input file.
# Input:  script/input/{chainId}/deploy-{chain}-{env}.json (deployer, beacon, proxy, rateLimits)
# Output: script/output/{chainId}/deploy-{chain}-{env}-latest.json (accessControls, controller)

# Mainnet

deploy-mainnet-production:
	CHAIN=mainnet ENV=production forge script script/0-Deploy.s.sol:DeployAccessControlsAndController \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

deploy-mainnet-staging:
	CHAIN=mainnet ENV=staging forge script script/0-Deploy.s.sol:DeployAccessControlsAndController \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

# --------------------------------------------------------------------------------------------------
# Configure: Controller                                                                            #
# --------------------------------------------------------------------------------------------------
# Updates controller integrations and migrates ERC4626 max exchange rates, Curve/Aave max slippage
# and UniswapV4 pool settings from the legacy ALM_CONTROLLER.
# Input: script/input/{chainId}/config-{chain}-{env}.json (controller, integrationIds)
#
# Run AFTER deploy.

# Mainnet

configure-mainnet-production:
	CHAIN=mainnet ENV=production forge script script/1-Configure.s.sol:ConfigureController \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(MAINNET_RPC_URL)

configure-mainnet-staging:
	CHAIN=mainnet ENV=staging forge script script/1-Configure.s.sol:ConfigureController \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(MAINNET_RPC_URL)

# --------------------------------------------------------------------------------------------------
# Transfer Roles                                                                                   #
# --------------------------------------------------------------------------------------------------
# Grants ALLOCATOR_ROLE/ALLOCATOR_ADMIN_ROLE, sets role admin, transfers DEFAULT_ADMIN_ROLE to the
# final admin and revokes it from the deployer.
# Input: script/input/{chainId}/transfer-{chain}-{env}.json
#        (admin, accessControls, allocator, backstopAllocator, allocatorAdmin)
#
# Run AFTER configure.

# Mainnet

transfer-roles-mainnet-production:
	CHAIN=mainnet ENV=production forge script script/2-TransferRoles.s.sol:TransferRoles \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(MAINNET_RPC_URL)

transfer-roles-mainnet-staging:
	CHAIN=mainnet ENV=staging forge script script/2-TransferRoles.s.sol:TransferRoles \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(MAINNET_RPC_URL)
