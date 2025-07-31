# Phase 2 Modern Implementation (iOS 17+) - With Phase 1 Updates

## Overview
This document contains the modernized Phase 2 implementation using iOS 17+ features, along with all necessary Phase 1 updates. We're using SwiftData, AVAudioEngine, @Observable, and AsyncStream for a more modern, performant architecture.

## Required Phase 1 Updates

### Update 1: Convert Models to @Observable (Phase 1)

#### Update `Core/Services/ServiceLocator.swift`:
```swift
import Foundation
import Observation

// MARK: - Service Locator
@Observable
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
```

#### Update `Core/Protocols/ServiceProtocols.swift` for AsyncStream:
```swift
import Foundation
import CoreGraphics

// MARK: - CV Subscription
protocol CVSubscription {
    func cancel()
}

// MARK: - CV Service Protocol
protocol CVServiceProtocol: AnyObject {
    var isSessionActive: Bool { get }
    var debugMode: Bool { get set }
    
    func startSession() async throws
    func stopSession()
    func eventStream(gameId: String, events: [CVEventType]) -> AsyncStream<CVEvent>
}

// Keep other protocols the same but update persistence for SwiftData
protocol PersistenceServiceProtocol: AnyObject {
    // Game Progress
    func saveGameProgress(_ progress: GameProgress) async throws
    func loadGameProgress(for gameId: String) async -> GameProgress?
    
    // Level Completion
    func saveLevel(gameId: String, level: String, completed: Bool) async throws
    func isLevelCompleted(gameId: String, level: String) async -> Bool
    func getCompletedLevels(gameId: String) async -> [String]
    
    // High Scores
    func saveHighScore(gameId: String, level: String, score: Int) async throws
    func getHighScore(gameId: String, level: String) async -> Int?
    
    // Settings
    func saveUserSettings(_ settings: UserSettings) async throws
    func loadUserSettings() async -> UserSettings
}
```

#### Update `App/AppCoordinator.swift` to @Observable:
```swift
import SwiftUI
import Observation

// MARK: - App Coordinator
@Observable
final class AppCoordinator {
    var navigationPath = NavigationPath()
    var errorMessage: String?
    var showError = false
    
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
```

#### Update `Core/Services/MockCVService.swift` for AsyncStream:
```swift
import Foundation
import CoreGraphics

// MARK: - Mock CV Service
@Observable
final class MockCVService: CVServiceProtocol {
    var isSessionActive = false
    var debugMode = false
    
    private var eventContinuations: [String: AsyncStream<CVEvent>.Continuation] = [:]
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
        
        // End all streams
        eventContinuations.values.forEach { $0.finish() }
        eventContinuations.removeAll()
        
        print("[MockCV] Session stopped")
    }
    
    // MARK: - Event Stream
    func eventStream(gameId: String, events: [CVEventType]) -> AsyncStream<CVEvent> {
        AsyncStream { continuation in
            eventContinuations[gameId] = continuation
            print("[MockCV] Game \(gameId) subscribed to event stream")
            
            continuation.onTermination = { [weak self] _ in
                self?.eventContinuations.removeValue(forKey: gameId)
                print("[MockCV] Game \(gameId) stream terminated")
            }
        }
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
        
        // Send to all active continuations
        eventContinuations.values.forEach { continuation in
            continuation.yield(event)
        }
        
        if debugMode {
            print("[MockCV] Generated event: \(fingerCount) fingers detected")
        }
    }
}
```

## Phase 2: Modern Service Layer Implementation

### Step 1: SwiftData Setup and Models (30 minutes)

#### 1.1 Create SwiftData Models
Create `Core/Models/SwiftDataModels.swift`:

