//
//  CameraUnavailableView.swift
//  osmo
//
//  Created by Phase 3 Implementation
//

import SwiftUI

struct CameraUnavailableView: View {
    @Environment(\.dismiss) var dismiss
    let reason: CameraUnavailableReason
    
    enum CameraUnavailableReason {
        case noCamera
        case inUseByOtherApp
        case systemError
        
        var icon: String {
            switch self {
            case .noCamera: return "video.slash"
            case .inUseByOtherApp: return "video.badge.ellipsis"
            case .systemError: return "exclamationmark.triangle"
            }
        }
        
        var title: String {
            switch self {
            case .noCamera: return "No Camera Found"
            case .inUseByOtherApp: return "Camera In Use"
            case .systemError: return "Camera Error"
            }
        }
        
        var message: String {
            switch self {
            case .noCamera:
                return "This device doesn't have a camera that works with Osmo"
            case .inUseByOtherApp:
                return "Another app is using the camera. Please close it and try again"
            case .systemError:
                return "There was a problem accessing the camera. Please restart the app"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: reason.icon)
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text(reason.title)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(reason.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Back to Games") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
    }
}