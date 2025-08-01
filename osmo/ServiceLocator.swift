//
//  ServiceLocator.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation
import Observation
import os.log

// MARK: - Service Locator
@Observable
final class ServiceLocator {
    static let logger = Logger(subsystem: "com.osmoapp", category: "services")
    static let shared = ServiceLocator()
    
    private init() {}
    
    // Service storage
    private var cvService: CVServiceProtocol?
    private var audioService: AudioServiceProtocol?
    private var analyticsService: AnalyticsServiceProtocol?
    private var persistenceService: PersistenceServiceProtocol?
    
    // Track initialization state
    var isInitialized = false
    
    // MARK: - Registration
    func register<T>(_ service: T, for type: T.Type) {
        switch ObjectIdentifier(type) {
        case ObjectIdentifier(CVServiceProtocol.self):
            cvService = service as? CVServiceProtocol
        case ObjectIdentifier(AudioServiceProtocol.self):
            audioService = service as? AudioServiceProtocol
        case ObjectIdentifier(AnalyticsServiceProtocol.self):
            analyticsService = service as? AnalyticsServiceProtocol
        case ObjectIdentifier(PersistenceServiceProtocol.self):
            persistenceService = service as? PersistenceServiceProtocol
            Self.logger.info("[ServiceLocator] Registered PersistenceService")
        default:
            Self.logger.error("[ServiceLocator] Failed to register unknown service type")
            fatalError("Unknown service type: \(type)")
        }
    }
    
    // MARK: - Retrieval
    func resolve<T>(_ type: T.Type) -> T {
        switch ObjectIdentifier(type) {
        case ObjectIdentifier(CVServiceProtocol.self):
            guard let service = cvService as? T else {
                fatalError("CVService not registered")
            }
            return service
        case ObjectIdentifier(AudioServiceProtocol.self):
            guard let service = audioService as? T else {
                fatalError("AudioService not registered")
            }
            return service
        case ObjectIdentifier(AnalyticsServiceProtocol.self):
            guard let service = analyticsService as? T else {
                fatalError("AnalyticsService not registered")
            }
            return service
        case ObjectIdentifier(PersistenceServiceProtocol.self):
            guard let service = persistenceService as? T else {
                fatalError("PersistenceService not registered")
            }
            return service
        default:
            Self.logger.error("[ServiceLocator] Failed to resolve unknown service type")
            fatalError("Unknown service type: \(type)")
        }
    }
    
    // MARK: - Game Context Creation
    func createGameContext() -> GameContext {
        GameContextImpl(
            cvService: resolve(CVServiceProtocol.self),
            audioService: resolve(AudioServiceProtocol.self),
            analyticsService: resolve(AnalyticsServiceProtocol.self),
            persistenceService: resolve(PersistenceServiceProtocol.self)
        )
    }
    
    // MARK: - Initialization State
    var servicesInitialized: Bool {
        isInitialized
    }
    
    func requireInitialized() {
        guard isInitialized else {
            fatalError("Services accessed before initialization. Call ServiceLocator.shared.initializeServices() first.")
        }
    }
    
    // MARK: - Service Validation
    static func validateServices() {
        logger.info("\n=== Service Validation ===")
        
        // Test CV Service
        if let cvService = shared.cvService {
            logger.info("✅ CV Service: \(type(of: cvService))")
        } else {
            logger.error("❌ CV Service: Not registered")
        }
        
        // Test Audio Service
        if let audioService = shared.audioService {
            logger.info("✅ Audio Service: \(type(of: audioService))")
        } else {
            logger.error("❌ Audio Service: Not registered")
        }
        
        // Test Analytics Service
        if let analyticsService = shared.analyticsService {
            logger.info("✅ Analytics Service: \(type(of: analyticsService))")
        } else {
            logger.error("❌ Analytics Service: Not registered")
        }
        
        // Test Persistence Service
        if let persistenceService = shared.persistenceService {
            logger.info("✅ Persistence Service: \(type(of: persistenceService))")
        } else {
            logger.error("❌ Persistence Service: Not registered")
        }
        
        logger.info("========================\n")
    }
}

// MARK: - Game Context Implementation
private final class GameContextImpl: GameContext {
    let cvService: CVServiceProtocol
    let audioService: AudioServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let persistenceService: PersistenceServiceProtocol
    
    init(cvService: CVServiceProtocol,
         audioService: AudioServiceProtocol,
         analyticsService: AnalyticsServiceProtocol,
         persistenceService: PersistenceServiceProtocol) {
        self.cvService = cvService
        self.audioService = audioService
        self.analyticsService = analyticsService
        self.persistenceService = persistenceService
    }
}
