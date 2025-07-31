import Foundation
import CoreGraphics

// MARK: - Mock CV Service
final class MockCVService: CVServiceProtocol {
    var isSessionActive = false
    var debugMode = false
    
    private var subscriptions: [UUID: CVSubscription] = [:]
    private var eventTimer: Timer?
    
    // MARK: - Session Management
    func startSession() async throws {
        guard !isSessionActive else { return }
        isSessionActive = true
        startMockEventGeneration()
        print("[MockCV] Session started")
    }
    
    func stopSession() {
        isSessionActive = false
        eventTimer?.invalidate()
        eventTimer = nil
        print("[MockCV] Session stopped")
    }
    
    // MARK: - Subscriptions
    func subscribe(gameId: String,
                  events: [CVEventType],
                  handler: @escaping (CVEvent) -> Void) -> CVSubscription {
        let subscription = CVSubscription(
            gameId: gameId,
            eventTypes: events,
            handler: handler
        )
        subscriptions[subscription.id] = subscription
        print("[MockCV] Game \(gameId) subscribed to \(events.count) event types")
        return subscription
    }
    
    func unsubscribe(_ subscription: CVSubscription) {
        subscriptions.removeValue(forKey: subscription.id)
        print("[MockCV] Subscription removed for game \(subscription.gameId)")
    }
    
    // MARK: - Mock Event Generation
    private func startMockEventGeneration() {
        eventTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.generateMockEvent()
        }
    }
    
    private func generateMockEvent() {
        // Generate random finger count for testing
        let fingerCount = Int.random(in: 1...5)
        let event = CVEvent(
            type: .fingerCountDetected(count: fingerCount),
            position: CGPoint(x: 0.5, y: 0.5),
            confidence: 0.95
        )
        
        // Notify relevant subscribers
        DispatchQueue.main.async { [weak self] in
            self?.subscriptions.values.forEach { subscription in
                // Check if this subscription wants this type of event
                let wantsFingerEvents = subscription.eventTypes.contains { eventType in
                    if case .fingerCountDetected = eventType {
                        return true
                    }
                    return false
                }
                
                if wantsFingerEvents {
                    subscription.handle(event)
                }
            }
        }
        
        if debugMode {
            print("[MockCV] Generated event: \(fingerCount) fingers detected")
        }
    }
}