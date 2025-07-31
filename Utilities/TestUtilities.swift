import Foundation

// MARK: - Service Test Utilities
extension ServiceLocator {
    /// Validates all services are properly registered
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