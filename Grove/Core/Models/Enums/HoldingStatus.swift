import SwiftUI

enum HoldingStatus: String, Codable, CaseIterable, Identifiable {
    case estudo
    case aportar
    case quarentena
    case vender

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .estudo: "Estudo"
        case .aportar: "Aportar"
        case .quarentena: "Quarentena"
        case .vender: "Vender"
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
        case .estudo: "Estudando, ainda sem posicao"
        case .aportar: "Empresa boa, recebe aportes mensais"
        case .quarentena: "Nao compra, nao vende. Primeiro estagio da saida"
        case .vender: "Decisao tomada, saindo aos poucos"
        }
    }
}
