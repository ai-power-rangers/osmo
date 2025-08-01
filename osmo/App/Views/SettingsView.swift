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
    @State private var isLoading = true
    @State private var hasChanges = false
    
    var body: some View {
        Form {
            Section("Sound") {
                Toggle("Sound Effects", isOn: $userSettings.soundEnabled)
                    .onChange(of: userSettings.soundEnabled) { _, _ in
                        hasChanges = true
                        updateAudioService()
                    }
                
                Toggle("Background Music", isOn: $userSettings.musicEnabled)
                    .onChange(of: userSettings.musicEnabled) { _, _ in
                        hasChanges = true
                        updateAudioService()
                    }
                
                Toggle("Haptic Feedback", isOn: $userSettings.hapticEnabled)
                    .onChange(of: userSettings.hapticEnabled) { _, _ in
                        hasChanges = true
                        updateAudioService()
                    }
            }
            
            Section("Developer") {
                Toggle("CV Debug Mode", isOn: $userSettings.cvDebugMode)
                    .onChange(of: userSettings.cvDebugMode) { _, _ in
                        hasChanges = true
                    }
            }
            
            Section("Debug Actions") {
                Button("Test Sound") {
                    testSound()
                }
                
                Button("Test Haptic") {
                    testHaptic()
                }
                
                Button("Test Computer Vision") {
                    dismiss()
                    // Small delay to ensure dismiss completes before navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        coordinator.navigateTo(.cvTest)
                    }
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
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("Phase 3")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasChanges)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        Task {
                            // Reload original settings
                            await loadSettings()
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveSettings()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .task {
            await loadSettings()
            isLoading = false
        }
    }
    
    // MARK: - Data Operations
    private func loadSettings() async {
        guard ServiceLocator.shared.isInitialized else { return }
        
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        userSettings = await persistence.loadUserSettings()
        hasChanges = false
    }
    
    private func saveSettings() async {
        guard ServiceLocator.shared.isInitialized else { return }
        
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        do {
            try await persistence.saveUserSettings(userSettings)
            hasChanges = false
            
            // Log settings change
            let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
            analytics.logEvent("settings_updated", parameters: [
                "sound_enabled": String(userSettings.soundEnabled),
                "music_enabled": String(userSettings.musicEnabled),
                "haptic_enabled": String(userSettings.hapticEnabled),
                "cv_debug_mode": String(userSettings.cvDebugMode)
            ])
        } catch {
            // In production, show error alert
            print("[Settings] Failed to save: \(error)")
        }
    }
    
    // MARK: - Service Updates
    private func updateAudioService() {
        guard ServiceLocator.shared.isInitialized,
              let audioService = ServiceLocator.shared.resolve(AudioServiceProtocol.self) as? AudioEngineService else {
            return
        }
        
        audioService.updateSettings(userSettings)
    }
    
    // MARK: - Test Actions
    private func testSound() {
        guard ServiceLocator.shared.isInitialized else { return }
        
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
        audio.playSound("button_tap")
        
        // Log test action
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("debug_test_sound", parameters: [:])
    }
    
    private func testHaptic() {
        guard ServiceLocator.shared.isInitialized else { return }
        
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
        audio.playHaptic(.medium)
        
        // Log test action
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("debug_test_haptic", parameters: [:])
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppCoordinator())
    }
}