//
//  RootView.swift
//  osmo
//
//  Root view using native iOS NavigationStack
//

import SwiftUI

struct RootView: View {
    @Environment(ServiceContainer.self) private var services
    @State private var navigation = NavigationState()
    @State private var selectedGame: String?
    @State private var showingGameView = false
    
    var body: some View {
        NavigationStack(path: $navigation.navigationPath) {
            LobbyView(
                navigationPath: $navigation.navigationPath,
                onGameSelected: { gameId in
                    selectedGame = gameId
                    showingGameView = true
                }
            )
            .navigationDestination(for: NavigationState.Route.self) { route in
                destinationView(for: route)
            }
        }
        .environment(navigation)
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
    private func destinationView(for route: NavigationState.Route) -> some View {
        switch route {
        case .home:
            LobbyView(
                navigationPath: $navigation.navigationPath,
                onGameSelected: { gameId in
                    selectedGame = gameId
                    showingGameView = true
                }
            )
            
        case .lobby:
            LobbyView(
                navigationPath: $navigation.navigationPath,
                onGameSelected: { gameId in
                    selectedGame = gameId
                    showingGameView = true
                }
            )
            
        case .game(let gameInfo):
            GameHost(gameId: gameInfo.id) {
                navigation.goBack()
            }
            .injectServices(from: services)
            
        case .settings:
            SettingsView()
                .injectServices(from: services)
            
        case .editor(let gameInfo, let mode):
            if gameInfo.id == "tangram" {
                TangramEditor()
                    .injectServices(from: services)
            } else if gameInfo.id == "sudoku" {
                SudokuEditorLauncher()
                    .injectServices(from: services)
            } else {
                Text("Editor not available for \(gameInfo.displayName)")
            }
        }
    }
}