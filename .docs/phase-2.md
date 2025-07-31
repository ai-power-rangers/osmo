# Phase 2: Service Layer - Detailed Implementation Plan

## Overview
Phase 2 builds on the Phase 1 foundation by implementing real services and the game hosting infrastructure. By the end of this phase, you'll have working audio, persistence, analytics, and the ability to load and display SpriteKit games.

## Prerequisites
- Phase 1 completed successfully
- All mock services working and validated
- Navigation flow operational

## Step 1: Audio Service Implementation (60 minutes)

### 1.1 Create Audio Service
Replace `Core/Services/MockAudioService.swift` with `Core/Services/AudioService.swift`:

```swift
import Foundation
import AVFoundation
import UIKit

// MARK: - Audio Service
final class AudioService: AudioServiceProtocol {
    // Audio players
    private var soundPlayers: [String: AVAudioPlayer] = [:]
    private var backgroundMusicPlayer: AVAudioPlayer?
    
    // Haptic generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Settings
    private var soundEnabled = true
    private var musicEnabled = true
    private var hapticEnabled = true
    
    init() {
        setupAudioSession()
        loadSettings()
        
        // Prepare haptic generators
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            print("[AudioService] Audio session configured")
        } catch {
            print("[AudioService] Failed to setup audio session: \(error)")
        }
    }
    
    private func loadSettings() {
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        let settings = persistence.loadUserSettings()
        soundEnabled = settings.soundEnabled
        musicEnabled = settings.musicEnabled
        hapticEnabled = settings.hapticEnabled
    }
    
    // MARK: - Sound Effects
    func preloadSound(_ soundName: String) {
        guard soundPlayers[soundName] == nil else { return }
        
        if let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") ??
                     Bundle.main.url(forResource: soundName, withExtension: "wav") ??
                     Bundle.main.url(forResource: soundName, withExtension: "m4a") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                soundPlayers[soundName] = player
                print("[AudioService] Preloaded sound: \(soundName)")
            } catch {
                print("[AudioService] Failed to preload sound \(soundName): \(error)")
            }
        } else {
            print("[AudioService] Sound file not found: \(soundName)")
        }
    }
    
    func playSound(_ soundName: String) {
        playSound(soundName, volume: 1.0)
    }
    
    func playSound(_ soundName: String, volume: Float) {
        guard soundEnabled else { return }
        
        // Try to use preloaded player first
        if let player = soundPlayers[soundName] {
            player.volume = volume
            player.play()
            return
        }
        
        // Otherwise, load and play
        preloadSound(soundName)
        if let player = soundPlayers[soundName] {
            player.volume = volume
            player.play()
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
        backgroundMusicPlayer = nil
        
        // Start new music if provided
        guard let musicName = musicName else { return }
        
        if let url = Bundle.main.url(forResource: musicName, withExtension: "mp3") ??
                     Bundle.main.url(forResource: musicName, withExtension: "m4a") {
            do {
                backgroundMusicPlayer = try AVAudioPlayer(contentsOf: url)
                backgroundMusicPlayer?.numberOfLoops = -1 // Loop forever
                backgroundMusicPlayer?.volume = volume
                backgroundMusicPlayer?.play()
                print("[AudioService] Started background music: \(musicName)")
            } catch {
                print("[AudioService] Failed to play background music: \(error)")
            }
        }
    }
    
    // MARK: - Haptics
    func playHaptic(_ type: HapticType) {
        guard hapticEnabled else { return }
        
        switch type {
        case .light:
            lightImpact.impactOccurred()
        case .medium:
            mediumImpact.impactOccurred()
        case .heavy:
            heavyImpact.impactOccurred()
        case .success:
            notificationFeedback.notificationOccurred(.success)
        case .warning:
            notificationFeedback.notificationOccurred(.warning)
        case .error:
            notificationFeedback.notificationOccurred(.error)
        }
    }
    
    // MARK: - Settings Update
    func updateSettings(_ settings: UserSettings) {
        soundEnabled = settings.soundEnabled
        musicEnabled = settings.musicEnabled
        hapticEnabled = settings.hapticEnabled
        
        // Stop music if disabled
        if !musicEnabled {
            backgroundMusicPlayer?.stop()
        }
    }
}

// MARK: - Audio Service Extension for Common Sounds
extension AudioService {
    enum CommonSound: String {
        case buttonTap = "button_tap"
        case gameStart = "game_start"
        case levelComplete = "level_complete"
        case correctAnswer = "correct"
        case wrongAnswer = "wrong"
        case coinCollect = "coin"
        case powerUp = "powerup"
        
        var filename: String { rawValue }
    }
    
    func playCommonSound(_ sound: CommonSound, volume: Float = 1.0) {
        playSound(sound.filename, volume: volume)
    }
    
    func preloadCommonSounds() {
        CommonSound.allCases.forEach { sound in
            preloadSound(sound.filename)
        }
    }
}

// Extension to make CommonSound CaseIterable
extension AudioService.CommonSound: CaseIterable {}
```

