import SwiftUI

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let card: CGFloat = 16
    }

    enum FontSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 16
        static let title3: CGFloat = 20
        static let title2: CGFloat = 24
        static let title1: CGFloat = 28
        static let largeTitle: CGFloat = 34
        static let hero: CGFloat = 48
    }

    enum Layout {
        static let maxContentWidth: CGFloat = 1200
        static let compactCardMin: CGFloat = 150
        static let regularCardMin: CGFloat = 300
        static let sidebarWidth: CGFloat = 340
        static let wideThreshold: CGFloat = 700

        static func gaugeSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
            sizeClass == .regular ? 260 : 180
        }

        static func chartSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
            sizeClass == .regular ? 180 : 130
        }

        static func chartHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
            sizeClass == .regular ? 280 : 200
        }
    }
}
