-only do ios 17+ modern ios
-swiftui (no uikit)
-lint check: chmod +x /Users/mitchellwhite/Code/osmo/Scripts/lint.sh
-type check: chmod +x /Users/mitchellwhite/Code/osmo/Scripts/typecheck.sh
-follow repo's architecture, patterns, and conventions

⏺ Modern iOS 17+ Pattern:
  1. @Observable macro - Classes are observable by default
  2. No @Published - All stored properties are automatically observable
  3. @State for view models - Not @StateObject
  4. @Bindable - For creating bindings to observable objects
  5. @Environment - For dependency injection
  6. MainActor isolation - Proper actor isolation for UI updates