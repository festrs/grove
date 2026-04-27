#!/bin/bash
# Mutation testing for Grove — batched, critical-logic only.
#
# Scope (intentionally narrow):
#   Mutations target ONLY paths that drive money decisions or tax routing:
#     - RebalancingEngine     (where to invest)
#     - TaxTreatment / TaxCalculator (after-tax income math)
#     - IncomeProjector       (FIRE projection)
#     - Holding gainLoss      (per-position P&L)
#     - PortfolioRepository drift (allocation gap shown to user)
#     - AssetClassType        (currency + tax-treatment routing)
#
#   Deliberately excluded: onboarding UX guards, default property values,
#   one-time data migrations, UI categorization flags. They are tested
#   elsewhere; mutating them does not surface gaps in *financial* coverage.
#
# Strategy:
#   1. Mutations are listed as 4-tuples (file desc search replace).
#   2. Tool batches up to BATCH_SIZE mutations across DIFFERENT FILES at once.
#   3. Runs `just test` ONCE per batch:
#        - PASS → every mutation in the batch survived (rare in healthy suites).
#        - FAIL → reverts the batch and re-runs each mutation individually
#                  (linear bisect) to attribute kills/survivors precisely.
#   4. Reverts everything at the end.
#
# Tunable: BATCH_SIZE env var (default 6).

set -uo pipefail
cd "$(dirname "$0")/.."

# Self-heal if launched under Rosetta. On Apple Silicon, an x86_64 parent shell
# forces every spawned xcodebuild / swiftc / simulator process through Rosetta,
# roughly doubling iteration time. proc_translated == 1 means we're translated.
if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = "1" ]; then
    echo "→ re-execing under arm64 (parent shell was x86_64/Rosetta)"
    exec arch -arm64 /bin/bash "$0" "$@"
fi

PY="python3 scripts/mutate.py"
BATCH_SIZE="${BATCH_SIZE:-6}"
# Optional cap on mutations processed (for sample/CI runs). Empty = no limit.
MUTATION_LIMIT="${MUTATION_LIMIT:-}"

KILLED=0
SURVIVED=0
TOTAL=0
SURVIVORS=()

# Mutation tests run via `swift test` against the GroveCore SPM package —
# native macOS, no simulator, ~10× faster than xcodebuild test on iOS sim.
# Incremental rebuilds reuse .build/ inside the package directory.

PACKAGE_DIR="Packages/GroveCore"

setup_build() {
    echo "→ Cold swift build (one-time, primes module cache)..."
    local t0=$(date +%s)
    if ! (cd "$PACKAGE_DIR" && swift build --build-tests >/tmp/mutation-build.log 2>&1); then
        echo "error: initial swift build --build-tests failed" >&2
        tail -50 /tmp/mutation-build.log >&2
        exit 1
    fi
    echo "  cold build: $(( $(date +%s) - t0 ))s"
}

# Mutation list: each entry is a single line "file|||desc|||search|||replace"
MUTATIONS=()

add() {
    # add file desc search replace tests
    # `tests` is a comma-separated list of test class names (e.g. "RebalancingEngineTests").
    # The runner expands each into `-only-testing:GroveTests/<TestClass>` so we only
    # run the tests that could actually catch the mutant — typically 5-10× faster
    # than running the full suite per mutation.
    MUTATIONS+=("$1|||$2|||$3|||$4|||$5")
}

# --- RebalancingEngine: where to invest ---
E="Packages/GroveCore/Sources/GroveServices/RebalancingEngine.swift"
RE_TESTS="RebalancingEngineTests"
add "$E" "eligible: aportar->quarentena"     'let eligible = holdings.filter { $0.status == .aportar && $0.currentPrice > 0 }'  'let eligible = holdings.filter { $0.status == .quarentena && $0.currentPrice > 0 }' "$RE_TESTS"
add "$E" "remove vender exclusion"           'guard h.status != .vender else { continue }'           '// mutated: vender not excluded'                                                        "$RE_TESTS"
add "$E" "flip class gap sort"               'return a.classGap > b.classGap'                        'return a.classGap < b.classGap'                                                         "$RE_TESTS"
add "$E" "break zero investment guard"       'guard investmentAmount.amount > 0 else { return [] }'  'guard investmentAmount.amount > 999999 else { return [] }'                              "$RE_TESTS"
add "$E" "break empty eligible guard"        'guard !context.eligible.isEmpty'                       'guard context.eligible.isEmpty'                                                         "$RE_TESTS"
add "$E" "percent helper: divide by total"   'guard total > 0 else { return 0 }'                     'guard total < 0 else { return 0 }'                                                      "$RE_TESTS"

