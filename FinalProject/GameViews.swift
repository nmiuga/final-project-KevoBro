import SwiftUI
import AudioToolbox

private struct BubblegumText: ViewModifier {
    let size: CGFloat
    func body(content: Content) -> some View {
        content
            .font(.custom("Bubblegum", size: size))
            .foregroundStyle(.white)
            // Thin black outline via multi-directional shadows
            .shadow(color: .black.opacity(0.9), radius: 0, x: 0.6, y: 0.6)
            .shadow(color: .black.opacity(0.9), radius: 0, x: -0.6, y: 0.6)
            .shadow(color: .black.opacity(0.9), radius: 0, x: 0.6, y: -0.6)
            .shadow(color: .black.opacity(0.9), radius: 0, x: -0.6, y: -0.6)
    }
}

private extension View {
    func bubblegumStyle(size: CGFloat) -> some View { self.modifier(BubblegumText(size: size)) }
}

private struct FingerTrailPoint: Identifiable {
    let id = UUID()
    let point: CGPoint
    let timestamp: Date
}

struct TitleView: View {
    let start: () -> Void
    var body: some View {
        ZStack{
            Image("FullForest")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Image("Title")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360)
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
                    .padding(.top, 60)


                Button(action: start) {
                    Text("Start Game").bubblegumStyle(size: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)

                Spacer()
            }
            
        }
    }
}

