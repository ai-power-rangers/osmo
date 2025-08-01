import Foundation
import SwiftUI
import os.log

/// Manages loading and caching of Tangram puzzle blueprints
@MainActor
final class BlueprintStore: ObservableObject {
    @Published private(set) var puzzles: [Puzzle] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.osmoapp", category: "BlueprintStore")
    
    /// Load all puzzles from the Puzzles directory
    func loadAll() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        puzzles = []
        
        // Get the bundle path for puzzle files
        guard let puzzlesURL = Bundle.main.url(forResource: "Puzzles", withExtension: nil) else {
            // Try alternate path structure
            loadFromAlternatePath()
            return
        }
        
        loadPuzzlesFrom(directory: puzzlesURL)
    }
    
    private func loadFromAlternatePath() {
        // For development, look in the game module directory
        let gameModulePath = "Games/Tangram/Puzzles"
        
        do {
            // Get all JSON files in the puzzles directory
            let fileManager = FileManager.default
            
            // Try to find the puzzles in the main bundle
            if let bundlePath = Bundle.main.resourcePath {
                let puzzlesPath = (bundlePath as NSString).appendingPathComponent(gameModulePath)
                
                if fileManager.fileExists(atPath: puzzlesPath) {
                    let puzzleURL = URL(fileURLWithPath: puzzlesPath)
                    loadPuzzlesFrom(directory: puzzleURL)
                    return
                }
            }
            
            // If not found in bundle, create a default puzzle for testing
            loadDefaultPuzzles()
            
        } catch {
            self.error = error
            self.isLoading = false
            logger.error("Error loading puzzles: \(error)")
        }
    }
    
    private func loadPuzzlesFrom(directory: URL) {
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
            
            self.puzzles = loadedPuzzles.sorted { $0.name < $1.name }
            self.isLoading = false
            
        } catch {
            self.error = error
            self.isLoading = false
            logger.error("Error reading puzzles directory: \(error)")
            
            // Fallback to default puzzles
            loadDefaultPuzzles()
        }
    }
    
    /// Load default puzzles for development/testing
    private func loadDefaultPuzzles() {
        // Try to load the cat.json file directly
        if let catURL = Bundle.main.url(forResource: "cat", withExtension: "json") {
            do {
                let data = try Data(contentsOf: catURL)
                let puzzle = try decoder.decode(Puzzle.self, from: data)
                self.puzzles = [puzzle]
                self.isLoading = false
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
            self.puzzles = [puzzle]
        } catch {
            logger.error("Failed to parse embedded cat puzzle: \(error)")
            self.puzzles = []
        }
        
        self.isLoading = false
    }
    
    /// Get a specific puzzle by ID
    func puzzle(withId id: String) -> Puzzle? {
        puzzles.first { $0.id == id }
    }
}