### 1.2 Create Sound Assets Placeholder
Create `Resources/Sounds/README.md`:

```markdown
# Sound Assets

Place your sound files here with these names:
- button_tap.mp3 - UI button tap sound
- game_start.mp3 - Game launch sound
- level_complete.mp3 - Level completion fanfare
- correct.mp3 - Correct answer sound
- wrong.mp3 - Wrong answer sound
- coin.mp3 - Point/coin collection sound
- powerup.mp3 - Power-up activation sound

For testing, you can use system sounds or download free sounds from:
- freesound.org
- zapsplat.com
- opengameart.org

Supported formats: .mp3, .wav, .m4a
```

### 1.3 Update Settings View for Audio
Update `Features/Settings/SettingsView.swift` to notify audio service:

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
                        .onChange(of: userSettings.soundEnabled) { _ in
                            updateAudioService()
                        }
                    
                    Toggle("Background Music", isOn: $userSettings.musicEnabled)
                        .onChange(of: userSettings.musicEnabled) { _ in
                            updateAudioService()
                        }
                    
                    Toggle("Haptic Feedback", isOn: $userSettings.hapticEnabled)
                        .onChange(of: userSettings.hapticEnabled) { _ in
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
                        saveSettings()
                        coordinator.navigateBack()
                    }
                }
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        userSettings = persistence.loadUserSettings()
    }
    
    private func saveSettings() {
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        persistence.saveUserSettings(userSettings)
    }
    
    private func updateAudioService() {
        if let audioService = ServiceLocator.shared.resolve(AudioServiceProtocol.self) as? AudioService {
            audioService.updateSettings(userSettings)
        }
    }
}
```

## Step 2: Persistence Service Implementation (45 minutes)

### 2.1 Create Persistence Service
Replace `Core/Services/MockPersistenceService.swift` with `Core/Services/PersistenceService.swift`:

```swift
import Foundation

// MARK: - Persistence Service
final class PersistenceService: PersistenceServiceProtocol {
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Cache for frequently accessed data
    private var settingsCache: UserSettings?
    private var progressCache: [String: GameProgress] = [:]
    
    init() {
        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        print("[PersistenceService] Initialized")
    }
    
    // MARK: - Game Progress
    func saveGameProgress(_ progress: GameProgress) {
        let key = PersistenceKey.gameProgress(gameId: progress.gameId).stringValue
        
        do {
            let data = try encoder.encode(progress)
            userDefaults.set(data, forKey: key)
            progressCache[progress.gameId] = progress
            print("[PersistenceService] Saved progress for game: \(progress.gameId)")
        } catch {
            print("[PersistenceService] Failed to save progress: \(error)")
        }
    }
    
    func loadGameProgress(for gameId: String) -> GameProgress? {
        // Check cache first
        if let cached = progressCache[gameId] {
            return cached
        }
        
        let key = PersistenceKey.gameProgress(gameId: gameId).stringValue
        
        guard let data = userDefaults.data(forKey: key) else {
            print("[PersistenceService] No saved progress for game: \(gameId)")
            return nil
        }
        
        do {
            let progress = try decoder.decode(GameProgress.self, from: data)
            progressCache[gameId] = progress
            return progress
        } catch {
            print("[PersistenceService] Failed to load progress: \(error)")
            return nil
        }
    }
    
    // MARK: - Level Completion
    func saveLevel(gameId: String, level: String, completed: Bool) {
        var progress = loadGameProgress(for: gameId) ?? GameProgress(gameId: gameId)
        
        if completed {
            progress.levelsCompleted.insert(level)
        } else {
            progress.levelsCompleted.remove(level)
        }
        
        progress.lastPlayed = Date()
        saveGameProgress(progress)
    }
    
    func isLevelCompleted(gameId: String, level: String) -> Bool {
        let progress = loadGameProgress(for: gameId)
        return progress?.levelsCompleted.contains(level) ?? false
    }
    
    func getCompletedLevels(gameId: String) -> [String] {
        let progress = loadGameProgress(for: gameId)
        return Array(progress?.levelsCompleted ?? [])
    }
    
    // MARK: - High Scores
    func saveHighScore(gameId: String, level: String, score: Int) {
        let key = "highscore.\(gameId).\(level)"
        let currentHigh = userDefaults.integer(forKey: key)
        
        if score > currentHigh {
            userDefaults.set(score, forKey: key)
            print("[PersistenceService] New high score for \(gameId).\(level): \(score)")
        }
    }
    
