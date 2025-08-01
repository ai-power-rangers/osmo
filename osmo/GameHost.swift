//
//  GameHost.swift
//  osmo
//
//  Hosts SpriteKit games with proper CV integration
//

import SwiftUI
import SpriteKit
import AVFoundation

struct GameHost: View {
    let gameId: String
    @Environment(AppCoordinator.self) var coordinator
    @State private var gameModule: (any GameModule)?
    @State private var gameScene: SKScene?
    @State private var showExitConfirmation = false
    @State private var cameraSession: AVCaptureSession?
    @State private var overlayViewModel = CVOverlayViewModel()
    @State private var cvEventTask: Task<Void, Never>?
    @State private var cvService: CVServiceProtocol?
    
    var body: some View {
        ZStack {
            if let scene = gameScene {
                // Camera preview with game overlay
                CameraPreviewWithGame(
                    scene: scene,
                    cameraSession: cameraSession,
                    overlayViewModel: overlayViewModel
                )
                .ignoresSafeArea()
            } else {
                // Loading state
                ProgressView("Loading game...")
                    .progressViewStyle(CircularProgressViewStyle())
            }
            
            // Exit button overlay
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showExitConfirmation = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadGame()
        }
        .onDisappear {
            cleanupGame()
        }
        .alert("Exit Game?", isPresented: $showExitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Exit", role: .destructive) {
                coordinator.navigateBack()
            }
        } message: {
            Text("Are you sure you want to exit the game?")
        }
    }
    
    private func loadGame() {
        // Create game context with overlay view model
        let context = GameHostContext(overlayViewModel: overlayViewModel)
        
        // Load appropriate game module
        switch gameId {
        case "rock-paper-scissors":
            let module = RockPaperScissorsGameModule()
            gameModule = module
            gameScene = module.createGameScene(
                size: UIScreen.main.bounds.size,
                context: context
            )
            
            // Start CV session and get camera session
            startCVSession(context: context)
            
        case "finger_count":
            // Placeholder for finger count game
            coordinator.showError("Game not yet implemented: \(gameId)")
            coordinator.navigateBack()
            
        default:
            // Show error for unknown game
            coordinator.showError("Unknown game: \(gameId)")
            coordinator.navigateBack()
        }
        
        // Track game launch
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("game_launched", parameters: ["game_id": gameId])
    }
    
    private func startCVSession(context: GameHostContext) {
        Task {
            do {
                let service = context.cvService
                
                // Store the service reference
                await MainActor.run {
                    self.cvService = service
                }
                
                // Enable debug mode
                if let cameraService = service as? CameraVisionService {
                    cameraService.debugMode = true
                }
                
                // Start CV session
                try await service.startSession()
                
                // Get camera session for preview
                if let cameraService = service as? CameraVisionService {
                    await MainActor.run {
                        cameraSession = cameraService.cameraSession
                    }
                }
                
                // Subscribe to CV events for overlay updates
                await subscribeToCVEvents(cvService: service)
            } catch {
                print("[GameHost] Failed to start CV session: \(error)")
            }
        }
    }
    
    private func subscribeToCVEvents(cvService: CVServiceProtocol) async {
        let stream = cvService.eventStream(
            gameId: gameId,
            events: [] // Subscribe to all events
        )
        
        let overlayVM = overlayViewModel
        cvEventTask = Task {
            for await event in stream {
                await MainActor.run {
                    Self.updateOverlay(overlayVM, with: event)
                }
            }
        }
    }
    
    private static func updateOverlay(_ overlayViewModel: CVOverlayViewModel, with event: CVEvent) {
        switch event.type {
        case .fingerCountDetected(let count):
            // Update overlay with hand bounding box
            if let metadata = event.metadata, let boundingBox = metadata.boundingBox {
                let chirality: HandChirality = {
                    if let chiralityString = metadata.additionalProperties["hand_chirality"] as? String,
                       let detectedChirality = HandChirality(rawValue: chiralityString) {
                        return detectedChirality
                    }
                    return .unknown
                }()
                
                overlayViewModel.updateHand(
                    boundingBox: boundingBox,
                    fingerCount: count,
                    confidence: event.confidence,
                    chirality: chirality
                )
            }
            
        case .handLost:
            overlayViewModel.clearHands()
            
        default:
            break
        }
    }
    
    private func cleanupGame() {
        print("[GameHost] Starting cleanup...")
        
        // Cancel CV event subscription first
        cvEventTask?.cancel()
        cvEventTask = nil
        
        // Stop CV session
        if let service = cvService {
            print("[GameHost] Stopping CV session...")
            service.stopSession()
            
            // Disable debug mode if it was enabled
            if let cameraService = service as? CameraVisionService {
                cameraService.debugMode = false
            }
        }
        cvService = nil
        
        // Clean up game components
        gameModule?.cleanup()
        gameModule = nil
        gameScene = nil
        cameraSession = nil
        overlayViewModel.clearHands()
        
        // Track game exit
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("game_exited", parameters: ["game_id": gameId])
        
        print("[GameHost] Cleanup completed")
    }
}

// MARK: - Camera Preview with Game Overlay
struct CameraPreviewWithGame: View {
    let scene: SKScene
    let cameraSession: AVCaptureSession?
    @Bindable var overlayViewModel: CVOverlayViewModel
    
    var body: some View {
        ZStack {
            // Camera preview layer
            if let session = cameraSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
                    .overlay(
                        CVDetectionOverlayView(
                            viewModel: overlayViewModel,
                            frameSize: UIScreen.main.bounds.size
                        )
                    )
            } else {
                // Fallback to black background
                Color.black
                    .ignoresSafeArea()
            }
            
            // Game overlay with transparent background
            SpriteView(scene: scene, options: [.allowsTransparency])
                .ignoresSafeArea()
        }
    }
}

// MARK: - Game Context Implementation
private final class GameHostContext: GameContext {
    let overlayViewModel: CVOverlayViewModel
    
    init(overlayViewModel: CVOverlayViewModel) {
        self.overlayViewModel = overlayViewModel
    }
    
    var cvService: CVServiceProtocol {
        ServiceLocator.shared.resolve(CVServiceProtocol.self)
    }
    
    var audioService: AudioServiceProtocol {
        ServiceLocator.shared.resolve(AudioServiceProtocol.self)
    }
    
    var analyticsService: AnalyticsServiceProtocol {
        ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
    }
    
    var persistenceService: PersistenceServiceProtocol {
        ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
    }
}
