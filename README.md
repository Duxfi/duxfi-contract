# DuxFi.com Contracts

[![Foundry](https://img.shields.io/badge/framework-Foundry-blueviolet.svg)](https://book.getfoundry.sh/)

> Part of the [DuxFi](duxfi.com) ecosystem - A DeFi simulation platform running on Base Sepolia testnet.

A decentralized exchange (DEX) smart contract developed based on the Foundry framework, implementing Uniswap V2-like Automated Market Maker (AMM) functionality.

**⚠️ Important**: This project runs on Base Sepolia testnet. All tokens are test tokens with no real value. This is an educational platform for learning DeFi concepts.

## Features

- **Token Swapping**: Support multi-path token swaps (e.g., USDT → ETH → DUX)
- **Liquidity Management**: Add/remove liquidity, LP token minting and burning
- **Trading Fees**: Configurable fees (0.3% default, up to 1% max)
- **TWAP Oracle**: Built-in Time-Weighted Average Price (TWAP) oracle
- **Faucet**: Daily test token claiming for developer testing
- **Security Mechanisms**: Reentrancy lock, pause functionality, access control


## Project Structure

```
duxfi-contract/
├── src/dex/
│   ├── core/                          # Core contracts
│   │   ├── DuCoin.sol                 # Project token (ERC20 + mintable)
│   │   ├── DuxFactory.sol             # Factory - create and manage pairs
│   │   ├── DuxPair.sol                # Pair - AMM core logic (mint/burn/swap/TWAP)
│   │   ├── interfaces/
│   │   │   ├── IDuxCallee.sol         # Flashswap callback interface
│   │   │   ├── IDuxFactory.sol        # Factory interface
│   │   │   └── IDuxPair.sol           # Pair interface
│   │   └── libraries/
│   │       └── Math.sol               # Math operations for core
│   ├── libraries/
│   │   └── FixedPoint.sol             # Fixed-point arithmetic (uq112x112)
│   └── periphery/                     # Periphery contracts
│       ├── DuxRouter.sol              # Router - user entry (add/remove liq, swap)
│       ├── DuxFaucet.sol              # Faucet - test token distribution
│       ├── interfaces/
│       │   └── IDuxRouter.sol         # Router interface
│       └── libraries/
│           ├── DuxLibrary.sol         # Router helpers (getAmountOut/In, sortTokens)
│           └── DuxTWAPOracleLibrary.sol # TWAP price oracle helper
├── script/dex/
│   ├── DeployCoreContracts.s.sol      # Deploy DuxFactory, DuxRouter, DuxFaucet
│   ├── DeployTokens.s.sol             # Deploy test tokens (USDC, USDT, DUX, BTC, ...)
│   ├── DeploySingleToken.s.sol        # Deploy a single DuCoin token
│   └── DeployAddTokensToFaucet.s.sol  # Add a token to DuxFaucet
├── test/dex/
│   ├── unit/                          # Unit tests
│   │   ├── Ducoin.t.sol
│   │   ├── DuxFactory.t.sol
│   │   ├── DuxFaucet.t.sol
│   │   ├── DuxPair.t.sol              # Pair baseline
│   │   ├── DuxPair.admin.t.sol        # Pair admin (fee setter, pause)
│   │   ├── DuxPair.mint.t.sol         # add liquidity
│   │   ├── DuxPair.burn.t.sol         # remove liquidity
│   │   ├── DuxPair.swap.t.sol         # swap
│   │   ├── DuxPairAmm.t.sol           # AMM math
│   │   ├── DuxRouter.t.sol            # Router baseline
│   │   ├── DuxRouter.addLiquidity.t.sol
│   │   ├── DuxRouter.removeLiquidity.t.sol
│   │   └── DuxRouter.swap.t.sol
│   ├── integration/                   # Integration tests
│   │   ├── DuxIntegrationTest.t.sol
│   │   └── DuxEdgeCaseIntegrationTest.t.sol
│   ├── fuzz/                          # Fuzz / invariant tests
│   │   ├── DuxPairFuzz.t.sol
│   │   └── DuxRouterFuzz.t.sol
│   ├── mocks/
│   │   └── MockERC.sol                # Mock ERC20 for tests
│   ├── shared/
│   │   └── fixtures/                  # Reusable test fixtures
│   │       ├── BaseFixture.sol
│   │       ├── EventFixture.sol
│   │       ├── LiquidityFixture.sol
│   │       └── RouterFixture.sol
│   └── utils/
│       └── SwapLib.sol                # Test helpers for swaps
├── frontend/                          # Frontend configuration
│   └── abis/                          # ABI files
└── broadcast/                         # Deployment broadcast records
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
- `claimDaily()` - Claim all enabled tokens at once (configurable cooldown, default 24h)
- `addToken(token, dailyAmount)` - Admin add a token to the claimable list (max 50 tokens)
- `updateToken(token, dailyAmount, enabled)` - Admin update token amount / enable-disable
- `removeToken(token)` - Admin remove a token from the list
- `getTokens()` - Query all configured tokens
- `setCooldown(newCooldown)` - Admin set claim cooldown (max 30 days)
- `pause() / unpause()` - Emergency stop / resume

**Events:**
- `TokenAdded(token, dailyAmount)`
- `TokenUpdated(token, dailyAmount, enabled)`
- `TokenRemoved(token)`
- `TokenClaimed(user, timestamp, tokens[], amounts[])` - aggregated event per claim
- `CooldownChanged(oldCooldown, newCooldown)`

**Features:**
- Cooldown based on blockchain timestamp (default 24h, configurable)
- Multi-token claiming in a single transaction
- Admin can dynamically configure token list and claim limits
- ReentrancyGuard + Pausable + Ownable access control
- ETH and ERC20 recovery via `withdrawETH()` / `withdrawERC20()`

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

# Base Sepolia RPC
SEPOLIA_RPC_URL=https://base-sepolia.publicnode.com

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

### Quick Start with Makefile

The project provides Makefile targets for common deployment flows. All commands
read RPC and Etherscan keys from `.env` based on the `NET` selector.

```bash
# Start a local Anvil node (state persisted to ./anvil-state.json)
make a

# Fund deployer and gas wallet from Anvil account 0
make a-setup

# Deploy everything (Factory + Router + Faucet + Tokens) to local
make a-d
make a-d-faucet   # then add tokens to faucet (requires FAUCET_ADDRESS/TOKEN_ADDRESS/DAILY_AMOUNT)

# Deploy only DuxFaucet (does not touch Factory/Router)
make deploy-faucet NET=local
make deploy-faucet NET=sepolia VERIFY=1
make deploy-faucet NET=base-sepolia VERIFY=1

# Add a token to an existing Faucet (human-readable amount + decimals)
make faucet-add-token \
  NET=local \
  FAUCET_ADDRESS=0x... \
  TOKEN_ADDRESS=0x... \
  TOKEN_DECIMAL=6 \
  AMOUNT_UNIT=10000
```

### Manual Deployment (forge script / forge create)

```bash
# 1. Start anvil node (delete existing state file if any)
rm ./anvil-state.json
anvil --state ./anvil-state.json --port 9000 --block-time 12

# 2. Deploy core contracts (DuxFactory, DuxRouter, DuxFaucet)
forge script script/dex/DeployCoreContracts.s.sol:DeployCoreContracts \
  --rpc-url http://localhost:9000 --private-key $DU_DEPLOY_PRIVATE_KEY --broadcast -vv

# 3. Deploy test tokens (USDC, USDT, DUX, BTC, ETH, SOL, DAI, LINK, OKB)
forge script script/dex/DeployTokens.s.sol:DeployTokens \
  --rpc-url http://localhost:9000 --private-key $DU_DEPLOY_PRIVATE_KEY --broadcast -vv

# 4. Add a token to the faucet (tokenDecimal + amountUnit, raw amount computed inside)
forge script script/dex/DeployAddTokensToFaucet.s.sol \
  --sig "run(address,address,uint256,uint256)" \
  $FAUCET_ADDRESS $TOKEN_ADDRESS 6 10000 \
  --rpc-url http://localhost:9000 --private-key $DU_DEPLOY_PRIVATE_KEY --broadcast -vv
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