```swift
import Foundation
import SwiftData

// MARK: - Game Progress Model
@Model
final class SDGameProgress {
    @Attribute(.unique) var gameId: String
    var levelsCompleted: [String]
    var totalPlayTime: TimeInterval
    var lastPlayed: Date
    var highScores: [String: Int] // level: score
    
    init(gameId: String) {
        self.gameId = gameId
        self.levelsCompleted = []
        self.totalPlayTime = 0
        self.lastPlayed = Date()
        self.highScores = [:]
    }
    
    func toGameProgress() -> GameProgress {
        var progress = GameProgress(gameId: gameId)
        progress.levelsCompleted = Set(levelsCompleted)
        progress.totalPlayTime = totalPlayTime
        progress.lastPlayed = lastPlayed
        return progress
    }
    
    func update(from progress: GameProgress) {
        self.levelsCompleted = Array(progress.levelsCompleted)
        self.totalPlayTime = progress.totalPlayTime
        self.lastPlayed = progress.lastPlayed
    }
}

// MARK: - User Settings Model
@Model
final class SDUserSettings {
    var soundEnabled: Bool = true
    var musicEnabled: Bool = true
    var hapticEnabled: Bool = true
    var cvDebugMode: Bool = false
    var parentalControlsEnabled: Bool = false
    var lastUpdated: Date = Date()
    
    init() {}
    
    func toUserSettings() -> UserSettings {
        var settings = UserSettings()
        settings.soundEnabled = soundEnabled
        settings.musicEnabled = musicEnabled
        settings.hapticEnabled = hapticEnabled
        settings.cvDebugMode = cvDebugMode
        settings.parentalControlsEnabled = parentalControlsEnabled
        return settings
    }
    
    func update(from settings: UserSettings) {
        self.soundEnabled = settings.soundEnabled
        self.musicEnabled = settings.musicEnabled
        self.hapticEnabled = settings.hapticEnabled
        self.cvDebugMode = settings.cvDebugMode
        self.parentalControlsEnabled = settings.parentalControlsEnabled
        self.lastUpdated = Date()
    }
}

// MARK: - Analytics Event Model
@Model
final class SDAnalyticsEvent {
    var eventId: UUID
    var eventType: String
    var gameId: String
    var timestamp: Date
    var parameters: Data? // JSON encoded
    
    init(event: AnalyticsEvent) {
        self.eventId = event.eventId
        self.eventType = event.eventType.description
        self.gameId = event.gameId
        self.timestamp = event.timestamp
        self.parameters = try? JSONSerialization.data(withJSONObject: event.parameters)
    }
}

// MARK: - Game Session Model
@Model
final class SDGameSession {
    var sessionId: UUID
    var gameId: String
    var startTime: Date
    var endTime: Date?
    var eventCount: Int
    var errorCount: Int
    
    init(gameId: String) {
        self.sessionId = UUID()
        self.gameId = gameId
        self.startTime = Date()
        self.eventCount = 0
        self.errorCount = 0
    }
}
```

### Step 2: Modern Audio Service with AVAudioEngine (60 minutes)

#### 2.1 Create AVAudioEngine Service
Create `Core/Services/AudioEngineService.swift`:

