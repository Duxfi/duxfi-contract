# DuxFi.com Contracts

[![Foundry](https://img.shields.io/badge/framework-Foundry-blueviolet.svg)](https://book.getfoundry.sh/)

> Part of the [DuxFi](duxfi.com) ecosystem - A DeFi simulation platform running on Base Sepolia testnet.

A decentralized exchange (DEX) smart contract developed based on the Foundry framework, implementing Uniswap V2-like Automated Market Maker (AMM) functionality.

**⚠️ Important**: This project runs on Sepolia testnet. All tokens are test tokens with no real value. This is an educational platform for learning DeFi concepts.

## Features

- **Token Swapping**: Support multi-path token swaps (e.g., USDT → ETH → DUX)
- **Liquidity Management**: Add/remove liquidity, LP token minting and burning
- **Trading Fees**: Configurable fees (0.3% default, up to 1% max)
- **TWAP Oracle**: Built-in Time-Weighted Average Price (TWAP) oracle
- **Faucet**: Daily test token claiming for developer testing
- **Security Mechanisms**: Reentrancy lock, pause functionality, access control


## Project Structure

```
dux_contract/
├── src/
│   ├── core/              # Core contracts
│   │   ├── DuxFactory.sol # Factory contract - create and manage pairs
│   │   ├── DuxPair.sol    # Pair contract - AMM core logic
│   │   ├── DuCoin.sol     # Project token
│   │   └── interfaces/    # Interface definitions
│   ├── periphery/         # Periphery contracts
│   │   ├── DuxRouter.sol  # Router contract - user interaction entry
│   │   ├── DuxFaucet.sol  # Faucet contract - test token distribution
│   │   └── libraries/     # Utility libraries
│   └── libraries/         # Shared libraries
│       ├── FixedPoint.sol # Fixed point arithmetic
│       └── Math.sol       # Math operations
├── script/                # Deployment scripts
│   ├── DeployCores.s.sol  # Deploy core contracts
│   ├── DeployTokens.s.sol # Deploy test tokens
│   └── ConfigureDuxFaucet.s.sol
├── test/                  # Test files
│   ├── unit/              # Unit tests
│   ├── integration/        # Integration tests
│   └── fuzz/              # Fuzz tests
├── frontend/               # Frontend configuration
│   └── abis/              # ABI files
└── broadcast/             # Deployment broadcast records
```

## Core Contracts

### DuxFactory
Factory contract responsible for creating and managing all trading pairs.

**Main Features:**
- `createPair()` - Create new trading pair
- `pausePair() / unpausePair()` - Pause/resume trading pair
- `getPair()` - Query pair address
- Support batch pause operations

### DuxPair
Trading pair contract implementing AMM core logic.

**Main Features:**
- `mintLpToken()` - Mint LP tokens (add liquidity)
- `burnLpToken()` - Burn LP tokens (remove liquidity)
- `swap()` - Token swap
- `getReserves()` - Get reserves
- `getCumulativePrices()` - Get TWAP prices

**Security Features:**
- Reentrancy lock protection
- Pause functionality
- K value verification (anti-liquidity attack)
- Minimum liquidity lock

### DuxRouter
Router contract, the main entry point for user interaction.

**Main Features:**
- `addLiquidity()` - Add liquidity
- `removeLiquidity()` - Remove liquidity
- `swapExactTokensForTokens()` - Multi-path token swap (up to 5 hops)
- `currentCumulativePrices()` - Get current cumulative prices

### DuCoin
Project governance token.

### DuxFaucet
Test faucet contract for distributing test tokens to facilitate user interaction on DuxFi.com.

**Main Features:**
- `claimDaily()` - Claim daily test tokens (24-hour cooldown)
- `setTokens()` - Admin set claimable tokens and daily limits
- `removeToken()` - Admin remove token
- `getTokens()` - Query all claimable tokens

**Features:**
- 24-hour cooldown based on blockchain timestamp
- Support multi-token claiming
- Admin can dynamically configure token list and claim limits

## Environment Requirements

- [Foundry](https://book.getfoundry.sh/) (including forge, cast, anvil)
- Node.js 18+ (for frontend build)

## Installation

```bash
# Install dependencies
make install

# Or install manually
forge install cyfrin/foundry-devops@0.1.0 --no-commit
forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
forge install foundry-rs/forge-std@v1.5.3 --no-commit
forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit
```

## Configuration

Create `.env` file:

```env
# Deployment private key (use dedicated test account)
DU_DEPLOY_PRIVATE_KEY=0x...
DU_DEPLOY_ADDRESS=0x...

# Gas fee payment account
DU_GAS_WALLET_PUBLIC_ADDRESS=0x...

# Sepolia RPC
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_API_KEY

# Etherscan verification
ETHERSCAN_API_KEY=YOUR_API_KEY

# Anvil test account
ANVIL_ACCOUNT_0_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Commands

### Basic Commands

```bash
make build      # Compile contracts
make test       # Run tests
make format     # Format code
make clean      # Clean build artifacts
make cov        # Generate test coverage report
```

## Deployment
### Development Environment Anvil Deployment Process
```bash
# 1 Start anvil node (use --state parameter to specify state file)
# delete existing state file if any
rm ./anvil-state.json
#start local anvil node and save chain state
@anvil --state ./anvil-state.json --port http://localhost:8545
# deploy contracts
@echo "Transferring 1000 ETH to deployer...$(DU_DEPLOY_ADDRESS)"
@cast send $(DU_DEPLOY_ADDRESS) --value 1000ether --private-key $(ANVIL_ACCOUNT_0_PRIVATE_KEY) --rpc-url $(LOCAL_RPC_URL_9000) -vvvv
@echo "Transferring 900 ETH to gas wallet...$(DU_GAS_WALLET_PUBLIC_ADDRESS)"
@cast send $(DU_GAS_WALLET_PUBLIC_ADDRESS) --value 900ether --private-key $(ANVIL_ACCOUNT_0_PRIVATE_KEY) --rpc-url http://localhost:8545 -vvvv
```
### Export ABI Creation
```bash
# must deploy contracts first and then run this command to generate new ABI files
node extractAbi.cjs DuxPair DuxRouter DuxFactory DuxFaucet DuCoin
```


## Testing

### Basic Commands

```bash
# Run all tests
forge test

# Run specific test type
forge test --match-path "test/unit/*"      # Unit tests
forge test --match-path "test/integration/*" # Integration tests
forge test --match-path "test/fuzz/*"     # Fuzz tests
```

### Fuzz Testing

This project includes comprehensive fuzz testing to ensure robustness against unexpected inputs:

| Contract | Test Cases | Coverage |
|----------|------------|----------|
| DuxPair | mintLpToken, Swap, BurnLPToken | Core AMM logic |
| DuxRouter | addLiquidity, removeLiquidity, swapExactTokensForTokens | Router operations |

**Run Fuzz Tests:**
```bash
# Run all fuzz tests
forge test --match-path "test/fuzz/*" -vvv

# Run specific fuzz test
forge test --match-contract DuxPairFuzzTest -vvv
```

**Security Features Tested:**
- **Input Boundaries**: Input values constrained to safe ranges (1e6 ~ 1e25)
- **Edge Cases**: Empty pool initialization, partial/complete LP burning
- **Error Handling**: Graceful handling of invalid inputs and revert conditions
- **State Consistency**: Verification of reserves, balances, and supply after operations

## Security Features

1. **Reentrancy Protection**: Using ReentrancyGuard
2. **Pause Mechanism**: Pausable for emergency stop
3. **Access Control**: Ownable pattern
4. **K Value Verification**: Prevent malicious attacks
5. **Minimum Liquidity Lock**: 1000 LP tokens permanently locked

## Fee Structure

| Action | Fee |
|--------|-----|
| Token Swap | 0.3% (default, configurable up to 1%) |
| Add Liquidity | None |
| Remove Liquidity | None |

## License

MIT