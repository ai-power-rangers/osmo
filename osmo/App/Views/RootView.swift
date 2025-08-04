//
//  RootView.swift
//  osmo
//
//  Root view using native iOS NavigationStack
//

import SwiftUI

struct RootView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            LobbyView(navigationPath: $path, onGameSelected: handleGameSelected)
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
    }
    
    private func handleGameSelected(_ gameId: String) {
        switch gameId {
        case "tangram":
            path.append(AppRoute.tangramPuzzleSelect)
        default:
            break
        }
    }
    
    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .lobby:
            LobbyView(navigationPath: $path, onGameSelected: handleGameSelected)
            
        case .settings:
            SettingsView()
            
        case .tangramGame(let puzzleId):
            TangramGame(puzzleId: puzzleId)
            
        case .tangramEditor(let puzzleId):
            ImprovedTangramEditor(puzzleId: puzzleId)
            
        case .tangramPuzzleSelect:
            TangramPuzzleSelect()
            
        case .cvTest:
            CVTestView()
        }
    }
}