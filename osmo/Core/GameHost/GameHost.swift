//
//  GameHost.swift
//  osmo
//
//  Game host view - Refactored with proper service injection
//

import SwiftUI
import SpriteKit

struct GameHost: View {
    let gameId: String
    let onExit: () -> Void
    
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.audioService) private var audioService
    @Environment(\.cvService) private var cvService
    @Environment(ServiceContainer.self) private var services
    
    @State private var gameModule: (any GameModule)?
    @State private var gameContext: GameContext?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var startTime = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading game...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppColors.gameBackground)
                } else if let error = loadError {
                    GameLoadErrorView(error: error, onRetry: loadGame, onExit: onExit)
                } else if let module = gameModule, let context = gameContext {
                    // Create a SpriteView to host the game scene
                    GeometryReader { geometry in
                        let scene = module.createGameScene(
                            size: geometry.size,
                            context: context
                        )
                        
                        SpriteView(scene: scene)
                            .ignoresSafeArea()
                            .onAppear {
                                print("[GameHost] SpriteView appeared for game: \(gameId)")
                            }
                            .onDisappear {
                                print("[GameHost] SpriteView disappearing for game: \(gameId)")
                                trackGameExit()
                                module.cleanup()
                            }
                    }
                } else {
                    GameNotFoundView(gameId: gameId, onExit: onExit)
                }
            }
            .navigationTitle(gameDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onExit()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                }
            }
        }
        .task {
            await loadGame()
        }
    }
    
    private var gameDisplayName: String {
        switch gameId {
        case "tangram": return "Tangram"
        case "sudoku": return "Sudoku"
        case "rock-paper-scissors": return "Rock Paper Scissors"
        default: return "Game"
        }
    }
    
    @MainActor
    private func loadGame() async {
        isLoading = true
        loadError = nil
        startTime = Date()
        
        // Log game launch attempt
        analyticsService?.logEvent("game_launch_attempt", parameters: ["game_id": gameId])
        
        do {
            // Create game context with all services
            let context = GameContextImpl(
                cvService: services.cvService,
                audioService: services.audioService,
                analyticsService: services.analyticsService,
                persistenceService: services.persistenceService
            )
            
            // Create game module
            let module = createGameModule(for: gameId, context: context)
            
            if let module = module {
                self.gameModule = module
                self.gameContext = context
                
                // Log successful launch
                analyticsService?.logEvent("game_launched", parameters: [
                    "game_id": gameId,
                    "load_time": String(format: "%.2f", Date().timeIntervalSince(startTime))
                ])
                
                // Play launch sound
                audioService?.playSound("game_start")
            } else {
                throw GameError.gameNotFound(gameId)
            }
            
        } catch {
            loadError = error
            
            // Log error
            analyticsService?.logEvent("game_launch_error", parameters: [
                "game_id": gameId,
                "error": error.localizedDescription
            ])
        }
        
        isLoading = false
    }
    
    private func createGameModule(for gameId: String, context: GameContext) -> (any GameModule)? {
        switch gameId {
        case "tangram":
            return TangramGameModule()
        case "sudoku":
            return SudokuGameModule()
        case "rock-paper-scissors":
            return RockPaperScissorsGameModule()
        default:
            return nil
        }
    }
    
    private func trackGameExit() {
        let sessionDuration = Date().timeIntervalSince(startTime)
        
        analyticsService?.logEvent("game_exited", parameters: [
            "game_id": gameId,
            "session_duration": String(format: "%.2f", sessionDuration)
        ])
    }
}

// MARK: - Error Views

struct GameLoadErrorView: View {
    let error: Error
    let onRetry: () async -> Void
    let onExit: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 10) {
                Text("Unable to Load Game")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 20) {
                Button("Exit") {
                    onExit()
                }
                .buttonStyle(.bordered)
                
                Button("Retry") {
                    Task {
                        await onRetry()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct GameNotFoundView: View {
    let gameId: String
    let onExit: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "questionmark.square.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 10) {
                Text("Game Not Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("The game '\(gameId)' is not available.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Button("Back to Games") {
                onExit()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Game Context Implementation

final class GameContextImpl: GameContext {
    let cvService: CVServiceProtocol
    let audioService: AudioServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let persistenceService: PersistenceServiceProtocol
    let storageService: PuzzleStorageProtocol
    
    init(cvService: CVServiceProtocol,
         audioService: AudioServiceProtocol,
         analyticsService: AnalyticsServiceProtocol,
         persistenceService: PersistenceServiceProtocol) {
        self.cvService = cvService
        self.audioService = audioService
        self.analyticsService = analyticsService
        self.persistenceService = persistenceService
        // Use a generic storage service that can handle all puzzle types
        self.storageService = UniversalPuzzleStorage.shared
    }
}

// MARK: - Game Errors

enum GameError: LocalizedError {
    case gameNotFound(String)
    case initializationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .gameNotFound(let gameId):
            return "Game '\(gameId)' not found"
        case .initializationFailed(let reason):
            return "Failed to initialize game: \(reason)"
        }
    }
}