    func getHighScore(gameId: String, level: String) -> Int? {
        let key = "highscore.\(gameId).\(level)"
        let score = userDefaults.integer(forKey: key)
        return score > 0 ? score : nil
    }
    
    // MARK: - Settings
    func saveUserSettings(_ settings: UserSettings) {
        let key = PersistenceKey.userSettings.stringValue
        
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: key)
            settingsCache = settings
            print("[PersistenceService] Saved user settings")
        } catch {
            print("[PersistenceService] Failed to save settings: \(error)")
        }
    }
    
    func loadUserSettings() -> UserSettings {
        // Check cache first
        if let cached = settingsCache {
            return cached
        }
        
        let key = PersistenceKey.userSettings.stringValue
        
        guard let data = userDefaults.data(forKey: key) else {
            let defaultSettings = UserSettings()
            settingsCache = defaultSettings
            return defaultSettings
        }
        
        do {
            let settings = try decoder.decode(UserSettings.self, from: data)
            settingsCache = settings
            return settings
        } catch {
            print("[PersistenceService] Failed to load settings: \(error)")
            let defaultSettings = UserSettings()
            settingsCache = defaultSettings
            return defaultSettings
        }
    }
    
    // MARK: - Session Management
    func saveCurrentSession(gameId: String, sessionStart: Date) {
        let key = PersistenceKey.currentSession.stringValue
        let sessionData: [String: Any] = [
            "gameId": gameId,
            "startTime": sessionStart.timeIntervalSince1970
        ]
        userDefaults.set(sessionData, forKey: key)
    }
    
    func loadCurrentSession() -> (gameId: String, startTime: Date)? {
        let key = PersistenceKey.currentSession.stringValue
        guard let data = userDefaults.dictionary(forKey: key),
              let gameId = data["gameId"] as? String,
              let timestamp = data["startTime"] as? TimeInterval else {
            return nil
        }
        return (gameId, Date(timeIntervalSince1970: timestamp))
    }
    
    func clearCurrentSession() {
        let key = PersistenceKey.currentSession.stringValue
        userDefaults.removeObject(forKey: key)
    }
    
    // MARK: - Data Management
    func clearAllGameData(for gameId: String) {
        // Clear progress
        let progressKey = PersistenceKey.gameProgress(gameId: gameId).stringValue
        userDefaults.removeObject(forKey: progressKey)
        progressCache.removeValue(forKey: gameId)
        
        // Clear high scores
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let highScorePrefix = "highscore.\(gameId)."
        allKeys.filter { $0.hasPrefix(highScorePrefix) }.forEach { key in
            userDefaults.removeObject(forKey: key)
        }
        
        print("[PersistenceService] Cleared all data for game: \(gameId)")
    }
    
    func exportAllData() -> Data? {
        let allData = userDefaults.dictionaryRepresentation()
        return try? JSONSerialization.data(withJSONObject: allData, options: .prettyPrinted)
    }
}

// MARK: - Migration Support
extension PersistenceService {
    func migrateDataIfNeeded() {
        let migrationKey = "data_migration_version"
        let currentVersion = 1
        let savedVersion = userDefaults.integer(forKey: migrationKey)
        
        if savedVersion < currentVersion {
            print("[PersistenceService] Migrating data from version \(savedVersion) to \(currentVersion)")
            // Add migration logic here as needed
            userDefaults.set(currentVersion, forKey: migrationKey)
        }
    }
}
```

## Step 3: Analytics Service Implementation (30 minutes)

### 3.1 Create Analytics Service
Replace `Core/Services/MockAnalyticsService.swift` with `Core/Services/AnalyticsService.swift`:

```swift
import Foundation
import os.log

// MARK: - Analytics Service
final class AnalyticsService: AnalyticsServiceProtocol {
    private let logger = Logger(subsystem: "com.osmoapp", category: "analytics")
    private var eventQueue: [AnalyticsEvent] = []
    private let maxQueueSize = 100
    private let flushInterval: TimeInterval = 30.0
    private var flushTimer: Timer?
    
    // Session tracking
    private var currentSession: GameSession?
    private let sessionTimeout: TimeInterval = 300 // 5 minutes
    
    init() {
        setupFlushTimer()
        observeAppLifecycle()
    }
    
    deinit {
        flushTimer?.invalidate()
    }
    
