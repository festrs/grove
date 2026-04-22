import UIKit

enum DeviceIdentifier {

    private static let storageKey = "com.tranquilidade.deviceID"

    static var current: String {
        if let stored = UserDefaults.standard.string(forKey: storageKey) {
            return stored
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: storageKey)
        return id
    }
}
