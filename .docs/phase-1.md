# Phase 1: Core Foundation - Detailed Implementation Plan

## Overview
This document provides a granular, step-by-step implementation guide for Phase 1 of the Osmo-like Educational App. Each step includes specific code to write, files to create, and validation checks.

## Step 1: Project Setup (30 minutes)

### 1.1 Create New Xcode Project
- Open Xcode → Create New Project
- Choose iOS App template
- Product Name: `OsmoApp`
- Interface: SwiftUI
- Language: Swift
- Include Tests: Yes (for future use)
- Core Data: No

### 1.2 Configure Project Settings
- Set Deployment Target: iOS 16.0
- Device: iPad only
- Orientation: Landscape only
- Add to Info.plist:
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>This app needs camera access to see your toys and play games!</string>
  ```

### 1.3 Create Folder Structure
Create the following groups in Xcode:
```
OsmoApp/
├── App/
│   ├── OsmoApp.swift (rename from default)
│   └── ContentView.swift (will delete later)
├── Core/
│   ├── Protocols/
│   ├── Models/
│   └── Services/
├── Features/
│   ├── Lobby/
│   ├── GameHost/
│   └── Settings/
├── Games/
├── Resources/
└── Utilities/
```

## Step 2: Core Models (45 minutes)

### 2.1 Create CVEvent Models
Create `Core/Models/CVEvent.swift`:
```swift
import Foundation
import CoreGraphics

// MARK: - CV Event Types
enum CVEventType: Equatable {
    case objectDetected(type: String, objectId: UUID)
    case objectMoved(type: String, objectId: UUID, from: CGPoint, to: CGPoint)
    case objectRemoved(type: String, objectId: UUID)
    case gestureRecognized(type: GestureType)
    case fingerCountDetected(count: Int) // For our mock game
}

enum GestureType: String, Equatable {
    case tap
    case swipe
    case pinch
    case rotate
}

// MARK: - CV Event
struct CVEvent {
    let id: UUID = UUID()
    let type: CVEventType
    let position: CGPoint // Normalized 0-1
    let confidence: Float // 0-1
    let timestamp: TimeInterval
    let metadata: CVMetadata?
    