    // MARK: - Event Logging
    func logEvent(_ event: String, parameters: [String: Any] = [:]) {
        let analyticsEvent = AnalyticsEvent(
            eventType: .customEvent(name: event),
            gameId: currentSession?.gameId ?? "app",
            parameters: parameters
        )
        
        addToQueue(analyticsEvent)
        
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
            endCurrentSession()
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
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        persistence.saveCurrentSession(gameId: gameId, sessionStart: Date())
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
            let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
            persistence.saveLevel(gameId: gameId, level: level, completed: true)
            
            if let score = score {
                persistence.saveHighScore(gameId: gameId, level: level, score: score)
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
    private func addToQueue(_ event: AnalyticsEvent) {
        eventQueue.append(event)
        currentSession?.events.append(event)
        
        // Flush if queue is full
        if eventQueue.count >= maxQueueSize {
            flushEvents()
        }
    }
    
    private func flushEvents() {
        guard !eventQueue.isEmpty else { return }
        
        logger.info("📊 Flushing \(self.eventQueue.count) analytics events")
        
        // In a real app, send to analytics backend here
        // For now, just log summary
        let eventSummary = Dictionary(grouping: eventQueue) { event in
            event.eventType.description
        }.mapValues { $0.count }
        
        logger.info("📊 Event Summary: \(eventSummary)")
        
        // Save summary to persistence for debugging
        if let jsonData = try? JSONEncoder().encode(eventSummary),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            UserDefaults.standard.set(jsonString, forKey: "last_analytics_flush")
            UserDefaults.standard.set(Date(), forKey: "last_analytics_flush_date")
        }
        
        // Clear queue
        eventQueue.removeAll()
    }
    
    // MARK: - Timer Management
    private func setupFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            self?.flushEvents()
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
        flushEvents()
        endCurrentSession()
    }
    
    @objc private func appWillTerminate() {
        flushEvents()
    }
    
    private func endCurrentSession() {
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
        persistence.clearCurrentSession()
    }
}

// MARK: - Event Type Description
extension EventType {
    var description: String {
        switch self {
        case .gameStarted: return "game_started"
        case .levelCompleted: return "level_completed"
        case .achievementUnlocked: return "achievement_unlocked"
        case .errorOccurred: return "error_occurred"
        case .cvEventProcessed: return "cv_event_processed"
        case .customEvent(let name): return name
        }
    }
}

// MARK: - Debug Helpers
extension AnalyticsService {
    func getEventSummary() -> [String: Int] {
        Dictionary(grouping: eventQueue) { event in
            event.eventType.description
        }.mapValues { $0.count }
    }
    
    func getCurrentSessionInfo() -> String? {
        guard let session = currentSession else { return nil }
        return """
        Session ID: \(session.sessionId)
        Game: \(session.gameId)
        Duration: \(Int(Date().timeIntervalSince(session.startTime)))s
        Events: \(session.events.count)
        Errors: \(session.errorCount)
        """
    }
}
```

## Step 4: Game Loading System (45 minutes)

### 4.1 Create Game Registry
Create `Core/Services/GameRegistry.swift`:

```swift
import Foundation

// MARK: - Game Registry
final class GameRegistry {
    static let shared = GameRegistry()
    
    private var registeredGames: [String: GameModule.Type] = [:]
    private var gameInfoCache: [String: GameInfo] = [:]
    
    private init() {
        loadGameManifest()
    }
    
    // MARK: - Registration
    func register(_ gameType: GameModule.Type) {
        let gameId = gameType.gameId
        registeredGames[gameId] = gameType
        gameInfoCache[gameId] = gameType.gameInfo
        print("[GameRegistry] Registered game: \(gameId)")
    }
    
    func unregister(_ gameId: String) {
        registeredGames.removeValue(forKey: gameId)
        gameInfoCache.removeValue(forKey: gameId)
        print("[GameRegistry] Unregistered game: \(gameId)")
    }
    
    // MARK: - Retrieval
    func getGameModule(for gameId: String) -> GameModule.Type? {
        return registeredGames[gameId]
    }
    
    func getGameInfo(for gameId: String) -> GameInfo? {
        return gameInfoCache[gameId]
    }
    
    func getAllGameInfo() -> [GameInfo] {
        return Array(gameInfoCache.values).sorted { $0.displayName < $1.displayName }
    }
    
    func getGamesForCategory(_ category: GameCategory) -> [GameInfo] {
        return gameInfoCache.values
            .filter { $0.category == category }
            .sorted { $0.displayName < $1.displayName }
    }
    
    // MARK: - Manifest Loading
    private func loadGameManifest() {
        // In Phase 2, we'll use hardcoded games
        // In production, this would load from a JSON manifest
        
        // Note: Actual game modules will be registered in Phase 4
        // For now, we're just preparing the infrastructure
    }
    
    // MARK: - Validation
    func validateGame(_ gameId: String) -> Result<Void, GameLoadError> {
        guard let _ = registeredGames[gameId] else {
            return .failure(.gameNotFound(gameId))
        }
        
        guard let info = gameInfoCache[gameId] else {
            return .failure(.missingGameInfo(gameId))
        }
        
        // Check bundle size (mock check for now)
        if info.bundleSize > 500 {
            return .failure(.bundleTooLarge(gameId, info.bundleSize))
        }
        
        return .success(())
    }
}

