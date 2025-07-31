# Data Model & Flow Architecture

## Overview

This document defines the data models and data flows for both the overall game platform architecture and the 100-day learning curriculum system.

## Core Platform Data Model

### 1. Game Registry & Metadata

```swift
// Game registration and discovery
struct GameInfo {
    let gameId: String              // Unique identifier
    let displayName: String         // User-facing name
    let description: String         // Short description
    let iconName: String           // Asset name for icon
    let minAge: Int                // Minimum age requirement
    let maxAge: Int                // Maximum age recommendation
    let requiredCVEvents: [CVEventType]  // CV events this game needs
    let category: GameCategory     // educational, creative, etc.
    let isLocked: Bool            // For future IAP
    let bundleSize: Int           // Size in MB
}

enum GameCategory {
    case literacy
    case math
    case creativity
    case spatialReasoning
    case problemSolving
}
```

### 2. Computer Vision Data Model

```swift
// CV Event System
struct CVEvent {
    let id: UUID
    let type: CVEventType
    let position: CGPoint         // Normalized 0-1
    let confidence: Float         // 0-1 confidence score
    let timestamp: TimeInterval
    let frameNumber: Int
    let metadata: CVMetadata?
}

enum CVEventType {
    case objectDetected(type: String, objectId: UUID)
    case objectMoved(type: String, objectId: UUID, from: CGPoint, to: CGPoint)
    case objectRemoved(type: String, objectId: UUID)
    case gestureRecognized(type: GestureType)
    case shapeDetected(shape: ShapeType, vertices: [CGPoint])
}

struct CVMetadata {
    let boundingBox: CGRect?
    let rotation: Float?
    let color: String?
    let additionalProperties: [String: Any]
}

// CV Session Management
struct CVSession {
    let sessionId: UUID
    let startTime: Date
    let configuration: CVConfiguration
    var subscribers: [String: CVSubscription]  // gameId -> subscription
}

struct CVSubscription {
    let gameId: String
    let eventTypes: [CVEventType]
    let handler: (CVEvent) -> Void
    let priority: CVPriority  // For future optimization
}
```

### 3. Game Progress & Persistence

```swift
// Player Progress
struct GameProgress {
    let gameId: String
    let playerId: String          // For future multi-user
    let levelsCompleted: Set<String>
    let levelScores: [String: LevelScore]
    let achievements: Set<String>
    let totalPlayTime: TimeInterval
    let lastPlayed: Date
    let statistics: GameStatistics
}

struct LevelScore {
    let levelId: String
    let highScore: Int
    let stars: Int               // 1-3 star rating
    let completionTime: TimeInterval
    let firstCompletedDate: Date
    let playCount: Int
}

struct GameStatistics {
    let averageSessionTime: TimeInterval
    let totalSessions: Int
    let perfectScoreCount: Int
    let favoriteLevel: String?
}

// Persistence Keys Schema
enum PersistenceKey {
    case gameProgress(gameId: String)
    case levelCompletion(gameId: String, levelId: String)
    case userSettings
    case currentSession
    
    var stringValue: String {
        switch self {
        case .gameProgress(let gameId):
            return "game.\(gameId).progress"
        case .levelCompletion(let gameId, let levelId):
            return "game.\(gameId).level.\(levelId)"
        case .userSettings:
            return "settings.user"
        case .currentSession:
            return "session.current"
        }
    }
}
```

### 4. Analytics & Telemetry

```swift
// Analytics Events
struct AnalyticsEvent {
    let eventId: UUID
    let eventType: EventType
    let gameId: String
    let timestamp: Date
    let sessionId: String
    let parameters: [String: Any]
}

enum EventType {
    case gameStarted
    case levelCompleted
    case achievementUnlocked
    case errorOccurred
    case cvEventProcessed
    case customEvent(name: String)
}

// Session Tracking
struct GameSession {
    let sessionId: UUID
    let gameId: String
    let startTime: Date
    var endTime: Date?
    var events: [AnalyticsEvent]
    var cvEventCount: Int
    var errorCount: Int
}
```

### 5. Service Layer Models

```swift
// Audio System
struct AudioAsset {
    let assetId: String
    let filename: String
    let category: AudioCategory
    let duration: TimeInterval
    let volume: Float
}

enum AudioCategory {
    case sfx
    case music
    case voice
    case ambient
}

// User Settings
struct UserSettings: Codable {
    var soundEnabled: Bool = true
    var musicEnabled: Bool = true
    var hapticEnabled: Bool = true
    var cvDebugMode: Bool = false
    var parentalControlsEnabled: Bool = false
}
```

## 100-Day Curriculum Data Model

### 1. Curriculum Structure