    init(type: CVEventType, 
         position: CGPoint = CGPoint(x: 0.5, y: 0.5),
         confidence: Float = 1.0,
         timestamp: TimeInterval = Date().timeIntervalSince1970,
         metadata: CVMetadata? = nil) {
        self.type = type
        self.position = position
        self.confidence = confidence
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - CV Metadata
struct CVMetadata {
    let boundingBox: CGRect?
    let rotation: Float?
    let additionalProperties: [String: Any]
    
    init(boundingBox: CGRect? = nil,
         rotation: Float? = nil,
         additionalProperties: [String: Any] = [:]) {
        self.boundingBox = boundingBox
        self.rotation = rotation
        self.additionalProperties = additionalProperties
    }
}

// MARK: - CV Subscription
class CVSubscription {
    let id = UUID()
    let gameId: String
    let eventTypes: [CVEventType]
    private let handler: (CVEvent) -> Void
    
    init(gameId: String, eventTypes: [CVEventType], handler: @escaping (CVEvent) -> Void) {
        self.gameId = gameId
        self.eventTypes = eventTypes
        self.handler = handler
    }
    
    func handle(_ event: CVEvent) {
        handler(event)
    }
    
    func cancel() {
        // Implementation will be added when we build the real CV service
    }
}
```

### 2.2 Create Game Models
Create `Core/Models/GameInfo.swift`:
```swift
import Foundation

// MARK: - Game Category
enum GameCategory: String, CaseIterable, Codable {
    case literacy
    case math
    case creativity
    case spatialReasoning
    case problemSolving
    
    var displayName: String {
        switch self {
        case .literacy: return "Reading & Writing"
        case .math: return "Math & Numbers"
        case .creativity: return "Art & Creativity"
        case .spatialReasoning: return "Shapes & Space"
        case .problemSolving: return "Logic & Puzzles"
        }
    }
    
    var iconName: String {
        switch self {
        case .literacy: return "text.book.closed"
        case .math: return "number.square"
        case .creativity: return "paintbrush"
        case .spatialReasoning: return "cube"
        case .problemSolving: return "puzzlepiece"
        }
    }
}

// MARK: - Game Info
struct GameInfo: Identifiable, Codable {
    let id: String // Same as gameId for Identifiable
    let gameId: String
    let displayName: String
    let description: String
    let iconName: String
    let minAge: Int
    let maxAge: Int
    let category: GameCategory
    let isLocked: Bool
    let bundleSize: Int // in MB
    let requiredCVEvents: [String] // Simplified for codable
    
    init(gameId: String,
         displayName: String,
         description: String,
         iconName: String,
         minAge: Int,
         maxAge: Int = 8,
         category: GameCategory,
         isLocked: Bool = false,
         bundleSize: Int = 50,
         requiredCVEvents: [String] = []) {
        self.id = gameId
        self.gameId = gameId
        self.displayName = displayName
        self.description = description
        self.iconName = iconName
        self.minAge = minAge
        self.maxAge = maxAge
        self.category = category
        self.isLocked = isLocked
        self.bundleSize = bundleSize
        self.requiredCVEvents = requiredCVEvents
    }
}

// MARK: - Game Progress
struct GameProgress: Codable {
    let gameId: String
    var levelsCompleted: Set<String>
    var totalPlayTime: TimeInterval
    var lastPlayed: Date
    
    init(gameId: String) {
        self.gameId = gameId
        self.levelsCompleted = []
        self.totalPlayTime = 0
        self.lastPlayed = Date()
    }
}
```

### 2.3 Create Service Models
Create `Core/Models/ServiceModels.swift`:
```swift
import Foundation
import UIKit

// MARK: - Audio Models
enum AudioCategory: String {
    case sfx
    case music
    case voice
    case ambient
}

enum HapticType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
}

// MARK: - Analytics Event
struct AnalyticsEvent {
    let eventId = UUID()
    let eventType: EventType
    let gameId: String
    let timestamp = Date()
    let parameters: [String: Any]
}

enum EventType: String {
    case gameStarted
    case levelCompleted
    case achievementUnlocked
    case errorOccurred
    case cvEventProcessed
}

// MARK: - User Settings
struct UserSettings: Codable {
    var soundEnabled: Bool = true
    var musicEnabled: Bool = true
    var hapticEnabled: Bool = true
    var cvDebugMode: Bool = false
    var parentalControlsEnabled: Bool = false
}

// MARK: - Persistence Keys
enum PersistenceKey {
    case gameProgress(gameId: String)
    case userSettings
    case currentSession
    
    var stringValue: String {
        switch self {
        case .gameProgress(let gameId):
            return "game.\(gameId).progress"
        case .userSettings:
            return "settings.user"
        case .currentSession:
            return "session.current"
        }
    }
}
```

## Step 3: Core Protocols (45 minutes)

### 3.1 Create Service Protocols
Create `Core/Protocols/ServiceProtocols.swift`:
```swift
import Foundation
import CoreGraphics

// MARK: - CV Service Protocol
protocol CVServiceProtocol: AnyObject {
    var isSessionActive: Bool { get }
    var debugMode: Bool { get set }
    
    func startSession() async throws
    func stopSession()
    func subscribe(gameId: String, 
                  events: [CVEventType], 
                  handler: @escaping (CVEvent) -> Void) -> CVSubscription
    func unsubscribe(_ subscription: CVSubscription)
}

// MARK: - Audio Service Protocol
protocol AudioServiceProtocol: AnyObject {
    func preloadSound(_ soundName: String)
    func playSound(_ soundName: String)
    func playSound(_ soundName: String, volume: Float)
    func stopSound(_ soundName: String)
    func playHaptic(_ type: HapticType)
    func setBackgroundMusic(_ musicName: String?, volume: Float)
}

// MARK: - Analytics Service Protocol
protocol AnalyticsServiceProtocol: AnyObject {
    func logEvent(_ event: String, parameters: [String: Any])
    func startLevel(gameId: String, level: String)
    func endLevel(gameId: String, level: String, success: Bool, score: Int?)
    func logError(_ error: Error, context: String)
}

// MARK: - Persistence Service Protocol
protocol PersistenceServiceProtocol: AnyObject {
    // Game Progress
    func saveGameProgress(_ progress: GameProgress)
    func loadGameProgress(for gameId: String) -> GameProgress?
    
