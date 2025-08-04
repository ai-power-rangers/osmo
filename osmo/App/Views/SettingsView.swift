//
//  SettingsView.swift
//  osmo
//
//  Settings view - Refactored with proper service injection
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.persistenceService) private var persistenceService
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.audioService) private var audioService
    
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
            
            Section("Games") {
                ForEach(GameSettingsRegistry.shared.allProviders(), id: \.gameId) { provider in
                    NavigationLink(destination: provider.createSettingsView()) {
                        Label(provider.displayName, systemImage: provider.iconName)
                    }
                }
                
                if GameSettingsRegistry.shared.allProviders().isEmpty {
                    Text("No game settings available")
                        .foregroundColor(.secondary)
                        .font(.caption)
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
                
                NavigationLink("Test Computer Vision", value: AppRoute.cvTest)
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
                    Button("Save") {
                        Task {
                            await saveSettings()
                            dismiss()
                        }
                    }
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
        guard let persistence = persistenceService else { return }
        
        userSettings = await persistence.loadUserSettings()
        hasChanges = false
    }
    
    private func saveSettings() async {
        guard let persistence = persistenceService else { return }
        
        do {
            try await persistence.saveUserSettings(userSettings)
            hasChanges = false
            
            // Log settings change
            analyticsService?.logEvent("settings_updated", parameters: [
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
        guard let audio = audioService as? AudioEngineService else { return }
        
        audio.updateSettings(userSettings)
    }
    
    // MARK: - Test Actions
    
    private func testSound() {
        audioService?.playSound("button_tap")
        
        // Log test action
        analyticsService?.logEvent("debug_test_sound", parameters: [:])
    }
    
    private func testHaptic() {
        audioService?.playHaptic(.medium)
        
        // Log test action
        analyticsService?.logEvent("debug_test_haptic", parameters: [:])
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}