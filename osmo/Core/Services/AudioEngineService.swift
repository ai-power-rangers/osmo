//
//  AudioEngineService.swift
//  osmo
//
//  Created by Phase 2 Implementation
//

import Foundation
import AVFoundation
import CoreHaptics
import Observation
import os.log

// MARK: - Audio Engine Service
@Observable
final class AudioEngineService: AudioServiceProtocol, ServiceLifecycle {
    private let logger = Logger(subsystem: "com.osmoapp", category: "audio")
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
    private var hapticEngine: CHHapticEngine?
    private var hapticPatterns: [HapticType: CHHapticPattern] = [:]
    
    // Settings
    var soundEnabled = true
    var musicEnabled = true
    var hapticEnabled = true
    
    init() {
        mainMixer = audioEngine.mainMixerNode
        setupAudioEngine()
        setupHaptics()
        // Don't load settings in init - let the app do it after all services are registered
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
            
            logger.info("[AudioEngine] Engine started successfully")
        } catch {
            logger.error("[AudioEngine] Failed to setup: \(error)")
        }
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            createHapticPatterns()
        } catch {
            logger.error("[AudioEngine] Haptics setup failed: \(error)")
        }
    }
    
    private func createHapticPatterns() {
        // Create patterns for different haptic types
        createHapticPattern(for: .light)
        createHapticPattern(for: .medium)
        createHapticPattern(for: .heavy)
        createHapticPattern(for: .success)
        createHapticPattern(for: .warning)
        createHapticPattern(for: .error)
    }
    
    private func createHapticPattern(for type: HapticType) {
        switch type {
        case .light:
            hapticPatterns[type] = try? CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0)
            ], parameters: [])
            
        case .medium:
            hapticPatterns[type] = try? CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0)
            ], parameters: [])
            
        case .heavy:
            hapticPatterns[type] = try? CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0)
            ], parameters: [])
            
        case .success:
            hapticPatterns[type] = try? CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0.1)
            ], parameters: [])
            
        case .warning:
            hapticPatterns[type] = try? CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ], relativeTime: 0.15)
            ], parameters: [])
            
        case .error:
            hapticPatterns[type] = try? CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0, duration: 0.3)
            ], parameters: [])
        }
    }
    
    // MARK: - Sound Loading
    func preloadSound(_ soundName: String) {
        guard soundBuffers[soundName] == nil else { return }
        
        Task {
            if let buffer = await loadAudioBuffer(named: soundName) {
                soundBuffers[soundName] = buffer
                logger.debug("[AudioEngine] Preloaded: \(soundName)")
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
                    logger.error("[AudioEngine] Failed to load \(name).\(ext): \(error)")
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
            let buffer: AVAudioPCMBuffer?
            if let cached = soundBuffers[soundName] {
                buffer = cached
            } else {
                buffer = await loadAudioBuffer(named: soundName)
            }
            guard let buffer = buffer else {
                logger.warning("[AudioEngine] Sound not found: \(soundName)")
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
        
        // Create haptic patterns for all types if not already created
        if hapticPatterns[type] == nil {
            createHapticPattern(for: type)
        }
        
        // Play the pattern
        if let pattern = hapticPatterns[type] {
            try? hapticEngine?.makePlayer(with: pattern).start(atTime: 0)
        }
    }
    
    // MARK: - ServiceLifecycle
    func initialize() async throws {
        await loadSettings()
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
