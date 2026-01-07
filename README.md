# Cheese Mints

A Lua smart contract for the AO (Arweave) ecosystem that manages a collection of achievement badges called "Cheese Mints". Cheese Mints can be created, updated, and awarded to addresses with role-based access control.

## Overview

Cheese Mints are on-chain achievements that can be awarded to users. Each Cheese Mint has:

- Name (up to 250 characters)
- Description (up to 1000 characters)
- Points value
- Icon (Arweave transaction ID)
- Category

The contract supports both individual and bulk awarding of Cheese Mints to addresses.

## Prerequisites

- Node.js 24+
- npm
- [Busted](https://lunarmodules.github.io/busted/) (for running Lua tests)

## Installation

```bash
npm install
```

## Scripts

### Bundle Lua Contracts

Bundles Lua source files into deployable contract files:

```bash
npm run bundle
```

Output is written to `dist/collection/process.lua`.

### Run Tests

Bundles contracts and runs the Lua test suite:

```bash
npm test
```

### Clean Build Artifacts

```bash
npm run clean
```

## Deployment

### Environment Variables

Create a `.env` file with the following variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PROCESS_NAME` | Name for the AO process | (required) |
| `PROCESS_SOURCE_PATH` | Path to bundled Lua source | (required) |
| `DEPLOYER_PRIVATE_KEY_PATH` | Path to Arweave wallet JWK | (required) |
| `APP_NAME` | Application name tag | `Cheese-Mint` |
| `SCHEDULER` | AO scheduler address | `_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA` |
| `AUTHORITY` | Authority address | `fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY` |
| `AOS_MODULE_ID` | AO module ID | `ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s` |
| `CALL_INIT_HANDLER` | Call init handler after spawn | `false` |
| `INIT_DATA_PATH` | Path to init data JSON | (required if `CALL_INIT_HANDLER=true`) |
| `INIT_DELAY_MS` | Delay before init call | `30000` |

### Spawn a New Process

```bash
npx tsx scripts/spawn.ts
```

### Send Action Messages

```bash
npx tsx scripts/send-action-message.ts
```

### View State (Dry Run)

```bash
npx tsx scripts/dryrun-view-state.ts
```

## Docker

Build and run using Docker:

```bash
docker build -t cheese-mints .
```

The Dockerfile uses a multi-stage build:
1. Builder stage: Installs dependencies and bundles Lua contracts
2. Runtime stage: Minimal image with production dependencies and bundled output

## Contract Handlers

### Role Management

- `Update-Roles` - Update access control roles
- `View-Roles` - View current role assignments

### Cheese Mint Management

- `Create-Cheese-Mint` - Create a new Cheese Mint definition
- `Update-Cheese-Mint` - Update an existing Cheese Mint
- `Remove-Cheese-Mint` - Remove a Cheese Mint from the collection

### Awarding

- `Award-Cheese-Mint` - Award a Cheese Mint to an address
- `Bulk-Award-Cheese-Mint` - Award multiple Cheese Mints to multiple addresses
- `Revoke-Cheese-Mint` - Revoke a Cheese Mint from an address

## Access Control

The contract uses role-based access control. Available roles:

- `owner` - Full access to all handlers
- `admin` - Full access to all handlers
- Handler-specific roles (e.g., `Create-Cheese-Mint`, `Award-Cheese-Mint`)

## Project Structure

```
cheese-mints/
├── src/
│   └── contracts/
│       ├── collection/
│       │   └── collection.lua    # Main contract
│       └── common/
│           └── acl.lua           # Access control module
├── spec/
│   ├── collection/
│   │   └── init.spec.lua         # Contract tests
│   ├── hyper-aos.lua
│   └── setup.lua
├── scripts/
│   ├── bundle.ts                 # Lua bundler script
│   ├── spawn.ts                  # Deploy new AO process
│   ├── send-action-message.ts    # Send messages to process
│   ├── dryrun-view-state.ts      # Query process state
│   ├── publish-view.ts
│   └── util/
│       ├── lua-bundler.ts
│       └── send-aos-message.ts
├── Dockerfile
├── package.json
└── tsconfig.json
```

## License

AGPL-3.0
