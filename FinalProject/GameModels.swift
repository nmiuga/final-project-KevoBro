import Foundation
import SwiftUI

struct GridPosition: Hashable, Equatable {
    let row: Int
    let col: Int
}

enum GameScreen {
    case title
    case playing
    case gameOver(finalScore: Int)
}

struct GameConfig {
    static let rows = 5
    static let cols = 6
    static let sessionDuration: TimeInterval = 120 // 2 minutes
    static let dragDuration: TimeInterval = 8 // seconds
    static let baseScore = 100
    static let extraPerOrb = 50 // per orb over 3
    static let comboExpBase: Double = 1.3 // exponential combo multiplier base (>1 means growth)
}

extension Collection where Element == GridPosition {
    func contains(_ r: Int, _ c: Int) -> Bool {
        return self.contains { $0.row == r && $0.col == c }
    }
}

struct CapybaraSprites {
    static let idle = "IdleCapybara"
    // All non-idle capybara sprite asset names
    static let others: [String] = [
        "FullCapybara",
        "MunchCapybara",
        "StarEyes",
        "StrawberryEyes",
        "WowCapybara",
        "YayCapybara"
    ]
}

struct ComboPopup: Identifiable, Equatable {
    let id = UUID()
    let group: [GridPosition]
    let count: Int
}

