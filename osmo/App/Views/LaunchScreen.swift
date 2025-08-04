//
//  LaunchScreen.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import SwiftUI

struct LaunchScreen: View {
    @State private var isAnimating = false
    @State private var progress: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.purple, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Osmo")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // Loading indicator
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.white)
                    .scaleEffect(x: 1, y: 2)
                    .frame(width: 200)
            }
        }
        .onAppear {
            isAnimating = true
            // Simulate loading
            withAnimation(.linear(duration: 2)) {
                progress = 1.0
            }
        }
    }
}
