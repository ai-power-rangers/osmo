//
//  ContentView.swift
//  osmo
//
//  Created by Mitchell White on 7/30/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppCoordinator.self) var coordinator
    @State private var permissionManager = CameraPermissionManager.shared
    @State private var showPermissionView = false
    
    var body: some View {
        @Bindable var coordinator = coordinator
        
        NavigationStack(path: $coordinator.navigationPath) {
            LobbyView()
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .lobby:
                        LobbyView()
                    case .game(let gameId):
                        // Check permission before showing game
                        if permissionManager.status.canUseCamera {
                            GameHost(gameId: gameId)
                        } else {
                            CameraPermissionNeededView(gameId: gameId)
                        }
                    case .settings:
                        SettingsView()
                    case .parentGate:
                        ParentGatePlaceholder()
                    case .cvTest:
                        CVTestView()
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
        .onAppear {
            checkInitialPermissions()
        }
    }
    
    private func checkInitialPermissions() {
        permissionManager.checkCurrentStatus()
        
        // Log permission status
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("app_launch_permission_status", parameters: [
            "camera_permission": String(describing: permissionManager.status)
        ])
    }
}

// MARK: - Placeholder Views
struct GameHostPlaceholder: View {
    let gameId: String
    @Environment(AppCoordinator.self) var coordinator
    
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

// MARK: - Permission Needed View
struct CameraPermissionNeededView: View {
    let gameId: String
    @Environment(AppCoordinator.self) var coordinator
    
    var body: some View {
        CameraPermissionView {
            // Permission granted - reload the game
            coordinator.navigateBack()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                coordinator.launchGame(gameId)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppCoordinator())
}
