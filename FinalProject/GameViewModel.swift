import Foundation
import SwiftUI
import Combine
import AudioToolbox

final class GameViewModel: ObservableObject {
    @Published var board: [[OrbElement?]] = [] // rows x cols
    @Published var score: Int = 0
    @Published var highScore: Int = UserDefaults.standard.integer(forKey: "highScore")
    @Published var comboCount: Int = 0
    @Published var isPaused: Bool = false
    @Published var isResolving: Bool = false
    @Published var comboPopups: [ComboPopup] = []
    @Published var capybaraAssetName: String = CapybaraSprites.idle
    @Published var capybaraJumpTick: Int = 0
    @Published var highlightedMatches: Set<GridPosition> = []
    @Published var fadingMatches: Set<GridPosition> = []
    @Published var sessionTimeRemaining: TimeInterval = GameConfig.sessionDuration

    // Drag state
    @Published var isDragging: Bool = false
    @Published var dragOrigin: GridPosition? // where drag started
    @Published var dragCurrent: GridPosition? // current cell of dragged orb
    @Published var dragTrail: [GridPosition] = [] // recent path for trailing effect
    @Published var dragTimeRemaining: TimeInterval = 0
    @Published var swapTick: Int = 0

    private let matchSoundId: SystemSoundID = 1114

    // UI flags
    @Published var showPauseOverlay: Bool = false

    private var sessionTimer: Timer?
    private var dragTimer: Timer?

    init() {
        resetBoard()
    }

    func resetBoard() {
        board = (0..<GameConfig.rows).map { _ in
            (0..<GameConfig.cols).map { _ in OrbElement.allCases.randomElement() }
        }
        score = 0
        comboCount = 0
        comboPopups = []
        capybaraAssetName = CapybaraSprites.idle
        capybaraJumpTick += 1
        isPaused = false
        isResolving = false
        sessionTimeRemaining = GameConfig.sessionDuration
        cancelTimers()
        startSessionTimerIfNeeded()
    }

    func restartGamePreservingHighScore() {
        updateHighScoreIfNeeded()
        resetBoard()
    }

