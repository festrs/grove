# Grove

A passive income planner for Brazilian investors following the [Bastter](https://bastter.com) philosophy.

Grove helps you manage holdings across multiple asset classes (Ações BR, FIIs, US Stocks, REITs, Crypto, Renda Fixa), track dividend income, project passive income toward financial independence, and get monthly rebalancing recommendations.

## Features

- **Portfolio Management** — Organize holdings by asset class with target allocations
- **Rebalancing Engine** — Two-tier rebalancing (class allocations + per-holding weights) with monthly buy recommendations
- **Dividend Tracking** — Calendar view of upcoming payments and income history
- **Income Projection** — Project passive income growth toward your financial independence goal
- **Tax Calculator** — Brazilian tax rules for stocks, FIIs, and other asset types
- **iCloud Sync** — SwiftData persistence with automatic iCloud synchronization

## Requirements

- iOS 26.0+
- Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [just](https://github.com/casey/just) — `brew install just` (task runner)

## Getting Started

```bash
# Clone
git clone https://github.com/festrs/tranquilidade.git
cd tranquilidade

# Generate the Xcode project
xcodegen generate

# Create your secrets file (add your BRAPI_TOKEN)
cp Secrets.example Secrets.xcconfig

# Build
just build
```

## Common Commands

```bash
just build              # generate project + build
just test               # run all unit tests
just test-only <Name>   # run a specific test struct
just clean              # remove DerivedData
just rebuild            # clean + generate + build
just simulator          # show which simulator will be used
just --list             # list all recipes
```

## Architecture

- **Pattern:** MVVM with `@Observable` ViewModels
- **Persistence:** SwiftData with iCloud sync
- **Networking:** All API calls go through a FastAPI backend (no direct external calls from the app)
- **Design System:** Custom `TQ`-prefixed components, dark-mode only
- **Testing:** Swift Testing framework with TDD approach

## Backend

The companion backend lives in a separate repository (`project-fin`) — FastAPI + SQLAlchemy + SQLite, deployed via Docker with a Cloudflare tunnel.

## License

Private project.