```swift
import Foundation
import AVFoundation
import UIKit
import Observation

// MARK: - Audio Engine Service
@Observable
final class AudioEngineService: AudioServiceProtocol {
    // Audio Engine
    private let audioEngine = AVAudioEngine()
    private let mainMixer: AVAudioMixerNode
    
    // Sound players
    private var soundPlayers: [String: AVAudioPlayerNode] = [:]
    private var soundBuffers: [String: AVAudioPCMBuffer] = [:]
    private var backgroundMusicPlayer: AVAudioPlayerNode?
    private var backgroundMusicBuffer: AVAudioPCMBuffer?
    
    // Effects
    private let reverbNode = AVAudioUnitReverb()
    private let distortionNode = AVAudioUnitDistortion()
    
    // Haptic generators
    private let hapticEngine = CHHapticEngine()
    private var hapticPatterns: [HapticType: CHHapticPattern] = [:]
    
    // Settings
    var soundEnabled = true
    var musicEnabled = true
    var hapticEnabled = true
    
    init() {
        mainMixer = audioEngine.mainMixerNode
        setupAudioEngine()
        setupHaptics()
        Task { await loadSettings() }
    }
    
    // MARK: - Setup
    private func setupAudioEngine() {
        do {
            // Configure audio session
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            // Setup effects
            audioEngine.attach(reverbNode)
            audioEngine.attach(distortionNode)
            
            // Connect nodes
            audioEngine.connect(reverbNode, to: mainMixer, format: nil)
            
            // Configure reverb for game sounds
            reverbNode.loadFactoryPreset(.mediumHall)
            reverbNode.wetDryMix = 20 // Subtle reverb
            
            // Start engine
            try audioEngine.start()
            
            print("[AudioEngine] Engine started successfully")
        } catch {
            print("[AudioEngine] Failed to setup: \(error)")
        }
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            createHapticPatterns()
        } catch {
            print("[AudioEngine] Haptics setup failed: \(error)")
        }
    }
    
    private func createHapticPatterns() {
        // Success pattern
        hapticPatterns[.success] = try? CHHapticPattern(events: [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0.1)
        ], parameters: [])
        
        // Error pattern
        hapticPatterns[.error] = try? CHHapticPattern(events: [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0, duration: 0.3)
        ], parameters: [])
    }
    
    // MARK: - Sound Loading
    func preloadSound(_ soundName: String) {
        guard soundBuffers[soundName] == nil else { return }
        
        Task {
            if let buffer = await loadAudioBuffer(named: soundName) {
                soundBuffers[soundName] = buffer
                print("[AudioEngine] Preloaded: \(soundName)")
            }
        }
    }
    
    private func loadAudioBuffer(named name: String) async -> AVAudioPCMBuffer? {
        let extensions = ["mp3", "wav", "m4a", "aiff"]
        
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    let file = try AVAudioFile(forReading: url)
                    let format = file.processingFormat
                    let frameCount = UInt32(file.length)
                    
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                        return nil
                    }
                    
                    try file.read(into: buffer)
                    return buffer
                } catch {
                    print("[AudioEngine] Failed to load \(name).\(ext): \(error)")
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Sound Playback
    func playSound(_ soundName: String) {
        playSound(soundName, volume: 1.0)
    }
    
    func playSound(_ soundName: String, volume: Float) {
        guard soundEnabled else { return }
        
        Task {
            // Get or load buffer
            let buffer = soundBuffers[soundName] ?? await loadAudioBuffer(named: soundName)
            guard let buffer = buffer else {
                print("[AudioEngine] Sound not found: \(soundName)")
                return
            }
            
            // Store buffer if not already cached
            if soundBuffers[soundName] == nil {
                soundBuffers[soundName] = buffer
            }
            
            await MainActor.run {
                // Get or create player node
                let playerNode = soundPlayers[soundName] ?? {
                    let node = AVAudioPlayerNode()
                    audioEngine.attach(node)
                    audioEngine.connect(node, to: reverbNode, format: buffer.format)
                    soundPlayers[soundName] = node
                    return node
                }()
                
                // Set volume
                playerNode.volume = volume
                
                // Play
                if !playerNode.isPlaying {
                    try? audioEngine.start() // Ensure engine is running
                }
                
                playerNode.play()
                playerNode.scheduleBuffer(buffer, at: nil, completionHandler: nil)
            }
        }
    }
    
    func stopSound(_ soundName: String) {
        soundPlayers[soundName]?.stop()
    }
    
    // MARK: - Background Music
    func setBackgroundMusic(_ musicName: String?, volume: Float) {
        guard musicEnabled else { return }
        
        // Stop current music
        backgroundMusicPlayer?.stop()
        
        guard let musicName = musicName else { return }
        
        Task {
            guard let buffer = await loadAudioBuffer(named: musicName) else { return }
            
            await MainActor.run {
                if backgroundMusicPlayer == nil {
                    let player = AVAudioPlayerNode()
                    audioEngine.attach(player)
                    audioEngine.connect(player, to: mainMixer, format: buffer.format)
                    backgroundMusicPlayer = player
                }
                
                backgroundMusicPlayer?.volume = volume * 0.3 // Background volume
                backgroundMusicPlayer?.play()
                
                // Loop the music
                backgroundMusicPlayer?.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            }
        }
    }
    
    // MARK: - Haptics
    func playHaptic(_ type: HapticType) {
        guard hapticEnabled, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        switch type {
        case .light, .medium, .heavy:
            // Use UIKit haptics for simple impacts
            let impactStyle: UIImpactFeedbackGenerator.FeedbackStyle = {
                switch type {
                case .light: return .light
                case .medium: return .medium
                case .heavy: return .heavy
                default: return .medium
                }
            }()
            UIImpactFeedbackGenerator(style: impactStyle).impactOccurred()
            
        case .success, .warning, .error:
            // Use custom patterns
            if let pattern = hapticPatterns[type] {
                try? hapticEngine?.makePlayer(with: pattern).start(atTime: 0)
            } else {
                // Fallback to notification haptics
                let notificationType: UINotificationFeedbackGenerator.FeedbackType = {
                    switch type {
                    case .success: return .success
                    case .warning: return .warning
                    case .error: return .error
                    default: return .success
                    }
                }()
                UINotificationFeedbackGenerator().notificationOccurred(notificationType)
            }
        }
    }
    
    // MARK: - Settings
    private func loadSettings() async {
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        let settings = await persistence.loadUserSettings()
        soundEnabled = settings.soundEnabled
        musicEnabled = settings.musicEnabled
        hapticEnabled = settings.hapticEnabled
    }
    
    func updateSettings(_ settings: UserSettings) {
        soundEnabled = settings.soundEnabled
        musicEnabled = settings.musicEnabled
        hapticEnabled = settings.hapticEnabled
        
        if !musicEnabled {
            backgroundMusicPlayer?.stop()
        }
    }
}

// MARK: - Common Sounds Extension
extension AudioEngineService {
    enum CommonSound: String, CaseIterable {
        case buttonTap = "button_tap"
        case gameStart = "game_start"
        case levelComplete = "level_complete"
        case correctAnswer = "correct"
        case wrongAnswer = "wrong"
        case coinCollect = "coin"
        case powerUp = "powerup"
        
        var filename: String { rawValue }
    }
    
    func preloadCommonSounds() {
        CommonSound.allCases.forEach { sound in
            preloadSound(sound.filename)
        }
    }
}
```

