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
                // Guard against accessing services before initialization
                guard ServiceLocator.shared.isInitialized else { return }
                
                if let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self) as? AnalyticsService {
                    analytics.handleScenePhaseChange(newPhase)
                }
            }
        }
    }
    
    private func setupServices() {
        // CRITICAL: Services must be registered in dependency order
        
        // 1. Persistence - No dependencies
        do {
            let swiftDataService = try SwiftDataService()
            ServiceLocator.shared.register(swiftDataService, for: PersistenceServiceProtocol.self)
        } catch {
            fatalError("Failed to create SwiftData service: \(error)")
        }
        
        // 2. Analytics - Depends on Persistence
        ServiceLocator.shared.register(AnalyticsService(), for: AnalyticsServiceProtocol.self)
        
        // 3. Audio - Depends on Persistence
        ServiceLocator.shared.register(AudioEngineService(), for: AudioServiceProtocol.self)
        
        // 4. CV - Depends on Analytics
        ServiceLocator.shared.register(CameraVisionService(), for: CVServiceProtocol.self)
        
        logger.info("[App] All services registered")
        
        #if DEBUG
        ServiceLocator.validateServices()
        #endif
    }
    
    @MainActor
    private func initializeApp() async {
        // Initialize all services properly
        do {
            try await ServiceLocator.shared.initializeServices()
        } catch {
            logger.error("[App] Failed to initialize services: \(error)")
        }
        
        // Preload common sounds after initialization
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
        if let audioService = audio as? AudioEngineService {
            audioService.preloadCommonSounds()
        }
        
        // Minimum loading time for smooth UX
        try? await Task.sleep(for: .seconds(1.5))
    }
}