```swift
// Curriculum Definition
struct Curriculum {
    let id: String
    let name: String
    let description: String
    let totalDays: Int
    let targetAgeRange: ClosedRange<Int>
    let skillCategories: [SkillCategory]
    let prerequisites: [String]  // Other curriculum IDs
    let days: [DailyLesson]
}

struct DailyLesson {
    let day: Int
    let theme: String
    let objectives: [LearningObjective]
    let activities: [LessonActivity]
    let requiredMasteryLevel: Float  // 0-1
    let estimatedDuration: TimeInterval
    let parentGuidance: String?
}

struct LessonActivity {
    let id: String
    let sequenceOrder: Int
    let gameModuleId: String
    let activityType: ActivityType
    let configuration: ActivityConfiguration
    let completionCriteria: CompletionCriteria
    let adaptiveDifficulty: Bool
}

struct ActivityConfiguration {
    let difficulty: DifficultyLevel
    let contentIds: [String]        // Letters, words, numbers, etc.
    let timeLimit: TimeInterval?
    let visualTheme: String
    let audioInstructions: String?
    let cvRequirements: [CVEventType]
    let customParameters: [String: Any]
}

enum ActivityType {
    case introduction
    case practice
    case assessment
    case review
    case challenge
}
```

### 2. Learning Progress Tracking

```swift
// Progress Management
struct CurriculumProgress {
    let curriculumId: String
    let playerId: String
    let enrollmentDate: Date
    let currentDay: Int
    let completedDays: [DayProgress]
    let streakInfo: StreakInfo
    let skillMastery: SkillMasteryMap
    let assessmentHistory: [Assessment]
}

struct DayProgress {
    let day: Int
    let completionDate: Date
    let activities: [ActivityResult]
    let totalDuration: TimeInterval
    let masteryAchieved: Bool
    let retryCount: Int
    let parentNotes: String?
}

struct ActivityResult {
    let activityId: String
    let startTime: Date
    let endTime: Date
    let score: Score
    let interactions: [InteractionEvent]
    let errors: [ErrorDetail]
    let skillsProgressed: [SkillProgress]
    let cvEventsProcessed: Int
}

struct StreakInfo {
    var currentStreak: Int
    var longestStreak: Int
    var lastActivityDate: Date
    var totalDaysActive: Int
}
```

### 3. Skill & Mastery System

```swift
// Skill Tracking
struct SkillCategory {
    let id: String
    let name: String
    let subSkills: [Skill]
}

struct Skill {
    let id: String              // e.g., "phonics.sound.m"
    let name: String
    let category: String
    let prerequisites: [String]
    let assessmentCriteria: AssessmentCriteria
}

struct SkillProgress {
    let skillId: String
    let previousLevel: Float    // 0-1
    let currentLevel: Float     // 0-1
    let totalAttempts: Int
    let correctAttempts: Int
    let lastPracticed: Date
    let milestones: [SkillMilestone]
}

typealias SkillMasteryMap = [String: SkillProgress]  // skillId -> progress

struct SkillMilestone {
    let name: String
    let achievedDate: Date
    let triggerEvent: String
}
```

### 4. Assessment & Reporting

```swift
// Assessment System
struct Assessment {
    let id: UUID
    let date: Date
    let type: AssessmentType
    let skills: [String]         // Skill IDs assessed
    let results: AssessmentResults
    let recommendations: [String]
}

enum AssessmentType {
    case placement
    case progress
    case mastery
    case diagnostic
}

struct AssessmentResults {
    let overallScore: Float      // 0-1
    let skillScores: [String: Float]  // skillId -> score
    let timeSpent: TimeInterval
    let areasOfStrength: [String]
    let areasForImprovement: [String]
}

// Parent Reporting
struct ParentReport {
    let reportId: UUID
    let generatedDate: Date
    let reportPeriod: DateInterval
    let summary: ProgressSummary
    let detailedProgress: [SkillProgressReport]
    let recommendations: [Recommendation]
    let upcomingContent: [DailyLesson]
}

struct ProgressSummary {
    let daysCompleted: Int
    let totalTimeSpent: TimeInterval
    let averageSessionTime: TimeInterval
    let strongestSkills: [String]
    let focusAreas: [String]
    let achievementCount: Int
}
```

## Data Flow Diagrams

### 1. Main Application Flow

```
App Launch:
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  AppDelegate│────▶│AppCoordinator│────▶│    Lobby    │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                 │
                                                 ▼
                                         ┌───────────────┐
                                         │Load Game List │
                                         │ from Bundle   │
                                         └───────┬───────┘
                                                 │
                                                 ▼
                                         ┌───────────────┐
                                         │Load Progress  │
                                         │from Persistence│
                                         └───────┬───────┘
                                                 │
                                                 ▼
                                         ┌───────────────┐
                                         │Display Games  │
                                         │   with State  │
                                         └───────────────┘
```