    // Level Completion
    func saveLevel(gameId: String, level: String, completed: Bool)
    func isLevelCompleted(gameId: String, level: String) -> Bool
    func getCompletedLevels(gameId: String) -> [String]
    
    // High Scores
    func saveHighScore(gameId: String, level: String, score: Int)
    func getHighScore(gameId: String, level: String) -> Int?
    
    // Settings
    func saveUserSettings(_ settings: UserSettings)
    func loadUserSettings() -> UserSettings
}
```

### 3.2 Create Game Module Protocol
Create `Core/Protocols/GameModule.swift`:
```swift
import Foundation
import SpriteKit

// MARK: - Game Context Protocol
protocol GameContext {
    var cvService: CVServiceProtocol { get }
    var audioService: AudioServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var persistenceService: PersistenceServiceProtocol { get }
}

// MARK: - Game Module Protocol
protocol GameModule: AnyObject {
    static var gameId: String { get }
    static var gameInfo: GameInfo { get }
    
    init()
    func createGameScene(size: CGSize, context: GameContext) -> SKScene
    func cleanup()
}

// MARK: - Game Scene Protocol (Optional helper)
protocol GameSceneProtocol: SKScene {
    var gameContext: GameContext? { get set }
    func handleCVEvent(_ event: CVEvent)
    func pauseGame()
    func resumeGame()
}
```

### 3.3 Create Coordinator Protocol
Create `Core/Protocols/CoordinatorProtocol.swift`:
```swift
import SwiftUI

// MARK: - Navigation Destination
enum NavigationDestination: Hashable {
    case lobby
    case game(gameId: String)
    case settings
    case parentGate
}

// MARK: - Coordinator Protocol
protocol CoordinatorProtocol: ObservableObject {
    var navigationPath: NavigationPath { get set }
    
    func navigateTo(_ destination: NavigationDestination)
    func navigateBack()
    func navigateToRoot()
    func showError(_ message: String)
}

// MARK: - App Error
enum AppError: LocalizedError {
    case gameLoadFailed(gameId: String)
    case cameraPermissionDenied
    case cameraUnavailable
    case serviceInitializationFailed(service: String)
    
    var errorDescription: String? {
        switch self {
        case .gameLoadFailed(let gameId):
            return "Could not load game \(gameId)"
        case .cameraPermissionDenied:
            return "Camera access is needed to play"
        case .cameraUnavailable:
            return "Camera is not available"
        case .serviceInitializationFailed(let service):
            return "\(service) service failed to start"
        }
    }
}
```

## Step 4: Service Locator Implementation (30 minutes)

### 4.1 Create Service Locator
Create `Core/Services/ServiceLocator.swift`:
```swift
import Foundation

// MARK: - Service Locator
final class ServiceLocator {
    static let shared = ServiceLocator()
    
    private init() {}
    
    // Service storage
    private var cvService: CVServiceProtocol?
    private var audioService: AudioServiceProtocol?
    private var analyticsService: AnalyticsServiceProtocol?
    private var persistenceService: PersistenceServiceProtocol?
    
    // MARK: - Registration
    func register<T>(_ service: T, for type: T.Type) {
        switch type {
        case is CVServiceProtocol.Type:
            cvService = service as? CVServiceProtocol
        case is AudioServiceProtocol.Type:
            audioService = service as? AudioServiceProtocol
        case is AnalyticsServiceProtocol.Type:
            analyticsService = service as? AnalyticsServiceProtocol
        case is PersistenceServiceProtocol.Type:
            persistenceService = service as? PersistenceServiceProtocol
        default:
            fatalError("Unknown service type: \(type)")
        }
    }
    
    // MARK: - Retrieval
    func resolve<T>(_ type: T.Type) -> T {
        switch type {
        case is CVServiceProtocol.Type:
            guard let service = cvService as? T else {
                fatalError("CVService not registered")
            }
            return service
        case is AudioServiceProtocol.Type:
            guard let service = audioService as? T else {
                fatalError("AudioService not registered")
            }
            return service
        case is AnalyticsServiceProtocol.Type:
            guard let service = analyticsService as? T else {
                fatalError("AnalyticsService not registered")
            }
            return service
        case is PersistenceServiceProtocol.Type:
            guard let service = persistenceService as? T else {
                fatalError("PersistenceService not registered")
            }
            return service
        default:
            fatalError("Unknown service type: \(type)")
        }
    }
    
