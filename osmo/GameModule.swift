//
//  GameModule.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation
import SpriteKit

// MARK: - Game Context Protocol
protocol GameContext: AnyObject {
    var cvService: CVServiceProtocol { get }
    var audioService: AudioServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var persistenceService: PersistenceServiceProtocol { get }
}

// MARK: - Game Module Protocol
protocol GameModule: AnyObject {
    static var gameId: String { get }
    static var gameInfo: GameInfo { get }
    
    init()
    func createGameScene(size: CGSize, context: GameContext) -> SKScene
    func cleanup()
}

// MARK: - Game Scene Protocol (Optional helper)
protocol GameSceneProtocol: SKScene {
    var gameContext: GameContext? { get set }
    func handleCVEvent(_ event: CVEvent)
    func pauseGame()
    func resumeGame()
}
