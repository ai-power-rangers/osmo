//
//  ParentGate.swift
//  osmo
//
//  Parent gate component to protect adult-only areas with math challenges
//

import SwiftUI

struct ParentGate: View {
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    @State private var challenge = MathChallenge.random()
    @State private var userAnswer = ""
    @State private var showingError = false
    @State private var attempts = 0
    private let maxAttempts = 3
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Parent Verification")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please solve this problem to continue")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Math problem
            Text(challenge.displayText)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .padding(.vertical, 10)
            
            // Answer input
            TextField("Answer", text: $userAnswer)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 24, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(width: 120)
            
            // Error message
            if showingError {
                Text("Incorrect. Try again.")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Buttons
            HStack(spacing: 20) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Button("Submit") {
                    checkAnswer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(userAnswer.isEmpty)
            }
            
            // Attempts remaining
            if attempts > 0 {
                Text("\(maxAttempts - attempts) attempts remaining")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(30)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
        .frame(maxWidth: 350)
    }
    
    private func checkAnswer() {
        guard let answer = Int(userAnswer) else {
            showingError = true
            return
        }
        
        if answer == challenge.answer {
            onSuccess()
        } else {
            attempts += 1
            showingError = true
            userAnswer = ""
            
            if attempts >= maxAttempts {
                // Generate new challenge after max attempts
                challenge = MathChallenge.random()
                attempts = 0
            }
            
            // Hide error after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingError = false
            }
        }
    }
}

// MARK: - Math Challenge Model
struct MathChallenge {
    let firstNumber: Int
    let secondNumber: Int
    let operation: Operation
    
    enum Operation: CaseIterable {
        case addition
        case subtraction
        case multiplication
        
        var symbol: String {
            switch self {
            case .addition: return "+"
            case .subtraction: return "-"
            case .multiplication: return "×"
            }
        }
    }
    
    var displayText: String {
        "\(firstNumber) \(operation.symbol) \(secondNumber) = ?"
    }
    
    var answer: Int {
        switch operation {
        case .addition:
            return firstNumber + secondNumber
        case .subtraction:
            return firstNumber - secondNumber
        case .multiplication:
            return firstNumber * secondNumber
        }
    }
    
    static func random() -> MathChallenge {
        let operation = Operation.allCases.randomElement()!
        
        let (first, second): (Int, Int)
        switch operation {
        case .addition:
            first = Int.random(in: 10...50)
            second = Int.random(in: 10...50)
        case .subtraction:
            // Ensure positive result
            let a = Int.random(in: 20...80)
            let b = Int.random(in: 10...min(a - 1, 40))
            first = a
            second = b
        case .multiplication:
            first = Int.random(in: 2...12)
            second = Int.random(in: 2...9)
        }
        
        return MathChallenge(
            firstNumber: first,
            secondNumber: second,
            operation: operation
        )
    }
}

// MARK: - View Extension for Easy Integration
extension View {
    func parentGate(isPresented: Binding<Bool>, onSuccess: @escaping () -> Void) -> some View {
        self.overlay(
            Group {
                if isPresented.wrappedValue {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    ParentGate(
                        onSuccess: {
                            withAnimation {
                                isPresented.wrappedValue = false
                            }
                            onSuccess()
                        },
                        onCancel: {
                            withAnimation {
                                isPresented.wrappedValue = false
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isPresented.wrappedValue)
        )
    }
}

// MARK: - Alert Style Parent Gate
struct ParentGateAlert: ViewModifier {
    @Binding var isPresented: Bool
    let onSuccess: () -> Void
    
    @State private var challenge = MathChallenge.random()
    @State private var userAnswer = ""
    @State private var showingError = false
    
    func body(content: Content) -> some View {
        content
            .alert("Parent Verification", isPresented: $isPresented) {
                TextField("Answer", text: $userAnswer)
                    .keyboardType(.numberPad)
                
                Button("Cancel", role: .cancel) {
                    userAnswer = ""
                    challenge = MathChallenge.random()
                }
                
                Button("Submit") {
                    if let answer = Int(userAnswer), answer == challenge.answer {
                        onSuccess()
                        userAnswer = ""
                        challenge = MathChallenge.random()
                    } else {
                        showingError = true
                        userAnswer = ""
                        // Generate new challenge on wrong answer
                        challenge = MathChallenge.random()
                        
                        // Re-present the alert
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isPresented = true
                        }
                    }
                }
            } message: {
                VStack {
                    Text("Please solve: \(challenge.displayText)")
                    if showingError {
                        Text("Incorrect answer. Try again.")
                            .foregroundColor(.red)
                    }
                }
            }
    }
}

extension View {
    func parentGateAlert(isPresented: Binding<Bool>, onSuccess: @escaping () -> Void) -> some View {
        self.modifier(ParentGateAlert(isPresented: isPresented, onSuccess: onSuccess))
    }
}

#Preview("Parent Gate Overlay") {
    VStack {
        Text("Protected Content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.1))
    .parentGate(isPresented: .constant(true)) {
        print("Success!")
    }
}

#Preview("Parent Gate Alert") {
    struct PreviewWrapper: View {
        @State private var showGate = false
        
        var body: some View {
            Button("Show Parent Gate") {
                showGate = true
            }
            .parentGateAlert(isPresented: $showGate) {
                print("Success!")
            }
        }
    }
    
    return PreviewWrapper()
}