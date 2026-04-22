import SwiftUI
import AudioToolbox

private struct FingerTrailPoint: Identifiable {
    let id = UUID()
    let point: CGPoint
    let timestamp: Date
}

struct TitleView: View {
    let start: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("CapyBerry")
                .font(.system(size: 48, weight: .bold))
            Button("Start Game", action: start)
                .buttonStyle(.borderedProminent)
                .font(.title2)
            Spacer()
        }
        .padding()
    }
}

struct GameOverView: View {
    let score: Int
    let highScore: Int
    let playAgain: () -> Void
    let quit: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Game Over")
                .font(.largeTitle.bold())
            Text("Score: \(score)")
                .font(.title2)
            Text("High Score: \(highScore)")
                .font(.title3)
            HStack(spacing: 16) {
                Button("Play Again", action: playAgain)
                    .buttonStyle(.borderedProminent)
                Button("Quit", action: quit)
            }
            Spacer()
        }
        .padding()
    }
}

struct GameView: View {
    @ObservedObject var vm: GameViewModel
    @State private var dragOverlayPoint: CGPoint? = nil
    @State private var lastSwapTick: Int = 0
    private let swapSoundId: SystemSoundID = 1104
    @State private var fingerTrail: [FingerTrailPoint] = []
    let endGame: () -> Void

    @State private var comboPop = false

    var body: some View {
        VStack(spacing: 12) {
            topBar
            Spacer(minLength: 0)
            boardView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(CGFloat(GameConfig.cols) / CGFloat(GameConfig.rows), contentMode: .fit)
                .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .overlay { if vm.showPauseOverlay { pauseOverlay } }
        .onChange(of: vm.comboCount) { _, _ in
            guard vm.comboCount > 0 else { return }
            comboPop = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { comboPop = false }
        }
        .onChange(of: vm.swapTick) { _, newVal in
            if newVal != lastSwapTick {
                AudioServicesPlaySystemSound(swapSoundId)
                lastSwapTick = newVal
            }
        }
        .onChange(of: vm.sessionTimeRemaining) { _, newVal in
            if newVal <= 0 { endGame() }
        }
    }

    private var topBar: some View {
        HStack {
            Text(timeString(vm.sessionTimeRemaining))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Combo \(vm.comboCount)")
                .font(.headline)
                .scaleEffect(comboPop ? 1.2 : 1.0)
                .foregroundStyle(comboPop ? .yellow : .primary)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: comboPop)
                .frame(maxWidth: .infinity)
            Text("Score \(vm.score)")
                .frame(maxWidth: .infinity)
            Button(action: { vm.pauseGame() }) {
                Image(systemName: "pause.fill")
                    .padding(8)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Paused").font(.title2.bold())
                HStack(spacing: 12) {
                    Button("Resume") { vm.resumeGame() }
                        .buttonStyle(.borderedProminent)
                    Button("Restart") { vm.restartGamePreservingHighScore() }
                    Button("Title") { endGame() }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding()
        }
    }

    private var boardView: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / CGFloat(GameConfig.cols)
            let cellH = geo.size.height / CGFloat(GameConfig.rows)
            let cellSize = min(cellW, cellH)
            let offsetX = (geo.size.width - cellSize * CGFloat(GameConfig.cols)) / 2
            let offsetY = (geo.size.height - cellSize * CGFloat(GameConfig.rows)) / 2

            ZStack {
                // Grid background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))

                // Trailing effect
                if fingerTrail.count > 1 {
                    ForEach(0..<(fingerTrail.count - 1), id: \.self) { idx in
                        let start = fingerTrail[idx]
                        let end = fingerTrail[idx + 1]
                        let age = Date().timeIntervalSince(start.timestamp)
                        let opacity = max(0.1, 1.0 - age / 0.35)
                        Path { path in
                            path.move(to: start.point)
                            path.addLine(to: end.point)
                        }
                        .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: cellSize * 0.14, lineCap: .round, lineJoin: .round))
                        .shadow(color: Color.white.opacity(opacity * 0.6), radius: 4)
                    }
                }

                // Orbs
                ForEach(0..<GameConfig.rows, id: \.self) { r in
                    ForEach(0..<GameConfig.cols, id: \.self) { c in
                        let pos = GridPosition(row: r, col: c)
                        if let orb = vm.board[r][c] {
                            Group {
                                if !(vm.isDragging && vm.dragCurrent == pos) {
                                    Circle()
                                        .fill(orb.color)
                                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
                                        .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                                        .position(cellCenter(for: pos, cellSize: cellSize, offsetX: offsetX, offsetY: offsetY))
                                        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7), value: vm.board)
                                }
                            }
                        }
                    }
                }

                if vm.isDragging, let current = vm.dragCurrent, let originOrb = vm.board[current.row][current.col] {
                    let point: CGPoint = dragOverlayPoint ?? cellCenter(for: current, cellSize: cellSize, offsetX: offsetX, offsetY: offsetY)
                    Circle()
                        .fill(originOrb.color)
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 3))
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                        .frame(width: cellSize * 1.0, height: cellSize * 1.0)
                        .position(point)
                        .transition(.scale)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: vm.isDragging)
                }

            }
            .contentShape(Rectangle())
            .gesture(dragGesture(cellSize: cellSize, offsetX: offsetX, offsetY: offsetY))
        }
    }

    private func dragGesture(cellSize: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let pos = locationToGrid(value.location, cellSize: cellSize, offsetX: offsetX, offsetY: offsetY)
                guard let p = pos else { return }
                if !vm.isDragging {
                    vm.startDrag(at: p)
                } else {
                    vm.updateDrag(to: p)
                }
                dragOverlayPoint = value.location

                let now = Date()
                fingerTrail.append(FingerTrailPoint(point: value.location, timestamp: now))
                fingerTrail.removeAll { now.timeIntervalSince($0.timestamp) > 0.35 }
            }
            .onEnded { _ in
                dragOverlayPoint = nil
                fingerTrail = []
                vm.finishDrag()
            }
    }

    private func locationToGrid(_ loc: CGPoint, cellSize: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> GridPosition? {
        let x = loc.x - offsetX
        let y = loc.y - offsetY
        let c = Int(floor(x / cellSize))
        let r = Int(floor(y / cellSize))
        guard r >= 0, r < GameConfig.rows, c >= 0, c < GameConfig.cols else { return nil }
        return GridPosition(row: r, col: c)
    }

    private func cellCenter(for pos: GridPosition, cellSize: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> CGPoint {
        let x = offsetX + (CGFloat(pos.col) + 0.5) * cellSize
        let y = offsetY + (CGFloat(pos.row) + 0.5) * cellSize
        return CGPoint(x: x, y: y)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let sec = max(0, Int(t.rounded()))
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}
