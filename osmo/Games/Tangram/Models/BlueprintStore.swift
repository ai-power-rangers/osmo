import Foundation
import SwiftUI
import os.log

/// Manages loading and caching of Tangram puzzle blueprints
/// Uses modern @Observable pattern (iOS 17+)
@MainActor
@Observable
final class BlueprintStore {
    private(set) var puzzles: [Puzzle] = []
    private(set) var builtInPuzzles: [Puzzle] = []
    private(set) var customPuzzles: [Puzzle] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.osmoapp", category: "BlueprintStore")
    
    /// Load all puzzles from the Puzzles directory
    func loadAll() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        puzzles = []
        builtInPuzzles = []
        customPuzzles = []
        
        // Load built-in puzzles
        loadBuiltInPuzzles()
        
        // Load custom puzzles
        loadCustomPuzzles()
        
        // Combine all puzzles
        puzzles = builtInPuzzles + customPuzzles
        isLoading = false
    }
    
    private func loadBuiltInPuzzles() {
        print("[BlueprintStore] Loading built-in puzzles...")
        
        // Get the bundle path for puzzle files
        guard let puzzlesURL = Bundle.main.url(forResource: "Puzzles", withExtension: nil) else {
            print("[BlueprintStore] Puzzles resource not found, trying alternate path")
            // Try alternate path structure
            loadBuiltInFromAlternatePath()
            return
        }
        
        builtInPuzzles = loadPuzzlesFrom(directory: puzzlesURL)
        print("[BlueprintStore] Loaded \(builtInPuzzles.count) built-in puzzles")
    }
    
    private func loadCustomPuzzles() {
        // Load from custom puzzles directory
        let fileManager = FileManager.default
        let projectPath = fileManager.currentDirectoryPath
        let customPuzzlesURL = URL(fileURLWithPath: projectPath)
            .appendingPathComponent("osmo")
            .appendingPathComponent("Games")
            .appendingPathComponent("Tangram")
            .appendingPathComponent("Puzzles")
            .appendingPathComponent("Custom")
        
        if fileManager.fileExists(atPath: customPuzzlesURL.path) {
            customPuzzles = loadPuzzlesFrom(directory: customPuzzlesURL)
                .filter { puzzle in
                    // Filter out editor save files (with UUIDs)
                    !puzzle.id.contains("-")
                }
        }
    }
    
    private func loadBuiltInFromAlternatePath() {
        print("[BlueprintStore] Loading from alternate path...")
        
        // For now, hardcode the cat puzzle since we know it exists
        let catPuzzle = Puzzle(
            id: "cat",
            name: "Cat",
            imageName: "cat_icon",
            pieces: [
                PieceDefinition(pieceId: "square", targetPosition: SIMD2(3.2, 5.5), targetRotation: 0.785398, isMirrored: false),
                PieceDefinition(pieceId: "smallTriangle1", targetPosition: SIMD2(2.8, 6.5), targetRotation: 2.356194, isMirrored: false),
                PieceDefinition(pieceId: "smallTriangle2", targetPosition: SIMD2(3.6, 6.5), targetRotation: 0.785398, isMirrored: false),
                PieceDefinition(pieceId: "largeTriangle1", targetPosition: SIMD2(3.2, 3.5), targetRotation: 3.926991, isMirrored: false),
                PieceDefinition(pieceId: "mediumTriangle", targetPosition: SIMD2(2.0, 3.5), targetRotation: 4.712389, isMirrored: false),
                PieceDefinition(pieceId: "largeTriangle2", targetPosition: SIMD2(4.4, 2.5), targetRotation: 1.570796, isMirrored: false),
                PieceDefinition(pieceId: "parallelogram", targetPosition: SIMD2(5.8, 2.5), targetRotation: 0.000000, isMirrored: true)
            ],
            difficulty: "easy"
        )
        
        builtInPuzzles = [catPuzzle]
        print("[BlueprintStore] Loaded hardcoded cat puzzle")
    }
    
    private func loadPuzzlesFrom(directory: URL) -> [Puzzle] {
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: directory, 
                                                               includingPropertiesForKeys: nil)
            
            let jsonFiles = contents.filter { $0.pathExtension == "json" }
            
            var loadedPuzzles: [Puzzle] = []
            
            for fileURL in jsonFiles {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let puzzle = try decoder.decode(Puzzle.self, from: data)
                    loadedPuzzles.append(puzzle)
                    logger.info("Loaded puzzle: \(puzzle.name)")
                } catch {
                    logger.error("Failed to load puzzle from \(fileURL.lastPathComponent): \(error)")
                }
            }
            
            return loadedPuzzles.sorted { $0.name < $1.name }
            
        } catch {
            logger.error("Error reading puzzles directory: \(error)")
            return []
        }
    }
    
    /// Load default puzzles for development/testing
    private func loadDefaultPuzzles() {
        // Try to load the cat.json file directly
        if let catURL = Bundle.main.url(forResource: "cat", withExtension: "json") {
            do {
                let data = try Data(contentsOf: catURL)
                let puzzle = try decoder.decode(Puzzle.self, from: data)
                self.builtInPuzzles = [puzzle]
                return
            } catch {
                logger.error("Failed to load cat.json: \(error)")
            }
        }
        
        // Final fallback - create cat puzzle from embedded data
        let catPuzzleJSON = """
        {
          "id": "cat",
          "name": "Cat",
          "imageName": "cat_icon",
          "difficulty": "easy",
          "pieces": [
            {
              "pieceId": "square",
              "targetPosition": { "x": 3.2, "y": 5.5 },
              "targetRotation": 0.785398,
              "isMirrored": false
            },
            {
              "pieceId": "smallTriangle1",
              "targetPosition": { "x": 2.8, "y": 6.5 },
              "targetRotation": 2.356194,
              "isMirrored": false
            },
            {
              "pieceId": "smallTriangle2",
              "targetPosition": { "x": 3.6, "y": 6.5 },
              "targetRotation": 0.785398,
              "isMirrored": false
            },
            {
              "pieceId": "largeTriangle1",
              "targetPosition": { "x": 3.2, "y": 3.5 },
              "targetRotation": 3.926991,
              "isMirrored": false
            },
            {
              "pieceId": "mediumTriangle",
              "targetPosition": { "x": 2.0, "y": 3.5 },
              "targetRotation": 4.712389,
              "isMirrored": false
            },
            {
              "pieceId": "largeTriangle2",
              "targetPosition": { "x": 4.4, "y": 2.5 },
              "targetRotation": 1.570796,
              "isMirrored": false
            },
            {
              "pieceId": "parallelogram",
              "targetPosition": { "x": 5.8, "y": 2.5 },
              "targetRotation": 0.000000,
              "isMirrored": true
            }
          ]
        }
        """
        
        do {
            let data = catPuzzleJSON.data(using: .utf8)!
            let puzzle = try decoder.decode(Puzzle.self, from: data)
            self.builtInPuzzles = [puzzle]
        } catch {
            logger.error("Failed to parse embedded cat puzzle: \(error)")
            self.builtInPuzzles = []
        }
    }
    
    /// Get a specific puzzle by ID
    func puzzle(withId id: String) -> Puzzle? {
        puzzles.first { $0.id == id }
    }
}