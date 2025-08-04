import Foundation

/// Protocol defining the interface for puzzle storage operations
/// Provides consistent storage behavior across all puzzle types
public protocol PuzzleStorageProtocol {
    
    // MARK: - CRUD Operations
    
    /// Saves a puzzle to storage
    /// - Parameter puzzle: The puzzle to save
    /// - Throws: Storage errors if save fails
    func save<T: GamePuzzleProtocol>(_ puzzle: T) async throws
    
    /// Loads a puzzle by ID
    /// - Parameter id: The unique identifier of the puzzle
    /// - Returns: The puzzle if found, nil otherwise
    /// - Throws: Storage errors if load fails
    func load<T: GamePuzzleProtocol>(id: String) async throws -> T?
    
    /// Loads all puzzles of a specific type
    /// - Returns: Array of all puzzles of the specified type
    /// - Throws: Storage errors if load fails
    func loadAll<T: GamePuzzleProtocol>() async throws -> [T]
    
    /// Deletes a puzzle by ID
    /// - Parameter id: The unique identifier of the puzzle to delete
    /// - Throws: Storage errors if delete fails
    func delete(id: String) async throws
    
    /// Checks if a puzzle exists
    /// - Parameter id: The unique identifier to check
    /// - Returns: True if the puzzle exists, false otherwise
    func exists(id: String) async -> Bool
    
    // MARK: - Batch Operations
    
    /// Saves multiple puzzles in a batch operation
    /// - Parameter puzzles: Array of puzzles to save
    /// - Throws: Storage errors if any save fails
    func saveBatch<T: GamePuzzleProtocol>(_ puzzles: [T]) async throws
    
    /// Deletes multiple puzzles in a batch operation
    /// - Parameter ids: Array of puzzle IDs to delete
    /// - Throws: Storage errors if any delete fails
    func deleteBatch(_ ids: [String]) async throws
    
    // MARK: - Query Operations
    
    /// Loads puzzles matching specific criteria
    /// - Parameters:
    ///   - difficulty: Optional difficulty filter
    ///   - tags: Optional tags filter (puzzles must contain at least one tag)
    ///   - completed: Optional completion status filter
    /// - Returns: Array of matching puzzles
    /// - Throws: Storage errors if query fails
    func loadPuzzles<T: GamePuzzleProtocol>(
        difficulty: PuzzleDifficulty?,
        tags: Set<String>?,
        completed: Bool?
    ) async throws -> [T]
    
    /// Gets the count of puzzles matching criteria
    /// - Parameters:
    ///   - difficulty: Optional difficulty filter
    ///   - completed: Optional completion status filter
    /// - Returns: Number of matching puzzles
    /// - Throws: Storage errors if query fails
    func getPuzzleCount(
        difficulty: PuzzleDifficulty?,
        completed: Bool?
    ) async throws -> Int
    
    // MARK: - Metadata Operations
    
    /// Gets storage information and statistics
    /// - Returns: Storage metadata
    /// - Throws: Storage errors if metadata cannot be retrieved
    func getStorageInfo() async throws -> StorageInfo
    
    /// Performs cleanup operations (remove orphaned files, etc.)
    /// - Throws: Storage errors if cleanup fails
    func cleanup() async throws
    
    /// Exports puzzles to external format
    /// - Parameter puzzles: Puzzles to export
    /// - Returns: Exported data
    /// - Throws: Storage errors if export fails
    func exportPuzzles<T: GamePuzzleProtocol>(_ puzzles: [T]) async throws -> Data
    
    /// Imports puzzles from external format
    /// - Parameter data: Data to import
    /// - Returns: Imported puzzles
    /// - Throws: Storage errors if import fails
    func importPuzzles<T: GamePuzzleProtocol>(from data: Data) async throws -> [T]
}

// MARK: - Storage Info

