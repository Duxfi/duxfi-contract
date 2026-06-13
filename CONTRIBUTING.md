# Contributing to DuxSwap Contracts

Thank you for your interest in contributing to DuxSwap smart contracts!

## Project Overview

DuxSwap is a decentralized exchange smart contract implementing Uniswap V2-like AMM functionality. It is part of the [DuxFi](https://duxfi.com) ecosystem - a DeFi simulation platform on Sepolia testnet.

## Development Setup

### Requirements

- [Foundry](https://book.getfoundry.sh/) (forge, cast, anvil)
- Git
- Node.js 18+ (optional, for frontend)

### Quick Start

```bash
# Install dependencies
make install

# Build contracts
make build

# Run tests
make test

# Format code
make format
```

## Contribution Guidelines

### Code Style

- Solidity code follows the [Solidity style guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Use `forge fmt` to format code before committing
- All contracts should include NatSpec documentation

### Testing

- All new features must include tests
- Run `make test` to execute the full test suite
- Aim for comprehensive test coverage of new code
- Run `make cov` to check coverage

```bash
# Run specific test file
forge test --match-path test/unit/DuxPair.t.sol

# Run with verbose output
forge test -vvv
```

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb (Add, Fix, Update, Remove)
- Reference issues when applicable

### Pull Request Process

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes with passing tests
4. Ensure code is formatted (`make format`)
5. Submit a pull request with description

## Security

- Do NOT commit sensitive data or private keys
- All `.env` files are gitignored
- Follow the security patterns used in existing code
- For security issues, see [SECURITY.md](./SECURITY.md)

## License

By contributing, you agree that your contributions will be licensed under the ISC License.