# --- TaxTreatment / TaxCalculator: after-tax income ---
TT="Packages/GroveCore/Sources/GroveDomain/TaxTreatment.swift"
add "$TT" "nra30 multiplier 0.70 -> 1.0"     'case .nra30: 0.70'                                     'case .nra30: 1.0'                                                                       "TaxCalculatorTests"

T="Packages/GroveCore/Sources/GroveServices/TaxCalculator.swift"
add "$T" "flip withholding sign"             'gross * (1 - netMultiplier(for: assetClass))'          'gross * (1 + netMultiplier(for: assetClass))'                                           "TaxCalculatorTests"

# --- IncomeProjector: FIRE projection ---
I="Packages/GroveCore/Sources/GroveServices/IncomeProjector.swift"
add "$I" "skip projection loop"              'totalNet.amount < goalDisplay.amount && contributionDisplay.amount > 0'  'totalNet.amount > goalDisplay.amount && contributionDisplay.amount > 0' "IncomeProjectorTests"

# --- Holding: per-position P&L ---
H="Packages/GroveCore/Sources/GroveDomain/Holding.swift"
add "$H" "flip gainLoss sign"                'currentValue - totalCost'                              'totalCost - currentValue'                                                               "TransactionTests"

# --- PortfolioRepository: allocation drift ---
R="Packages/GroveCore/Sources/GroveRepositories/PortfolioRepository.swift"
add "$R" "flip drift sign"                   'drift: currentPct - targetPct'                         'drift: targetPct - currentPct'                                                          "PortfolioRepositoryTests"

# --- AssetClassType: currency + tax-treatment routing ---
A="Packages/GroveCore/Sources/GroveDomain/AssetClassType.swift"
add "$A" "detect FII -> acoesBR"             'if apiType == "fund" { return .fiis }'                 'if apiType == "fund" { return .acoesBR }'                                               "BackendDTOTests"
add "$A" "BR currency -> USD"                'case .acoesBR, .fiis, .rendaFixa: .brl'                'case .acoesBR, .fiis, .rendaFixa: .usd'                                                 "AssetClassTypeTests,TaxCalculatorTests"
add "$A" "detect crypto -> nil"              'if apiType == "crypto" { return .crypto }'             'if apiType == "crypto" { return nil }'                                                  "BackendDTOTests"

# ────────────────────────────────────────────────
#  Batched runner
# ────────────────────────────────────────────────

parse_entry() {
    # Splits "file|||desc|||search|||replace|||tests" into globals.
    local entry="$1"
    ENTRY_FILE="${entry%%|||*}"; entry="${entry#*|||}"
    ENTRY_DESC="${entry%%|||*}"; entry="${entry#*|||}"
    ENTRY_SEARCH="${entry%%|||*}"; entry="${entry#*|||}"
    ENTRY_REPLACE="${entry%%|||*}"; entry="${entry#*|||}"
    ENTRY_TESTS="$entry"
}

# Convert a comma-separated list of test classes into a regex `swift test --filter`
# argument: "RebalancingEngineTests|TaxCalculatorTests". Empty falls back to all.
build_filter_regex() {
    local csv="$1"
    if [ -z "$csv" ]; then
        echo ""
        return
    fi
    echo "$csv" | tr ',' '\n' | awk 'NF' | sort -u | paste -sd '|' -
}

apply_one() {
    local entry="$1"
    parse_entry "$entry"
    if ! $PY check "$ENTRY_FILE" "$ENTRY_SEARCH" >/dev/null 2>&1; then
        return 1  # pattern missing
    fi
    $PY apply "$ENTRY_FILE" "$ENTRY_SEARCH" "$ENTRY_REPLACE" "$(echo "$entry" | shasum | cut -c1-8)"
    return 0
}

revert_all_batch() {
    $PY revert-all >/dev/null 2>&1
}

run_tests_silent() {
    # Native macOS `swift test` against the SPM package — no simulator, no Xcode
    # orchestration. Incremental rebuild reuses .build/. Filter by suite so each
    # run only executes the tests that could catch this batch's mutations.
    local tests_csv="$1"
    local filter
    filter=$(build_filter_regex "$tests_csv")
    if [ -n "$filter" ]; then
        (cd "$PACKAGE_DIR" && swift test --filter "$filter" >/dev/null 2>&1)
    else
        (cd "$PACKAGE_DIR" && swift test >/dev/null 2>&1)
    fi
}

