# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Grove is a Brazilian investment portfolio tracker iOS app. It helps investors following the Bastter philosophy manage holdings across asset classes (Ações BR, FIIs, US Stocks, REITs, Crypto, Renda Fixa), track dividend income, project passive income toward financial independence, and get monthly rebalancing recommendations.

## Project Generation (XcodeGen)

The `.xcodeproj` is generated from `project.yml` and git-ignored. Regenerate after pulling, adding, or removing files:

```bash
xcodegen generate
```

## Build & Test

Use `just` (task runner). It auto-detects the latest iOS simulator — no hardcoded device names.

```bash
just build              # xcodegen generate + xcodebuild build
just test               # run all unit tests
just test-only <Name>   # run specific test struct (e.g. just test-only RebalancingEngineTests)
just clean              # rm DerivedData
just rebuild            # clean + generate + build
just resolve            # resolve SPM packages
just simulator          # show which simulator will be used
just backend            # rebuild + restart backend Docker container
just tunnel             # show current Cloudflare tunnel URL
just --list             # show all available recipes
```

**Deployment target:** iOS 26.0. **Simulator:** Use "iPhone Air" (not "iPhone 16 Pro" — may not exist).

## Architecture

**Pattern:** MVVM with `@Observable` (not ObservableObject/Combine). ViewModels are `@State private var viewModel = XViewModel()` in views.

**Persistence:** SwiftData with iCloud sync. Models: `Portfolio`, `Holding`, `DividendPayment`, `Contribution`, `UserSettings`. Enums stored as raw strings (`assetClassRaw`, `statusRaw`, `currencyRaw`) with computed getters/setters.

**Navigation:** 4-tab `TabView` (Dashboard, Portfolio, Aportar, Ajustes). DividendCalendar and IncomeHistory are pushed from Dashboard via `NavigationLink`. Portfolio uses `.navigationDestination(for: PersistentIdentifier.self)` for holding detail.

**Networking:** All API calls go through `BackendServiceProtocol` → `BackendService` (actor) → project-fin backend. No direct external API calls from the app. Mock service used in previews/tests via `@Environment(\.backendService)`.

**Design System:** Custom components prefixed `TQ` (TQCard, TQProgressRing, TQStatusBadge, etc.) in `Core/DesignSystem/`. Theme colors in `Color+Theme.swift`. App is dark-mode only (`.preferredColorScheme(.dark)` on root view).

## Key Domain Concepts

- **Two-tier rebalancing:** Class allocations (Portfolio level, must sum to 100%) determine budget per class. Holding weight (per-Holding, relative number like 5) distributes within class. `RebalancingEngine.suggestions(modelContext:investmentAmount:)` is the single entry point used by both Dashboard and Aportar.
- **Holding status (Bastter pipeline):** `.estudo` (studying, no position yet), `.aportar` (good company, receives monthly contributions), `.quarentena` (first stage of exit — counts toward allocation but receives no money), `.vender` (decision made to exit — excluded from allocation math entirely, sell gradually). A Holding without Contributions is in estudo; first buy promotes to aportar.
- **Contributions as source of truth:** `Holding.quantity` and `averagePrice` are cached but derived from `Contribution` records via `recalculateFromContributions()`. Always create a Contribution then call recalculate — never write quantity/averagePrice directly.
- **Asset class detection:** `AssetClassType.detect(from:apiType:)` uses the Brapi API `type` field (`"fund"` → FII, `"stock"` → Ações BR, `"bdr"` → US Stocks) as primary source, falls back to ticker heuristics. Always strip `.SA` suffix before display.

## Backend (project-fin)

Located at `/Users/felipediaspereira/Code/project-fin/`. FastAPI + SQLAlchemy + SQLite.

```bash
# Run with Docker
cd /path/to/project-fin && docker compose up -d

# Rebuild after code changes
docker compose up -d --build backend

# Check Cloudflare tunnel URL (changes on restart)
docker logs project-fin-tunnel 2>&1 | grep "trycloudflare.com" | grep -v ERR | tail -1

# Run backend tests
cd backend && .venv312/bin/python -m pytest tests/ -v
```

**Update tunnel URL** in `Grove/AppConstants.swift` → `backendBaseURL` when it changes.

**Key mobile endpoints** (`/api/mobile/`): `quotes`, `exchange-rate`, `dividends`, `dividends/summary`, `track`, `track/sync`. Search is at `/api/stocks/search`.

**`tracked_symbols` table:** iOS app tells backend which symbols to keep fresh via `POST /api/mobile/track/sync`. Cron jobs (9:00/17:00 UTC for prices, tue/fri for dividends) refresh both web-app transactions AND tracked symbols.

## Design Principles

**SOLID patterns are mandatory.** Apply single responsibility, open/closed, and dependency inversion throughout:

- **Views are thin.** A view only handles layout and user interaction. All business logic, formatting, computed display properties, and data transformation live on models, DTOs, or ViewModels — never in views.
- **Extract components.** Prefer small, reusable SwiftUI components over large monolithic views. When a view body grows beyond ~50 lines or contains repeated patterns, extract sub-views into their own structs. Shared UI patterns go in `Core/DesignSystem/Components/`.
- **Logic on models.** Computed properties like `displayTicker`, `displayDescription`, `formattedPrice` belong on the model/DTO struct. If you're writing a helper function in a view that reads model data, move it to the model instead.
- **Protocol-based services.** All services use protocols (`BackendServiceProtocol`, etc.) with mock implementations for previews and tests.

## Testing

**Target: 80% unit test coverage on ViewModels.** Use TDD when implementing new features — write the test first, then the implementation.

- Use Swift Testing framework (`import Testing`, `@Test`, `#expect`), not XCTest.
- Test ViewModels by testing their public methods and verifying state changes.
- Services like `RebalancingEngine`, `TaxCalculator`, `IncomeProjector` must have comprehensive test coverage.
- DTO decoding tests verify backend contract compatibility.
- When adding a new ViewModel method, write the test before the implementation.

## Code Conventions

- Money values from backend are strings (not doubles) to preserve precision. Use `Decimal` in Swift.
- `NSDecimalNumber(decimal:).doubleValue` for converting Decimal to Double (never use `.intValue` — it returns 0 for values < 1).
- Feature-based folder structure: `Features/Dashboard/`, `Features/Portfolio/`, etc.
- Previews should use `Holding.itub3`, `.btlg11`, etc. (static factory properties on `Holding` in `SampleData+Holdings.swift`).
- Brazilian Portuguese for UI strings (no localization framework yet — strings are inline).

## Git & PR Conventions

- Do NOT include `Co-Authored-By` lines in commit messages.
- Do NOT include "Generated with Claude Code" or any Claude attribution in PR descriptions.

## SPM Dependencies

- `swift-async-algorithms` — used for search debounce (`AsyncChannel` + `.debounce`)
