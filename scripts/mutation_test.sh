#!/bin/bash
# Mutation testing for Grove
#
# For each mutation:
#   1. Introduces a small bug in the source code
#   2. Runs all tests
#   3. If tests FAIL -> KILLED (good, tests caught the bug)
#   4. If tests PASS -> SURVIVED (bad, tests missed the bug)
#   5. Reverts the change
#
# A high kill rate means your tests are solid.
# Survivors show where you need better tests.

set -uo pipefail
cd "$(dirname "$0")/.."

PY="python3 scripts/mutate.py"
KILLED=0
SURVIVED=0
TOTAL=0
SURVIVORS=()

mutate() {
    local file="$1" desc="$2" search="$3" replace="$4"

    # Skip if pattern not found
    $PY check "$file" "$search" || return 0

    TOTAL=$((TOTAL + 1))
    $PY apply "$file" "$search" "$replace"

    printf "  [%2d] %-35s %-38s " "$TOTAL" "$(basename "$file")" "$desc"

    if just test > /dev/null 2>&1; then
        printf "SURVIVED !!!\n"
        SURVIVED=$((SURVIVED + 1))
        SURVIVORS+=("$(basename "$file"): $desc")
    else
        printf "KILLED\n"
        KILLED=$((KILLED + 1))
    fi

    $PY revert "$file"
}

echo "========================================"
echo " Mutation Testing - Grove"
echo "========================================"
echo ""

# --- RebalancingEngine ---
E="Grove/Core/Services/RebalancingEngine.swift"
echo ">> RebalancingEngine"
mutate "$E" "eligible: aportar->quarentena"     'status == .aportar'                           'status == .quarentena'
mutate "$E" "remove vender exclusion"           'guard h.status != .vender else { continue }'  '// mutated: vender not excluded'
mutate "$E" "flip class gap sort"               'return a.classGap > b.classGap'               'return a.classGap < b.classGap'
mutate "$E" "break zero investment guard"        'guard investmentAmount > 0'                   'guard investmentAmount > 999999'
echo ""

# --- TaxCalculator ---
T="Grove/Core/Services/TaxCalculator.swift"
echo ">> TaxCalculator"
mutate "$T" "nra30: 0.30 -> 0.00"              'case .nra30: return 0.30'   'case .nra30: return 0.00'
mutate "$T" "flip net multiplier"               '1 - taxRate'                '1 + taxRate'
echo ""

# --- Holding ---
H="Grove/Core/Models/Holding.swift"
echo ">> Holding"
mutate "$H" "flip gainLoss sign"                'currentValue - totalCost'   'totalCost - currentValue'
mutate "$H" "wrong congelar migration"          'if statusRaw == "congelar" { return .quarentena }' 'if statusRaw == "congelar" { return .aportar }'
mutate "$H" "recalc: flip sell cost"            'totalCost -= sellShares * avgAtSale'  'totalCost += sellShares * avgAtSale'
echo ""

# --- PortfolioRepository ---
R="Grove/Core/Repositories/PortfolioRepository.swift"
echo ">> PortfolioRepository"
mutate "$R" "flip drift sign"                   'drift: currentPct - targetPct'  'drift: targetPct - currentPct'
echo ""

# --- IncomeProjector ---
I="Grove/Core/Services/IncomeProjector.swift"
echo ">> IncomeProjector"
mutate "$I" "break income check"                'monthlyIncome > 0'  'monthlyIncome > 999999'
echo ""

# --- OnboardingViewModel ---
O="Grove/Features/Onboarding/OnboardingViewModel.swift"
echo ">> OnboardingViewModel"
mutate "$O" "break target validation"           'total >= 99'                  'total >= 0'
mutate "$O" "allow unlimited holdings"          'guard canAddMoreHoldings'     'guard true || canAddMoreHoldings'
echo ""

# --- AssetClassType ---
A="Grove/Core/Models/Enums/AssetClassType.swift"
echo ">> AssetClassType"
mutate "$A" "detect: FII->acoesBR"              'return .fiis'        'return .acoesBR'
mutate "$A" "BR currency->USD"                  'case .acoesBR, .fiis, .rendaFixa: .brl'  'case .acoesBR, .fiis, .rendaFixa: .usd'
echo ""

# --- Summary ---
echo "========================================"
echo " Results"
echo "========================================"
echo ""
echo "  Total:     $TOTAL"
echo "  Killed:    $KILLED"
echo "  Survived:  $SURVIVED"

if [ $TOTAL -gt 0 ]; then
    SCORE=$((KILLED * 100 / TOTAL))
    echo "  Score:     ${SCORE}%"
fi
echo ""

if [ ${#SURVIVORS[@]} -gt 0 ]; then
    echo "  SURVIVORS (need better tests):"
    for s in "${SURVIVORS[@]}"; do
        echo "    - $s"
    done
    echo ""
fi
