#!/bin/bash

# Pattern Enforcement Script for osmo
# Add this as a Build Phase in Xcode to enforce iOS 17+ patterns

set -e

echo "🔍 Checking iOS 17+ Pattern Compliance..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Function to check for pattern violations
check_pattern() {
    local pattern=$1
    local message=$2
    local severity=$3
    local exclude_pattern=$4
    
    if [ -n "$exclude_pattern" ]; then
        results=$(grep -r "$pattern" --include="*.swift" osmo 2>/dev/null | grep -v "$exclude_pattern" || true)
    else
        results=$(grep -r "$pattern" --include="*.swift" osmo 2>/dev/null || true)
    fi
    
    if [ -n "$results" ]; then
        if [ "$severity" = "error" ]; then
            echo -e "${RED}❌ ERROR: $message${NC}"
            echo "$results" | head -5
            ((ERRORS++))
        else
            echo -e "${YELLOW}⚠️  WARNING: $message${NC}"
            echo "$results" | head -3
            ((WARNINGS++))
        fi
        echo ""
    fi
}

# Check for ObservableObject usage
check_pattern "ObservableObject" \
    "ObservableObject found. Use @Observable instead (iOS 17+)" \
    "error" \
    "documentation\|.md"

# Check for @Published
check_pattern "@Published" \
    "@Published found. Use @Observable class instead" \
    "error" \
    "documentation\|.md"

# Check for @StateObject
check_pattern "@StateObject" \
    "@StateObject found. Use @State with @Observable" \
    "error" \
    "documentation\|.md"

# Check for @ObservedObject
check_pattern "@ObservedObject" \
    "@ObservedObject found. Use @State or direct passing" \
    "error" \
    "documentation\|.md"

# Check for @EnvironmentObject
check_pattern "@EnvironmentObject" \
    "@EnvironmentObject found. Use @Environment" \
    "error" \
    "documentation\|.md"

# Check for UIKit usage (excluding allowed files)
check_pattern "import UIKit" \
    "UIKit import found. Use SwiftUI instead" \
    "error" \
    "CameraPreviewView\|CameraVisionService"

# Check for UIColor usage
check_pattern "UIColor\." \
    "UIColor usage found. Use Color or SKColor" \
    "error" \
    "CameraPreviewView"

# Check for UIScreen usage
check_pattern "UIScreen\." \
    "UIScreen usage found. Use GeometryReader" \
    "error"

# Check for NavigationView
check_pattern "NavigationView" \
    "NavigationView found. Use NavigationStack" \
    "error" \
    "documentation\|.md"

# Check for Combine in @Observable classes
check_pattern "@Observable.*\n.*import Combine" \
    "Combine imported in @Observable class" \
    "warning"

# Check for $ publishers with viewModel
check_pattern "viewModel\.\$" \
    "@Observable doesn't create publishers. Use direct access" \
    "error"

# Check for .sink in scenes
check_pattern "Scene.*\n.*\.sink" \
    "Combine sink in SKScene. Use delegates instead" \
    "warning"

# Summary
echo "═══════════════════════════════════════"
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ Pattern Check Failed${NC}"
    echo -e "${RED}   $ERRORS error(s) found${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}   $WARNINGS warning(s) found${NC}"
    fi
    echo ""
    echo "Fix these issues to maintain iOS 17+ patterns."
    echo "See .docs/ios-patterns.md for guidelines."
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Pattern Check Passed with Warnings${NC}"
    echo -e "${YELLOW}   $WARNINGS warning(s) found${NC}"
    echo ""
    echo "Consider addressing warnings for better compliance."
    exit 0
else
    echo -e "${GREEN}✅ Pattern Check Passed${NC}"
    echo "   All iOS 17+ patterns correctly followed!"
    exit 0
fi