//
//  osmoApp.swift
//  osmo
//
//  Main app entry point - Refactored with proper service architecture
//

import SwiftUI
import os.log

@main
struct osmoApp: App {
    private let logger = Logger(subsystem: "com.osmoapp", category: "App")
    
    // MARK: - State
    @State private var services = ServiceContainer()
    @State private var showLaunchScreen = true
    
    // MARK: - Scene
    var body: some Scene {
        WindowGroup {
            Group {
                if showLaunchScreen {
                    LaunchScreen()
                        .transition(.opacity)
                } else {
                    RootView()
                        .serviceBoundary()
                        .injectServices(from: services)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showLaunchScreen)
            .task {
                await initializeApp()
            }
            .environment(services)
        }

    }
    
    // MARK: - Initialization
    
    private func initializeApp() async {
        logger.info("[App] Starting initialization...")
        
        // Initialize services
        await services.initialize()
        
        // Check if initialization succeeded
        if services.isInitialized {
            logger.info("[App] Services initialized successfully")
            
            // Migration removed in simplification
            
            // Wait for smooth transition
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Hide launch screen
            await MainActor.run {
                withAnimation {
                    self.showLaunchScreen = false
                }
            }
        } else if let error = services.initializationError {
            logger.error("[App] Service initialization failed: \(error)")
            // The ServiceBoundary will show the error UI
            await MainActor.run {
                self.showLaunchScreen = false
            }
        }
    }
}

// MARK: - App Environment