// MARK: - Game Load Errors
enum GameLoadError: LocalizedError {
    case gameNotFound(String)
    case missingGameInfo(String)
    case bundleTooLarge(String, Int)
    case initializationFailed(String, Error)
    
    var errorDescription: String? {
        switch self {
        case .gameNotFound(let gameId):
            return "Game not found: \(gameId)"
        case .missingGameInfo(let gameId):
            return "Missing info for game: \(gameId)"
        case .bundleTooLarge(let gameId, let size):
            return "Game \(gameId) is too large: \(size)MB"
        case .initializationFailed(let gameId, let error):
            return "Failed to initialize \(gameId): \(error.localizedDescription)"
        }
    }
}
```

### 4.2 Create Game Loader
Create `Core/Services/GameLoader.swift`:

```swift
import Foundation
import SpriteKit

// MARK: - Game Loader
final class GameLoader {
    private var loadedModules: [String: GameModule] = [:]
    private let maxLoadedModules = 3 // Memory management
    
    // MARK: - Loading
    func loadGame(_ gameId: String) throws -> GameModule {
        // Check if already loaded
        if let module = loadedModules[gameId] {
            print("[GameLoader] Using cached module for: \(gameId)")
            return module
        }
        
        // Validate game exists
        let validationResult = GameRegistry.shared.validateGame(gameId)
        if case .failure(let error) = validationResult {
            throw error
        }
        
        // Get game type from registry
        guard let gameType = GameRegistry.shared.getGameModule(for: gameId) else {
            throw GameLoadError.gameNotFound(gameId)
        }
        
        // Initialize game module
        do {
            let module = gameType.init()
            
            // Cache management
            if loadedModules.count >= maxLoadedModules {
                unloadOldestModule()
            }
            
            loadedModules[gameId] = module
            print("[GameLoader] Loaded game module: \(gameId)")
            
            // Log analytics
            let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
            analytics.logEvent("game_loaded", parameters: ["game_id": gameId])
            
            return module
        } catch {
            throw GameLoadError.initializationFailed(gameId, error)
        }
    }
    
    // MARK: - Unloading
    func unloadGame(_ gameId: String) {
        guard let module = loadedModules[gameId] else { return }
        
        module.cleanup()
        loadedModules.removeValue(forKey: gameId)
        
        print("[GameLoader] Unloaded game module: \(gameId)")
        
        // Log analytics
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("game_unloaded", parameters: ["game_id": gameId])
    }
    
    func unloadAllGames() {
        loadedModules.keys.forEach { unloadGame($0) }
    }
    
    // MARK: - Memory Management
    private func unloadOldestModule() {
        // For now, just remove the first one
        // In production, track last used time
        if let firstKey = loadedModules.keys.first {
            unloadGame(firstKey)
        }
    }
    
    // MARK: - Scene Creation
    func createGameScene(for gameId: String, size: CGSize) throws -> SKScene {
        let module = try loadGame(gameId)
        let context = ServiceLocator.shared.createGameContext()
        return module.createGameScene(size: size, context: context)
    }
}

// MARK: - Memory Monitoring
extension GameLoader {
    func getMemoryUsage() -> String {
        let loadedCount = loadedModules.count
        let gameIds = loadedModules.keys.joined(separator: ", ")
        return "Loaded modules: \(loadedCount) [\(gameIds)]"
    }
}
```

## Step 5: SpriteKit Hosting View (60 minutes)

### 5.1 Create SpriteKit View
Create `Features/GameHost/SpriteKitView.swift`:

```swift
import SwiftUI
import SpriteKit

// MARK: - SpriteKit View
struct SpriteKitView: UIViewRepresentable {
    let scene: SKScene
    let debugOptions: SpriteKitView.DebugOptions
    
    struct DebugOptions {
        var showsFPS = false
        var showsNodeCount = false
        var showsPhysics = false
        var showsFields = false
        var showsQuadCount = false
        
        static let none = DebugOptions()
        static let performance = DebugOptions(showsFPS: true, showsNodeCount: true, showsQuadCount: true)
        static let physics = DebugOptions(showsPhysics: true, showsFields: true)
        static let all = DebugOptions(showsFPS: true, showsNodeCount: true, showsPhysics: true, showsFields: true, showsQuadCount: true)
    }
    
    init(scene: SKScene, debugOptions: DebugOptions = .none) {
        self.scene = scene
        self.debugOptions = debugOptions
    }
    
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        
        // Configure view
        view.ignoresSiblingOrder = true
        view.allowsTransparency = false
        
        // Apply debug options
        view.showsFPS = debugOptions.showsFPS
        view.showsNodeCount = debugOptions.showsNodeCount
        view.showsPhysics = debugOptions.showsPhysics
        view.showsFields = debugOptions.showsFields
        view.showsQuadCount = debugOptions.showsQuadCount
        