struct GameOverView: View {
    let score: Int
    let highScore: Int
    let playAgain: () -> Void
    let quit: () -> Void
    var body: some View {
        
        ZStack {
            Image("FullForest")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.45)))
            Image("Plank")
                .resizable()
                .frame(width: 400, height: 300)
            
                VStack(spacing: 16) {
                Spacer()
                Text("Game Over")
                    .bubblegumStyle(size: 40)
                Text("Score: \(score)")
                    .bubblegumStyle(size: 24)
                Text("High Score: \(highScore)")
                    .bubblegumStyle(size: 20)
                HStack(spacing: 16) {
                    Button(action: playAgain) {
                        Text("Play Again").bubblegumStyle(size: 20)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(action: quit) {
                        Text("Quit").bubblegumStyle(size: 20)
                    }
                }
                Spacer()
            }
            .padding()
        }
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
    @State private var scorePop = false

    var body: some View {
        VStack(spacing: 12) {
            topBar
            boardView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(CGFloat(GameConfig.cols) / CGFloat(GameConfig.rows), contentMode: .fit)
                .padding(.top, 72)
                .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottomTrailing) {
            ZStack {
                if vm.showPauseOverlay { pauseOverlay }
                if !vm.showPauseOverlay {
                    HStack(alignment: .bottom, spacing: 12) {
                        
                        TimerPill(text: timeString(vm.sessionTimeRemaining))
                            .allowsHitTesting(false)
                            .padding(.bottom, 72)
                        
                        CapybaraView(assetName: vm.capybaraAssetName, jumpTick: vm.capybaraJumpTick)
                            .allowsHitTesting(false)
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 60)
                }
            }
        }
        .overlay {
            TimeAddedOverlay(tick: vm.timeAddedTick)
                .allowsHitTesting(false)
        }
        .background(
            ZStack {
                AnimatedSkyBackground()
                ForestForeground()
            }
        )
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
            VStack(spacing: 0) {
                Text("Score")
                    .bubblegumStyle(size: 18)
                    .lineLimit(1)
                ZStack {
                    if scorePop {
                        LinearGradient(colors: [Color.green, Color.mint, Color.green], startPoint: .leading, endPoint: .trailing)
                            .mask(
                                Text("\(vm.score)")
                                    .font(.custom("Bubblegum", size: 34))
                            )
                            .blur(radius: 1.5)
                            .opacity(0.9)
                    }
                    Text("\(vm.score)")
                        .bubblegumStyle(size: 34)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .scaleEffect(scorePop ? 1.15 : 1.0)
                .animation(.spring(response: 0.16, dampingFraction: 0.7), value: scorePop)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: { vm.pauseGame() }) {
                Image(systemName: "pause.fill")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.7)))
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .frame(height: 72)
        .onChange(of: vm.pointsFlyupTick) { _, _ in
            scorePop = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                scorePop = false
            }
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Paused").bubblegumStyle(size: 28)
                HStack(spacing: 12) {
                    Button(action: { vm.resumeGame() }) { Text("Resume").bubblegumStyle(size: 18) }
                        .buttonStyle(.borderedProminent)
                    Button(action: { vm.restartGamePreservingHighScore() }) { Text("Restart").bubblegumStyle(size: 18) }
                    Button(action: { endGame() }) { Text("Title").bubblegumStyle(size: 18) }
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
                    .fill(Color.gray.opacity(0.30))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.45)))

                // Orbs
                ForEach(0..<GameConfig.rows, id: \.self) { r in
                    ForEach(0..<GameConfig.cols, id: \.self) { c in
                        let pos = GridPosition(row: r, col: c)
                        if let orb = vm.board[r][c] {
                            let isHiddenByDrag = vm.isDragging && vm.dragCurrent == pos
                            let isHighlighted = vm.highlightedMatches.contains(pos)
                            let isFading = vm.fadingMatches.contains(pos)
                            let scale: CGFloat = isHighlighted ? 1.12 : 1.0
                            let opacity: CGFloat = isFading ? 0.0 : 1.0
                            Group {
                                if !isHiddenByDrag {
                                    Image(orb.assetName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
                                        .position(cellCenter(for: pos, cellSize: cellSize, offsetX: offsetX, offsetY: offsetY))
                                        .scaleEffect(scale)
                                        .opacity(opacity)
                                        .shadow(color: isHighlighted ? Color.white.opacity(0.9) : .clear, radius: 10)
                                        .animation(.easeInOut(duration: 0.2), value: vm.board)
                                        .animation(.easeInOut(duration: 0.2), value: vm.highlightedMatches)
                                        .animation(.easeInOut(duration: 0.2), value: vm.fadingMatches)
                                }
                            }
                        }
                    }
                }

                // Dragging orb overlay
                if vm.isDragging, let current = vm.dragCurrent, let originOrb = vm.board[current.row][current.col] {
                    let point: CGPoint = dragOverlayPoint ?? cellCenter(for: current, cellSize: cellSize, offsetX: offsetX, offsetY: offsetY)
                    Image(originOrb.assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cellSize * 1.0, height: cellSize * 1.0)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 3))
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                        .position(point)
                        .transition(.scale)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: vm.isDragging)
                }

                // Drag timer indicator above finger
                if vm.isDragging {
                    if let current = vm.dragCurrent {
                        let point: CGPoint = dragOverlayPoint ?? cellCenter(for: current, cellSize: cellSize, offsetX: offsetX, offsetY: offsetY)
                        DragTimerIndicator(fraction: max(0, min(1, vm.dragTimeRemaining / GameConfig.dragDuration)))
                            .position(x: point.x, y: point.y - cellSize * 0.9)
                            .allowsHitTesting(false)
                    } else if let p = dragOverlayPoint {
                        DragTimerIndicator(fraction: max(0, min(1, vm.dragTimeRemaining / GameConfig.dragDuration)))
                            .position(x: p.x, y: p.y - cellSize * 0.9)
                            .allowsHitTesting(false)
                    }
                }

                // Combo popups over matched groups
                ForEach(vm.comboPopups) { popup in
                    let center = groupCenter(popup.group, cellSize: cellSize, offsetX: offsetX, offsetY: offsetY)
                    ComboCountBubble(count: popup.count)
                        .position(center)
                }

                // Trailing effect (above orbs and drag overlay)
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
private func groupCenter(_ group: [GridPosition], cellSize: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> CGPoint {
    guard !group.isEmpty else { return CGPoint(x: offsetX, y: offsetY) }
    let xs = group.map { offsetX + (CGFloat($0.col) + 0.5) * cellSize }
    let ys = group.map { offsetY + (CGFloat($0.row) + 0.5) * cellSize }
    let cx = xs.reduce(0, +) / CGFloat(xs.count)
    let cy = ys.reduce(0, +) / CGFloat(ys.count)
    return CGPoint(x: cx, y: cy)
}

private struct ComboCountBubble: View {
    let count: Int
    @State private var appear = false
    @State private var gradientAngle: Double = 0

    private let cycleColors: [Color] = [.red, .blue, .green, .purple, .yellow]

    var body: some View {
        Text("\(count)x")
            .font(.custom("Bubblegum", size: 28))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bubbleBackground)
            .scaleEffect(appear ? 1.2 : 0.6)
            .opacity(appear ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
                    appear = true
                }
                if count >= 7 {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        gradientAngle = 360
                    }
                }
                // Fade away shortly after pop
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        appear = false
                    }
                }
            }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if count >= 7 {
            Capsule()
                .fill(AngularGradient(colors: cycleColors + [cycleColors.first!], center: .center))
                .rotationEffect(.degrees(gradientAngle))
                .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
        } else if count >= 3 {
            let idx = (count - 3) % cycleColors.count
            Capsule()
                .fill(cycleColors[idx].opacity(0.85))
                .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
        } else {
            Capsule()
                .fill(Color.black.opacity(0.55))
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
    }
}

