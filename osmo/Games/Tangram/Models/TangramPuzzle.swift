//
//  TangramPuzzle.swift
//  osmo
//
//  Tangram puzzle data model
//

import Foundation
import CoreGraphics
import UIKit

public struct TangramPuzzle: Codable, Identifiable {
    public let id: String
    public var name: String
    public var pieces: [TangramPiece]
    public var solution: TangramSolution
    public var difficulty: Difficulty
    public var createdAt: Date
    public var thumbnailData: Data?
    
    public enum Difficulty: String, Codable, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        case expert = "Expert"
    }
    
    public static let empty = TangramPuzzle(
        id: UUID().uuidString,
        name: "New Puzzle",
        pieces: TangramPiece.defaultSet,
        solution: TangramSolution(),
        difficulty: .medium,
        createdAt: Date()
    )
    
    public static let `default` = TangramPuzzle(
        id: "default",
        name: "Square",
        pieces: TangramPiece.defaultSet,
        solution: TangramSolution.square,
        difficulty: .easy,
        createdAt: Date()
    )
}

public struct TangramPiece: Codable, Identifiable {
    public let id: String
    public var shape: Shape
    public var position: CGPoint
    public var rotation: Double
    public var color: CodableColor
    public var isFlipped: Bool = false
    
    public enum Shape: String, Codable, CaseIterable {
        case largeTriangle
        case mediumTriangle
        case smallTriangle
        case square
        case parallelogram
    }
    
    public init(shape: Shape, position: CGPoint = .zero, rotation: Double = 0, color: UIColor = .systemBlue) {
        self.id = UUID().uuidString
        self.shape = shape
        self.position = position
        self.rotation = rotation
        self.color = CodableColor(uiColor: color)
    }
    
    public static let defaultSet: [TangramPiece] = [
        TangramPiece(shape: .largeTriangle, color: .systemRed),
        TangramPiece(shape: .largeTriangle, color: .systemBlue),
        TangramPiece(shape: .mediumTriangle, color: .systemGreen),
        TangramPiece(shape: .smallTriangle, color: .systemYellow),
        TangramPiece(shape: .smallTriangle, color: .systemPurple),
        TangramPiece(shape: .square, color: .systemOrange),
        TangramPiece(shape: .parallelogram, color: .systemPink)
    ]
}

public struct TangramSolution: Codable {
    public var targetPositions: [TargetPosition]
    
    public struct TargetPosition: Codable {
        public let pieceId: String
        public let position: CGPoint
        public let rotation: Double
        public let isFlipped: Bool
    }
    
    public init(targetPositions: [TargetPosition] = []) {
        self.targetPositions = targetPositions
    }
    
    public static let square = TangramSolution(targetPositions: [
        // Define positions for square shape
    ])
}

// MARK: - Codable Color

public struct CodableColor: Codable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat
    
    public init(uiColor: UIColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }
    
    public var uiColor: UIColor {
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}