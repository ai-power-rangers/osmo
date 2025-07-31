//
//  ServiceLocator.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation

// MARK: - Service Locator
final class ServiceLocator {
    static let shared = ServiceLocator()
    
    private init() {}
    
    // Service storage
    private var cvService: CVServiceProtocol?
    private var audioService: AudioServiceProtocol?
    private var analyticsService: AnalyticsServiceProtocol?
    private var persistenceService: PersistenceServiceProtocol?
    
    // MARK: - Registration
    func register<T>(_ service: T, for type: T.Type) {
        switch type {
        case is CVServiceProtocol.Type:
            cvService = service as? CVServiceProtocol
        case is AudioServiceProtocol.Type:
            audioService = service as? AudioServiceProtocol
        case is AnalyticsServiceProtocol.Type:
            analyticsService = service as? AnalyticsServiceProtocol
        case is PersistenceServiceProtocol.Type:
            persistenceService = service as? PersistenceServiceProtocol
        default:
            fatalError("Unknown service type: \(type)")
        }
    }
    
    // MARK: - Retrieval
    func resolve<T>(_ type: T.Type) -> T {
        switch type {
        case is CVServiceProtocol.Type:
            guard let service = cvService as? T else {
                fatalError("CVService not registered")
            }
            return service
        case is AudioServiceProtocol.Type:
            guard let service = audioService as? T else {
                fatalError("AudioService not registered")
            }
            return service
        case is AnalyticsServiceProtocol.Type:
            guard let service = analyticsService as? T else {
                fatalError("AnalyticsService not registered")
            }
            return service
        case is PersistenceServiceProtocol.Type:
            guard let service = persistenceService as? T else {
                fatalError("PersistenceService not registered")
            }
            return service
        default:
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
    
    // MARK: - Service Validation
    static func validateServices() {
        print("\n=== Service Validation ===")
        
        // Test CV Service
        do {
            let cvService = shared.resolve(CVServiceProtocol.self)
            print("✅ CV Service: \(type(of: cvService))")
        } catch {
            print("❌ CV Service: Not registered")
        }
        
        // Test Audio Service
        do {
            let audioService = shared.resolve(AudioServiceProtocol.self)
            print("✅ Audio Service: \(type(of: audioService))")
        } catch {
            print("❌ Audio Service: Not registered")
        }
        
        // Test Analytics Service
        do {
            let analyticsService = shared.resolve(AnalyticsServiceProtocol.self)
            print("✅ Analytics Service: \(type(of: analyticsService))")
        } catch {
            print("❌ Analytics Service: Not registered")
        }
        
        // Test Persistence Service
        do {
            let persistenceService = shared.resolve(PersistenceServiceProtocol.self)
            print("✅ Persistence Service: \(type(of: persistenceService))")
        } catch {
            print("❌ Persistence Service: Not registered")
        }
        
        print("========================\n")
    }
}

// MARK: - Game Context Implementation
private struct GameContextImpl: GameContext {
    let cvService: CVServiceProtocol
    let audioService: AudioServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let persistenceService: PersistenceServiceProtocol
}