        // Set the scene
        view.presentScene(scene)
        
        return view
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {
        // Update debug options if changed
        uiView.showsFPS = debugOptions.showsFPS
        uiView.showsNodeCount = debugOptions.showsNodeCount
        uiView.showsPhysics = debugOptions.showsPhysics
        uiView.showsFields = debugOptions.showsFields
        uiView.showsQuadCount = debugOptions.showsQuadCount
    }
    
    static func dismantleUIView(_ uiView: SKView, coordinator: ()) {
        uiView.presentScene(nil)
    }
}

// MARK: - View Modifiers
extension SpriteKitView {
    func debugMode(_ enabled: Bool) -> SpriteKitView {
        SpriteKitView(
            scene: scene,
            debugOptions: enabled ? .performance : .none
        )
    }
    
    func physicsDebugMode(_ enabled: Bool) -> SpriteKitView {
        var options = debugOptions
        options.showsPhysics = enabled
        options.showsFields = enabled
        return SpriteKitView(scene: scene, debugOptions: options)
    }
}
```

### 5.2 Create Game Host View
Create `Features/GameHost/GameHostView.swift`:

```swift
import SwiftUI
import SpriteKit

// MARK: - Game Host View
struct GameHostView: View {
    let gameId: String
    @Environment(\.coordinator) var coordinator
    @StateObject private var viewModel = GameHostViewModel()
    @State private var showPauseMenu = false
    @State private var showDebugInfo = false
    
