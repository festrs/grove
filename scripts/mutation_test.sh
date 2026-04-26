#!/bin/bash
# Mutation testing for Grove — batched.
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

# --- RebalancingEngine ---
E="Grove/Core/Services/RebalancingEngine.swift"
add "$E" "eligible: aportar->quarentena"     'status == .aportar'                           'status == .quarentena'
add "$E" "remove vender exclusion"           'guard h.status != .vender else { continue }'  '// mutated: vender not excluded'
add "$E" "flip class gap sort"               'return a.classGap > b.classGap'               'return a.classGap < b.classGap'
add "$E" "break zero investment guard"       'guard investmentAmount > 0'                   'guard investmentAmount > 999999'
add "$E" "break empty eligible guard"        'guard !context.eligible.isEmpty'              'guard context.eligible.isEmpty'
add "$E" "percent helper: divide by total"   'guard total > 0 else { return 0 }'            'guard total < 0 else { return 0 }'

# --- TaxCalculator ---
T="Grove/Core/Services/TaxCalculator.swift"
add "$T" "nra30: 0.30 -> 0.00"               'case .nra30: return 0.30'   'case .nra30: return 0.00'
add "$T" "flip net multiplier"               '1 - taxRate'                '1 + taxRate'

# --- Holding ---
H="Grove/Core/Models/Holding.swift"
add "$H" "flip gainLoss sign"                'currentValue - totalCost'   'totalCost - currentValue'
add "$H" "wrong congelar migration"          'if statusRaw == "congelar" { return .quarentena }' 'if statusRaw == "congelar" { return .aportar }'
add "$H" "default targetPercent 5 -> 1"      'targetPercent: Decimal = 5' 'targetPercent: Decimal = 1'

# --- DividendPayment ---
D="Grove/Core/Models/DividendPayment.swift"
add "$D" "informational guard inverted"      'totalAmount == 0'           'totalAmount != 0'

# --- PortfolioRepository ---
R="Grove/Core/Repositories/PortfolioRepository.swift"
add "$R" "flip drift sign"                   'drift: currentPct - targetPct'  'drift: targetPct - currentPct'

# --- IncomeProjector ---
I="Grove/Core/Services/IncomeProjector.swift"
add "$I" "break income check"                'monthlyIncome > 0'  'monthlyIncome > 999999'

# --- OnboardingViewModel ---
O="Grove/Features/Onboarding/OnboardingViewModel.swift"
add "$O" "break target validation"           'total >= 99'                  'total >= 0'
add "$O" "allow unlimited holdings"          'guard canAddMoreHoldings'     'guard true || canAddMoreHoldings'
add "$O" "completeOnboarding ignores status" 'status: pending.status'       'status: .estudo'

# --- AssetClassType ---
A="Grove/Core/Models/Enums/AssetClassType.swift"
add "$A" "detect: FII->acoesBR"              'return .fiis'        'return .acoesBR'
add "$A" "BR currency->USD"                  'case .acoesBR, .fiis, .rendaFixa: .brl'  'case .acoesBR, .fiis, .rendaFixa: .usd'
add "$A" "detect crypto -> nil"              'if apiType == "crypto" { return .crypto }'  'if apiType == "crypto" { return nil }'

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