    // MARK: - Game Context Creation
    func createGameContext() -> GameContext {
        GameContextImpl(
            cvService: resolve(CVServiceProtocol.self),
            audioService: resolve(AudioServiceProtocol.self),
            analyticsService: resolve(AnalyticsServiceProtocol.self),
            persistenceService: resolve(PersistenceServiceProtocol.self)
        )
    }
}

// MARK: - Game Context Implementation
private struct GameContextImpl: GameContext {
    let cvService: CVServiceProtocol
    let audioService: AudioServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let persistenceService: PersistenceServiceProtocol
}
```

## Step 5: Mock Service Implementations (60 minutes)

### 5.1 Create Mock CV Service
Create `Core/Services/MockCVService.swift`:
```swift
import Foundation
import CoreGraphics

// MARK: - Mock CV Service
final class MockCVService: CVServiceProtocol {
    var isSessionActive = false
    var debugMode = false
    
    private var subscriptions: [UUID: CVSubscription] = [:]
    private var eventTimer: Timer?
    
    // MARK: - Session Management
    func startSession() async throws {
        guard !isSessionActive else { return }
        isSessionActive = true
        startMockEventGeneration()
        print("[MockCV] Session started")
    }
    
    func stopSession() {
        isSessionActive = false
        eventTimer?.invalidate()
        eventTimer = nil
        print("[MockCV] Session stopped")
    }
    
    // MARK: - Subscriptions
    func subscribe(gameId: String,
                  events: [CVEventType],
                  handler: @escaping (CVEvent) -> Void) -> CVSubscription {
        let subscription = CVSubscription(
            gameId: gameId,
            eventTypes: events,
            handler: handler
        )
        subscriptions[subscription.id] = subscription
        print("[MockCV] Game \(gameId) subscribed to \(events.count) event types")
        return subscription
    }
    
    func unsubscribe(_ subscription: CVSubscription) {
        subscriptions.removeValue(forKey: subscription.id)
        print("[MockCV] Subscription removed for game \(subscription.gameId)")
    }
    
    // MARK: - Mock Event Generation
    private func startMockEventGeneration() {
        eventTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.generateMockEvent()
        }
    }
    
    private func generateMockEvent() {
        // Generate random finger count for testing
        let fingerCount = Int.random(in: 1...5)
        let event = CVEvent(
            type: .fingerCountDetected(count: fingerCount),
            position: CGPoint(x: 0.5, y: 0.5),
            confidence: 0.95
        )
        
        // Notify relevant subscribers
        DispatchQueue.main.async { [weak self] in
            self?.subscriptions.values.forEach { subscription in
                // Check if this subscription wants this type of event
                let wantsFingerEvents = subscription.eventTypes.contains { eventType in
                    if case .fingerCountDetected = eventType {
                        return true
                    }
                    return false
                }
                
                if wantsFingerEvents {
                    subscription.handle(event)
                }
            }
        }
        
        if debugMode {
            print("[MockCV] Generated event: \(fingerCount) fingers detected")
        }
    }
}
```

### 5.2 Create Mock Audio Service
Create `Core/Services/MockAudioService.swift`:
```swift
import Foundation

// MARK: - Mock Audio Service
final class MockAudioService: AudioServiceProtocol {
    private var currentBackgroundMusic: String?
    
    func preloadSound(_ soundName: String) {
        print("[MockAudio] Preloading sound: \(soundName)")
    }
    
    func playSound(_ soundName: String) {
        playSound(soundName, volume: 1.0)
    }
    
    func playSound(_ soundName: String, volume: Float) {
        print("[MockAudio] Playing sound: \(soundName) at volume: \(volume)")
    }
    
    func stopSound(_ soundName: String) {
        print("[MockAudio] Stopping sound: \(soundName)")
    }
    
    func playHaptic(_ type: HapticType) {
        print("[MockAudio] Playing haptic: \(type)")
    }
    
    func setBackgroundMusic(_ musicName: String?, volume: Float) {
        if let musicName = musicName {
            print("[MockAudio] Setting background music: \(musicName) at volume: \(volume)")
            currentBackgroundMusic = musicName
        } else {
            print("[MockAudio] Stopping background music")
            currentBackgroundMusic = nil
        }
    }
}
```

### 5.3 Create Mock Analytics Service
Create `Core/Services/MockAnalyticsService.swift`:
```swift
import Foundation

