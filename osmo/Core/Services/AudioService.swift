//
//  AudioService.swift
//  osmo
//
//  Simple audio service for GameKit
//

import AVFoundation
import SwiftUI

@MainActor
public final class AudioService {
    private var audioEngine = AVAudioEngine()
    private var players: [String: AVAudioPlayer] = [:]
    private var backgroundMusicPlayer: AVAudioPlayer?
    
    public init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[Audio] Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Sound Effects
    
    public func play(_ sound: Sound) {
        playSound(sound.fileName)
    }
    
    public func playSound(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") ??
                       Bundle.main.url(forResource: name, withExtension: "wav") ??
                       Bundle.main.url(forResource: name, withExtension: "m4a") else {
            print("[Audio] Sound file not found: \(name)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            players[name] = player
        } catch {
            print("[Audio] Failed to play sound \(name): \(error)")
        }
    }
    
    // MARK: - Background Music
    
    public func playBackgroundMusic(_ name: String, volume: Float = 0.3) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("[Audio] Music file not found: \(name)")
            return
        }
        
        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundMusicPlayer?.numberOfLoops = -1 // Loop forever
            backgroundMusicPlayer?.volume = volume
            backgroundMusicPlayer?.prepareToPlay()
            backgroundMusicPlayer?.play()
        } catch {
            print("[Audio] Failed to play music \(name): \(error)")
        }
    }
    
    public func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
    }
    
    // MARK: - Control
    
    public func stopAll() {
        players.values.forEach { $0.stop() }
        players.removeAll()
        stopBackgroundMusic()
    }
    
    public func setVolume(_ volume: Float) {
        backgroundMusicPlayer?.volume = volume
    }
    
    // MARK: - Preloading
    
    public func preload(_ sounds: [Sound]) async {
        for sound in sounds {
            preloadSound(sound.fileName)
        }
    }
    
    private func preloadSound(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") ??
                       Bundle.main.url(forResource: name, withExtension: "wav") else {
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[name] = player
        } catch {
            print("[Audio] Failed to preload \(name): \(error)")
        }
    }
}

// MARK: - Sound Enum

public enum Sound: String {
    // UI Sounds
    case buttonTap = "button_tap"
    case menuSelect = "menu_select"
    case back = "back"
    
    // Game Sounds
    case piecePickup = "piece_pickup"
    case pieceDrop = "piece_drop"
    case pieceRotate = "piece_rotate"
    case pieceSnap = "piece_snap"
    
    // Feedback
    case success = "success"
    case failure = "failure"
    case correct = "correct"
    case incorrect = "incorrect"
    
    // Game Events
    case gameStart = "game_start"
    case gameComplete = "game_complete"
    case levelComplete = "level_complete"
    
    // Editor
    case save = "save"
    case delete = "delete"
    case generate = "generate"
    
    var fileName: String {
        return rawValue
    }
}