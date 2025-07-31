//
//  SettingsView.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

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
                    
                    Button("Test Computer Vision") {
                        dismiss()
                        coordinator.navigateTo(.cvTest)
                    }
                    .foregroundColor(.blue)
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
