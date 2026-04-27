import SwiftUI

public enum HoldingStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case estudo
    case aportar
    case quarentena
    case vender

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .estudo: "Study"
        case .aportar: "Invest"
        case .quarentena: "Quarantine"
        case .vender: "Sell"
        }
    }

    public var color: Color {
        switch self {
        case .estudo: .blue
        case .aportar: .green
        case .quarentena: .orange
        case .vender: .red
        }
    }

    public var icon: String {
        switch self {
        case .estudo: "magnifyingglass.circle.fill"
        case .aportar: "arrow.up.circle.fill"
        case .quarentena: "pause.circle.fill"
        case .vender: "arrow.down.circle.fill"
        }
    }

    public var description: String {
        switch self {
        case .estudo: "Studying, no position yet"
        case .aportar: "Good company, receives monthly investments"
        case .quarentena: "Not buying, not selling. First exit stage"
        case .vender: "Decision made, exiting gradually"
        }
    }
}
