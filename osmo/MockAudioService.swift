//
//  MockAudioService.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

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