import SwiftUI

enum HoldingStatus: String, Codable, CaseIterable, Identifiable {
    case aportar
    case congelar
    case quarentena

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aportar: "Aportar"
        case .congelar: "Congelar"
        case .quarentena: "Quarentena"
        }
    }

    var color: Color {
        switch self {
        case .aportar: .green
        case .congelar: .gray
        case .quarentena: .orange
        }
    }

    var icon: String {
        switch self {
        case .aportar: "plus.circle.fill"
        case .congelar: "snow"
        case .quarentena: "exclamationmark.triangle.fill"
        }
    }

    var description: String {
        switch self {
        case .aportar: "Elegivel para novos aportes"
        case .congelar: "Manter posicao, nao aportar"
        case .quarentena: "Em revisao, possivel saida"
        }
    }
}
