#!/bin/bash
# Refactor Verification Script
# Run this to check if the refactor plan has been fully implemented

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "=== Osmo Refactor Verification Script ==="
echo "========================================="
echo ""

TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0

# Function to check and report
check() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if eval "$1" 2>/dev/null; then
        echo -e "${GREEN}✅${NC} $2"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌${NC} $2"
        return 1
    fi
}

# Function for warnings
warn_check() {
    if eval "$1" 2>/dev/null; then
        echo -e "${YELLOW}⚠️${NC}  $2"
        WARNINGS=$((WARNINGS + 1))
        return 1
    else
        return 0
    fi
}

echo "📁 Phase 1: Foundation Layer"
echo "----------------------------"
check "test -f osmo/Core/GameBase/Scenes/BaseGameScene.swift" "BaseGameScene exists"
check "test -f osmo/Core/GameBase/ViewModels/BaseGameViewModel.swift" "BaseGameViewModel exists"
check "test -f osmo/Core/GameBase/Models/GamePuzzleProtocol.swift" "GamePuzzleProtocol exists"
check "test -f osmo/Core/GameBase/Storage/PuzzleStorageProtocol.swift" "PuzzleStorageProtocol exists"
check "test -f osmo/Core/GameBase/Storage/BasePuzzleStorage.swift" "BasePuzzleStorage exists"
check "test -f osmo/Core/GameBase/Views/PuzzleCardView.swift" "PuzzleCardView exists"
check "grep -q 'weak var gameContext' osmo/Core/GameBase/Scenes/BaseGameScene.swift" "BaseGameScene has gameContext"
check "grep -q '@Observable' osmo/Core/GameBase/ViewModels/BaseGameViewModel.swift" "BaseGameViewModel is @Observable"
echo ""

echo "🎮 Phase 2: Game Standardization"
echo "--------------------------------"
check "grep -q 'BaseGameScene' osmo/Games/Tangram/TangramScene.swift" "TangramScene inherits BaseGameScene"
check "grep -q 'BaseGameScene' osmo/Games/Sudoku/SudokuScene.swift" "SudokuScene inherits BaseGameScene"
check "grep -q 'BaseGameViewModel' osmo/Games/Tangram/TangramViewModel.swift" "TangramViewModel inherits BaseGameViewModel"
check "grep -q 'BaseGameViewModel' osmo/Games/Sudoku/SudokuViewModel.swift" "SudokuViewModel inherits BaseGameViewModel"
check "! grep -q 'struct SudokuPuzzleCard' osmo/Games/Sudoku/" "No duplicate SudokuPuzzleCard"
echo ""

echo "🧭 Phase 3: Navigation Standardization"
echo "--------------------------------------"
check "! test -f osmo/Core/Navigation/NavigationCoordinator.swift" "NavigationCoordinator removed"
check "! test -f osmo/Core/Protocols/CoordinatorProtocol.swift" "CoordinatorProtocol removed"
check "test -f osmo/Core/Navigation/AppRoute.swift" "AppRoute exists"
check "grep -q 'NavigationStack' osmo/App/Views/RootView.swift" "RootView uses NavigationStack"
check "grep -q 'navigationDestination' osmo/App/Views/RootView.swift" "RootView uses navigationDestination"
check "! grep -q 'coordinator?' osmo/Games/" "No coordinator usage in games"
echo ""

echo "💉 Phase 4: Service Integration"
echo "-------------------------------"
check "grep -q 'storageService: PuzzleStorageProtocol' osmo/Core/Protocols/GameModule.swift" "GameContext has storageService"
warn_check "grep -q '.shared' osmo/Games/Sudoku/" "⚠️ Sudoku still uses singleton pattern"
warn_check "grep -q '.shared' osmo/Games/Tangram/" "⚠️ Tangram still uses singleton pattern"
echo ""

echo "🧹 Phase 5: Clean Up & Validation"
echo "---------------------------------"
check "! find osmo -name '*.swift' -empty | grep -q '.'" "No empty Swift files"
check "test -f .docs/refactor.md" "Refactor plan documented"
echo ""

echo "========================================="
echo "📊 Verification Summary"
echo "========================================="
echo -e "Total Checks: ${TOTAL_CHECKS}"
echo -e "Passed: ${GREEN}${PASSED_CHECKS}${NC}"
echo -e "Failed: ${RED}$((TOTAL_CHECKS - PASSED_CHECKS))${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"
echo ""

# Calculate percentage
PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

if [ $PERCENTAGE -eq 100 ]; then
    echo -e "${GREEN}✨ PERFECT! Refactor fully implemented!${NC}"
elif [ $PERCENTAGE -ge 90 ]; then
    echo -e "${GREEN}✅ Excellent! Refactor mostly complete (${PERCENTAGE}%)${NC}"
elif [ $PERCENTAGE -ge 70 ]; then
    echo -e "${YELLOW}⚠️ Good progress! Refactor ${PERCENTAGE}% complete${NC}"
else
    echo -e "${RED}❌ Needs work! Only ${PERCENTAGE}% complete${NC}"
fi

echo ""
echo "========================================="
echo "🔍 Remaining Technical Debt"
echo "========================================="

if [ $WARNINGS -gt 0 ] || [ $PASSED_CHECKS -ne $TOTAL_CHECKS ]; then
    echo "Issues to address:"
    echo ""
fi

# Check for specific technical debt
if grep -q '.shared' osmo/Games/Sudoku/ 2>/dev/null; then
    echo "1. Sudoku still uses singleton pattern (.shared)"
    echo "   Files affected:"
    grep -l '.shared' osmo/Games/Sudoku/*.swift osmo/Games/Sudoku/**/*.swift 2>/dev/null | sed 's/^/   - /'
    echo ""
fi

if grep -q '.shared' osmo/Games/Tangram/ 2>/dev/null; then
    echo "2. Tangram still uses singleton pattern (.shared)"
    echo "   Files affected:"
    grep -l '.shared' osmo/Games/Tangram/*.swift osmo/Games/Tangram/**/*.swift 2>/dev/null | sed 's/^/   - /'
    echo ""
fi

if ! grep -q 'storageService: PuzzleStorageProtocol' osmo/Core/Protocols/GameModule.swift 2>/dev/null; then
    echo "3. GameContext missing storageService property"
    echo ""
fi

# Check for any coordinator references
COORD_COUNT=$(grep -r "coordinator\|NavigationCoordinator" osmo/ --include="*.swift" 2>/dev/null | wc -l)
if [ $COORD_COUNT -gt 0 ]; then
    echo "4. Found $COORD_COUNT references to old coordinator pattern"
    echo ""
fi

echo "========================================="
echo "📝 Recommendations"
echo "========================================="

if [ $WARNINGS -gt 0 ]; then
    echo "• Replace singleton patterns with dependency injection"
    echo "• Pass storage service through GameContext"
    echo "• Update ViewModels to receive storage via init"
fi

if [ $PASSED_CHECKS -ne $TOTAL_CHECKS ]; then
    echo "• Complete missing foundation components"
    echo "• Ensure all games inherit from base classes"
    echo "• Remove all coordinator references"
fi

echo ""
echo "Run './Scripts/verify-refactor.sh' to check progress"