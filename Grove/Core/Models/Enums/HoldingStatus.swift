import SwiftUI

enum HoldingStatus: String, Codable, CaseIterable, Identifiable {
    case estudo
    case aportar
    case quarentena
    case vender

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .estudo: "Study"
        case .aportar: "Invest"
        case .quarentena: "Quarantine"
        case .vender: "Sell"
        }
    }

    var color: Color {
        switch self {
        case .estudo: .blue
        case .aportar: .green
        case .quarentena: .orange
        case .vender: .red
        }
    }

    var icon: String {
        switch self {
        case .estudo: "magnifyingglass.circle.fill"
        case .aportar: "arrow.up.circle.fill"
        case .quarentena: "pause.circle.fill"
        case .vender: "arrow.down.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .estudo: "Studying, no position yet"
        case .aportar: "Good company, receives monthly investments"
        case .quarentena: "Not buying, not selling. First exit stage"
        case .vender: "Decision made, exiting gradually"
        }
    }
}