// MARK: - Mock Analytics Service
final class MockAnalyticsService: AnalyticsServiceProtocol {
    private var eventQueue: [AnalyticsEvent] = []
    
    func logEvent(_ event: String, parameters: [String: Any]) {
        print("[MockAnalytics] Event: \(event)")
        if !parameters.isEmpty {
            print("[MockAnalytics] Parameters: \(parameters)")
        }
    }
    
    func startLevel(gameId: String, level: String) {
        logEvent("level_start", parameters: [
            "game_id": gameId,
            "level": level,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func endLevel(gameId: String, level: String, success: Bool, score: Int?) {
        var params: [String: Any] = [
            "game_id": gameId,
            "level": level,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let score = score {
            params["score"] = score
        }
        logEvent("level_end", parameters: params)
    }
    
    func logError(_ error: Error, context: String) {
        print("[MockAnalytics] ERROR in \(context): \(error.localizedDescription)")
    }
}
```

### 5.4 Create Mock Persistence Service
Create `Core/Services/MockPersistenceService.swift`:
```swift
import Foundation

// MARK: - Mock Persistence Service
final class MockPersistenceService: PersistenceServiceProtocol {
    // In-memory storage for mock
    private var gameProgress: [String: GameProgress] = [:]
    private var levelCompletions: Set<String> = []
    private var highScores: [String: Int] = [:]
    private var userSettings = UserSettings()
    
    // MARK: - Game Progress
    func saveGameProgress(_ progress: GameProgress) {
        gameProgress[progress.gameId] = progress
        print("[MockPersistence] Saved progress for game: \(progress.gameId)")
    }
    
    func loadGameProgress(for gameId: String) -> GameProgress? {
        let progress = gameProgress[gameId]
        print("[MockPersistence] Loaded progress for game: \(gameId) - found: \(progress != nil)")
        return progress
    }
    
    // MARK: - Level Completion
    func saveLevel(gameId: String, level: String, completed: Bool) {
        let key = "\(gameId).\(level)"
        if completed {
            levelCompletions.insert(key)
        } else {
            levelCompletions.remove(key)
        }
        print("[MockPersistence] Level \(level) in game \(gameId): \(completed ? "completed" : "not completed")")
    }
    
    func isLevelCompleted(gameId: String, level: String) -> Bool {
        let key = "\(gameId).\(level)"
        return levelCompletions.contains(key)
    }
    
    func getCompletedLevels(gameId: String) -> [String] {
        let prefix = "\(gameId)."
        let completedLevels = levelCompletions
            .filter { $0.hasPrefix(prefix) }
            .map { $0.replacingOccurrences(of: prefix, with: "") }
        print("[MockPersistence] Found \(completedLevels.count) completed levels for game: \(gameId)")
        return Array(completedLevels)
    }
    
    // MARK: - High Scores
    func saveHighScore(gameId: String, level: String, score: Int) {
        let key = "\(gameId).\(level)"
        highScores[key] = score
        print("[MockPersistence] Saved high score \(score) for \(key)")
    }
    
    func getHighScore(gameId: String, level: String) -> Int? {
        let key = "\(gameId).\(level)"
        return highScores[key]
    }
    
    // MARK: - Settings
    func saveUserSettings(_ settings: UserSettings) {
        userSettings = settings
        print("[MockPersistence] Saved user settings")
    }
    
    func loadUserSettings() -> UserSettings {
        print("[MockPersistence] Loaded user settings")
        return userSettings
    }
}
```

## Step 6: App Coordinator (30 minutes)

### 6.1 Create App Coordinator
Create `App/AppCoordinator.swift`:
```swift
import SwiftUI

// MARK: - App Coordinator
final class AppCoordinator: CoordinatorProtocol {
    @Published var navigationPath = NavigationPath()
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Navigation
    func navigateTo(_ destination: NavigationDestination) {
        navigationPath.append(destination)
    }
    
    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func navigateToRoot() {
        navigationPath = NavigationPath()
    }
    
    // MARK: - Error Handling
    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Game Launch
    func launchGame(_ gameId: String) {
        // Analytics
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("game_selected", parameters: ["game_id": gameId])
        
        // Navigate
        navigateTo(.game(gameId: gameId))
    }
}

// MARK: - Environment Key
struct CoordinatorKey: EnvironmentKey {
    static let defaultValue = AppCoordinator()
}

extension EnvironmentValues {
    var coordinator: AppCoordinator {
        get { self[CoordinatorKey.self] }
        set { self[CoordinatorKey.self] = newValue }
    }
}
```

## Step 7: Basic Navigation Views (45 minutes)

### 7.1 Create Launch Screen
Create `Features/Launch/LaunchScreen.swift`:
```swift
import SwiftUI

struct LaunchScreen: View {
    @State private var isAnimating = false
    @State private var progress: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.purple, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // App logo placeholder
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("OsmoApp")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Loading indicator
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.white)
                    .scaleEffect(x: 1, y: 2)
                    .frame(width: 200)
            }
        }
        .onAppear {
            isAnimating = true
            // Simulate loading
            withAnimation(.linear(duration: 2)) {
                progress = 1.0
            }
        }
    }
}
```

### 7.2 Create Lobby View
Create `Features/Lobby/LobbyView.swift`:
```swift
import SwiftUI

