//
//  UIConstants.swift
//  osmo
//
//  Centralized UI constants for consistent design across the app
//

import SwiftUI

// MARK: - Spacing System

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    
    // Navigation specific
    static let navigationPadding: CGFloat = 16
    static let navigationContentHeight: CGFloat = 44
}

// MARK: - Typography

enum Typography {
    // Navigation
    static let navigationTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let navigationButton = Font.system(size: 17, weight: .regular)
    
    // Games
    static let gameTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let gameScore = Font.system(size: 24, weight: .semibold, design: .rounded)
    
    // Content
    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let title = Font.system(size: 28, weight: .bold)
    static let title2 = Font.system(size: 22, weight: .bold)
    static let title3 = Font.system(size: 20, weight: .semibold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let callout = Font.system(size: 16, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .regular)
    static let footnote = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let caption2 = Font.system(size: 11, weight: .regular)
}

// MARK: - Colors

enum AppColors {
    // Navigation
    static let navigationBackground = Color(.systemBackground)
    static let navigationMaterial = Material.ultraThinMaterial
    static let navigationTint = Color.blue
    static let navigationTitle = Color.primary
    
    // Games
    static let gameBackground = Color(.systemGray6)
    static let gamePrimary = Color.blue
    static let gameSecondary = Color.purple
    
    // Semantic colors
    static let destructive = Color.red
    static let success = Color.green
    static let warning = Color.orange
    static let info = Color.blue
    
    // UI Elements
    static let cardBackground = Color(.systemBackground)
    static let cardShadow = Color.black.opacity(0.1)
    static let divider = Color(.separator)
    static let disabled = Color(.systemGray3)
}

// MARK: - Animations

enum Animations {
    static let standard = Animation.easeInOut(duration: 0.3)
    static let quick = Animation.easeInOut(duration: 0.2)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let smooth = Animation.easeInOut(duration: 0.4)
}

// MARK: - Corner Radius

enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 20
    static let round: CGFloat = 100
}

// MARK: - Shadow

enum Shadow {
    static let small = (radius: CGFloat(2), y: CGFloat(1))
    static let medium = (radius: CGFloat(5), y: CGFloat(3))
    static let large = (radius: CGFloat(10), y: CGFloat(5))
    static let extraLarge = (radius: CGFloat(20), y: CGFloat(10))
}

// MARK: - Layout

enum Layout {
    static let maxContentWidth: CGFloat = 600
    static let minButtonHeight: CGFloat = 44
    static let gridSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 16
}