/// Information about the storage system
public struct StorageInfo: Codable {
    /// Total number of puzzles stored
    public let totalPuzzles: Int
    
    /// Storage size in bytes
    public let storageSizeBytes: Int
    
    /// Last cleanup date
    public let lastCleanup: Date?
    
    /// Storage format version
    public let version: String
    
    /// Available storage space in bytes
    public let availableSpaceBytes: Int?
    
    /// Breakdown by puzzle type
    public let puzzleTypeBreakdown: [String: Int]
    
    public init(
        totalPuzzles: Int,
        storageSizeBytes: Int,
        lastCleanup: Date? = nil,
        version: String,
        availableSpaceBytes: Int? = nil,
        puzzleTypeBreakdown: [String: Int] = [:]
    ) {
        self.totalPuzzles = totalPuzzles
        self.storageSizeBytes = storageSizeBytes
        self.lastCleanup = lastCleanup
        self.version = version
        self.availableSpaceBytes = availableSpaceBytes
        self.puzzleTypeBreakdown = puzzleTypeBreakdown
    }
}

// MARK: - Storage Errors

/// Errors that can occur during storage operations
public enum PuzzleStorageError: Error, LocalizedError {
    case puzzleNotFound(String)
    case invalidPuzzleData
    case storageNotAvailable
    case insufficientSpace
    case corruptedData(String)
    case unsupportedVersion(String)
    case networkError(Error)
    case permissionDenied
    case quotaExceeded
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .puzzleNotFound(let id):
            return "Puzzle with ID '\(id)' not found"
        case .invalidPuzzleData:
            return "Invalid puzzle data format"
        case .storageNotAvailable:
            return "Storage system is not available"
        case .insufficientSpace:
            return "Insufficient storage space"
        case .corruptedData(let details):
            return "Corrupted data detected: \(details)"
        case .unsupportedVersion(let version):
            return "Unsupported storage version: \(version)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied for storage operation"
        case .quotaExceeded:
            return "Storage quota exceeded"
        case .unknown(let error):
            return "Unknown storage error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Storage Configuration

/// Configuration options for puzzle storage
public struct PuzzleStorageConfiguration {
    /// Maximum number of puzzles to keep in memory cache
    public let maxCacheSize: Int
    
    /// Enable automatic cleanup of old temporary files
    public let enableAutoCleanup: Bool
    
    /// Cleanup interval in seconds
    public let cleanupInterval: TimeInterval
    
    /// Enable compression for stored puzzles
    public let enableCompression: Bool
    
    /// Enable encryption for stored puzzles
    public let enableEncryption: Bool
    
    /// Backup configuration
    public let backupConfiguration: BackupConfiguration?
    
    public init(
        maxCacheSize: Int = 100,
        enableAutoCleanup: Bool = true,
        cleanupInterval: TimeInterval = 86400, // 24 hours
        enableCompression: Bool = true,
        enableEncryption: Bool = false,
        backupConfiguration: BackupConfiguration? = nil
    ) {
        self.maxCacheSize = maxCacheSize
        self.enableAutoCleanup = enableAutoCleanup
        self.cleanupInterval = cleanupInterval
        self.enableCompression = enableCompression
        self.enableEncryption = enableEncryption
        self.backupConfiguration = backupConfiguration
    }
}

/// Configuration for backup operations
public struct BackupConfiguration {
    /// Enable automatic backups
    public let enabled: Bool
    
    /// Backup interval in seconds
    public let interval: TimeInterval
    
    /// Maximum number of backups to keep
    public let maxBackups: Int
    
    /// Backup location (nil for default)
    public let backupLocation: URL?
    
    public init(
        enabled: Bool = false,
        interval: TimeInterval = 604800, // 1 week
        maxBackups: Int = 5,
        backupLocation: URL? = nil
    ) {
        self.enabled = enabled
        self.interval = interval
        self.maxBackups = maxBackups
        self.backupLocation = backupLocation
    }
}