struct LobbyView: View {
    @Environment(\.coordinator) var coordinator
    @State private var selectedCategory: GameCategory? = nil
    
    // Mock game data for Phase 1
    let mockGames = [
        GameInfo(
            gameId: "finger_count",
            displayName: "Finger Count",
            description: "Show the right number of fingers!",
            iconName: "hand.raised.fill",
            minAge: 3,
            category: .math
        ),
        GameInfo(
            gameId: "shape_match",
            displayName: "Shape Match",
            description: "Match shapes with real objects",
            iconName: "square.on.circle",
            minAge: 4,
            category: .spatialReasoning,
            isLocked: true
        ),
        GameInfo(
            gameId: "color_hunt",
            displayName: "Color Hunt",
            description: "Find colors in your room",
            iconName: "paintpalette.fill",
            minAge: 3,
            category: .creativity,
            isLocked: true
        )
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 20)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            CategoryChip(
                                category: nil,
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil }
                            )
                            
                            ForEach(GameCategory.allCases, id: \.self) { category in
                                CategoryChip(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    
                    // Games Grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredGames) { game in
                                GameCard(gameInfo: game) {
                                    if !game.isLocked {
                                        coordinator.launchGame(game.gameId)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Choose a Game")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        coordinator.navigateTo(.settings)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                    }
                }
            }
        }
    }
    
    private var filteredGames: [GameInfo] {
        guard let category = selectedCategory else { return mockGames }
        return mockGames.filter { $0.category == category }
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: GameCategory?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let category = category {
                    Image(systemName: category.iconName)
                    Text(category.displayName)
                } else {
                    Image(systemName: "square.grid.2x2")
                    Text("All Games")
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(uiColor: .systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Game Card
struct GameCard: View {
    let gameInfo: GameInfo
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(gameInfo.isLocked ? Color.gray : Color.blue)
                        .frame(height: 150)
                    
                    Image(systemName: gameInfo.iconName)
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    if gameInfo.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 50, height: 50))
                            .offset(x: 60, y: -60)
                    }
                }
                
                // Title
                Text(gameInfo.displayName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Description
                Text(gameInfo.description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // Age badge
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text("\(gameInfo.minAge)+")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(uiColor: .systemGray6))
                .clipShape(Capsule())
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .disabled(gameInfo.isLocked)
    }
}
```

### 7.3 Create Settings View Placeholder
Create `Features/Settings/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.coordinator) var coordinator
    @State private var userSettings = UserSettings()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sound") {
                    Toggle("Sound Effects", isOn: $userSettings.soundEnabled)
                    Toggle("Background Music", isOn: $userSettings.musicEnabled)
                    Toggle("Haptic Feedback", isOn: $userSettings.hapticEnabled)
                }
                
                Section("Developer") {
                    Toggle("CV Debug Mode", isOn: $userSettings.cvDebugMode)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Save settings
                        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
                        persistence.saveUserSettings(userSettings)
                        
                        coordinator.navigateBack()
                    }
                }
            }
        }
        .onAppear {
            // Load settings
            let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
            userSettings = persistence.loadUserSettings()
        }
    }
}
```

## Step 8: Main App Setup (30 minutes)

### 8.1 Update Main App File
Replace `App/OsmoApp.swift`:
```swift
import SwiftUI

