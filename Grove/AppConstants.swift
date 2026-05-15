import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.felipepereira.Grove"

    static let freeTierMaxHoldings = 10
    static let freeTierMaxPortfolios = 1

    enum API {
        #if GROVE_BETA
        // GroveBeta target — points at the Docker backend on this Mac. Works
        // out of the box in the simulator (NSExceptionDomains/localhost ATS
        // exception is in GroveBeta-Info.plist). On a physical device,
        // replace `localhost` with the Mac's LAN IP or use `just tunnel`.
        static let backendBaseURL = "http://localhost:8000/api"
        #else
        static let backendBaseURL = "https://grove-invest-api.fly.dev/api"
        #endif
    }

    enum Defaults {
        static let monthlyCostOfLiving: Decimal = 15_000
    }

    enum Debug {
        /// UserDefaults key — when true (DEBUG builds only) the free-tier
        /// holdings cap is bypassed so we can pile assets in for testing.
        static let unlimitedHoldingsKey = "debug_unlimitedHoldings"
    }
}