### Step 3: SwiftData Persistence Service (45 minutes)

#### 3.1 Create SwiftData Service
Create `Core/Services/SwiftDataService.swift`:

```swift
import Foundation
import SwiftData
import Observation

// MARK: - SwiftData Persistence Service
@Observable
final class SwiftDataService: PersistenceServiceProtocol {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    // Cache for performance
    private var settingsCache: UserSettings?
    
    init() throws {
        let schema = Schema([
            SDGameProgress.self,
            SDUserSettings.self,
            SDAnalyticsEvent.self,
            SDGameSession.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none // Can enable for sync later
        )
        
        modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = true
        
        print("[SwiftData] Service initialized")
    }
    
    // MARK: - Game Progress
    func saveGameProgress(_ progress: GameProgress) async throws {
        let fetchDescriptor = FetchDescriptor<SDGameProgress>(
            predicate: #Predicate { $0.gameId == progress.gameId }
        )
        
        let existingProgress = try modelContext.fetch(fetchDescriptor).first
        
        if let existing = existingProgress {
            existing.update(from: progress)
        } else {
            let sdProgress = SDGameProgress(gameId: progress.gameId)
            sdProgress.update(from: progress)
            modelContext.insert(sdProgress)
        }
        
        try modelContext.save()
        print("[SwiftData] Saved progress for game: \(progress.gameId)")
    }
    
    func loadGameProgress(for gameId: String) async -> GameProgress? {
        let fetchDescriptor = FetchDescriptor<SDGameProgress>(
            predicate: #Predicate { $0.gameId == gameId }
        )
        
        do {
            if let sdProgress = try modelContext.fetch(fetchDescriptor).first {
                return sdProgress.toGameProgress()
            }
        } catch {
            print("[SwiftData] Failed to load progress: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Level Completion
    func saveLevel(gameId: String, level: String, completed: Bool) async throws {
        let progress = await loadGameProgress(for: gameId) ?? GameProgress(gameId: gameId)
        
        if completed {
            progress.levelsCompleted.insert(level)
        } else {
            progress.levelsCompleted.remove(level)
        }
        
        progress.lastPlayed = Date()
        try await saveGameProgress(progress)
    }
    
    func isLevelCompleted(gameId: String, level: String) async -> Bool {
        let progress = await loadGameProgress(for: gameId)
        return progress?.levelsCompleted.contains(level) ?? false
    }
    
    func getCompletedLevels(gameId: String) async -> [String] {
        let progress = await loadGameProgress(for: gameId)
        return Array(progress?.levelsCompleted ?? [])
    }
    
    // MARK: - High Scores
    func saveHighScore(gameId: String, level: String, score: Int) async throws {
        let fetchDescriptor = FetchDescriptor<SDGameProgress>(
            predicate: #Predicate { $0.gameId == gameId }
        )
        
        let progress = try modelContext.fetch(fetchDescriptor).first ?? {
            let new = SDGameProgress(gameId: gameId)
            modelContext.insert(new)
            return new
        }()
        
        let currentHigh = progress.highScores[level] ?? 0
        if score > currentHigh {
            progress.highScores[level] = score
            try modelContext.save()
            print("[SwiftData] New high score for \(gameId).\(level): \(score)")
        }
    }
    
    func getHighScore(gameId: String, level: String) async -> Int? {
        let fetchDescriptor = FetchDescriptor<SDGameProgress>(
            predicate: #Predicate { $0.gameId == gameId }
        )
        
        do {
            if let progress = try modelContext.fetch(fetchDescriptor).first {
                return progress.highScores[level]
            }
        } catch {
            print("[SwiftData] Failed to get high score: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Settings
    func saveUserSettings(_ settings: UserSettings) async throws {
        let fetchDescriptor = FetchDescriptor<SDUserSettings>()
        
        let existingSettings = try modelContext.fetch(fetchDescriptor).first ?? {
            let new = SDUserSettings()
            modelContext.insert(new)
            return new
        }()
        
        existingSettings.update(from: settings)
        try modelContext.save()
        
        settingsCache = settings
        print("[SwiftData] Saved user settings")
    }
    
    func loadUserSettings() async -> UserSettings {
        // Check cache first
        if let cached = settingsCache {
            return cached
        }
        
        let fetchDescriptor = FetchDescriptor<SDUserSettings>()
        
        do {
            if let sdSettings = try modelContext.fetch(fetchDescriptor).first {
                let settings = sdSettings.toUserSettings()
                settingsCache = settings
                return settings
            }
        } catch {
            print("[SwiftData] Failed to load settings: \(error)")
        }
        
        let defaultSettings = UserSettings()
        settingsCache = defaultSettings
        return defaultSettings
    }
    
    // MARK: - Session Management
    func saveCurrentSession(gameId: String, sessionStart: Date) async throws {
        let session = SDGameSession(gameId: gameId)
        modelContext.insert(session)
        try modelContext.save()
    }
    
    func loadCurrentSession() async -> (gameId: String, startTime: Date)? {
        let fetchDescriptor = FetchDescriptor<SDGameSession>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            if let session = try modelContext.fetch(fetchDescriptor).first {
                return (session.gameId, session.startTime)
            }
        } catch {
            print("[SwiftData] Failed to load session: \(error)")
        }
        
        return nil
    }
    
    func clearCurrentSession() async throws {
        let fetchDescriptor = FetchDescriptor<SDGameSession>(
            predicate: #Predicate { $0.endTime == nil }
        )
        
        do {
            let sessions = try modelContext.fetch(fetchDescriptor)
            sessions.forEach { $0.endTime = Date() }
            try modelContext.save()
        } catch {
            print("[SwiftData] Failed to clear session: \(error)")
        }
    }
    
    // MARK: - Analytics Support
    func saveAnalyticsEvent(_ event: AnalyticsEvent) async throws {
        let sdEvent = SDAnalyticsEvent(event: event)
        modelContext.insert(sdEvent)
        
        // Save in batches for performance
        if Int.random(in: 0..<10) == 0 { // 10% chance to save
            try modelContext.save()
        }
    }
    
    func getAnalyticsEvents(since date: Date) async -> [SDAnalyticsEvent] {
        let fetchDescriptor = FetchDescriptor<SDAnalyticsEvent>(
            predicate: #Predicate { $0.timestamp > date },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        do {
            return try modelContext.fetch(fetchDescriptor)
        } catch {
            print("[SwiftData] Failed to fetch analytics: \(error)")
            return []
        }
    }
}
```

