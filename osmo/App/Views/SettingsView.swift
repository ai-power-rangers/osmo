//
//  SettingsView.swift
//  osmo
//
//  Settings view - Refactored with proper service injection
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                NavigationLink(destination: Text("Tangram Settings")) {
                    Label("Tangram", systemImage: "square.on.square")
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
        // Load settings from GameKit storage
        do {
            userSettings = try await GameKit.storage.loadSettings()
        } catch {
            // Use default settings if not available
            userSettings = UserSettings()
        }
        hasChanges = false
    }
    
    private func saveSettings() async {
        // Save settings using GameKit
        do {
            try await GameKit.storage.saveSettings(userSettings)
            hasChanges = false
            
            // Log settings change
            GameKit.analytics.logEvent("settings_updated", parameters: [
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
        // Audio settings are applied immediately through UserSettings
    }
    
    // MARK: - Test Actions
    
    private func testSound() {
        // Use GameKit for immediate access
        Task { @MainActor in
            GameKit.audio.play(.buttonTap)
            GameKit.analytics.logEvent("debug_test_sound", parameters: [:])
        }
    }
    
    private func testHaptic() {
        // Use GameKit for immediate access
        Task { @MainActor in
            GameKit.haptics.playHaptic(.medium)
            GameKit.analytics.logEvent("debug_test_haptic", parameters: [:])
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}