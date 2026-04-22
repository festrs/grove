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

    var preferredCurrency: Currency {
        get { Currency(rawValue: preferredCurrencyRaw) ?? .brl }
        set { preferredCurrencyRaw = newValue.rawValue }
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