@main
struct OsmoApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @State private var isLoading = true
    
    init() {
        setupServices()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    LaunchScreen()
                        .onAppear {
                            // Simulate loading
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isLoading = false
                            }
                        }
                } else {
                    ContentView()
                        .environmentObject(coordinator)
                        .environment(\.coordinator, coordinator)
                }
            }
            .preferredColorScheme(.light)
        }
    }
    
    private func setupServices() {
        // Register all services with mock implementations
        ServiceLocator.shared.register(MockCVService(), for: CVServiceProtocol.self)
        ServiceLocator.shared.register(MockAudioService(), for: AudioServiceProtocol.self)
        ServiceLocator.shared.register(MockAnalyticsService(), for: AnalyticsServiceProtocol.self)
        ServiceLocator.shared.register(MockPersistenceService(), for: PersistenceServiceProtocol.self)
        
        print("[App] All services registered")
    }
}
```

### 8.2 Create Main Content View
Replace `App/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
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
```

## Step 9: Testing & Validation (15 minutes)

### 9.1 Create Test Utilities
Create `Utilities/TestUtilities.swift`:
```swift
import Foundation

// MARK: - Service Test Utilities
extension ServiceLocator {
    /// Validates all services are properly registered
    static func validateServices() {
        print("\n=== Service Validation ===")
        
        // Test CV Service
        do {
            let cvService = shared.resolve(CVServiceProtocol.self)
            print("✅ CV Service: \(type(of: cvService))")
        } catch {
            print("❌ CV Service: Not registered")
        }
        
        // Test Audio Service
        do {
            let audioService = shared.resolve(AudioServiceProtocol.self)
            print("✅ Audio Service: \(type(of: audioService))")
        } catch {
            print("❌ Audio Service: Not registered")
        }
        
        // Test Analytics Service
        do {
            let analyticsService = shared.resolve(AnalyticsServiceProtocol.self)
            print("✅ Analytics Service: \(type(of: analyticsService))")
        } catch {
            print("❌ Analytics Service: Not registered")
        }
        
        // Test Persistence Service
        do {
            let persistenceService = shared.resolve(PersistenceServiceProtocol.self)
            print("✅ Persistence Service: \(type(of: persistenceService))")
        } catch {
            print("❌ Persistence Service: Not registered")
        }
        
        print("========================\n")
    }
}
```

### 9.2 Add Validation to App Launch
Update `OsmoApp.swift` setupServices():
```swift
private func setupServices() {
    // Register all services with mock implementations
    ServiceLocator.shared.register(MockCVService(), for: CVServiceProtocol.self)
    ServiceLocator.shared.register(MockAudioService(), for: AudioServiceProtocol.self)
    ServiceLocator.shared.register(MockAnalyticsService(), for: AnalyticsServiceProtocol.self)
    ServiceLocator.shared.register(MockPersistenceService(), for: PersistenceServiceProtocol.self)
    
    print("[App] All services registered")
    
    #if DEBUG
    // Validate services in debug builds
    ServiceLocator.validateServices()
    #endif
}
```

## Phase 1 Completion Checklist

### ✅ Core Models
- [ ] CVEvent and related types
- [ ] GameInfo and GameProgress
- [ ] Service models (Audio, Analytics, Settings)

### ✅ Core Protocols  
- [ ] Service protocols (CV, Audio, Analytics, Persistence)
- [ ] GameModule and GameContext protocols
- [ ] Coordinator protocol

### ✅ Service Infrastructure
- [ ] ServiceLocator implementation
- [ ] Mock implementations for all services
- [ ] GameContext creation

### ✅ Navigation
- [ ] AppCoordinator with navigation stack
- [ ] Navigation destinations enum
- [ ] Error handling flow

### ✅ UI Foundation
- [ ] Launch screen with animation
- [ ] Lobby with game grid
- [ ] Settings screen
- [ ] Basic navigation flow

### ✅ Project Structure
- [ ] Proper folder organization
- [ ] All files in correct locations
- [ ] Clean separation of concerns

## Next Steps for Phase 2

With Phase 1 complete, you now have:
1. A working navigation system
2. All core protocols defined
3. Mock services that log actions
4. A lobby that displays games
5. The foundation for loading game modules

Phase 2 will implement:
- Real service implementations
- SpriteKit hosting view
- Game loading system
- Actual gameplay integration