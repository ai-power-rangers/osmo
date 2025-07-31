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
            
            VStack(spacing: 40) {
                // App logo placeholder
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("Osmo")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Loading indicator
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.white)
                    .scaleEffect(x: 1, y: 2)
                    .frame(width: 200)
            }
        }
        .onAppear {
            // Start animation
            isAnimating = true
            
            // Simulate loading progress
            withAnimation(.linear(duration: 2)) {
                progress = 1.0
            }
        }
    }
}