### Step 4: Updated Analytics Service (30 minutes)

#### 4.1 Create Modern Analytics Service
Update `Core/Services/AnalyticsService.swift`:

```swift
import Foundation
import os.log
import Observation

// MARK: - Analytics Service
@Observable
final class AnalyticsService: AnalyticsServiceProtocol {
    private let logger = Logger(subsystem: "com.osmoapp", category: "analytics")
    private var eventQueue: [AnalyticsEvent] = []
    private let maxQueueSize = 100
    
    // Use async approach instead of Timer
    private var flushTask: Task<Void, Never>?
    
    // Session tracking
    private var currentSession: GameSession?
    
    init() {
        startFlushTask()
        observeAppLifecycle()
    }
    
    deinit {
        flushTask?.cancel()
    }
    
    // MARK: - Event Logging
    func logEvent(_ event: String, parameters: [String: Any] = [:]) {
        let analyticsEvent = AnalyticsEvent(
            eventType: .customEvent(name: event),
            gameId: currentSession?.gameId ?? "app",
            parameters: parameters
        )
        
        Task {
            await addToQueue(analyticsEvent)
        }
        
        // Log to console in debug
        #if DEBUG
        logger.debug("📊 Event: \(event)")
        if !parameters.isEmpty {
            logger.debug("📊 Parameters: \(parameters)")
        }
        #endif
    }
    
    // MARK: - Game Events
    func startLevel(gameId: String, level: String) {
        // Start or update session
        if currentSession?.gameId != gameId {
            Task {
                await endCurrentSession()
            }
            currentSession = GameSession(
                sessionId: UUID(),
                gameId: gameId,
                startTime: Date(),
                events: [],
                cvEventCount: 0,
                errorCount: 0
            )
        }
        
        logEvent("level_start", parameters: [
            "game_id": gameId,
            "level": level,
            "session_id": currentSession?.sessionId.uuidString ?? "unknown"
        ])
        
        // Update persistence
        Task {
            let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
            try? await persistence.saveCurrentSession(gameId: gameId, sessionStart: Date())
        }
    }
    
    func endLevel(gameId: String, level: String, success: Bool, score: Int? = nil) {
        var params: [String: Any] = [
            "game_id": gameId,
            "level": level,
            "success": success,
            "session_id": currentSession?.sessionId.uuidString ?? "unknown"
        ]
        
        if let score = score {
            params["score"] = score
        }
        
        // Calculate level duration
        if let session = currentSession {
            let duration = Date().timeIntervalSince(session.startTime)
            params["duration_seconds"] = Int(duration)
        }
        
        logEvent("level_end", parameters: params)
        
        // Update game progress
        if success {
            Task {
                let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
                try? await persistence.saveLevel(gameId: gameId, level: level, completed: true)
                
                if let score = score {
                    try? await persistence.saveHighScore(gameId: gameId, level: level, score: score)
                }
            }
        }
    }
    
    // MARK: - Error Logging
    func logError(_ error: Error, context: String) {
        currentSession?.errorCount += 1
        
        logger.error("❌ Error in \(context): \(error.localizedDescription)")
        
        logEvent("error_occurred", parameters: [
            "error_type": String(describing: type(of: error)),
            "error_message": error.localizedDescription,
            "context": context,
            "error_count": currentSession?.errorCount ?? 0
        ])
    }
    
    // MARK: - Queue Management
    @MainActor
    private func addToQueue(_ event: AnalyticsEvent) async {
        eventQueue.append(event)
        currentSession?.events.append(event)
        
        // Save to SwiftData
        if let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self) as? SwiftDataService {
            try? await persistence.saveAnalyticsEvent(event)
        }
        
        // Flush if queue is full
        if eventQueue.count >= maxQueueSize {
            await flushEvents()
        }
    }
    
    private func flushEvents() async {
        guard !eventQueue.isEmpty else { return }
        
        logger.info("📊 Flushing \(self.eventQueue.count) analytics events")
        
        // In a real app, send to analytics backend here
        let eventSummary = Dictionary(grouping: eventQueue) { event in
            event.eventType.description
        }.mapValues { $0.count }
        
        logger.info("📊 Event Summary: \(eventSummary)")
        
        // Clear queue
        eventQueue.removeAll()
    }
    
    // MARK: - Async Flush Task
    private func startFlushTask() {
        flushTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await flushEvents()
            }
        }
    }
    
    // MARK: - App Lifecycle
    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        Task {
            await flushEvents()
            await endCurrentSession()
        }
    }
    
    @objc private func appWillTerminate() {
        Task {
            await flushEvents()
        }
    }
    
    private func endCurrentSession() async {
        if let session = currentSession {
            session.endTime = Date()
            logEvent("session_end", parameters: [
                "session_id": session.sessionId.uuidString,
                "duration_seconds": Int(session.endTime!.timeIntervalSince(session.startTime)),
                "event_count": session.events.count,
                "cv_event_count": session.cvEventCount,
                "error_count": session.errorCount
            ])
        }
        currentSession = nil
        
        // Clear session from persistence
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        try? await persistence.clearCurrentSession()
    }
}
```

