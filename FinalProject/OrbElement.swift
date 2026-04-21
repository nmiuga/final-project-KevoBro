import SwiftUI

enum OrbElement: CaseIterable, Identifiable, Equatable {
    case red, blue, green, yellow, purple
    var id: Self { self }
    var color: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .purple: return .purple
        }
    }
}
