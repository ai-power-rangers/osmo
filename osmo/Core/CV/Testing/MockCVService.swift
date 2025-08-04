//
//  MockCVService.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation
import CoreGraphics
import Observation
import os.log

// MARK: - Mock CV Service
@Observable
final class MockCVService: CVServiceProtocol, ServiceLifecycle {
    private let logger = Logger(subsystem: "com.osmoapp", category: "cv")
    var isSessionActive = false
    var debugMode = false
    
    private var eventContinuations: [String: AsyncStream<CVEvent>.Continuation] = [:]
    private var eventTimer: Timer?
    
    // MARK: - ServiceLifecycle
    func initialize() async throws {
        logger.info("[MockCV] Service initialized")
        // Mock service has no dependencies to initialize
    }
    
    func cleanup() async {
        stopSession()
    }
    
    // MARK: - Session Management
    func startSession() async throws {
        guard !isSessionActive else { return }
        isSessionActive = true
        startMockEventGeneration()
        logger.info("[MockCV] Session started")
    }
    
    func stopSession() {
        isSessionActive = false
        eventTimer?.invalidate()
        eventTimer = nil
        
        // End all streams
        eventContinuations.values.forEach { $0.finish() }
        eventContinuations.removeAll()
        
        logger.info("[MockCV] Session stopped")
    }
    
    // MARK: - Event Stream
    func eventStream(gameId: String, events: [CVEventType]) -> AsyncStream<CVEvent> {
        AsyncStream { continuation in
            eventContinuations[gameId] = continuation
            logger.info("[MockCV] Game \(gameId) subscribed to event stream")
            
            continuation.onTermination = { [weak self] _ in
                self?.eventContinuations.removeValue(forKey: gameId)
                self?.logger.info("[MockCV] Game \(gameId) stream terminated")
            }
        }
    }
    
    func eventStream(gameId: String, events: [CVEventType], configuration: [String: Any]) -> AsyncStream<CVEvent> {
        // Mock service ignores configuration
        return eventStream(gameId: gameId, events: events)
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
        
        // Send to all active continuations
        eventContinuations.values.forEach { continuation in
            continuation.yield(event)
        }
        
        if debugMode {
            logger.debug("[MockCV] Generated event: \(fingerCount) fingers detected")
        }
    }
}
