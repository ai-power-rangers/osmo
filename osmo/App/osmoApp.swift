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
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showLaunchScreen)
            .task {
                await initializeApp()
            }
        }
    }
    
    // MARK: - Initialization
    
    private func initializeApp() async {
        logger.info("[App] Starting initialization...")
        
        // Initialize GameKit services
        await GameKit.configure()
        
        logger.info("[App] Services initialized successfully")
        
        // Wait for smooth transition
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Hide launch screen
        await MainActor.run {
            withAnimation {
                self.showLaunchScreen = false
            }
        }
    }
}

// MARK: - App Environment

