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
    
    var assetName: String {
        switch self {
        case .red: return "StrawberryIcon"
        case .blue: return "BlueberryIcon"
        case .green: return "GrapeIcon"
        case .yellow: return "LemonIcon"
        case .purple: return "PurpleGrapeIcon"
        }
    }
}