### Step 5: Updated Game Host View Model (30 minutes)

#### 5.1 Update GameHostViewModel to @Observable
Create `Features/GameHost/GameHostViewModel.swift`:

```swift
import Foundation
import SpriteKit
import Observation

// MARK: - Game Host View Model
@Observable
@MainActor
final class GameHostViewModel {
    var gameScene: SKScene?
    var isLoading = true
    var error: Error?
    var gameName = ""
    
    private let gameLoader = GameLoader()
    private var currentGameId: String?
    private var cvStartTask: Task<Void, Never>?
    
    // MARK: - Game Loading
    func loadGame(_ gameId: String) {
        currentGameId = gameId
        isLoading = true
        error = nil
        
        // Get game info
        if let info = GameRegistry.shared.getGameInfo(for: gameId) {
            gameName = info.displayName
        }
        
        // Start CV service if needed
        startCVServiceIfNeeded()
        
        // Load game
        Task {
            do {
                // Simulate loading time for better UX
                try await Task.sleep(for: .milliseconds(500))
                
                // Get screen size
                let screenSize = UIScreen.main.bounds.size
                
                // Create game scene
                let scene = try gameLoader.createGameScene(for: gameId, size: screenSize)
                
                // Configure scene
                scene.scaleMode = .aspectFill
                scene.backgroundColor = .black
                
                // Update UI
                self.gameScene = scene
                self.isLoading = false
                
                // Log analytics
                let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
                analytics.startLevel(gameId: gameId, level: "main")
                
                // Play start sound
                let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
                audio.playSound("game_start")
                audio.playHaptic(.medium)
                
            } catch {
                self.error = error
                self.isLoading = false
                
                // Log error
                let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
                analytics.logError(error, context: "game_loading")
            }
        }
    }
    
    // MARK: - CV Service Management
    private func startCVServiceIfNeeded() {
        cvStartTask = Task {
            let cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self)
            
            if !cvService.isSessionActive {
                do {
                    try await cvService.startSession()
                    print("[GameHost] CV session started")
                } catch {
                    print("[GameHost] Failed to start CV session: \(error)")
                    // Games should still work without CV
                }
            }
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        // Pause scene
        gameScene?.isPaused = true
        
        // Cancel CV start if still running
        cvStartTask?.cancel()
        
        // Unload game
        if let gameId = currentGameId {
            gameLoader.unloadGame(gameId)
            
            // Log analytics
            let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
            analytics.endLevel(gameId: gameId, level: "main", success: false)
        }
        
        // Clear scene
        gameScene = nil
        
        print("[GameHost] Cleanup completed")
    }
}
```

