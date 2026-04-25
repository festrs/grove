import Foundation
import SwiftData

@Model
final class UserSettings {
    var monthlyIncomeGoal: Decimal
    var monthlyCostOfLiving: Decimal
    var emergencyReserveTarget: Decimal
    var emergencyReserveCurrent: Decimal
    var hasCompletedOnboarding: Bool
    var preferredCurrencyRaw: String
    var recommendationCount: Int = 2

    /// Global asset class allocation targets as JSON: {"acoesBR": 40, "fiis": 30, ...}
    /// Must sum to 100. Single source of truth for rebalancing across all portfolios.
    var classAllocationJSON: String = "{}"

    var preferredCurrency: Currency {
        get { Currency(rawValue: preferredCurrencyRaw) ?? .brl }
        set { preferredCurrencyRaw = newValue.rawValue }
    }

    var classAllocations: [AssetClassType: Double] {
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

    init(
        monthlyIncomeGoal: Decimal = 10_000,
        monthlyCostOfLiving: Decimal = 15_000,
        emergencyReserveTarget: Decimal = 180_000,
        emergencyReserveCurrent: Decimal = 0,
        hasCompletedOnboarding: Bool = false,
        preferredCurrency: Currency = .brl
    ) {
        self.monthlyIncomeGoal = monthlyIncomeGoal
        self.monthlyCostOfLiving = monthlyCostOfLiving
        self.emergencyReserveTarget = emergencyReserveTarget
        self.emergencyReserveCurrent = emergencyReserveCurrent
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.preferredCurrencyRaw = preferredCurrency.rawValue
    }
}
