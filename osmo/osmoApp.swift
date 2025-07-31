//
//  osmoApp.swift
//  osmo
//
//  Created by Mitchell White on 7/30/25.
//

import SwiftUI

@main
struct osmoApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @State private var isLoading = true
    
    init() {
        setupServices()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    LaunchScreen()
                        .onAppear {
                            // Simulate loading
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isLoading = false
                            }
                        }
                } else {
                    ContentView()
                        .environmentObject(coordinator)
                        .environment(\.coordinator, coordinator)
                }
            }
            .preferredColorScheme(.light)
        }
    }
    
    private func setupServices() {
        // Register all services with mock implementations
        ServiceLocator.shared.register(MockCVService(), for: CVServiceProtocol.self)
        ServiceLocator.shared.register(MockAudioService(), for: AudioServiceProtocol.self)
        ServiceLocator.shared.register(MockAnalyticsService(), for: AnalyticsServiceProtocol.self)
        ServiceLocator.shared.register(MockPersistenceService(), for: PersistenceServiceProtocol.self)
        
        print("[App] All services registered")
        
        #if DEBUG
        // Validate services in debug builds
        ServiceLocator.validateServices()
        #endif
    }
}