### Step 6: Updated App Integration (30 minutes)

#### 6.1 Update Main App
Update `App/OsmoApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct OsmoApp: App {
    @State private var coordinator = AppCoordinator()
    @State private var isLoading = true
    
    let modelContainer: ModelContainer
    
    init() {
        // Setup SwiftData
        do {
            let schema = Schema([
                SDGameProgress.self,
                SDUserSettings.self,
                SDAnalyticsEvent.self,
                SDGameSession.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        setupServices()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    LaunchScreen()
                        .onAppear {
                            Task {
                                await initializeApp()
                                isLoading = false
                            }
                        }
                } else {
                    ContentView()
                        .environment(coordinator)
                }
            }
            .preferredColorScheme(.light)
            .modelContainer(modelContainer)
        }
    }
    
    private func setupServices() {
        // Register modern services
        ServiceLocator.shared.register(MockCVService(), for: CVServiceProtocol.self) // Still mock in Phase 2
        ServiceLocator.shared.register(AudioEngineService(), for: AudioServiceProtocol.self)
        ServiceLocator.shared.register(AnalyticsService(), for: AnalyticsServiceProtocol.self)
        
        // Register SwiftData service
        do {
            let swiftDataService = try SwiftDataService()
            ServiceLocator.shared.register(swiftDataService, for: PersistenceServiceProtocol.self)
        } catch {
            fatalError("Failed to create SwiftData service: \(error)")
        }
        
        print("[App] All services registered")
        
        #if DEBUG
        ServiceLocator.validateServices()
        #endif
    }
    
    @MainActor
    private func initializeApp() async {
        // Perform any async initialization
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        
        // Preload common sounds
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
        if let audioService = audio as? AudioEngineService {
            audioService.preloadCommonSounds()
        }
        
        // Setup accessibility
        AccessibilityManager.shared.announceScreenChange("Welcome to OsmoApp")
        
        // Minimum loading time
        try? await Task.sleep(for: .seconds(1.5))
    }
}
```

