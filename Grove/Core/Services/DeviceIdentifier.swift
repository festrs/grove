#if canImport(UIKit)
import UIKit
#endif
import Foundation

enum DeviceIdentifier {

    private static let storageKey = "com.grove.deviceID"

    static var current: String {
        if let stored = UserDefaults.standard.string(forKey: storageKey) {
            return stored
        }
        #if canImport(UIKit)
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        let id = UUID().uuidString
        #endif
        UserDefaults.standard.set(id, forKey: storageKey)
        return id
    }
}