private struct CapybaraView: View {
    let assetName: String
    let jumpTick: Int
    @State private var jumpOffset: CGFloat = 0
    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 240, height: 240)
            .offset(y: jumpOffset)
            .onChange(of: jumpTick) { _, _ in
                jump()
            }
            .onAppear {
                // ensure an initial state
                jumpOffset = 0
            }
    }

    private func jump() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
            jumpOffset = -14
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                jumpOffset = 0
            }
        }
    }
}

private struct TimerPill: View {
    let text: String
    var body: some View {
        Text(text)
            .bubblegumStyle(size: 52)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
            )
    }
}

private struct DragTimerIndicator: View {
    let fraction: Double // 0...1 remaining

    private var arcColor: Color {
        let clamped = max(0, min(1, fraction))
        let hue = clamped * 0.33 // red -> yellow -> green
        return Color(hue: hue, saturation: 0.95, brightness: 1.0)
    }

    var body: some View {
        ZStack {
            // Subtle outer outline
            Circle()
                .stroke(Color.black.opacity(0.45), lineWidth: 1)

            // Thin background ring
            Circle()
                .stroke(Color.white.opacity(0.32), lineWidth: 2)

            // Foreground arc showing remaining time
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .rotation(Angle(degrees: -90))
                .stroke(arcColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(width: 26, height: 26)
        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
        .opacity(0.9)
        .animation(.linear(duration: 0.05), value: fraction)
    }
}

private struct AnimatedSkyBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let speed: Double = 20 // points per second
                let offset = CGFloat((t * speed).truncatingRemainder(dividingBy: Double(w)))
                HStack(spacing: 0) {
                    Image("SkyBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .clipped()
                    Image("SkyBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .clipped()
                }
                .offset(x: -offset)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
private struct ForestForeground: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Image("ForestBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height * 0.80)
                    .clipped()
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct TimeAddedOverlay: View {
    let tick: Int
    @State private var visible = false
    @State private var angle: Double = 0
    var body: some View {
        ZStack {
            if visible {
                ZStack {
                    // Black outlined base
                    Text("Time Added!")
                        .font(.custom("Bubblegum", size: 44))
                        .foregroundStyle(.black)
                        .shadow(color: .black, radius: 0, x: 1, y: 1)
                        .shadow(color: .black, radius: 0, x: -1, y: 1)
                        .shadow(color: .black, radius: 0, x: 1, y: -1)
                        .shadow(color: .black, radius: 0, x: -1, y: -1)
                    // Animated rainbow fill masked by text
                    AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center, angle: .degrees(angle))
                        .mask(
                            Text("Time Added!")
                                .font(.custom("Bubblegum", size: 44))
                        )
                }
                .scaleEffect(visible ? 1.15 : 0.7)
                .opacity(visible ? 1.0 : 0.0)
                .onAppear {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        visible = true
                    }
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeOut(duration: 0.25)) { visible = false }
                    }
                }
            }
        }
        .onChange(of: tick) { _, _ in
            // retrigger animation on tick change
            visible = false
            angle = 0
            DispatchQueue.main.async {
                visible = true
            }
        }
    }
}

