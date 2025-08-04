//
//  ContentView.swift
//  osmo
//
//  Main content view - Refactored with proper service injection
//

import SwiftUI
import AVFoundation

struct ContentView: View {

    @Environment(\.analyticsService) private var analyticsService
    @Environment(ServiceContainer.self) private var services
    
    @State private var selectedGame: String?
    @State private var showingGameView = false
    @State private var hasCheckedPermissions = false
    
    private let games = [
        GameDisplayInfo(id: "tangram", name: "Tangram", icon: "square.split.diagonal.2x2", color: .blue),
        GameDisplayInfo(id: "sudoku", name: "Sudoku", icon: "square.grid.3x3", color: .purple),
        GameDisplayInfo(id: "rockpaperscissors", name: "Rock Paper Scissors", icon: "hand.raised", color: .green)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Header
                    VStack(spacing: Spacing.s) {
                        Text("Choose a Game")
                            .font(Typography.title)
                        
                        Text("Select a game to play")
                            .font(Typography.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, Spacing.xl)
                    
                    // Game Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: Spacing.m) {
                        ForEach(games) { game in
                            GameCard(game: game) {
                                selectGame(game.id)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.m)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Osmo Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Settings navigation handled in LobbyView
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
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
        .task {
            if !hasCheckedPermissions {
                await checkInitialPermissions()
                hasCheckedPermissions = true
            }
        }
    }
    
    private func selectGame(_ gameId: String) {
        analyticsService?.logEvent("game_selected", parameters: ["game_id": gameId])
        
        selectedGame = gameId
        showingGameView = true
    }
    
    private func checkInitialPermissions() async {
        // Check camera permissions for CV games
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        analyticsService?.logEvent("permission_status_check", parameters: [
            "permission_type": "camera",
            "status": permissionStatusString(status)
        ])
    }
    
    private func permissionStatusString(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "not_determined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Game Card

struct GameCard: View {
    let game: GameDisplayInfo
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.m) {
                Image(systemName: game.icon)
                    .font(.system(size: 50))
                    .foregroundColor(game.color)
                    .frame(height: 60)
                
                Text(game.name)
                    .font(Typography.headline)
                    .foregroundColor(.primary)
            }
            .frame(width: 150, height: 150)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.extraLarge)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: game.color.opacity(0.2),
                        radius: isPressed ? Shadow.small.radius : Shadow.large.radius,
                        y: isPressed ? Shadow.small.y : Shadow.large.y
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.extraLarge)
                    .stroke(game.color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(Animations.quick) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Game Display Info

struct GameDisplayInfo: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(ServiceContainer())
}