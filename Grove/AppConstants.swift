import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.felipepereira.Grove"

    static let freeTierMaxHoldings = 10
    static let freeTierMaxPortfolios = 1

    enum API {
        static let backendBaseURL = "https://grove-invest-api.fly.dev/api"
    }

    enum Defaults {
        static let monthlyIncomeGoal: Decimal = 10_000
        static let monthlyCostOfLiving: Decimal = 15_000
        static let emergencyReserveTarget: Decimal = 180_000
    }
}
