import SwiftUI
import SpriteKit

// MARK: - TangramGridEditor

/// Grid editor implementation for Tangram puzzles using the new architecture
@MainActor
public final class TangramGridEditor: ObservableObject, GridEditor {
    public let gameType: GameType = .tangram
    
    @Published public var arrangementName: String = "New Puzzle"
    @Published public var selectedPieceId: String?
    @Published public var showValidationErrors: Bool = false
    
    // Core services from new architecture
    private let poseSource: TouchPoseSource
    private let anchorManager: DefaultAnchorManager
    private let validator: BasicConstraintValidator
    private let shapeLibrary: TangramShapeLibrary
    private let adapter: TangramEditorAdapter
    private let configuration: TangramGridConfiguration
    
    // Current arrangement
    private var arrangement: GridArrangement
    
    public var currentArrangement: GridArrangement {
        // Update arrangement with current poses
        let (_, relPoses) = anchorManager.anchorRelativePoses(from: poseSource.currentPoses())
        
        // Convert poses to placed elements
        var elements: [PlacedElement] = []
        for (pieceId, pose) in relPoses {
            if let pieceData = pieceDataMap[pieceId] {
                elements.append(PlacedElement(
                    elementId: pieceId,
                    elementType: pieceData.shape.rawValue,
                    rotationIndex: rotationIndexFromAngle(pose.theta),
                    mirrored: pieceData.isMirrored,
                    position: CGPoint(x: pose.x, y: pose.y)
                ))
            }
        }
        
        return GridArrangement(
            id: arrangement.id,
            gameType: arrangement.gameType,
            name: arrangementName,
            elements: elements,
            constraints: arrangement.constraints,
            metadata: arrangement.metadata,
            createdAt: arrangement.createdAt,
            updatedAt: Date()
        )
    }
    
    public var isValid: Bool {
        validate().filter { $0.severity == .error }.isEmpty
    }
    
    // Track piece data
    private var pieceDataMap: [String: TangramEditorPieceData] = [:]
    
    public init() {
        // Initialize configuration
        self.configuration = TangramGridConfiguration()
        
        // Initialize services
        self.poseSource = TouchPoseSource(screenSize: UIScreen.main.bounds.size)
        self.anchorManager = DefaultAnchorManager()
        self.shapeLibrary = TangramShapeLibrary()
        self.validator = BasicConstraintValidator(shapeLibrary: shapeLibrary, tolerances: configuration.defaultMetadata.tolerances)
        self.adapter = TangramEditorAdapter()
        
        // Create initial arrangement
        self.arrangement = GridArrangement(
            gameType: gameType,
            name: "New Puzzle",
            elements: [],
            constraints: [],
            metadata: configuration.defaultMetadata
        )
    }
    
    public func createEditorView() -> AnyView {
        AnyView(TangramGridEditorView(editor: self))
    }
    
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Validate using constraint validator
        let (_, relPoses) = anchorManager.anchorRelativePoses(from: poseSource.currentPoses())
        let validationResult = validator.validate(
            arrangement: currentArrangement,
            relPoses: relPoses
        )
        
        // Convert validation violations to errors
        if !validationResult.violatedConstraints.isEmpty {
            errors.append(ValidationError(
                elementId: nil,
                message: "Constraint violations detected: \(validationResult.violatedConstraints.count) constraints failed",
                severity: .error
            ))
        }
        
        // Add overlap errors
        for overlap in validationResult.overlaps {
            errors.append(ValidationError(
                elementId: overlap.0,
                message: "Pieces overlap: \(overlap.0) and \(overlap.1)",
                severity: .error
            ))
        }
        
        // Check if all piece types are used
        let usedTypes = Set(pieceDataMap.values.map { $0.shape })
        let allTypes = Set(TangramShape.allCases)
        let missingTypes = allTypes.subtracting(usedTypes)
        
        if !missingTypes.isEmpty {
            let typeNames = missingTypes.map { $0.rawValue }.joined(separator: ", ")
            errors.append(ValidationError(
                elementId: nil,
                message: "Missing pieces: \(typeNames)",
                severity: .warning
            ))
        }
        
