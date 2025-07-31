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