import Foundation
import CoreGraphics

/// Represents a named corner on a shape
public struct Corner: Codable, Identifiable {
    public let id: String              // Semantic name: "right-angle", "acute-1", etc.
    public let vertexIndex: Int        // Index into vertices array
    public let angle: Double           // Interior angle at this corner (degrees)
    
    public init(id: String, vertexIndex: Int, angle: Double) {
        self.id = id
        self.vertexIndex = vertexIndex
        self.angle = angle
    }
}

/// Represents a named edge on a shape
public struct Edge: Codable, Identifiable {
    public let id: String              // Semantic name: "hypotenuse", "base", etc.
    public let startCornerId: String   // Defines edge direction
    public let endCornerId: String     // start → end is positive direction
    public let length: Double          // In unit space
    
    public init(id: String, startCornerId: String, endCornerId: String, length: Double) {
        self.id = id
        self.startCornerId = startCornerId
        self.endCornerId = endCornerId
        self.length = length
    }
}

/// Canonical shape definition with semantic features
public struct ShapeGeometry: Codable, Identifiable {
    public let id: String = UUID().uuidString
    public let shapeId: String              // Type identifier (e.g., "largeTriangle")
    public let vertices: [CGPoint]          // In unit space, origin at bottom-left
    public let corners: [Corner]            // Named corners with canonical order
    public let edges: [Edge]                // Named edges between corners
    public let centerOfMass: CGPoint        // For rotation calculations
    
    public init(shapeId: String, vertices: [CGPoint], corners: [Corner], edges: [Edge], centerOfMass: CGPoint) {
        self.shapeId = shapeId
        self.vertices = vertices
        self.corners = corners
        self.edges = edges
        self.centerOfMass = centerOfMass
    }
    
    /// Get corner by ID
    public func corner(withId id: String) -> Corner? {
        corners.first { $0.id == id }
    }
    
    /// Get edge by ID
    public func edge(withId id: String) -> Edge? {
        edges.first { $0.id == id }
    }
    
    /// Get vertex position for a corner
    public func vertex(for corner: Corner) -> CGPoint? {
        guard corner.vertexIndex < vertices.count else { return nil }
        return vertices[corner.vertexIndex]
    }
    
    /// Apply rotation and optional mirroring to vertices
    public func transformedVertices(rotationIndex: Int, mirrored: Bool) -> [CGPoint] {
        let angleStep = Double.pi / 4  // 45 degrees
        let rotation = Double(rotationIndex) * angleStep
        
        return vertices.map { vertex in
            var transformed = vertex
            
            // Apply mirroring first (about Y axis)
            if mirrored {
                transformed.x = -transformed.x
            }
            
            // Then apply rotation
            let cosTheta = CGFloat(cos(rotation))
            let sinTheta = CGFloat(sin(rotation))
            
            let x = transformed.x * cosTheta - transformed.y * sinTheta
            let y = transformed.x * sinTheta + transformed.y * cosTheta
            
            return CGPoint(x: x, y: y)
        }
    }
}

/// Mapping for mirrored shapes
public struct ChiralityMapping: Codable {
    public let shapeId: String
    public let cornerMapping: [String: String]  // original → mirrored corner IDs
    public let edgeMapping: [String: String]    // original → mirrored edge IDs
    
    public init(shapeId: String, cornerMapping: [String: String], edgeMapping: [String: String]) {
        self.shapeId = shapeId
        self.cornerMapping = cornerMapping
        self.edgeMapping = edgeMapping
    }
}

/// Shape library protocol for game-specific shapes
public protocol ShapeLibraryProtocol {
    /// Get all available shapes
    func allShapes() -> [String: ShapeGeometry]
    
    /// Get shape by ID
    func shape(for shapeId: String) -> ShapeGeometry?
    
    /// Get chirality mapping for a shape (if it can be mirrored)
    func chiralityMapping(for shapeId: String) -> ChiralityMapping?
}