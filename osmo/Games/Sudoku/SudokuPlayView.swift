//
//  SudokuPlayView.swift
//  osmo
//
//  Play view for Sudoku puzzles with puzzle selection
//

import SwiftUI
import SpriteKit

struct SudokuPlayView: View {
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel: SudokuViewModel?
    @State private var showingPuzzleSelector = false
    @State private var selectedNumber: Int?
    
    private let puzzle: SudokuPuzzle?
    
    init(puzzle: SudokuPuzzle? = nil) {
        self.puzzle = puzzle
    }
    
    var body: some View {
        Group {
            if let vm = viewModel {
                playContent(vm: vm)
            } else {
                ProgressView("Loading game...")
                    .onAppear {
                        viewModel = SudokuViewModel(
                            puzzle: puzzle,
                            editorMode: nil,
                            services: services
                        )
                    }
            }
        }
    }
    
    @ViewBuilder
    private func playContent(vm: SudokuViewModel) -> some View {
        ZStack {
            // Background
            AppColors.gameBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top controls
                HStack {
                    // Timer
                    Text(vm.formattedTime)
                        .font(.title2)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    // Moves counter
                    Text("Moves: \(vm.moveCount)")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Puzzle selector
                    Button(action: { showingPuzzleSelector = true }) {
                        Label("Puzzles", systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.white.opacity(0.9))
                
                // Game scene
                GeometryReader { geometry in
                    SudokuGameHost(viewModel: vm)
                }
                .aspectRatio(1, contentMode: .fit)
                .padding()
                
                // Number pad
                NumberPad(
                    selectedNumber: $selectedNumber,
                    availableNumbers: 1...9,
                    onNumberTap: { number in
                        if let cell = vm.selectedCell {
                            vm.placeNumber(number, at: cell)
                        }
                    }
                )
                .padding()
                
                // Bottom controls
                HStack(spacing: 20) {
                    Button(action: {
                        vm.undo()
                    }) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!vm.canUndo)
                    
                    Button(action: {
                        vm.redo()
                    }) {
                        Label("Redo", systemImage: "arrow.uturn.forward")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!vm.canRedo)
                    
                    Spacer()
                    
                    if vm.isComplete {
                        Text("✅ Complete!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        vm.provideHint()
                    }) {
                        Label("Hint", systemImage: "lightbulb")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle(vm.currentPuzzle?.name ?? "Sudoku")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPuzzleSelector) {
            SudokuPuzzleSelector { puzzleId, _ in
                // Load puzzle by ID
                Task {
                    if let puzzle: SudokuPuzzle = try? await SudokuStorage.shared.load(id: puzzleId) {
                        vm.loadPuzzle(puzzle)
                    }
                }
                showingPuzzleSelector = false
            }
        }
    }
}

// MARK: - Supporting Views

struct NumberPad: View {
    @Binding var selectedNumber: Int?
    let availableNumbers: ClosedRange<Int>
    let onNumberTap: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(availableNumbers, id: \.self) { number in
                Button(action: {
                    selectedNumber = number
                    onNumberTap(number)
                }) {
                    Text("\(number)")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(
                            selectedNumber == number ? Color.blue : Color.gray.opacity(0.2)
                        )
                        .foregroundColor(selectedNumber == number ? .white : .primary)
                        .cornerRadius(8)
                }
            }
            
            // Clear button
            Button(action: {
                selectedNumber = nil
                // Clear selected cell logic would go here
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(8)
            }
        }
    }
}

// SudokuGameHost is defined in SudokuEditor.swift