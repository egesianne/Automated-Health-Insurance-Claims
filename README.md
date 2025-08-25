# 🏥 Automated Health Insurance Claims (AHIC)

A smart contract system for automated health insurance claim processing on the Stacks blockchain, designed to reduce fraud and streamline claim payments.

## 🚀 Features

- **Automated Claims Processing**: Smart contract automatically validates and processes insurance claims
- **Fraud Prevention**: Built-in fraud scoring system for medical providers
- **Policy Management**: Complete policy lifecycle management with premiums and coverage limits
- **Provider Verification**: Medical provider registration and verification system
- **Real-time Payouts**: Instant claim payouts upon verification
- **Transparent Operations**: All transactions recorded on blockchain for auditing

## 📋 Contract Overview

The AHIC smart contract manages:

- **Insurance Policies**: Registration, activation, and management
- **Medical Providers**: Registration, verification, and fraud monitoring  
- **Claims Processing**: Submission, verification, and automated payouts
- **Fund Management**: Contract funding and emergency controls

## 🛠️ Usage Instructions

### For Insurance Companies

#### 1. Fund the Contract
```clarity
(contract-call? .AHIC fund-contract u1000000000)
```

#### 2. Verify Medical Providers
```clarity
(contract-call? .AHIC verify-provider 'SP1234...PROVIDER)
```

#### 3. Process Claims
```clarity
(contract-call? .AHIC verify-claim u1)
(contract-call? .AHIC process-claim u1)
```

### For Policy Holders

#### 1. Register Insurance Policy
```clarity
(contract-call? .AHIC register-policy u5000000 u50000000 u1000000 u52560)
```
Parameters: premium, coverage-limit, deductible, duration-blocks

#### 2. Submit Claims
```clarity
(contract-call? .AHIC submit-claim u1 'SP5678...PROVIDER u5000000 "A01.1" u1234567)
```
Parameters: policy-id, provider, amount, diagnosis-code, treatment-date

### For Medical Providers

#### 1. Register as Provider
```clarity
(contract-call? .AHIC register-provider "Dr. Smith Clinic" "MD-12345")
```

## 📊 Query Functions

### Policy Information
```clarity
(contract-call? .AHIC get-policy u1)
(contract-call? .AHIC get-policy-usage u1)
```

### Claim Information
```clarity
(contract-call? .AHIC get-claim u1)
(contract-call? .AHIC get-claim-status u1)
(contract-call? .AHIC calculate-payout u1)
```

### Provider Information
```clarity
(contract-call? .AHIC get-provider 'SP1234...PROVIDER)
(contract-call? .AHIC get-provider-stats 'SP1234...PROVIDER)
```

### Contract Statistics
```clarity
(contract-call? .AHIC get-contract-stats)
(contract-call? .AHIC get-user-claims-count 'SP9876...USER)
```

## 🔒 Security Features

- **Access Control**: Only contract owner can verify providers and claims
- **Fraud Detection**: Automatic fraud scoring for providers
- **Claim Validation**: Multiple validation checks before processing
- **Time Limits**: Claims expire after specified block period
- **Coverage Limits**: Enforced policy coverage limits
- **Emergency Controls**: Owner emergency withdrawal capabilities

## 💰 Financial Model

- **Premiums**: Set during policy registration
- **Deductibles**: Subtracted from claim payouts
- **Coverage Limits**: Maximum payout per policy
- **Fraud Thresholds**: Automatic provider blocking based on fraud scores

## 🧪 Testing

Run the contract tests:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 📝 Contract Constants

| Constant | Value | Description |
|----------|--------|-------------|
| `CLAIM_EXPIRY_BLOCKS` | 1008 | Blocks until claim expires (≈1 week) |
| `MIN_CLAIM_AMOUNT` | 1,000,000 | Minimum claim amount (10 STX) |
| `MAX_CLAIM_AMOUNT` | 100,000,000 | Maximum claim amount (1,000 STX) |
| `FRAUD_THRESHOLD` | 5 | Maximum fraud score for providers |

## 🔧 Development Setup

1. Install Clarinet
2. Clone repository
3. Navigate to project directory
4. Run `clarinet check` to validate contracts
5. Use `clarinet console` for interactive testing

## 📈 Workflow

1. **Setup**: Insurance company funds contract and verifies providers
2. **Policy Creation**: Users register insurance policies with premiums
3. **Claim Submission**: Policy holders submit claims through verified providers
4. **Verification**: Insurance company verifies claim legitimacy
5. **Automated Payout**: Smart contract automatically processes payment
6. **Monitoring**: Continuous fraud monitoring and policy management

## 🛡️ Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100 | Unauthorized | Caller lacks required permissions |
| 101 | Claim Not Found | Claim ID does not exist |
| 102 | Invalid Claim | Claim data is invalid |
| 103 | Claim Expired | Claim submission deadline passed |
| 104 | Insufficient Funds | Contract lacks funds for payout |
| 105 | Already Processed | Claim has been processed |
| 106 | Invalid Provider | Provider not verified |
| 107 | Policy Not Active | Policy is inactive or expired |
| 108 | Amount Exceeded | Claim exceeds coverage limit |

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes and test thoroughly
4. Submit pull request with detailed description

## 📄 License

MIT License - see LICENSE file for details
