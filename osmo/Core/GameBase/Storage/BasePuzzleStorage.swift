import Foundation

/// Base implementation of puzzle storage using FileManager
/// Provides local file-based storage with caching and error handling
public class BasePuzzleStorage: PuzzleStorageProtocol {
    
    // MARK: - Properties
    
    /// Storage configuration
    public let configuration: PuzzleStorageConfiguration
    
    /// Base directory for puzzle storage
    private let baseDirectory: URL
    
    /// In-memory cache for frequently accessed puzzles
    private var cache: [String: Any] = [:]
    
    /// Cache access tracking for LRU eviction
    private var cacheAccessTimes: [String: Date] = [:]
    
    /// File manager instance
    private let fileManager = FileManager.default
    
    /// JSON encoder for serialization
    private let encoder: JSONEncoder
    
    /// JSON decoder for deserialization
    private let decoder: JSONDecoder
    
    /// Queue for serializing storage operations
    private let storageQueue = DispatchQueue(label: "BasePuzzleStorage", qos: .utility)
    
    /// Last cleanup date
    private var lastCleanupDate: Date?
    
    // MARK: - Initialization
    
    /// Initializes storage with configuration
    /// - Parameters:
    ///   - configuration: Storage configuration options
    ///   - baseDirectory: Base directory for storage (nil for default Documents directory)
    /// - Throws: Storage errors if setup fails
    public init(
        configuration: PuzzleStorageConfiguration = PuzzleStorageConfiguration(),
        baseDirectory: URL? = nil
    ) throws {
        self.configuration = configuration
        
        // Set up base directory
        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw PuzzleStorageError.storageNotAvailable
            }
            self.baseDirectory = documentsDirectory.appendingPathComponent("OsmoPuzzles")
        }
        
        // Configure JSON coding
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Create base directory if needed
        if let directory = baseDirectory {
            try createDirectoryIfNeeded(directory)
        }
        
        // Start auto-cleanup if enabled
        if configuration.enableAutoCleanup {
            startAutoCleanup()
        }
    }
    
    // MARK: - CRUD Operations
    
    public func save<T: GamePuzzleProtocol>(_ puzzle: T) async throws {
        try await withCheckedThrowingContinuation { continuation in
            storageQueue.async {
                do {
                    let puzzleType = String(describing: T.self)
                    let directory = try self.getDirectoryForPuzzleType(puzzleType)
                    let fileURL = directory.appendingPathComponent("\(puzzle.id).json")
                    
                    // Encode puzzle
                    let data = try self.encoder.encode(puzzle)
                    
                    // Compress if enabled
                    let finalData = self.configuration.enableCompression ? 
                        try self.compress(data) : data
                    
                    // Write to file
                    try finalData.write(to: fileURL)
                    
                    // Update cache
                    self.updateCache(key: puzzle.id, value: puzzle)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: self.mapError(error))
                }
            }
        }
    }
    
    public func load<T: GamePuzzleProtocol>(id: String) async throws -> T? {
        return try await withCheckedThrowingContinuation { continuation in
            storageQueue.async {
                do {
                    // Check cache first
                    if let cached = self.getCachedPuzzle(id: id) as? T {
                        continuation.resume(returning: cached)
                        return
                    }
                    
                    let puzzleType = String(describing: T.self)
                    let directory = try self.getDirectoryForPuzzleType(puzzleType)
                    let fileURL = directory.appendingPathComponent("\(id).json")
                    
                    // Check if file exists
                    guard self.fileManager.fileExists(atPath: fileURL.path) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Read and decode
                    let data = try Data(contentsOf: fileURL)
                    let finalData = self.configuration.enableCompression ? 
                        try self.decompress(data) : data
                    
                    let puzzle = try self.decoder.decode(T.self, from: finalData)
                    
                    // Update cache
                    self.updateCache(key: id, value: puzzle)
                    
                    continuation.resume(returning: puzzle)
                } catch {
                    continuation.resume(throwing: self.mapError(error))
                }
            }
        }
    }
    
    public func loadAll<T: GamePuzzleProtocol>() async throws -> [T] {
        return try await withCheckedThrowingContinuation { continuation in
            storageQueue.async {
                do {
                    let puzzleType = String(describing: T.self)
                    let directory = try self.getDirectoryForPuzzleType(puzzleType)
                    
                    let fileURLs = try self.fileManager.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: [.contentModificationDateKey],
                        options: .skipsHiddenFiles
                    ).filter { $0.pathExtension == "json" }
                    
                    var puzzles: [T] = []
                    
                    for fileURL in fileURLs {
                        let data = try Data(contentsOf: fileURL)
                        let finalData = self.configuration.enableCompression ? 
                            try self.decompress(data) : data
                        
                        let puzzle = try self.decoder.decode(T.self, from: finalData)
                        puzzles.append(puzzle)
                        
                        // Update cache
                        self.updateCache(key: puzzle.id, value: puzzle)
                    }
                    
                    continuation.resume(returning: puzzles)
                } catch {
                    continuation.resume(throwing: self.mapError(error))
                }
            }
        }
    }
    
    public func delete(id: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            storageQueue.async {
                do {
                    // Remove from cache
                    self.cache.removeValue(forKey: id)
                    self.cacheAccessTimes.removeValue(forKey: id)
                    
                    // Find and delete file
                    let fileURL = try self.findFileForPuzzleId(id)
                    try self.fileManager.removeItem(at: fileURL)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: self.mapError(error))
                }
            }
        }
    }
    
    public func exists(id: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            storageQueue.async {
                // Check cache first
                if self.cache[id] != nil {
                    continuation.resume(returning: true)
                    return
                }
                
                // Check file system
                do {
                    let _ = try self.findFileForPuzzleId(id)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    public func saveBatch<T: GamePuzzleProtocol>(_ puzzles: [T]) async throws {
        for puzzle in puzzles {
            try await save(puzzle)
        }
    }
    
    public func deleteBatch(_ ids: [String]) async throws {
        for id in ids {
            try await delete(id: id)
        }
    }
    
    // MARK: - Query Operations
    
    public func loadPuzzles<T: GamePuzzleProtocol>(
        difficulty: PuzzleDifficulty?,
        tags: Set<String>?,
        completed: Bool?
    ) async throws -> [T] {
        let allPuzzles: [T] = try await loadAll()
        
        return allPuzzles.filter { puzzle in
            // Filter by difficulty
            if let difficulty = difficulty, puzzle.difficulty != difficulty {
                return false
            }
            
            // Filter by tags
            if let tags = tags, puzzle.tags.isDisjoint(with: tags) {
                return false
            }
            
            // Filter by completion
            if let completed = completed, puzzle.hasBeenCompleted != completed {
                return false
            }
            
            return true
        }
    }
    
    public func getPuzzleCount(
        difficulty: PuzzleDifficulty?,
        completed: Bool?
    ) async throws -> Int {
        // For simplicity, we'll load all and count
        // In a real implementation, this could be optimized
        let puzzles: [any GamePuzzleProtocol] = try await loadAllPuzzlesGeneric()
        
        return puzzles.filter { puzzle in
            if let difficulty = difficulty, puzzle.difficulty != difficulty {
                return false
            }
            
            if let completed = completed, puzzle.hasBeenCompleted != completed {
                return false
            }
            
            return true
        }.count
    }
    
    // MARK: - Metadata Operations
    
    public func getStorageInfo() async throws -> StorageInfo {
        return try await withCheckedThrowingContinuation { continuation in
            storageQueue.async {
                do {
                    let puzzles = try self.loadAllPuzzlesGeneric()
                    let totalPuzzles = puzzles.count
                    
                    // Calculate storage size
                    let storageSize = try self.calculateStorageSize()
                    
                    // Get available space
                    let availableSpace = try self.getAvailableSpace()
                    
                    // Calculate puzzle type breakdown
                    var breakdown: [String: Int] = [:]
                    for puzzle in puzzles {
                        let typeName = String(describing: type(of: puzzle))
                        breakdown[typeName, default: 0] += 1
                    }
                    
                    let info = StorageInfo(
                        totalPuzzles: totalPuzzles,
                        storageSizeBytes: storageSize,
                        lastCleanup: self.lastCleanupDate,
                        version: "1.0",
                        availableSpaceBytes: availableSpace,
                        puzzleTypeBreakdown: breakdown
                    )
                    
                    continuation.resume(returning: info)
                } catch {
                    continuation.resume(throwing: self.mapError(error))
                }
            }
        }
    }
    
    public func cleanup() async throws {
        try await withCheckedThrowingContinuation { continuation in
            storageQueue.async {
                do {
                    // Clear cache beyond max size
                    self.evictOldCacheEntries()
                    
                    // Remove any temporary or corrupted files
                    try self.cleanupCorruptedFiles()
                    
                    self.lastCleanupDate = Date()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: self.mapError(error))
                }
            }
        }
    }
    
    public func exportPuzzles<T: GamePuzzleProtocol>(_ puzzles: [T]) async throws -> Data {
        return try encoder.encode(puzzles)
    }
    
    public func importPuzzles<T: GamePuzzleProtocol>(from data: Data) async throws -> [T] {
        return try decoder.decode([T].self, from: data)
    }
    
    // MARK: - Private Helper Methods
    
    private func createDirectoryIfNeeded(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    private func getDirectoryForPuzzleType(_ puzzleType: String) throws -> URL {
        let directory = baseDirectory.appendingPathComponent(puzzleType)
        try createDirectoryIfNeeded(directory)
        return directory
    }
    
    private func findFileForPuzzleId(_ id: String) throws -> URL {
        // Search through all puzzle type directories
        let contents = try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        for subdirectory in contents {
            let fileURL = subdirectory.appendingPathComponent("\(id).json")
            if fileManager.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        
        throw PuzzleStorageError.puzzleNotFound(id)
    }
    
    // MARK: - Cache Management
    
    private func updateCache(key: String, value: Any) {
        cache[key] = value
        cacheAccessTimes[key] = Date()
        evictOldCacheEntries()
    }
    
    private func getCachedPuzzle(id: String) -> Any? {
        if let puzzle = cache[id] {
            cacheAccessTimes[id] = Date()
            return puzzle
        }
        return nil
    }
    
    private func evictOldCacheEntries() {
        guard cache.count > configuration.maxCacheSize else { return }
        
        let sortedEntries = cacheAccessTimes.sorted { $0.value < $1.value }
        let entriesToRemove = sortedEntries.prefix(cache.count - configuration.maxCacheSize)
        
        for (key, _) in entriesToRemove {
            cache.removeValue(forKey: key)
            cacheAccessTimes.removeValue(forKey: key)
        }
    }
    
    // MARK: - Compression
    
    private func compress(_ data: Data) throws -> Data {
        return try (data as NSData).compressed(using: .lzfse) as Data
    }
    
    private func decompress(_ data: Data) throws -> Data {
        return try (data as NSData).decompressed(using: .lzfse) as Data
    }
    
    // MARK: - Utility Methods
    
    private func loadAllPuzzlesGeneric() throws -> [any GamePuzzleProtocol] {
        // This is a simplified implementation
        // In a real app, you'd need to register puzzle types
        var allPuzzles: [any GamePuzzleProtocol] = []
        
        // This would need to be extended to handle all puzzle types
        // For now, we'll return empty array
        return allPuzzles
    }
    
    private func calculateStorageSize() throws -> Int {
        let enumerator = fileManager.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [],
            errorHandler: nil
        )
        
        var totalSize = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += resourceValues.fileSize ?? 0
        }
        
        return totalSize
    }
    
    private func getAvailableSpace() throws -> Int {
        let resourceValues = try baseDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return Int(resourceValues.volumeAvailableCapacity ?? 0)
    }
    
    private func cleanupCorruptedFiles() throws {
        // Implementation for cleaning up corrupted files
        // This would scan for files that can't be decoded and remove them
    }
    
    private func startAutoCleanup() {
        Timer.scheduledTimer(withTimeInterval: configuration.cleanupInterval, repeats: true) { _ in
            Task {
                try? await self.cleanup()
            }
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapError(_ error: Error) -> PuzzleStorageError {
        if let storageError = error as? PuzzleStorageError {
            return storageError
        }
        
        if error is DecodingError {
            return .invalidPuzzleData
        }
        
        let nsError = error as NSError
        switch nsError.code {
        case NSFileReadNoSuchFileError:
            return .puzzleNotFound("File not found")
        case NSFileWriteFileExistsError:
            return .insufficientSpace
        default:
            return .unknown(error)
        }
    }
}