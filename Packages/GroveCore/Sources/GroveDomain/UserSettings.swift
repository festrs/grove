import Foundation
import SwiftData

@Model
public final class UserSettings {
    public var monthlyIncomeGoal: Decimal
    public var monthlyCostOfLiving: Decimal
    public var emergencyReserveTarget: Decimal
    public var emergencyReserveCurrent: Decimal
    public var hasCompletedOnboarding: Bool
    public var preferredCurrencyRaw: String
    public var recommendationCount: Int = 2

    public var monthlyIncomeGoalCurrencyRaw: String = Currency.brl.rawValue
    public var monthlyCostOfLivingCurrencyRaw: String = Currency.brl.rawValue
    public var emergencyReserveTargetCurrencyRaw: String = Currency.brl.rawValue
    public var emergencyReserveCurrentCurrencyRaw: String = Currency.brl.rawValue

    /// Global asset class allocation targets as JSON: {"acoesBR": 40, "fiis": 30, ...}
    /// Must sum to 100. Single source of truth for rebalancing across all portfolios.
    public var classAllocationJSON: String = "{}"

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

    public var emergencyReserveTargetCurrency: Currency {
        get { Currency(rawValue: emergencyReserveTargetCurrencyRaw) ?? .brl }
        set { emergencyReserveTargetCurrencyRaw = newValue.rawValue }
    }

    public var emergencyReserveCurrentCurrency: Currency {
        get { Currency(rawValue: emergencyReserveCurrentCurrencyRaw) ?? .brl }
        set { emergencyReserveCurrentCurrencyRaw = newValue.rawValue }
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

    public var emergencyReserveTargetMoney: Money {
        get { Money(amount: emergencyReserveTarget, currency: emergencyReserveTargetCurrency) }
        set {
            emergencyReserveTarget = newValue.amount
            emergencyReserveTargetCurrencyRaw = newValue.currency.rawValue
        }
    }

    public var emergencyReserveCurrentMoney: Money {
        get { Money(amount: emergencyReserveCurrent, currency: emergencyReserveCurrentCurrency) }
        set {
            emergencyReserveCurrent = newValue.amount
            emergencyReserveCurrentCurrencyRaw = newValue.currency.rawValue
        }
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
        monthlyIncomeGoal: Decimal = 10_000,
        monthlyCostOfLiving: Decimal = 15_000,
        emergencyReserveTarget: Decimal = 180_000,
        emergencyReserveCurrent: Decimal = 0,
        hasCompletedOnboarding: Bool = false,
        preferredCurrency: Currency = .brl,
        goalCurrency: Currency = .brl
    ) {
        self.monthlyIncomeGoal = monthlyIncomeGoal
        self.monthlyCostOfLiving = monthlyCostOfLiving
        self.emergencyReserveTarget = emergencyReserveTarget
        self.emergencyReserveCurrent = emergencyReserveCurrent
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.preferredCurrencyRaw = preferredCurrency.rawValue
        self.monthlyIncomeGoalCurrencyRaw = goalCurrency.rawValue
        self.monthlyCostOfLivingCurrencyRaw = goalCurrency.rawValue
        self.emergencyReserveTargetCurrencyRaw = goalCurrency.rawValue
        self.emergencyReserveCurrentCurrencyRaw = goalCurrency.rawValue
    }
}