    var body: some View {
        ZStack {
            // Game content
            if let scene = viewModel.gameScene {
                GeometryReader { geometry in
                    SpriteKitView(scene: scene)
                        .debugMode(showDebugInfo)
                        .ignoresSafeArea()
                        .onAppear {
                            // Ensure scene fills the view
                            scene.size = geometry.size
                            scene.scaleMode = .aspectFill
                        }
                }
            } else if viewModel.isLoading {
                LoadingView(gameName: viewModel.gameName)
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    coordinator.navigateBack()
                }
            }
            
            // Overlay UI
            if viewModel.gameScene != nil {
                VStack {
                    // Top bar
                    HStack {
                        // Back button
                        Button {
                            showPauseMenu = true
                        } label: {
                            Image(systemName: "pause.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                        
                        Spacer()
                        
                        // Debug toggle
                        #if DEBUG
                        Button {
                            showDebugInfo.toggle()
                        } label: {
                            Image(systemName: showDebugInfo ? "eye.fill" : "eye.slash.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                        #endif
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .sheet(isPresented: $showPauseMenu) {
            PauseMenuView(
                onResume: { showPauseMenu = false },
                onQuit: {
                    viewModel.cleanup()
                    coordinator.navigateBack()
                }
            )
        }
        .onAppear {
            viewModel.loadGame(gameId)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

// MARK: - Loading View
private struct LoadingView: View {
    let gameName: String
    @State private var dots = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
                
                Text("Loading \(gameName)\(String(repeating: ".", count: dots))")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dots = (dots + 1) % 4
            }
        }
    }
}

// MARK: - Error View
private struct ErrorView: View {
    let error: Error
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                
                Text("Oops! Something went wrong")
                    .font(.title)
                    .foregroundColor(.white)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Back to Games") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Pause Menu
private struct PauseMenuView: View {
    let onResume: () -> Void
    let onQuit: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Game Paused")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(spacing: 20) {
                    Button {
                        onResume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .frame(width: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button {
                        onQuit()
                    } label: {
                        Label("Quit Game", systemImage: "xmark.circle.fill")
                            .frame(width: 200)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.red)
                }
            }
        }
    }
}
```

### 5.3 Create Game Host View Model
Create `Features/GameHost/GameHostViewModel.swift`:

```swift
import Foundation
import SpriteKit
import Combine

// MARK: - Game Host View Model
@MainActor
final class GameHostViewModel: ObservableObject {
    @Published var gameScene: SKScene?
    @Published var isLoading = true
    @Published var error: Error?
    @Published var gameName = ""
    
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
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Get screen size
                let screenSize = UIScreen.main.bounds.size
                
                // Create game scene
                let scene = try gameLoader.createGameScene(for: gameId, size: screenSize)
                
                // Configure scene
                scene.scaleMode = .aspectFill
                scene.backgroundColor = .black
                
                // Update UI
                await MainActor.run {
                    self.gameScene = scene
                    self.isLoading = false
                }
                
                // Log analytics
                let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
                analytics.startLevel(gameId: gameId, level: "main")
                
                // Play start sound
                let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
                audio.playSound("game_start")
                audio.playHaptic(.medium)
                
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
                
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

## Step 6: Update App Integration (30 minutes)

### 6.1 Update Service Registration
Update `App/OsmoApp.swift`:

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
                            // Initialize services and load data
                            Task {
                                await initializeApp()
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
        // Register real services (replacing mocks from Phase 1)
        ServiceLocator.shared.register(MockCVService(), for: CVServiceProtocol.self) // Still mock in Phase 2
        ServiceLocator.shared.register(AudioService(), for: AudioServiceProtocol.self)
        ServiceLocator.shared.register(AnalyticsService(), for: AnalyticsServiceProtocol.self)
        ServiceLocator.shared.register(PersistenceService(), for: PersistenceServiceProtocol.self)
        
        print("[App] All services registered")
        
        #if DEBUG
        ServiceLocator.validateServices()
        #endif
    }
    
    @MainActor
    private func initializeApp() async {
        // Perform any async initialization
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        
        // Check for migration
        if let persistenceService = persistence as? PersistenceService {
            persistenceService.migrateDataIfNeeded()
        }
        
        // Preload common sounds
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
        if let audioService = audio as? AudioService {
            audioService.preloadCommonSounds()
        }
        
        // Restore session if app crashed
        if let session = persistence.loadCurrentSession() {
            print("[App] Restored session for game: \(session.gameId)")
            // Could auto-resume game here if desired
        }
        
        // Minimum loading time for smooth transition
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
    }
}
```

### 6.2 Update Content View
Update `App/ContentView.swift`:

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
                        GameHostView(gameId: gameId)  // Now using real implementation
                    case .settings:
                        SettingsView()
                    case .parentGate:
                        ParentGateView()  // Will implement this now
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

### 6.3 Create Parent Gate View
Create `Features/Settings/ParentGateView.swift`:

```swift
import SwiftUI

struct ParentGateView: View {
    @Environment(\.coordinator) var coordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var answer = ""
    @State private var showError = false
    
    // Generate random math problem
    let number1 = Int.random(in: 10...20)
    let number2 = Int.random(in: 10...20)
    
    var correctAnswer: String {
        String(number1 + number2)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Parent Gate")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Please solve this problem to continue")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Math problem
                HStack(spacing: 20) {
                    Text("\(number1)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    Text("+")
                        .font(.system(size: 36))
                    
                    Text("\(number2)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    Text("=")
                        .font(.system(size: 36))
                    
                    TextField("?", text: $answer)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 100)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Button("Submit") {
                    checkAnswer()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(answer.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Incorrect", isPresented: $showError) {
                Button("Try Again") {
                    answer = ""
                }
            } message: {
                Text("That's not the right answer. Please try again.")
            }
        }
    }
    
    private func checkAnswer() {
        if answer == correctAnswer {
            // Success - allow access
            let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
            audio.playSound("correct")
            audio.playHaptic(.success)
            
            dismiss()
            // Parent gate passed - could set a flag here
        } else {
            // Wrong answer
            let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
            audio.playSound("wrong")
            audio.playHaptic(.error)
            
            showError = true
        }
    }
}
```

### 6.4 Update Lobby View
Update `Features/Lobby/LobbyView.swift` to use real game registry:

```swift
import SwiftUI

struct LobbyView: View {
    @Environment(\.coordinator) var coordinator
    @State private var selectedCategory: GameCategory? = nil
    @State private var games: [GameInfo] = []
    
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
                    if games.isEmpty {
                        EmptyGamesView()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(filteredGames) { game in
                                    GameCard(gameInfo: game) {
                                        if !game.isLocked {
                                            coordinator.launchGame(game.gameId)
                                        }
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding()
                            .animation(.easeInOut, value: selectedCategory)
                        }
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
        .onAppear {
            loadGames()
        }
    }
    
    private var filteredGames: [GameInfo] {
        if let category = selectedCategory {
            return games.filter { $0.category == category }
        }
        return games
    }
    
    private func loadGames() {
        // In Phase 2, still using mock data
        // In Phase 4, this will load from GameRegistry
        games = [
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
    }
}

// MARK: - Empty Games View
struct EmptyGamesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Games Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Games will appear here once they're loaded")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}
```

## Step 7: Testing & Validation (15 minutes)

### 7.1 Create Service Tests
Create `Utilities/ServiceTests.swift`:

```swift
import Foundation
import Combine

// MARK: - Service Test Suite
struct ServiceTestSuite {
    
    // MARK: - Audio Service Tests
    static func testAudioService() {
        print("\n=== Testing Audio Service ===")
        
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
        
        // Test sound playback
        print("Testing sound playback...")
        audio.playSound("button_tap")
        
        // Test haptics
        print("Testing haptics...")
        audio.playHaptic(.medium)
        
        // Test background music
        print("Testing background music...")
        audio.setBackgroundMusic("theme_music", volume: 0.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            audio.setBackgroundMusic(nil, volume: 0)
        }
        
        print("✅ Audio Service tests completed")
    }
    
    // MARK: - Persistence Service Tests
    static func testPersistenceService() {
        print("\n=== Testing Persistence Service ===")
        
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        
        // Test settings
        print("Testing settings persistence...")
        var settings = UserSettings()
        settings.soundEnabled = false
        persistence.saveUserSettings(settings)
        
        let loadedSettings = persistence.loadUserSettings()
        assert(loadedSettings.soundEnabled == false, "Settings not persisted correctly")
        
        // Test game progress
        print("Testing game progress...")
        let progress = GameProgress(gameId: "test_game")
        persistence.saveGameProgress(progress)
        
        let loadedProgress = persistence.loadGameProgress(for: "test_game")
        assert(loadedProgress != nil, "Progress not loaded")
        
        // Test level completion
        print("Testing level completion...")
        persistence.saveLevel(gameId: "test_game", level: "level_1", completed: true)
        assert(persistence.isLevelCompleted(gameId: "test_game", level: "level_1"), "Level completion not saved")
        
        print("✅ Persistence Service tests completed")
    }
    
    // MARK: - Analytics Service Tests
    static func testAnalyticsService() {
        print("\n=== Testing Analytics Service ===")
        
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        
        // Test event logging
        print("Testing event logging...")
        analytics.logEvent("test_event", parameters: ["test_param": "value"])
        
        // Test level tracking
        print("Testing level tracking...")
        analytics.startLevel(gameId: "test_game", level: "level_1")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            analytics.endLevel(gameId: "test_game", level: "level_1", success: true, score: 100)
        }
        
        // Test error logging
        print("Testing error logging...")
        let error = NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        analytics.logError(error, context: "test_context")
        
        print("✅ Analytics Service tests completed")
    }
    
    // MARK: - Run All Tests
    static func runAllTests() {
        print("\n🧪 Running Service Test Suite...")
        
        testAudioService()
        testPersistenceService()
        testAnalyticsService()
        
        print("\n✅ All service tests completed!")
        
        // Print summary
        if let analyticsService = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self) as? AnalyticsService {
            print("\nAnalytics Summary:")
            print(analyticsService.getEventSummary())
        }
    }
}
```

### 7.2 Add Debug Menu
Update `Features/Settings/SettingsView.swift` to add debug section:

```swift
// Add to the Form in SettingsView:

Section("Debug Tools") {
    Button("Run Service Tests") {
        ServiceTestSuite.runAllTests()
    }
    
    Button("Clear All Data") {
        clearAllData()
    }
    .foregroundColor(.red)
    
    Button("Export Analytics") {
        exportAnalytics()
    }
    
    if let gameLoader = GameLoader() as GameLoader? {
        Text(gameLoader.getMemoryUsage())
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

// Add these methods:
private func clearAllData() {
    let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
    
    // Clear each game's data
    ["finger_count", "shape_match", "color_hunt"].forEach { gameId in
        if let service = persistence as? PersistenceService {
            service.clearAllGameData(for: gameId)
        }
    }
    
    // Reset settings
    persistence.saveUserSettings(UserSettings())
    
    // Reload
    loadSettings()
}

private func exportAnalytics() {
    if let service = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self) as? PersistenceService,
       let data = service.exportAllData() {
        // In a real app, share this data
        print("Exported \(data.count) bytes of analytics data")
    }
}
```

## Phase 2 Completion Checklist

### ✅ Audio Service
- [ ] AVAudioSession configuration
- [ ] Sound effect playback with preloading
- [ ] Background music with looping
- [ ] Haptic feedback implementation
- [ ] Settings integration

### ✅ Persistence Service  
- [ ] UserDefaults-based storage
- [ ] Game progress saving/loading
- [ ] Level completion tracking
- [ ] High score management
- [ ] Settings persistence
- [ ] Data migration support

### ✅ Analytics Service
- [ ] Event logging system
- [ ] Session tracking
- [ ] Level start/end tracking
- [ ] Error logging
- [ ] Automatic flushing
- [ ] App lifecycle integration

### ✅ Game Infrastructure
- [ ] Game Registry for module management
- [ ] Game Loader with memory management
- [ ] SpriteKit hosting view
- [ ] Game Host view with pause menu
- [ ] Loading and error states

### ✅ UI Enhancements
- [ ] Parent Gate implementation
- [ ] Enhanced settings with debug tools
- [ ] Empty states for lobby
- [ ] Service test suite

## Next Steps for Phase 3

With Phase 2 complete, you now have:
1. Working audio with haptics
2. Persistent data storage
3. Analytics tracking
4. SpriteKit game hosting
5. Complete game loading infrastructure

Phase 3 will add:
- Real CV service with ARKit
- Camera permissions flow
- CV debug overlay
- Finger detection logic
- Event publishing system

The foundation is now ready for actual games!