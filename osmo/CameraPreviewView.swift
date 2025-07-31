//
//  CameraPreviewView.swift
//  osmo
//
//  Camera preview with AVCaptureVideoPreviewLayer for CV visualization
//

import SwiftUI
import AVFoundation

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.session = session
    }
}

// MARK: - UIView wrapper for preview layer
class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    var session: AVCaptureSession? {
        didSet {
            setupPreviewLayer()
        }
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    private func setupPreviewLayer() {
        guard let session = session else {
            previewLayer?.removeFromSuperlayer()
            previewLayer = nil
            return
        }
        
        // Get the preview layer
        guard let layer = layer as? AVCaptureVideoPreviewLayer else { return }
        
        layer.session = session
        layer.videoGravity = .resizeAspectFill
        
        // Store reference
        previewLayer = layer
        
        // Set initial orientation
        updateOrientation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateOrientation()
    }
    
    private func updateOrientation() {
        guard let connection = previewLayer?.connection else { return }
        
        // Use rotation angle for iOS 17+
        if #available(iOS 17.0, *) {
            // For front camera in portrait, we need 90 degrees rotation
            // This is because the camera sensor is landscape by default
            connection.videoRotationAngle = 90
        }
    }
}