import Foundation
import SwiftData

public enum FIIncomeMode: String, CaseIterable, Sendable {
    case essentials
    case lifestyle
    case lifestylePlusBuffer = "lifestyle_plus_buffer"

    public var multiplier: Decimal {
        switch self {
        case .essentials: 1.0
        case .lifestyle: 1.5
        case .lifestylePlusBuffer: 2.0
        }
    }
}

@Model
public final class UserSettings {
    public var monthlyIncomeGoal: Decimal
    public var monthlyCostOfLiving: Decimal
    public var hasCompletedOnboarding: Bool
    public var preferredCurrencyRaw: String
    public var recommendationCount: Int = 2

    public var monthlyIncomeGoalCurrencyRaw: String = Currency.brl.rawValue
    public var monthlyCostOfLivingCurrencyRaw: String = Currency.brl.rawValue

    /// Global asset class allocation targets as JSON: {"acoesBR": 40, "fiis": 30, ...}
    /// Must sum to 100. Single source of truth for rebalancing across all portfolios.
    public var classAllocationJSON: String = "{}"

    // MARK: - Freedom Plan

    /// Year the user wants to reach financial independence. 0 = unset.
    public var targetFIYear: Int = 0
    public var fiIncomeModeRaw: String = FIIncomeMode.essentials.rawValue
    /// Cost of living at FI / cost of living today. Falls back to the mode's
    /// multiplier when the user hasn't authored a plan.
    public var costAtFIMultiplier: Decimal = 1.0
    public var monthlyContributionCapacity: Decimal = 0
    public var monthlyContributionCapacityCurrencyRaw: String = Currency.brl.rawValue
    /// 0–100. Remainder is USD. Informational in v1 (drives copy, not math).
    public var fiCurrencyMixBRLPercent: Decimal = 100
    /// nil = user hasn't completed the Freedom Plan flow yet.
    public var freedomPlanCompletedAt: Date? = nil

    public var preferredCurrency: Currency {
        get { Currency(rawValue: preferredCurrencyRaw) ?? .brl }
        set { preferredCurrencyRaw = newValue.rawValue }
    }

    public var monthlyIncomeGoalCurrency: Currency {
        get { Currency(rawValue: monthlyIncomeGoalCurrencyRaw) ?? .brl }
        set { monthlyIncomeGoalCurrencyRaw = newValue.rawValue }
    }

    public var monthlyCostOfLivingCurrency: Currency {
        get { Currency(rawValue: monthlyCostOfLivingCurrencyRaw) ?? .brl }
        set { monthlyCostOfLivingCurrencyRaw = newValue.rawValue }
    }

    public var monthlyContributionCapacityCurrency: Currency {
        get { Currency(rawValue: monthlyContributionCapacityCurrencyRaw) ?? .brl }
        set { monthlyContributionCapacityCurrencyRaw = newValue.rawValue }
    }

    public var fiIncomeMode: FIIncomeMode {
        get { FIIncomeMode(rawValue: fiIncomeModeRaw) ?? .essentials }
        set { fiIncomeModeRaw = newValue.rawValue }
    }

    public var monthlyIncomeGoalMoney: Money {
        get { Money(amount: monthlyIncomeGoal, currency: monthlyIncomeGoalCurrency) }
        set {
            monthlyIncomeGoal = newValue.amount
            monthlyIncomeGoalCurrencyRaw = newValue.currency.rawValue
        }
    }

    public var monthlyCostOfLivingMoney: Money {
        get { Money(amount: monthlyCostOfLiving, currency: monthlyCostOfLivingCurrency) }
        set {
            monthlyCostOfLiving = newValue.amount
            monthlyCostOfLivingCurrencyRaw = newValue.currency.rawValue
        }
    }

    public var monthlyContributionCapacityMoney: Money {
        get { Money(amount: monthlyContributionCapacity, currency: monthlyContributionCapacityCurrency) }
        set {
            monthlyContributionCapacity = newValue.amount
            monthlyContributionCapacityCurrencyRaw = newValue.currency.rawValue
        }
    }

    /// Cost of living projected to FI (cost-today × multiplier), expressed in
    /// the same currency as `monthlyCostOfLiving`.
    public var costAtFIMoney: Money {
        Money(
            amount: monthlyCostOfLiving * costAtFIMultiplier,
            currency: monthlyCostOfLivingCurrency
        )
    }

    public var classAllocations: [AssetClassType: Double] {
        get {
            guard let data = classAllocationJSON.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            var result: [AssetClassType: Double] = [:]
            for (key, value) in dict {
                if let ct = AssetClassType(rawValue: key) {
                    result[ct] = value
                }
            }
            return result
        }
        set {
            let dict = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            if let data = try? JSONEncoder().encode(dict),
               let json = String(data: data, encoding: .utf8) {
                classAllocationJSON = json
            }
        }
    }

    public init(
        monthlyIncomeGoal: Decimal = 0,
        monthlyCostOfLiving: Decimal = 15_000,
        hasCompletedOnboarding: Bool = false,
        preferredCurrency: Currency = .brl,
        goalCurrency: Currency = .brl
    ) {
        self.monthlyIncomeGoal = monthlyIncomeGoal
        self.monthlyCostOfLiving = monthlyCostOfLiving
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.preferredCurrencyRaw = preferredCurrency.rawValue
        self.monthlyIncomeGoalCurrencyRaw = goalCurrency.rawValue
        self.monthlyCostOfLivingCurrencyRaw = goalCurrency.rawValue
        self.monthlyContributionCapacityCurrencyRaw = goalCurrency.rawValue
    }
}
