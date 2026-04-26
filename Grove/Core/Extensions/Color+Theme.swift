import SwiftUI

extension Color {
    static let tqAccentGreen = Color(red: 0.18, green: 0.74, blue: 0.45)
    static let tqAccentBlue = Color(red: 0.30, green: 0.55, blue: 0.95)
    static let tqPositive = Color.green
    static let tqNegative = Color.red
    static let tqWarning = Color.orange

    #if canImport(UIKit)
    static let tqBackground = Color(.systemGroupedBackground)
    static let tqCardBackground = Color(.secondarySystemGroupedBackground)
    static let tqSecondaryText = Color(.secondaryLabel)
    static let tqFrozen = Color(.systemGray4)
    #elseif canImport(AppKit)
    static let tqBackground = Color(nsColor: .windowBackgroundColor)
    static let tqCardBackground = Color(nsColor: .controlBackgroundColor)
    static let tqSecondaryText = Color(nsColor: .secondaryLabelColor)
    static let tqFrozen = Color(nsColor: .systemGray)
    #endif
}
