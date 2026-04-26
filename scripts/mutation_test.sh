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

PY="python3 scripts/mutate.py"
BATCH_SIZE="${BATCH_SIZE:-6}"

KILLED=0
SURVIVED=0
TOTAL=0
SURVIVORS=()

# Mutation list: each entry is a single line "file|||desc|||search|||replace"
MUTATIONS=()

add() {
    MUTATIONS+=("$1|||$2|||$3|||$4")
}

# --- RebalancingEngine: where to invest ---
E="Grove/Core/Services/RebalancingEngine.swift"
add "$E" "eligible: aportar->quarentena"     'status == .aportar'                                    'status == .quarentena'
add "$E" "remove vender exclusion"           'guard h.status != .vender else { continue }'           '// mutated: vender not excluded'
add "$E" "flip class gap sort"               'return a.classGap > b.classGap'                        'return a.classGap < b.classGap'
add "$E" "break zero investment guard"       'guard investmentAmount.amount > 0 else { return [] }'  'guard investmentAmount.amount > 999999 else { return [] }'
add "$E" "break empty eligible guard"        'guard !context.eligible.isEmpty'                       'guard context.eligible.isEmpty'
add "$E" "percent helper: divide by total"   'guard total > 0 else { return 0 }'                     'guard total < 0 else { return 0 }'

# --- TaxTreatment / TaxCalculator: after-tax income ---
TT="Grove/Core/Models/Enums/TaxTreatment.swift"
add "$TT" "nra30 multiplier 0.70 -> 1.0"     'case .nra30: 0.70'                                     'case .nra30: 1.0'

T="Grove/Core/Services/TaxCalculator.swift"
add "$T" "flip withholding sign"             'gross * (1 - netMultiplier(for: assetClass))'          'gross * (1 + netMultiplier(for: assetClass))'

# --- IncomeProjector: FIRE projection ---
I="Grove/Core/Services/IncomeProjector.swift"
add "$I" "skip projection loop"              'totalNet.amount < goalDisplay.amount && contributionDisplay.amount > 0'  'totalNet.amount > goalDisplay.amount && contributionDisplay.amount > 0'

# --- Holding: per-position P&L ---
H="Grove/Core/Models/Holding.swift"
add "$H" "flip gainLoss sign"                'currentValue - totalCost'                              'totalCost - currentValue'

# --- PortfolioRepository: allocation drift ---
R="Grove/Core/Repositories/PortfolioRepository.swift"
add "$R" "flip drift sign"                   'drift: currentPct - targetPct'                         'drift: targetPct - currentPct'

# --- AssetClassType: currency + tax-treatment routing ---
A="Grove/Core/Models/Enums/AssetClassType.swift"
add "$A" "detect FII -> acoesBR"             'if apiType == "fund" { return .fiis }'                 'if apiType == "fund" { return .acoesBR }'
add "$A" "BR currency -> USD"                'case .acoesBR, .fiis, .rendaFixa: .brl'                'case .acoesBR, .fiis, .rendaFixa: .usd'
add "$A" "detect crypto -> nil"              'if apiType == "crypto" { return .crypto }'             'if apiType == "crypto" { return nil }'

# ────────────────────────────────────────────────
#  Batched runner
# ────────────────────────────────────────────────

parse_entry() {
    # Splits "file|||desc|||search|||replace" into globals: ENTRY_FILE, ENTRY_DESC, ENTRY_SEARCH, ENTRY_REPLACE
    local entry="$1"
    ENTRY_FILE="${entry%%|||*}"; entry="${entry#*|||}"
    ENTRY_DESC="${entry%%|||*}"; entry="${entry#*|||}"
    ENTRY_SEARCH="${entry%%|||*}"; entry="${entry#*|||}"
    ENTRY_REPLACE="$entry"
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
    just test >/dev/null 2>&1
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
        if run_tests_silent; then
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
    for entry in "${batch[@]}"; do
        if apply_one "$entry"; then
            applied+=("$entry")
        fi
    done

    if [ ${#applied[@]} -eq 0 ]; then
        return
    fi

    if run_tests_silent; then
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
}

echo "========================================"
echo " Mutation Testing - Grove (batched, size=$BATCH_SIZE)"
echo "========================================"
echo ""

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
