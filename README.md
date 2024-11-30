# TimeCapsule 🕰️🔒

## Overview

TimeCapsule is a decentralized, secure time-locked asset vault built on the Stacks blockchain. It allows users to lock their STX tokens for a predetermined period, providing a robust mechanism for long-term asset management, controlled fund release, and beneficiary-based asset protection.

## 🌟 Key Features

### Time-Locked Asset Management
- Lock STX tokens for a customizable duration
- Minimum lock period: 1 day
- Maximum lock period: 1 year
- Flexible lock duration controls

### Beneficiary System
- Optional beneficiary nomination
- Fallback mechanism for asset recovery
- Grace period for beneficiary claims
- Secure beneficiary status management

### Advanced Vault Controls
- Extend lock periods
- Update beneficiary details
- Deposit and withdraw functionality
- Activity tracking and vault management

## 🛡️ Security Mechanisms

- Strict validation for lock periods
- Beneficiary status tracking
- Comprehensive error handling
- Contract-level access controls
- Immutable vault creation rules

## 🚀 Core Functions

### Vault Creation
```clarity
(create-vault 
  (lock-duration uint) 
  (beneficiary (optional principal)) 
  (grace-period uint)
)
```

### Key Operations
- `deposit-stx`: Add funds to vault
- `withdraw-stx`: Withdraw after unlock period
- `extend-lock-period`: Prolong vault duration
- `update-beneficiary`: Change beneficiary details
- `claim-as-beneficiary`: Claim funds as nominated beneficiary

## 📋 Usage Scenarios

1. **Personal Savings Vault**
   - Lock STX for future financial goals
   - Set a long-term saving commitment

2. **Inheritance Planning**
   - Nominate a beneficiary
   - Ensure asset transfer if original owner is inactive

3. **Investment Lockup**
   - Prevent impulsive withdrawals
   - Enforce disciplined investment strategy

## 🔍 Technical Details

- **Blockchain**: Stacks
- **Language**: Clarity Smart Contract
- **Token Support**: STX (expandable)
- **Minimum Lock**: 1 day (144 blocks)
- **Maximum Lock**: 1 year (52,560 blocks)

## 🛠️ Installation & Deployment

### Requirements
- Stacks Wallet
- Web3 Compatibility
- Clarity Smart Contract Support

### Deployment Steps
1. Compile the Clarity contract
2. Deploy to Stacks blockchain
3. Interact via compatible wallet or interface

## ⚠️ Considerations

- Double-check lock periods
- Carefully select beneficiaries
- Understand grace period mechanics
- Keep track of vault activity

## 🔮 Future Roadmap
- Multi-token support
- Enhanced beneficiary features
- Improved activity tracking
- Potential integrations with DeFi protocols

## 🤝 Contributing
Contributions, issues, and feature requests are welcome!

## 💡 Disclaimer
 Always review and understand smart contract mechanics before deployment.