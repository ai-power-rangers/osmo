//
//  SimpleAnalyticsService.swift
//  osmo
//
//  Simplified analytics for GameKit
//

import Foundation

public final class SimpleAnalyticsService {
    private var events: [AnalyticsEvent] = []
    private let queue = DispatchQueue(label: "analytics.queue")
    
    public init() {}
    
    public func logEvent(_ name: String, parameters: [String: Any] = [:]) {
        queue.async { [weak self] in
            let event = AnalyticsEvent(
                name: name,
                parameters: parameters,
                timestamp: Date()
            )
            
            self?.events.append(event)
            
            #if DEBUG
            print("[Analytics] \(name): \(parameters)")
            #endif
        }
    }
    
    public func clearEvents() {
        queue.async { [weak self] in
            self?.events.removeAll()
        }
    }
    
    struct AnalyticsEvent {
        let name: String
        let parameters: [String: Any]
        let timestamp: Date
    }
}