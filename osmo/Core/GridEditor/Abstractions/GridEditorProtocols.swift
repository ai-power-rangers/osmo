import Foundation
import SwiftUI

/// Configuration for a grid editor
public protocol GridConfiguration {
    var gridStep: Double { get }           // Grid snapping resolution
    var canvasSize: CGSize { get }         // Canvas dimensions in units
    var rotationStep: Int { get }          // Number of discrete rotations (e.g., 8 for 45°)
    var defaultMetadata: ArrangementMetadata { get }
}

/// Protocol for grid editor instances
@MainActor
public protocol GridEditor: AnyObject {
    var gameType: GameType { get }
    var currentArrangement: GridArrangement { get }
    var isValid: Bool { get }
    
    func createEditorView() -> AnyView
    func validate() -> [ValidationError]
}

/// Validation error for editor feedback
public struct ValidationError: Identifiable {
    public let id = UUID()
    public let elementId: String?
    public let message: String
    public let severity: Severity
    
    public enum Severity {
        case warning
        case error
    }
    
    public init(elementId: String? = nil, message: String, severity: Severity) {
        self.elementId = elementId
        self.message = message
        self.severity = severity
    }
}

/// Protocol for grid editor service
@MainActor
public protocol GridEditorServiceProtocol: AnyObject {
    func createEditor(for gameType: GameType, configuration: GridConfiguration) -> GridEditor
    func saveArrangement(_ arrangement: GridArrangement) async throws
    func loadArrangements(for gameType: GameType) async -> [GridArrangement]
    func deleteArrangement(_ arrangementId: String) async throws
}

/// Protocol for game-specific editor adapters
public protocol GridEditorAdapter {
    associatedtype ElementType
    associatedtype ConfigType: GridConfiguration
    
    /// Convert game element to grid element
    func toGridElement(_ element: ElementType) -> PlacedElement
    
    /// Convert grid element to game element
    func fromGridElement(_ element: PlacedElement) -> ElementType?
    
    /// Provide game-specific shape library
    func shapeLibrary() -> ShapeLibraryProtocol
    
    /// Game-specific validation rules
    func additionalValidators() -> [ConstraintValidatorProtocol]
    
    /// UI customization hooks
    func customizePalette(_ palette: ComponentPaletteView)
    func customizeInspector(_ inspector: PropertyInspectorView)
}

/// Placeholder views for UI components (to be implemented)
public struct ComponentPaletteView: View {
    public var body: some View {
        Text("Component Palette")
    }
}

public struct PropertyInspectorView: View {
    public var body: some View {
        Text("Property Inspector")
    }
}