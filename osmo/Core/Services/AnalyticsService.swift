//
//  AnalyticsService.swift
//  osmo
//
//  Created by Phase 2 Implementation
//

import Foundation
import os.log
import SwiftUI
import Observation

// MARK: - Analytics Service
@Observable
final class AnalyticsService: AnalyticsServiceProtocol, ServiceLifecycle {
    private let logger = Logger(subsystem: "com.osmoapp", category: "analytics")
    private var eventQueue: [AnalyticsEvent] = []
    private let maxQueueSize = 100
    
    // Use async approach instead of Timer
    private var flushTask: Task<Void, Never>?
    
    // Session tracking
    private var currentSession: GameSession?
    
    init() {
        startFlushTask()
        observeAppLifecycle()
    }
    
    deinit {
        flushTask?.cancel()
    }
    
    // MARK: - ServiceLifecycle
    func initialize() async throws {
        // Load any persisted session
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        if let session = await persistence.loadCurrentSession() {
            currentSession = GameSession(
                sessionId: UUID(),
                gameId: session.gameId,
                startTime: session.startTime,
                events: [],
                cvEventCount: 0,
                errorCount: 0
            )
            logger.info("[Analytics] Resumed session: \(session.gameId)")
        }
    }
    
    // MARK: - Event Logging
    func logEvent(_ event: String, parameters: [String: Any] = [:]) {
        let analyticsEvent = AnalyticsEvent(
            eventType: .customEvent(name: event),
            gameId: currentSession?.gameId ?? "app",
            parameters: parameters
        )
        
        Task {
            await addToQueue(analyticsEvent)
        }
        
        // Log to console in debug
        #if DEBUG
        logger.debug("📊 Event: \(event)")
        if !parameters.isEmpty {
            logger.debug("📊 Parameters: \(parameters)")
        }
        #endif
    }
    
    // MARK: - Game Events
    func startLevel(gameId: String, level: String) {
        // Start or update session
        if currentSession?.gameId != gameId {
            Task {
                await endCurrentSession()
            }
            currentSession = GameSession(
                sessionId: UUID(),
                gameId: gameId,
                startTime: Date(),
                events: [],
                cvEventCount: 0,
                errorCount: 0
            )
        }
        
        logEvent("level_start", parameters: [
            "game_id": gameId,
            "level": level,
            "session_id": currentSession?.sessionId.uuidString ?? "unknown"
        ])
        
        // Update persistence
        Task {
            let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
            try? await persistence.saveCurrentSession(gameId: gameId, sessionStart: Date())
        }
    }
    
    func endLevel(gameId: String, level: String, success: Bool, score: Int? = nil) {
        var params: [String: Any] = [
            "game_id": gameId,
            "level": level,
            "success": success,
            "session_id": currentSession?.sessionId.uuidString ?? "unknown"
        ]
        
        if let score = score {
            params["score"] = score
        }
        
        // Calculate level duration
        if let session = currentSession {
            let duration = Date().timeIntervalSince(session.startTime)
            params["duration_seconds"] = Int(duration)
        }
        
        logEvent("level_end", parameters: params)
        
        // Update game progress
        if success {
            Task {
                let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
                try? await persistence.saveLevel(gameId: gameId, level: level, completed: true)
                
                if let score = score {
                    try? await persistence.saveHighScore(gameId: gameId, level: level, score: score)
                }
            }
        }
    }
    
    // MARK: - Error Logging
    func logError(_ error: Error, context: String) {
        currentSession?.errorCount += 1
        
        logger.error("❌ Error in \(context): \(error.localizedDescription)")
        
        logEvent("error_occurred", parameters: [
            "error_type": String(describing: type(of: error)),
            "error_message": error.localizedDescription,
            "context": context,
            "error_count": currentSession?.errorCount ?? 0
        ])
    }
    
    // MARK: - Queue Management
    @MainActor
    private func addToQueue(_ event: AnalyticsEvent) async {
        eventQueue.append(event)
        currentSession?.events.append(event)
        
        // Save to SwiftData with error handling
        if let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self) as? SwiftDataService {
            do {
                try await persistence.saveAnalyticsEvent(event)
            } catch {
                // Ignore errors during shutdown
                print("[Analytics] Failed to persist event: \(error)")
            }
        }
        
        // Flush if queue is full
        if eventQueue.count >= maxQueueSize {
            await flushEvents()
        }
    }
    
    private func flushEvents() async {
        guard !eventQueue.isEmpty else { return }
        
        logger.info("📊 Flushing \(self.eventQueue.count) analytics events")
        
        // In a real app, send to analytics backend here
        let eventSummary = Dictionary(grouping: eventQueue) { event in
            event.eventType.description
        }.mapValues { $0.count }
        
        logger.info("📊 Event Summary: \(eventSummary)")
        
        // Clear queue
        eventQueue.removeAll()
    }
    
    // MARK: - Async Flush Task
    private func startFlushTask() {
        flushTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await flushEvents()
            }
        }
    }
    
    // MARK: - App Lifecycle
    private func observeAppLifecycle() {
        // In SwiftUI, lifecycle is handled differently
        // The app should call these methods from the App struct using @Environment(\.scenePhase)
    }
    
    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            Task {
                await flushEvents()
                await endCurrentSession()
            }
        case .inactive:
            Task {
                await flushEvents()
            }
        case .active:
            break
        @unknown default:
            break
        }
    }
    
    private func endCurrentSession() async {
        if let session = currentSession {
            session.endTime = Date()
            logEvent("session_end", parameters: [
                "session_id": session.sessionId.uuidString,
                "duration_seconds": Int((session.endTime ?? Date()).timeIntervalSince(session.startTime)),
                "event_count": session.events.count,
                "cv_event_count": session.cvEventCount,
                "error_count": session.errorCount
            ])
        }
        currentSession = nil
        
        // Clear session from persistence
        let persistence = ServiceLocator.shared.resolve(PersistenceServiceProtocol.self)
        try? await persistence.clearCurrentSession()
    }
}