### 2. Game Session Flow

```
Game Selection:
┌──────────┐     ┌──────────────┐     ┌─────────────┐
│   User   │────▶│Lobby selects │────▶│Game Host    │
│  Action  │     │    game      │     │ Created     │
└──────────┘     └──────────────┘     └──────┬──────┘
                                              │
                                              ▼
                                      ┌───────────────┐
                                      │  Load Game    │
                                      │   Module      │
                                      └───────┬───────┘
                                              │
                                              ▼
                                      ┌───────────────┐
                                      │Init Services: │
                                      │-CV            │
                                      │-Audio         │
                                      │-Analytics     │
                                      └───────┬───────┘
                                              │
                                              ▼
                                      ┌───────────────┐
                                      │Create Context │
                                      │Start Session  │
                                      └───────────────┘
```

### 3. CV Event Flow

```
CV Processing Pipeline:
┌────────────┐     ┌──────────────┐     ┌─────────────┐
│   Camera   │────▶│  CV Service  │────▶│   Process   │
│   Frame    │     │  (BG Queue)  │     │   Frame     │
└────────────┘     └──────────────┘     └──────┬──────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │Detect Objects │
                                        │  & Gestures   │
                                        └───────┬───────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │Generate Events│
                                        │(Main Queue)   │
                                        └───────┬───────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │  Publish to   │
                                        │ Subscribers   │
                                        └───────────────┘
```

### 4. Curriculum Data Flow

```
Daily Lesson Flow:
┌────────────┐     ┌──────────────┐     ┌─────────────┐
│   Start    │────▶│Load Curriculum│────▶│Check Progress│
│   100-Day  │     │     JSON      │     │   (Day N)    │
└────────────┘     └──────────────┘     └──────┬──────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │Load Day N     │
                                        │  Activities   │
                                        └───────┬───────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │Launch Activity│
                                        │  (Mini-game)  │
                                        └───────┬───────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │Collect Results│
                                        │Update Progress│
                                        └───────┬───────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │Next Activity  │
                                        │or Day Complete│
                                        └───────────────┘
```

### 5. Progress Persistence Flow

```
Save Progress:
┌────────────┐     ┌──────────────┐     ┌─────────────┐
│   Game     │────▶│   Generate   │────▶│  Validate   │
│  Complete  │     │   Results    │     │    Data     │
└────────────┘     └──────────────┘     └──────┬──────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │Update Progress│
                                        │   Object      │
                                        └───────┬───────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │Save to        │
                                        │UserDefaults   │
                                        └───────┬───────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │Queue Analytics│
                                        │    Event      │
                                        └───────────────┘
```

## Data Storage Locations

### Local Storage (UserDefaults)
```
game.<gameId>.progress          → GameProgress object
game.<gameId>.level.<levelId>  → LevelScore object
curriculum.<currId>.progress    → CurriculumProgress object
curriculum.<currId>.day.<N>     → DayProgress object
settings.user                   → UserSettings object
session.current                 → Current session info
```

### Bundle Resources
```
Games/
├── GameRegistry.json          → All GameInfo objects
├── <GameId>/
│   ├── Info.json             → Game-specific config
│   └── Assets/               → Game assets
│
Curriculum/
├── read_100_days.json        → Curriculum definition
├── math_100_days.json        → Math curriculum
└── Activities/
    └── configs/              → Activity configurations
```

### In-Memory Caches
```
ServiceLocator:
├── cvService                 → Active CV session
├── audioService              → Loaded audio assets
├── analyticsService          → Event queue
└── persistenceService        → Write cache

GameLoader:
├── loadedModules            → Active game modules
└── moduleCache              → Recently used modules
```

## Data Synchronization

### Real-time Sync Points
1. **CV Events**: Camera → CV Service → Game (30-60 FPS)
2. **Audio Triggers**: Game → Audio Service (immediate)
3. **Progress Saves**: Level complete → Persistence (immediate)

### Batch Sync Points
1. **Analytics**: Every 30 seconds or app background
2. **Parent Reports**: Generated on-demand
3. **Achievement Checks**: After each activity

### Data Validation Rules
1. **CV Events**: Position must be normalized (0-1)
2. **Scores**: Must be within defined range
3. **Progress**: Can't skip days in curriculum
4. **Time Tracking**: Session can't exceed 24 hours

This data architecture ensures efficient flow between components while maintaining data integrity and enabling both real-time gameplay and long-term progress tracking.