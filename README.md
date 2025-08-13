# SolvBTC Rate Provider

SolvBTC Rate Provider is an Ethereum-based smart contract system that provides real-time exchange rate information for SolvBTC tokens. The system obtains reserve data through Chainlink oracles and calculates accurate exchange rates by combining total supply and total value locked (TVL).

## Core Features

### Exchange Rate Main Mechanism

#### 1. Exchange Rate Calculation Logic
- **Basic Formula**: `Exchange Rate = Total TVL / Total Supply`
- **Precision Factor**: Uses 18 decimal precision (1e18)
- **Rate Range**: Limited between 0.95 - 1.05 to ensure exchange rates fluctuate within reasonable bounds

#### 2. Data Validation Mechanism
- **Reserve Data Validation**: Obtains BTC reserve prices through Chainlink oracles
- **Difference Threshold Check**: Validates whether the difference between oracle data and incoming TVL is within allowed ranges
- **Exception Handling**: Issues alert events and returns the last valid exchange rate when data is abnormal

#### 3. Permission Management
- **Owner**: Can set reserve oracle addresses, updater addresses, and maximum difference percentages
- **Updater**: Only designated updaters can call exchange rate update functions
- **Upgradability**: Supports contract upgrades using OpenZeppelin's upgradeable contract pattern

#### 4. Event System
- `ReserveFeedSet`: Reserve oracle address setting event
- `UpdaterSet`: Updater address setting event
- `MaxDifferencePercentSet`: Maximum difference percentage setting event
- `AlertInvalidReserve`: Invalid reserve data alert
- `AlertInvalidReserveDifference`: Reserve difference too large alert
- `AlertInvalidRate`: Invalid exchange rate alert
- `LatestRateUpdated`: Latest exchange rate update event

## Technical Architecture

### Contract Features
- **Solidity Version**: ^0.8.0
- **Storage Pattern**: Uses EIP-1967 storage slots to avoid storage conflicts
- **Dependency Libraries**: OpenZeppelin contract libraries, Chainlink oracle interfaces
- **Mathematical Calculations**: Uses OpenZeppelin Math library for safe mathematical operations

### Key Constants
- `RATE_PRECISION_FACTOR`: 1e18 (18 decimal precision)
- `MIN_RATE`: 0.95 (minimum exchange rate)
- `MAX_RATE`: 1.05 (maximum exchange rate)

## Development Environment Setup

### System Requirements
- Node.js 16+
- npm or yarn
- Git

### Installation Steps

1. **Clone the Project**
```bash
git clone <repository-url>
cd SolvBTCRateProvider
```

2. **Install Dependencies**
```bash
npm install
```

3. **Install Foundry (Optional, for advanced testing)**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Environment Configuration

The project supports two development environments:

#### Hardhat Environment
- Default Solidity version: 0.8.28
- Integrated Foundry support
- TypeScript configuration support

#### Foundry Environment
- Source directory: `contracts/`
- Output directory: `out/`
- Test directory: `test/`
- Cache directory: `cache_forge/`

### Running Tests with Foundry

1. **Run All Tests**
```bash
forge test
```

2. **Run Specific Test File**
```bash
forge test --match-path test/SolvBTCRateProvider.t.sol
```

3. **Run Tests with Detailed Logs**
```bash
forge test -vvv
```

4. **Run Tests and Generate Coverage Report**
```bash
forge coverage
```

5. **Run Specific Test Function**
```bash
forge test --match-test testFunctionName
```

### Test File Structure

Test files are located in the `test/` directory:
- `SolvBTCRateProvider.t.sol`: Main contract test file
- Includes unit tests, integration tests, and boundary condition tests

### Test Coverage Scope

Tests cover the following main functionalities:
- Contract initialization and configuration
- Exchange rate update logic
- Data validation mechanisms
- Permission control
- Exception handling
- Event trigger validation

## Deployment Instructions

### Pre-deployment Preparation
1. Ensure sufficient ETH for gas fees
2. Prepare Chainlink oracle addresses
3. Set updater addresses
4. Configure maximum difference percentages

### Deployment Steps
1. Compile contracts
2. Deploy proxy contracts
3. Initialize contract parameters
4. Verify contract functionality

## Security Considerations

- Uses OpenZeppelin's audited contract libraries
- Implements permission control mechanisms
- Data validation and exception handling
- Supports contract upgrades to fix potential issues

## Contributing Guidelines

Welcome to submit Issues and Pull Requests to improve the project.

## License

This project is licensed under the MIT License.
