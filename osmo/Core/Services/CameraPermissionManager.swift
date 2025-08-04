//
//  CameraPermissionManager.swift
//  osmo
//
//  Created by Phase 3 Implementation
//

import Foundation
import AVFoundation
import Observation

// MARK: - Camera Permission Status
enum CameraPermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
    
    var needsRequest: Bool {
        return self == .notDetermined
    }
    
    var canUseCamera: Bool {
        return self == .authorized
    }
}

// MARK: - Camera Permission Manager
@Observable
final class CameraPermissionManager {
    static let shared = CameraPermissionManager()
    
    private(set) var status: CameraPermissionStatus = .notDetermined
    
    // Service dependencies
    private weak var analyticsService: AnalyticsServiceProtocol?
    
    private init() {
        checkCurrentStatus()
    }
    
    func setAnalyticsService(_ service: AnalyticsServiceProtocol) {
        self.analyticsService = service
    }
    
    // MARK: - Status Check
    func checkCurrentStatus() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        status = mapAuthorizationStatus(authStatus)
    }
    
    private func mapAuthorizationStatus(_ status: AVAuthorizationStatus) -> CameraPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
    
    // MARK: - Permission Request
    func requestPermission() async -> CameraPermissionStatus {
        // Check current status first
        checkCurrentStatus()
        
        guard status.needsRequest else {
            return status
        }
        
        // Request permission
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        
        // Update status
        await MainActor.run {
            self.status = granted ? .authorized : .denied
        }
        
        // Log analytics
        analyticsService?.logEvent("camera_permission_result", parameters: [
            "granted": granted
        ])
        
        return status
    }
    
    // MARK: - Settings Navigation
    func openSettings() {
        // Pure SwiftUI approach - we'll handle URL opening in the view layer
        // This avoids UIKit dependency
        analyticsService?.logEvent("camera_settings_requested", parameters: [:])
    }
}