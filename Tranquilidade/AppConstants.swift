import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.felipepereira.Tranquilidade"

    static let freeTierMaxHoldings = 10
    static let freeTierMaxPortfolios = 1

    enum API {
        static let brapiBaseURL = "https://brapi.dev/api"
        static let brapiToken: String = Secrets.brapiToken
        static let coinGeckoBaseURL = "https://api.coingecko.com/api/v3"
        static let awesomeAPIBaseURL = "https://economia.awesomeapi.com.br"
        static let backendBaseURL = "https://defence-studio-generations-unknown.trycloudflare.com/api"
    }

    enum Defaults {
        static let monthlyIncomeGoal: Decimal = 10_000
        static let monthlyCostOfLiving: Decimal = 15_000
        static let emergencyReserveTarget: Decimal = 180_000
    }
}
