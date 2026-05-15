import Foundation

/// API keys sourced from `Secrets.xcconfig` via build settings → Info.plist.
/// The xcconfig is git-ignored (see `Secrets.example`); this file is
/// committed and looks the values up at runtime so CI doesn't need to
/// materialize a Swift file.
enum Secrets {
    static var mobileAPIKey: String {
        Bundle.main.infoDictionary?["MOBILE_API_KEY"] as? String ?? ""
    }
}