    func updateHighScoreIfNeeded() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "highScore")
        }
    }

    func startSessionTimerIfNeeded() {
        guard sessionTimer == nil else { return }
        guard !isPaused, !isResolving else { return }
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] t in
            guard let self = self else { return }
            guard !self.isPaused, !self.isResolving else { return }
            self.sessionTimeRemaining -= 1/30
            if self.sessionTimeRemaining <= 0 {
                self.sessionTimeRemaining = 0
                t.invalidate()
                self.sessionTimer = nil
                self.endSession()
            }
        }
    }

    func pauseGame() {
        isPaused = true
        showPauseOverlay = true
        cancelSessionTimer()
    }

    func resumeGame() {
        isPaused = false
        showPauseOverlay = false
        startSessionTimerIfNeeded()
    }

    func endSession() {
        // End the game
        updateHighScoreIfNeeded()
        // Views can observe time reaching 0 to navigate to game over
    }

    private func cancelSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    private func cancelTimers() {
        cancelSessionTimer()
        dragTimer?.invalidate()
        dragTimer = nil
    }

    // MARK: - Drag Handling
    func startDrag(at pos: GridPosition) {
        guard !isResolving, !isPaused, sessionTimeRemaining > 0 else { return }
        guard inBounds(pos), board[pos.row][pos.col] != nil else { return }
        isDragging = true
        dragOrigin = pos
        dragCurrent = pos
        dragTrail = [pos]
        dragTimeRemaining = GameConfig.dragDuration
        startDragTimer()
        startSessionTimerIfNeeded() // ensure session timer runs during drag
    }

    private func startDragTimer() {
        dragTimer?.invalidate()
        dragTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] t in
            guard let self = self else { return }
            guard self.isDragging else { t.invalidate(); self.dragTimer = nil; return }
            self.dragTimeRemaining -= 1/60
            if self.dragTimeRemaining <= 0 {
                self.dragTimeRemaining = 0
                self.finishDrag()
            }
        }
    }

    func updateDrag(to pos: GridPosition) {
        guard isDragging, let current = dragCurrent else { return }
        guard inBounds(pos) else { return }
        // Swap if Chebyshev distance == 1 (adjacent including diagonals)
        let dr = abs(pos.row - current.row)
        let dc = abs(pos.col - current.col)
        guard max(dr, dc) == 1 else { return }
        swapOrbs(current, pos)
        dragCurrent = pos
        dragTrail.append(pos)
        if dragTrail.count > 10 { dragTrail.removeFirst() }
    }

    func finishDrag() {
        guard isDragging else { return }
        isDragging = false
        dragTimer?.invalidate(); dragTimer = nil
        dragOrigin = nil
        dragCurrent = nil
        dragTrail.removeAll()
        // Pause session timer during resolution
        cancelSessionTimer()
        resolveBoard()
    }

    private func inBounds(_ p: GridPosition) -> Bool {
        return p.row >= 0 && p.row < GameConfig.rows && p.col >= 0 && p.col < GameConfig.cols
    }

    private func swapOrbs(_ a: GridPosition, _ b: GridPosition) {
        guard inBounds(a), inBounds(b) else { return }
        let tmp = board[a.row][a.col]
        board[a.row][a.col] = board[b.row][b.col]
        board[b.row][b.col] = tmp
        swapTick += 1
    }

    // MARK: - Resolution Loop

    @MainActor
    private func emitComboPopup(for group: [GridPosition]) {
        comboCount += 1
        let popup = ComboPopup(group: group, count: comboCount)
        comboPopups.append(popup)
        // Update capybara sprite: first combo or every multiple of 3
        if comboCount == 1 || comboCount % 3 == 0 {
            if let next = CapybaraSprites.others.randomElement() {
                capybaraAssetName = next
                capybaraJumpTick += 1
            }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            self.comboPopups.removeAll { $0.id == popup.id }
        }
    }

    func resolveBoard() {
        guard !isResolving else { return }
        isResolving = true
        comboCount = 0
        Task { @MainActor in
            var totalMovePoints = 0
            while true {
                let groups = findMatchGroups()
                if groups.isEmpty { break }

                // Each loop of groups is one combo step
                // comboCount += 1  <-- removed this line

                // Animate each group sequentially: highlight -> fade -> remove
                for group in groups {
                    // Increment combo per group and show popup
                    emitComboPopup(for: group)

                    // Highlight (scale up)
                    highlightedMatches = Set(group)
                    AudioServicesPlaySystemSound(matchSoundId)
                    try? await Task.sleep(nanoseconds: 180_000_000)

                    // Fade out
                    fadingMatches = Set(group)
                    try? await Task.sleep(nanoseconds: 180_000_000)

                    // Remove from board
                    for p in group {
                        board[p.row][p.col] = nil
                    }

                    // Clear highlight/fade states before next group
                    highlightedMatches = []
                    fadingMatches = []
                }

                // Score this wave of groups (before gravity/refill)
                let points = score(for: groups)
                totalMovePoints += points

                // Let removals settle, then apply gravity and refill
                try? await Task.sleep(nanoseconds: 120_000_000)
                applyGravity()
                try? await Task.sleep(nanoseconds: 250_000_000)
                refill()
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            // When cascading ends (combo sequence is over), revert capybara to idle
            if comboCount > 0 {
                capybaraAssetName = CapybaraSprites.idle
                capybaraJumpTick += 1
            }

            // Apply combo multiplier once all cascading is complete
            if comboCount > 0 {
                let multiplier = 1.0 + 0.25 * Double(comboCount - 1)
                score += Int(Double(totalMovePoints) * multiplier)
                updateHighScoreIfNeeded()
            }

            isResolving = false
            // Resume session timer when done
            startSessionTimerIfNeeded()
        }
    }

    private func findMatchGroups() -> [[GridPosition]] {
        let rows = GameConfig.rows
        let cols = GameConfig.cols
        var marked = Set<GridPosition>()

        // Horizontal runs
        for r in 0..<rows {
            var c = 0
            while c < cols {
                guard let color = board[r][c] else { c += 1; continue }
                var run: [GridPosition] = [GridPosition(row: r, col: c)]
                var k = c + 1
                while k < cols {
                    guard let nextColor = board[r][k] else { break }
                    if nextColor == color {
                        run.append(GridPosition(row: r, col: k))
                        k += 1
                    } else {
                        break
                    }
                }
                if run.count >= 3 { marked.formUnion(run) }
                c = k
            }
        }

        // Vertical runs
        for c in 0..<cols {
            var r = 0
            while r < rows {
                guard let color = board[r][c] else { r += 1; continue }
                var run: [GridPosition] = [GridPosition(row: r, col: c)]
                var k = r + 1
                while k < rows {
                    guard let nextColor = board[k][c] else { break }
                    if nextColor == color {
                        run.append(GridPosition(row: k, col: c))
                        k += 1
                    } else {
                        break
                    }
                }
                if run.count >= 3 { marked.formUnion(run) }
                r = k
            }
        }

        if marked.isEmpty { return [] }

        // Group via BFS using 8-neighbor adjacency (including diagonals),
        // but require that all cells in a group share the same color.
        let dirs = [(1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)]
        var groups: [[GridPosition]] = []
        var visited = Set<GridPosition>()

        for start in marked {
            if visited.contains(start) { continue }
            guard let startColor = board[start.row][start.col] else { continue }
            var queue: [GridPosition] = [start]
            var comp: [GridPosition] = []
            visited.insert(start)
            while !queue.isEmpty {
                let cur = queue.removeFirst()
                comp.append(cur)
                for (dr, dc) in dirs {
                    let nr = cur.row + dr
                    let nc = cur.col + dc
                    let next = GridPosition(row: nr, col: nc)
                    if nr >= 0, nr < rows, nc >= 0, nc < cols,
                       marked.contains(next), !visited.contains(next),
                       let color = board[nr][nc], color == startColor {
                        visited.insert(next)
                        queue.append(next)
                    }
                }
            }
            if comp.count >= 3 { groups.append(comp) }
        }

        return groups
    }

    private func remove(groups: [[GridPosition]]) {
        for group in groups {
            for p in group {
                board[p.row][p.col] = nil
            }
        }
    }

    private func applyGravity() {
        let rows = GameConfig.rows
        let cols = GameConfig.cols
        for c in 0..<cols {
            var write = rows - 1
            for r in stride(from: rows - 1, through: 0, by: -1) {
                if let orb = board[r][c] {
                    board[write][c] = orb
                    if write != r { board[r][c] = nil }
                    write -= 1
                }
            }
            while write >= 0 {
                board[write][c] = nil
                write -= 1
            }
        }
    }

    private func refill() {
        for r in 0..<GameConfig.rows {
            for c in 0..<GameConfig.cols {
                if board[r][c] == nil {
                    board[r][c] = OrbElement.allCases.randomElement()
                }
            }
        }
    }

    private func score(for groups: [[GridPosition]]) -> Int {
        // Count group sizes and use scoring rule: 100 + 50 * (n - 3) for each group size n
        var total = 0
        for group in groups {
            let n = group.count
            if n >= 3 {
                total += GameConfig.baseScore + GameConfig.extraPerOrb * (n - 3)
            }
        }
        return total
    }
}

// MARK: - Safe index helper
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
