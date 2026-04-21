//
//  ContentView.swift
//  FinalProject
//
//  Created by Kevin Huynh on 4/13/26.
//

import SwiftUI

struct ContentView: View {
    @State private var appScreen: GameScreen = .title
    @StateObject private var vm = GameViewModel()

    var body: some View {
        switch appScreen {
        case .title:
            TitleView {
                vm.resetBoard()
                appScreen = .playing
            }
        case .playing:
            GameView(vm: vm) {
                // Called when session ends or user taps Title in pause overlay
                if vm.sessionTimeRemaining <= 0 {
                    // Session ended
                    vm.updateHighScoreIfNeeded()
                    appScreen = .gameOver(finalScore: vm.score)
                } else {
                    // Title tapped
                    appScreen = .title
                }
            }
        case .gameOver(let finalScore):
            GameOverView(score: finalScore, highScore: vm.highScore, playAgain: {
                vm.resetBoard()
                appScreen = .playing
            }, quit: {
                appScreen = .title
            })
        }
    }
}

#Preview {
    ContentView()
}
