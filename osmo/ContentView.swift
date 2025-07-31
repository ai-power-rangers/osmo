//
//  ContentView.swift
//  osmo
//
//  Created by Mitchell White on 7/30/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppCoordinator.self) var coordinator
    
    var body: some View {
        @Bindable var coordinator = coordinator
        
        NavigationStack(path: $coordinator.navigationPath) {
            LobbyView()
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .lobby:
                        LobbyView()
                    case .game(let gameId):
                        GameHostPlaceholder(gameId: gameId)
                    case .settings:
                        SettingsView()
                    case .parentGate:
                        ParentGatePlaceholder()
                    }
                }
        }
        .alert("Error", isPresented: $coordinator.showError) {
            Button("OK") {
                coordinator.showError = false
            }
        } message: {
            Text(coordinator.errorMessage ?? "An error occurred")
        }
    }
}

// MARK: - Placeholder Views
struct GameHostPlaceholder: View {
    let gameId: String
    @Environment(\.coordinator) var coordinator
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Game: \(gameId)")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Text("Game Host will be implemented in Phase 2")
                    .foregroundColor(.gray)
                
                Button("Back to Lobby") {
                    coordinator.navigateBack()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationBarHidden(true)
    }
}

struct ParentGatePlaceholder: View {
    var body: some View {
        Text("Parent Gate - Coming Soon")
            .navigationTitle("Parent Gate")
    }
}

#Preview {
    ContentView()
        .environment(AppCoordinator())
}
