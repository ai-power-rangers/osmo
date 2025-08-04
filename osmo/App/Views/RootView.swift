//
//  RootView.swift
//  osmo
//
//  Root view using native iOS NavigationStack
//

import SwiftUI

struct RootView: View {
    @Environment(ServiceContainer.self) private var services
    
    @State private var navigationPath = NavigationPath()
    @State private var selectedGame: String?
    @State private var showingGameView = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            LobbyView(
                navigationPath: $navigationPath,
                onGameSelected: { gameId in
                    selectedGame = gameId
                    showingGameView = true
                }
            )
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
        }
        .fullScreenCover(isPresented: $showingGameView) {
            if let gameId = selectedGame {
                GameHost(gameId: gameId) {
                    showingGameView = false
                    selectedGame = nil
                }
                .injectServices(from: services)
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .settings:
            SettingsView()
                .injectServices(from: services)
            
        case .cvTest:
            CVTestView()
                .injectServices(from: services)
            
        case .gameSettings:
            Text("Game Settings")
                .injectServices(from: services)
            
        case .tangramEditor(let puzzleId):
            TangramEditor()
                .injectServices(from: services)
            
        case .tangramPuzzleSelect:
            TangramPlayView()
                .injectServices(from: services)
            
        case .sudokuEditor(let puzzleId):
            SudokuEditorLauncher()
                .injectServices(from: services)
            
        case .sudokuPuzzleSelect:
            SudokuPuzzleSelector(onGameSelected: { gameId, puzzleId in
                selectedGame = gameId
                showingGameView = true
            })
            .injectServices(from: services)
                
        case .gridEditor(let gameType):
            GridEditorHostView(gameType: gameType)
                .injectServices(from: services)
            
        case .game(let gameId, let puzzleId):
            // This shouldn't be reached since games use fullScreenCover
            EmptyView()
        }
    }
}