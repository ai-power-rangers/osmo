//
//  ServiceLifecycle.swift
//  osmo
//
//  Service Lifecycle Management
//

import Foundation

// MARK: - Service Lifecycle Protocol
/// Services that need post-registration initialization should conform to this
protocol ServiceLifecycle {
    /// Called after all services are registered
    /// This is where services can safely access other services
    func initialize() async throws
}

// MARK: - Service Initialization Manager
extension ServiceLocator {
    /// Initialize all services that conform to ServiceLifecycle
    /// Call this AFTER all services are registered
    func initializeServices() async throws {
        Self.logger.info("[ServiceLocator] Initializing services...")
        
        // Initialize services in dependency order
        // Persistence has no dependencies, so it's safe to initialize first
        if let persistence = resolve(PersistenceServiceProtocol.self) as? ServiceLifecycle {
            Self.logger.info("[ServiceLocator] Initializing Persistence service")
            try await persistence.initialize()
        }
        
        // Analytics depends on Persistence
        if let analytics = resolve(AnalyticsServiceProtocol.self) as? ServiceLifecycle {
            Self.logger.info("[ServiceLocator] Initializing Analytics service")
            try await analytics.initialize()
        }
        
        // Audio depends on Persistence
        if let audio = resolve(AudioServiceProtocol.self) as? ServiceLifecycle {
            Self.logger.info("[ServiceLocator] Initializing Audio service")
            try await audio.initialize()
        }
        
        // CV depends on Analytics
        if let cv = resolve(CVServiceProtocol.self) as? ServiceLifecycle {
            Self.logger.info("[ServiceLocator] Initializing CV service")
            try await cv.initialize()
        }
        
        Self.logger.info("[ServiceLocator] All services initialized")
        
        // Mark as initialized
        isInitialized = true
    }
}