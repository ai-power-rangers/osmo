//
//  ServiceContainer.swift
//  osmo
//
//  Proper service container with dependency injection
//

import Foundation
import SwiftUI
import os.log

/// Service initialization errors
enum ServiceError: LocalizedError {
    case initializationFailed(String)
    case dependencyMissing(String)
    case alreadyInitialized
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let service):
            return "Failed to initialize \(service) service"
        case .dependencyMissing(let dependency):
            return "Required dependency \(dependency) is missing"
        case .alreadyInitialized:
            return "Services have already been initialized"
        }
    }
}

/// Main service container that manages all app services
/// Uses modern @Observable pattern (iOS 17+)
@MainActor
@Observable
public final class ServiceContainer: GameContext {
    private static let logger = Logger(subsystem: "com.osmoapp", category: "ServiceContainer")
    
    // MARK: - Observable State
    private(set) var isInitialized = false
    private(set) var initializationError: Error?
    private(set) var initializationProgress: Double = 0
    
    // MARK: - Services (Non-optional, guaranteed after initialization)
    private var _persistence: PersistenceServiceProtocol?
    private var _analytics: AnalyticsServiceProtocol?
    private var _audio: AudioServiceProtocol?
    private var _cv: CVServiceProtocol?
    
    public var persistenceService: PersistenceServiceProtocol {
        guard let service = _persistence else {
            fatalError("ServiceContainer not initialized. Call initialize() first.")
        }
        return service
    }
    
    public var analyticsService: AnalyticsServiceProtocol {
        guard let service = _analytics else {
            fatalError("ServiceContainer not initialized. Call initialize() first.")
        }
        return service
    }
    
    public var audioService: AudioServiceProtocol {
        guard let service = _audio else {
            fatalError("ServiceContainer not initialized. Call initialize() first.")
        }
        return service
    }
    
    public var cvService: CVServiceProtocol {
        guard let service = _cv else {
            fatalError("ServiceContainer not initialized. Call initialize() first.")
        }
        return service
    }
    
    private var _storage: PuzzleStorageProtocol?
    
    public var storageService: PuzzleStorageProtocol {
        guard let service = _storage else {
            fatalError("ServiceContainer not initialized. Call initialize() first.")
        }
        return service
    }
    private(set) var gridEditor: GridEditorServiceProtocol?
    
    // MARK: - Initialization
    
    /// Initialize all services in dependency order
    func initialize() async {
        guard !isInitialized else {
            Self.logger.warning("Attempted to initialize services twice")
            initializationError = ServiceError.alreadyInitialized
            return
        }
        
        Self.logger.info("Starting service initialization...")
        
        do {
            // 1. Persistence Service (no dependencies)
            updateProgress(0.1, "Initializing persistence...")
            self._persistence = try await initializePersistence()
            
            // 2. Analytics Service (depends on persistence)
            updateProgress(0.3, "Initializing analytics...")
            self._analytics = await initializeAnalytics(persistence: persistenceService)
            
            // 3. Audio Service (depends on persistence)
            updateProgress(0.5, "Initializing audio...")
            self._audio = await initializeAudio(persistence: persistenceService)
            
            // 4. CV Service (depends on analytics)
            updateProgress(0.7, "Initializing computer vision...")
            self._cv = await initializeCV(analytics: analyticsService)
            
            // 5. Storage Service (no dependencies)
            updateProgress(0.85, "Initializing storage...")
            self._storage = SimplePuzzleStorage()
            
            // 6. Grid Editor Service (depends on persistence and analytics)
            updateProgress(0.9, "Initializing grid editor...")
            let gridEditorService = await initializeGridEditor(
                persistence: persistenceService,
                analytics: analyticsService
            )
            self.gridEditor = gridEditorService
            
            // Mark as initialized
            updateProgress(1.0, "Services ready")
            self.isInitialized = true
            
            Self.logger.info("All services initialized successfully")
            
        } catch {
            Self.logger.error("Service initialization failed: \(error)")
            self.initializationError = error
            self.isInitialized = false
        }
    }
    
    /// Cleanup all services
    func cleanup() async {
        Self.logger.info("Cleaning up services...")
        
        // Cleanup in reverse dependency order
        if let cv = _cv as? ServiceLifecycle {
            await cv.cleanup()
        }
        
        if let audio = _audio as? ServiceLifecycle {
            await audio.cleanup()
        }
        
        if let analytics = _analytics as? ServiceLifecycle {
            await analytics.cleanup()
        }
        
        if let persistence = _persistence as? ServiceLifecycle {
            await persistence.cleanup()
        }
        
        // Reset services
        self._cv = nil
        self._audio = nil
        self._analytics = nil
        self._persistence = nil
        self.gridEditor = nil
        self.isInitialized = false
        self.initializationProgress = 0
        
        Self.logger.info("Service cleanup complete")
    }
    
    // MARK: - Private Initialization Methods
    
    private func initializePersistence() async throws -> PersistenceServiceProtocol {
        let service = try SwiftDataService()
        
        if let lifecycle = service as? ServiceLifecycle {
            try await lifecycle.initialize()
        }
        
        return service
    }
    
    private func initializeAnalytics(persistence: PersistenceServiceProtocol) async -> AnalyticsServiceProtocol {
        let service = AnalyticsService()
        
        if let lifecycle = service as? ServiceLifecycle {
            try? await lifecycle.initialize()
        }
        
        // Inject persistence service
        service.setPersistenceService(persistence)
        
        return service
    }
    
    private func initializeAudio(persistence: PersistenceServiceProtocol) async -> AudioServiceProtocol {
        let service = AudioEngineService()
        
        if let lifecycle = service as? ServiceLifecycle {
            try? await lifecycle.initialize()
        }
        
        // Inject persistence service
        service.setPersistenceService(persistence)
        
        return service
    }
    
    private func initializeCV(analytics: AnalyticsServiceProtocol) async -> CVServiceProtocol {
        // Determine which CV service to use based on device capabilities
        let service: CVServiceProtocol
        
        // For now, always use CameraVisionService
        // In the future, this could check for ARKit support and choose appropriately
        service = CameraVisionService()
        
        if let lifecycle = service as? ServiceLifecycle {
            try? await lifecycle.initialize()
        }
        
        // Inject analytics service
        if let cameraService = service as? CameraVisionService {
            cameraService.setAnalyticsService(analytics)
        } else if let arKitService = service as? ARKitCVService {
            arKitService.setAnalyticsService(analytics)
        }
        
        return service
    }
    
    private func initializeGridEditor(persistence: PersistenceServiceProtocol,
                                     analytics: AnalyticsServiceProtocol) async -> GridEditorServiceProtocol {
        return GridEditorService(
            persistenceService: persistence,
            analyticsService: analytics
        )
    }
    
    private func updateProgress(_ progress: Double, _ message: String) {
        self.initializationProgress = progress
        Self.logger.debug("[\(String(format: "%.0f%%", progress * 100))] \(message)")
    }
}

// MARK: - Service Access Extensions
// Service properties are now defined directly in the main class to conform to GameContext protocol