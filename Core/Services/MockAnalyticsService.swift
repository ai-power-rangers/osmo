import Foundation

// MARK: - Mock Analytics Service
final class MockAnalyticsService: AnalyticsServiceProtocol {
    private var eventQueue: [AnalyticsEvent] = []
    
    func logEvent(_ event: String, parameters: [String: Any]) {
        print("[MockAnalytics] Event: \(event)")
        if !parameters.isEmpty {
            print("[MockAnalytics] Parameters: \(parameters)")
        }
    }
    
    func startLevel(gameId: String, level: String) {
        logEvent("level_start", parameters: [
            "game_id": gameId,
            "level": level,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func endLevel(gameId: String, level: String, success: Bool, score: Int?) {
        var params: [String: Any] = [
            "game_id": gameId,
            "level": level,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let score = score {
            params["score"] = score
        }
        logEvent("level_end", parameters: params)
    }
    
    func logError(_ error: Error, context: String) {
        print("[MockAnalytics] ERROR in \(context): \(error.localizedDescription)")
    }
}