record_killed() {
    KILLED=$((KILLED + 1))
    printf "  KILLED   %s\n" "$1"
}

record_survived() {
    SURVIVED=$((SURVIVED + 1))
    SURVIVORS+=("$1")
    printf "  SURVIVED %s\n" "$1"
}

run_individually() {
    # Re-run each mutation in the batch one at a time when the batch failed.
    local -a batch=("$@")
    for entry in "${batch[@]}"; do
        parse_entry "$entry"
        if ! $PY check "$ENTRY_FILE" "$ENTRY_SEARCH" >/dev/null 2>&1; then
            continue
        fi
        TOTAL=$((TOTAL + 1))
        $PY apply "$ENTRY_FILE" "$ENTRY_SEARCH" "$ENTRY_REPLACE"
        if run_tests_silent "$ENTRY_TESTS"; then
            record_survived "$(basename "$ENTRY_FILE"): $ENTRY_DESC"
        else
            record_killed "$(basename "$ENTRY_FILE"): $ENTRY_DESC"
        fi
        $PY revert "$ENTRY_FILE"
    done
}

run_batch() {
    local -a batch=("$@")
    local applied=()
    local batch_tests_csv=""
    for entry in "${batch[@]}"; do
        if apply_one "$entry"; then
            applied+=("$entry")
            parse_entry "$entry"
            if [ -n "$ENTRY_TESTS" ]; then
                if [ -n "$batch_tests_csv" ]; then
                    batch_tests_csv="$batch_tests_csv,$ENTRY_TESTS"
                else
                    batch_tests_csv="$ENTRY_TESTS"
                fi
            fi
        fi
    done

    if [ ${#applied[@]} -eq 0 ]; then
        return
    fi

    local t0=$(date +%s)
    if run_tests_silent "$batch_tests_csv"; then
        # Whole batch survived
        for entry in "${applied[@]}"; do
            parse_entry "$entry"
            TOTAL=$((TOTAL + 1))
            record_survived "$(basename "$ENTRY_FILE"): $ENTRY_DESC"
        done
        revert_all_batch
    else
        # At least one was killed — fall back to per-mutation tests for accuracy
        revert_all_batch
        run_individually "${applied[@]}"
    fi
    echo "  (batch took $(( $(date +%s) - t0 ))s, ${#applied[@]} mutation(s))"
}

echo "========================================"
echo " Mutation Testing - Grove (batched, size=$BATCH_SIZE)"
echo "========================================"
echo ""

setup_build

# Apply MUTATION_LIMIT (used for sample/CI runs to validate timing changes
# without paying for the full mutation set).
if [ -n "$MUTATION_LIMIT" ]; then
    echo "→ MUTATION_LIMIT=$MUTATION_LIMIT — sampling first $MUTATION_LIMIT mutations"
    MUTATIONS=("${MUTATIONS[@]:0:$MUTATION_LIMIT}")
fi

# bash 3.2 compatible: walk MUTATIONS, fill each batch with mutations from
# distinct files, and push the rest into the next pass.
remaining=("${MUTATIONS[@]}")
while [ ${#remaining[@]} -gt 0 ]; do
    batch=()
    files_in_batch=""
    next_pass=()
    for entry in "${remaining[@]}"; do
        f="${entry%%|||*}"
        if [ ${#batch[@]} -lt $BATCH_SIZE ] && [[ "$files_in_batch" != *"|$f|"* ]]; then
            batch+=("$entry")
            files_in_batch="${files_in_batch}|$f|"
        else
            next_pass+=("$entry")
        fi
    done
    run_batch "${batch[@]}"
    remaining=("${next_pass[@]+"${next_pass[@]}"}")
done

revert_all_batch

echo ""
echo "========================================"
echo " Results"
echo "========================================"
echo "  Total:     $TOTAL"
echo "  Killed:    $KILLED"
echo "  Survived:  $SURVIVED"
if [ $TOTAL -gt 0 ]; then
    SCORE=$((KILLED * 100 / TOTAL))
    echo "  Score:     ${SCORE}%"
fi

if [ ${#SURVIVORS[@]} -gt 0 ]; then
    echo ""
    echo "  SURVIVORS (need better tests):"
    for s in "${SURVIVORS[@]}"; do
        echo "    - $s"
    done
fi
