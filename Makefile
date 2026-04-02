# Mainnet
wire-mainnet-staging:
	CHAIN=mainnet ENV=staging forge script script/WireFacets.s.sol:WireFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(MAINNET_RPC_URL)

wire-mainnet-production:
	CHAIN=mainnet ENV=production forge script script/WireFacets.s.sol:WireFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(MAINNET_RPC_URL)

# Base
wire-base-staging:
	CHAIN=base ENV=staging forge script script/WireFacets.s.sol:WireFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(BASE_RPC_URL)

wire-base-production:
	CHAIN=base ENV=production forge script script/WireFacets.s.sol:WireFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(BASE_RPC_URL)

# Arbitrum One
wire-arbitrum-staging:
	CHAIN=arbitrum_one ENV=staging forge script script/WireFacets.s.sol:WireFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(ARBITRUM_ONE_RPC_URL)

wire-arbitrum-production:
	CHAIN=arbitrum_one ENV=production forge script script/WireFacets.s.sol:WireFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(ARBITRUM_ONE_RPC_URL)

# Avalanche
wire-avalanche-staging:
	CHAIN=avalanche ENV=staging forge script script/WireFacets.s.sol:WireFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(AVALANCHE_RPC_URL)

wire-avalanche-production:
	CHAIN=avalanche ENV=production forge script script/WireFacets.s.sol:WireFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --rpc-url $(AVALANCHE_RPC_URL)
