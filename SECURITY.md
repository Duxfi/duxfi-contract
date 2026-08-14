# Security Policy

## Overview

DuxFi is a DeFi learning and experimentation platform that enables users to explore decentralized finance concepts in a safe environment.

The current deployment runs on public test networks and does not involve real user funds or assets.

DuxFi smart contracts are developed with a focus on transparency, security best practices, and continuous improvement.

---

## Testnet Disclaimer

The current version of DuxFi is deployed on testnet environments only.

Please note:

- All tokens are test tokens with no monetary value
- No real funds or valuable assets are involved
- Smart contracts are provided for educational and research purposes
- Users should not expect financial returns from interacting with the protocol
- Testnet deployments may contain bugs or incomplete features

---

## Security Practices

Although the current deployment is testnet-only, DuxFi follows established smart contract development practices:

- Solidity development using Foundry
- Automated testing with Foundry test framework
- Static security analysis using Slither
- Usage of OpenZeppelin security libraries
- Access control mechanisms
- Emergency pause functionality where applicable
- Code review and continuous security improvements

---

## Security Analysis

DuxFi performs automated security analysis during development.

Current security tools include:

- Slither static analyzer
- Foundry unit and integration tests

Latest automated analysis report:

- [Slither Report](slither-report.md)

The automated reports are used to identify potential security issues and improve code quality. Some findings may be false positives or intentional design decisions and are reviewed accordingly.

---

## Reporting a Vulnerability

Please do not publicly disclose security vulnerabilities through GitHub Issues.

If you discover a potential security issue, please report it privately.

You can submit a private vulnerability report:

https://github.com/duxfi/dux-swap-contracts/security/advisories/new

When reporting a vulnerability, please include:

- Vulnerability description
- Affected contract or function
- Steps to reproduce
- Potential impact
- Any suggested mitigation

We appreciate responsible disclosure and will review all security reports carefully.

---

## Supported Versions

| Version | Status | Network |
|---------|--------|---------|
| main | Active | Sepolia Testnet |
| development | Active | Local Anvil |

---

## Audits

DuxFi has not completed a formal third-party security audit at this stage.

The current deployment operates on testnet without real asset exposure.

Before any future mainnet deployment involving real assets, additional security reviews and independent audits will be considered.

---

## Responsible Disclosure

Security researchers and community members are encouraged to report issues responsibly.

We appreciate contributions that help improve the security, reliability, and transparency of the DuxFi protocol.

Thank you for helping us build a safer decentralized finance ecosystem.