#### 6.2 Update ContentView for @Observable
Update `App/ContentView.swift`:

```swift
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
                        GameHostView(gameId: gameId)
                    case .settings:
                        SettingsView()
                    case .parentGate:
                        ParentGateView()
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
```

#### 6.3 Update Settings View
Update `Features/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(AppCoordinator.self) var coordinator
    @Environment(\.dismiss) var dismiss
    @State private var userSettings = UserSettings()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sound") {
                    Toggle("Sound Effects", isOn: $userSettings.soundEnabled)
                        .onChange(of: userSettings.soundEnabled) { _, _ in
                            updateAudioService()
                        }
                    
                    Toggle("Background Music", isOn: $userSettings.musicEnabled)
                        .onChange(of: userSettings.musicEnabled) { _, _ in
                            updateAudioService()
                        }
                    
                    Toggle("Haptic Feedback", isOn: $userSettings.hapticEnabled)
                        .onChange(of: userSettings.hapticEnabled) { _, _ in
                            updateAudioService()
                        }
                }
                
                Section("Developer") {
                    Toggle("CV Debug Mode", isOn: $userSettings.cvDebugMode)
                }
                
                Section("Debug Actions") {
                    Button("Test Sound") {
                        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
                        audio.playSound("button_tap")
                    }
                    
                    Button("Test Haptic") {
                        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
                        audio.playHaptic(.medium)
                    }
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
                        Task {
                            await saveSettings()
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            await loadSettings()
        }
    }
    
    private func loadSettings() async {
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        userSettings = await persistence.loadUserSettings()
    }
    
    private func saveSettings() async {
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        try? await persistence.saveUserSettings(userSettings)
    }
    
    private func updateAudioService() {
        if let audioService = ServiceLocator.shared.resolve(AudioServiceProtocol.self) as? AudioEngineService {
            audioService.updateSettings(userSettings)
        }
    }
}
```

## Phase 2 Modern Completion Checklist

### ✅ Phase 1 Updates
- [ ] Converted all ViewModels to @Observable
- [ ] Updated protocols for async/await
- [ ] Replaced Combine subscriptions with AsyncStream
- [ ] Updated MockCVService for AsyncStream

### ✅ AVAudioEngine Audio Service
- [ ] Audio engine setup with effects nodes
- [ ] Async buffer loading
- [ ] CHHapticEngine integration
- [ ] Real-time volume and effects control
- [ ] Background music with proper mixing

### ✅ SwiftData Persistence  
- [ ] SwiftData models for all data types
- [ ] Async/await API throughout
- [ ] Proper error handling
- [ ] Migration support built-in
- [ ] CloudKit ready (just need to enable)

### ✅ Modern Analytics Service
- [ ] Async task-based flushing
- [ ] SwiftData integration for event storage
- [ ] Structured concurrency
- [ ] Modern logging with os.log

### ✅ Updated UI Components
- [ ] @Observable view models
- [ ] Environment-based coordinator
- [ ] Modern SwiftUI patterns
- [ ] Async data loading

## Key Improvements Over Original Phase 2

1. **SwiftData Benefits**:
   - Type-safe queries with #Predicate
   - Automatic iCloud sync capability
   - Better performance for complex data
   - Built-in migration support

2. **AVAudioEngine Benefits**:
   - Real-time audio effects
   - Lower latency
   - Better mixing capabilities
   - More professional sound

3. **@Observable Benefits**:
   - Less boilerplate code
   - Better performance
   - Cleaner syntax
   - Automatic dependency tracking

4. **AsyncStream Benefits**:
   - Natural async/await integration
   - Better memory management
   - Simpler cancellation
   - More intuitive API

The foundation is now modern, scalable, and ready for iOS 17+ features!