        return errors
    }
    
    // MARK: - Editor Operations
    
    public func addPiece(_ shape: TangramShape, at position: CGPoint) {
        let pieceId = UUID().uuidString
        let unitPosition = poseSource.coordinateSystem.toUnit(position)
        
        // Create piece data
        let pieceData = TangramEditorPieceData(
            pieceId: pieceId,
            shape: shape,
            position: unitPosition,
            rotationIndex: 0,
            isMirrored: false
        )
        
        // Store piece data
        pieceDataMap[pieceId] = pieceData
        
        // Update pose source
        poseSource.setPose(
            for: pieceId,
            pose: SE2Pose(x: Double(unitPosition.x), y: Double(unitPosition.y), theta: 0)
        )
        
        // Select the new piece
        selectedPieceId = pieceId
        objectWillChange.send()
    }
    
    public func removePiece(_ pieceId: String) {
        pieceDataMap.removeValue(forKey: pieceId)
        poseSource.removePiece(pieceId)
        
        if selectedPieceId == pieceId {
            selectedPieceId = nil
        }
        objectWillChange.send()
    }
    
    public func updatePiecePosition(_ pieceId: String, to position: CGPoint) {
        guard pieceDataMap[pieceId] != nil else { return }
        
        let unitPosition = poseSource.coordinateSystem.toUnit(position)
        let snappedPosition = snapToGrid(unitPosition)
        
        // Update pose
        let currentPose = poseSource.currentPoses()[pieceId] ?? SE2Pose(x: 0, y: 0, theta: 0)
        poseSource.setPose(
            for: pieceId,
            pose: SE2Pose(x: Double(snappedPosition.x), y: Double(snappedPosition.y), theta: currentPose.theta)
        )
        
        objectWillChange.send()
    }
    
    public func rotatePiece(_ pieceId: String) {
        guard let currentData = pieceDataMap[pieceId] else { return }
        
        // Create updated piece data with new rotation
        let newRotationIndex = (currentData.rotationIndex + 1) % configuration.rotationStep
        let updatedData = TangramEditorPieceData(
            pieceId: pieceId,
            shape: currentData.shape,
            position: currentData.position,
            rotationIndex: newRotationIndex,
            isMirrored: currentData.isMirrored
        )
        pieceDataMap[pieceId] = updatedData
        
        // Update pose
        let angle = angleFromRotationIndex(updatedData.rotationIndex)
        let currentPose = poseSource.currentPoses()[pieceId] ?? SE2Pose(x: 0, y: 0, theta: 0)
        poseSource.setPose(
            for: pieceId,
            pose: SE2Pose(x: currentPose.x, y: currentPose.y, theta: angle)
        )
        
        objectWillChange.send()
    }
    
    public func mirrorPiece(_ pieceId: String) {
        guard let currentData = pieceDataMap[pieceId],
              currentData.shape == .parallelogram else { return }
        
        // Create updated piece data with toggled mirror state
        let updatedData = TangramEditorPieceData(
            pieceId: pieceId,
            shape: currentData.shape,
            position: currentData.position,
            rotationIndex: currentData.rotationIndex,
            isMirrored: !currentData.isMirrored
        )
        pieceDataMap[pieceId] = updatedData
        
        objectWillChange.send()
    }
    
    public func clearAll() {
        pieceDataMap.removeAll()
        poseSource.reset()
        selectedPieceId = nil
        objectWillChange.send()
    }
    
    public func snapToGrid(_ position: CGPoint) -> CGPoint {
        let snappedX = round(position.x * 4) / 4  // Snap to 0.25 units
        let snappedY = round(position.y * 4) / 4
        return CGPoint(x: snappedX, y: snappedY)
    }
    
    // MARK: - Helper Methods
    
    private func rotationIndexFromAngle(_ angle: Double) -> Int {
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 2 * .pi)
        let index = Int(round(normalizedAngle / (.pi / 4))) % 8
        return index < 0 ? index + 8 : index
    }
    
    private func angleFromRotationIndex(_ index: Int) -> Double {
        return Double(index) * .pi / 4
    }
    
    // MARK: - Public Accessors
    
    public func getPieceData(_ pieceId: String) -> TangramEditorPieceData? {
        return pieceDataMap[pieceId]
    }
    
    public func getAllPieces() -> [(id: String, data: TangramEditorPieceData)] {
        return pieceDataMap.map { ($0.key, $0.value) }
    }
    
    public func getScreenPosition(for pieceId: String) -> CGPoint? {
        return poseSource.screenPosition(for: pieceId)
    }
}