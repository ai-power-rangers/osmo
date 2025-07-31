//
//  osmoApp.swift
//  osmo
//
//  Created by Mitchell White on 7/30/25.
//

import SwiftUI
import SwiftData
import os.log

@main
struct OsmoApp: App {
    @State private var coordinator = AppCoordinator()
    @State private var isLoading = true
    @Environment(\.scenePhase) var scenePhase
    
    let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "com.osmoapp", category: "app")
    
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
            .onChange(of: scenePhase) { _, newPhase in
                if let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self) as? AnalyticsService {
                    analytics.handleScenePhaseChange(newPhase)
                }
            }
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
        
        logger.info("[App] All services registered")
        
        #if DEBUG
        ServiceLocator.validateServices()
        #endif
    }
    
    @MainActor
    private func initializeApp() async {
        // Perform any async initialization
        _ = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        
        // Preload common sounds
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
        if let audioService = audio as? AudioEngineService {
            audioService.preloadCommonSounds()
        }
        
        // Minimum loading time
        try? await Task.sleep(for: .seconds(1.5))
    }
}
