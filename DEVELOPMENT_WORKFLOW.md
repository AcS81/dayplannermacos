# Development Workflow & Best Practices

## Overview

This document outlines the recommended development workflow, coding standards, and best practices for building the Day Planner app efficiently and maintainably.

## Development Workflow

### 1. Project Setup
```bash
# Initial setup
git clone <repository-url>
cd day-planner
./Scripts/setup.sh

# Verify environment
./Scripts/verify-setup.sh

# Start LM Studio for AI integration
open /Applications/LMStudio.app
```

### 2. Feature Development Cycle

#### Phase 1: Planning & Design
```bash
# Create feature branch
git checkout -b feature/action-bar-voice-mode

# Document the feature
# Update FEATURES_IMPLEMENTATION.md with specific details
# Add component specifications to COMPONENTS.md
# Update API_SPECIFICATIONS.md if needed

# Create development tasks
echo "- [ ] Implement VoiceInputView component" >> TODO.md
echo "- [ ] Add Speech recognition service" >> TODO.md
echo "- [ ] Integrate with Action Bar" >> TODO.md
echo "- [ ] Add tests" >> TODO.md
echo "- [ ] Update documentation" >> TODO.md
```

#### Phase 2: Test-Driven Development
```swift
// 1. Write failing tests first
class VoiceInputTests: XCTestCase {
    func testSpeechRecognitionStart() async throws {
        let voiceInput = VoiceInputView()
        // Test implementation
        XCTAssertTrue(voiceInput.canStartRecording)
    }
}

// 2. Implement minimum code to pass tests
class VoiceInputView {
    var canStartRecording: Bool { return true }
}

// 3. Refactor and improve
class VoiceInputView {
    @StateObject private var speechService = SpeechService()
    var canStartRecording: Bool { 
        speechService.authorizationStatus == .authorized 
    }
}
```

#### Phase 3: Implementation
```bash
# Run tests continuously during development
./Scripts/test-watch.sh

# Check code quality
./Scripts/lint.sh
./Scripts/format.sh

# Verify performance benchmarks
./Scripts/performance-check.sh
```

#### Phase 4: Integration & Review
```bash
# Run full test suite
./Scripts/test-all.sh

# Update documentation
# Update COMPONENTS.md with new component
# Update API_SPECIFICATIONS.md with new APIs
# Add integration tests

# Create pull request
git push origin feature/action-bar-voice-mode
# Open GitHub/GitLab PR with template
```

### 3. Git Workflow

#### Branch Strategy
```bash
# Main branches
main              # Production-ready code
develop           # Integration branch for features

# Supporting branches
feature/<name>    # New features
bugfix/<name>     # Bug fixes
hotfix/<name>     # Critical production fixes
release/<version> # Release preparation
```

#### Commit Messages
```bash
# Format: <type>(<scope>): <subject>
# 
# type: feat, fix, docs, style, refactor, test, chore
# scope: component, service, api, ui, etc.
# subject: imperative, present tense

# Examples:
git commit -m "feat(action-bar): add voice input with hold-to-talk gesture"
git commit -m "fix(calendar): resolve event overlap calculation in timeline"
git commit -m "docs(api): update AI service specifications with streaming"
git commit -m "test(voice): add speech recognition integration tests"
git commit -m "refactor(data): optimize event repository query performance"
```

## Code Organization

### Project Structure
```
DayPlanner/
├── App/
│   ├── DayPlannerApp.swift       # App entry point
│   ├── AppDelegate.swift         # AppKit delegate
│   └── ContentView.swift         # Root view
├── Features/
│   ├── ActionBar/               # Action Bar feature
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Services/
│   ├── Calendar/                # Calendar feature
│   ├── MindSpace/              # Goals, pillars, chains
│   └── Settings/               # App settings
├── Shared/
│   ├── Models/                 # Data models
│   ├── Services/              # Shared services
│   ├── Extensions/            # Swift extensions
│   ├── Utilities/             # Helper utilities
│   └── Components/            # Reusable UI components
├── Resources/
│   ├── Assets.xcassets
│   ├── Localizable.strings
│   └── Info.plist
└── Tests/
    ├── UnitTests/
    ├── IntegrationTests/
    └── UITests/
```

### File Naming Conventions
```swift
// Views
ActionBarView.swift
DayPlannerView.swift
EventCardView.swift

// ViewModels
ActionBarViewModel.swift
DayPlannerViewModel.swift
GoalDetailViewModel.swift

// Services
AIService.swift
CalendarService.swift
SpeechService.swift

// Models
Event.swift
Chain.swift
Goal.swift

// Extensions
Date+Extensions.swift
View+Extensions.swift
```

## Coding Standards

### Swift Style Guide

#### 1. Code Formatting
```swift
// Use 4 spaces for indentation
class ExampleClass {
    private let property: String
    
    init(property: String) {
        self.property = property
    }
    
    func methodName(parameter: String) -> String {
        guard !parameter.isEmpty else {
            return ""
        }
        
        return "Result: \(parameter)"
    }
}

// Line length: 120 characters maximum
let longVariableName = someFunction(withParameter: parameter,
                                   andAnotherParameter: anotherParameter)
```

#### 2. Naming Conventions
```swift
// Classes, Structs, Enums: PascalCase
class EventRepository { }
struct UserPreference { }
enum EventStatus { }

// Variables, Functions: camelCase
let userName: String
var isConnected: Bool
func fetchEvents() -> [Event] { }

// Constants: camelCase
let maxRetryAttempts = 3
static let defaultTimeout: TimeInterval = 30.0

// Protocols: adjective ending in -able, -ible, or noun
protocol Fetchable { }
protocol EventRepositoryProtocol { }
```

#### 3. SwiftUI Best Practices
```swift
// Prefer computed properties over functions for simple views
var headerView: some View {
    HStack {
        Text("Title")
        Spacer()
        Button("Action") { }
    }
}

// Use @State for simple local state
@State private var isExpanded = false
@State private var selectedDate = Date()

// Use @StateObject for ObservableObject creation
@StateObject private var viewModel = ActionBarViewModel()

// Use @ObservedObject for passed objects
@ObservedObject var event: Event

// Extract complex views into separate structs
struct ComplexEventCard: View {
    let event: Event
    
    var body: some View {
        VStack {
            HeaderView()
            ContentView()
            ActionsView()
        }
    }
}
```

#### 4. Error Handling
```swift
// Use Result type for operations that can fail
func fetchEvents() async -> Result<[Event], EventError> {
    do {
        let events = try await repository.fetchEvents()
        return .success(events)
    } catch {
        return .failure(.fetchFailed(error))
    }
}

// Use throws for async operations
func commitEvents() async throws -> [Event] {
    guard !stagedEvents.isEmpty else {
        throw EventError.noStagedEvents
    }
    
    return try await repository.commitEvents(stagedEvents)
}

// Create specific error types
enum EventError: LocalizedError {
    case noStagedEvents
    case fetchFailed(Error)
    case commitFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noStagedEvents:
            return "No staged events to commit"
        case .fetchFailed(let error):
            return "Failed to fetch events: \(error.localizedDescription)"
        case .commitFailed(let error):
            return "Failed to commit events: \(error.localizedDescription)"
        }
    }
}
```

### Architecture Patterns

#### 1. MVVM Implementation
```swift
// View: Minimal logic, delegates to ViewModel
struct DayPlannerView: View {
    @StateObject private var viewModel = DayPlannerViewModel()
    
    var body: some View {
        TimelineView(
            events: viewModel.events,
            onEventTap: viewModel.selectEvent
        )
        .task {
            await viewModel.loadEvents()
        }
    }
}

// ViewModel: Business logic, state management
@MainActor
class DayPlannerViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var selectedEvent: Event?
    @Published var isLoading = false
    
    private let eventRepository: EventRepositoryProtocol
    private let aiService: AIServiceProtocol
    
    init(
        eventRepository: EventRepositoryProtocol = EventRepository(),
        aiService: AIServiceProtocol = AIService()
    ) {
        self.eventRepository = eventRepository
        self.aiService = aiService
    }
    
    func loadEvents() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            events = try await eventRepository.fetchEvents(for: Date())
        } catch {
            handleError(error)
        }
    }
}
```

#### 2. Dependency Injection
```swift
// Protocol-based dependencies
protocol EventRepositoryProtocol {
    func fetchEvents(for date: Date) async throws -> [Event]
    func saveEvent(_ event: Event) async throws
}

// Dependency container
class AppDependencies {
    static let shared = AppDependencies()
    
    lazy var eventRepository: EventRepositoryProtocol = EventRepository()
    lazy var aiService: AIServiceProtocol = AIService()
    lazy var calendarService: CalendarServiceProtocol = CalendarService()
    
    private init() {}
}

// Injection in ViewModels
class DayPlannerViewModel: ObservableObject {
    private let dependencies: AppDependencies
    
    init(dependencies: AppDependencies = .shared) {
        self.dependencies = dependencies
    }
}
```

#### 3. Service Layer Pattern
```swift
// Abstract service protocols
protocol AIServiceProtocol {
    func generateSuggestions(context: PlanningContext) async throws -> [Suggestion]
}

protocol CalendarServiceProtocol {
    func fetchEvents(for dateRange: DateInterval) async throws -> [Event]
    func commitEvent(_ event: Event) async throws
}

// Concrete implementations
class AIService: AIServiceProtocol {
    private let connection: LMStudioConnection
    private let contextManager: ContextManager
    
    func generateSuggestions(context: PlanningContext) async throws -> [Suggestion] {
        // Implementation
    }
}

// Service composition in ViewModels
class ActionBarViewModel: ObservableObject {
    private let aiService: AIServiceProtocol
    private let calendarService: CalendarServiceProtocol
    
    // Use services without knowing implementation details
    func processSuggestion(_ suggestion: Suggestion) async {
        do {
            let event = try await calendarService.commitEvent(suggestion.toEvent())
            // Update UI state
        } catch {
            handleError(error)
        }
    }
}
```

## Development Tools & Scripts

### Build Scripts
```bash
#!/bin/bash
# Scripts/build.sh

set -e

echo "🔨 Building Day Planner..."

# Clean previous builds
xcodebuild clean -project DayPlanner.xcodeproj -scheme DayPlanner

# Build for Debug
xcodebuild build \
    -project DayPlanner.xcodeproj \
    -scheme DayPlanner \
    -configuration Debug \
    -destination "platform=macOS"

echo "✅ Build completed successfully"
```

### Testing Scripts
```bash
#!/bin/bash
# Scripts/test-all.sh

set -e

echo "🧪 Running complete test suite..."

# Unit tests
echo "Running unit tests..."
xcodebuild test \
    -project DayPlanner.xcodeproj \
    -scheme DayPlanner \
    -destination "platform=macOS" \
    -testPlan UnitTests

# Integration tests (if LM Studio available)
if curl -s http://localhost:1234/v1/models > /dev/null; then
    echo "Running integration tests..."
    xcodebuild test \
        -project DayPlanner.xcodeproj \
        -scheme DayPlanner \
        -destination "platform=macOS" \
        -testPlan IntegrationTests
fi

# UI tests
echo "Running UI tests..."
xcodebuild test \
    -project DayPlanner.xcodeproj \
    -scheme DayPlanner \
    -destination "platform=macOS" \
    -testPlan UITests

echo "✅ All tests completed"
```

### Code Quality Scripts
```bash
#!/bin/bash
# Scripts/lint.sh

echo "🔍 Running SwiftLint..."

if which swiftlint >/dev/null; then
    swiftlint
else
    echo "⚠️ SwiftLint not installed. Install with: brew install swiftlint"
    exit 1
fi

echo "✅ Linting completed"
```

### Performance Monitoring
```bash
#!/bin/bash
# Scripts/performance-check.sh

echo "⚡ Running performance checks..."

# Build for Release to check performance
xcodebuild build \
    -project DayPlanner.xcodeproj \
    -scheme DayPlanner \
    -configuration Release \
    -destination "platform=macOS"

# Run performance tests
xcodebuild test \
    -project DayPlanner.xcodeproj \
    -scheme DayPlanner \
    -destination "platform=macOS" \
    -testPlan PerformanceTests

echo "✅ Performance checks completed"
```

## Code Review Guidelines

### Pull Request Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] UI tests added/updated
- [ ] Manual testing completed

## Performance Impact
- [ ] No performance impact
- [ ] Performance improved
- [ ] Performance impact assessed and acceptable

## Documentation
- [ ] Code comments added/updated
- [ ] Documentation files updated
- [ ] API specifications updated

## Screenshots (if applicable)
Add screenshots of UI changes

## Additional Notes
Any additional context or notes for reviewers
```

### Review Checklist
```markdown
## Code Review Checklist

### Architecture & Design
- [ ] Follows MVVM pattern correctly
- [ ] Proper separation of concerns
- [ ] Dependency injection used appropriately
- [ ] No tight coupling between components

### Code Quality
- [ ] Code is readable and well-documented
- [ ] Naming conventions followed
- [ ] No code duplication
- [ ] Error handling implemented properly
- [ ] Performance considerations addressed

### Testing
- [ ] Unit tests cover critical functionality
- [ ] Integration tests for external dependencies
- [ ] UI tests for user-facing changes
- [ ] Tests are maintainable and reliable

### Security & Privacy
- [ ] No sensitive data hardcoded
- [ ] Proper data encryption where needed
- [ ] User permissions requested appropriately
- [ ] Privacy guidelines followed

### UI/UX
- [ ] Follows design system guidelines
- [ ] Accessibility considerations implemented
- [ ] Responsive design for different screen sizes
- [ ] Loading states and error states handled
```

## Debugging & Troubleshooting

### Common Issues & Solutions

#### 1. LM Studio Connection Issues
```bash
# Check if LM Studio is running
curl http://localhost:1234/v1/models

# If not working, check:
# 1. LM Studio app is open
# 2. Model is loaded
# 3. Server is started
# 4. Port 1234 is not blocked by firewall
```

#### 2. EventKit Permission Issues
```swift
// Check calendar permissions
func checkCalendarPermission() async {
    let status = EKEventStore.authorizationStatus(for: .event)
    switch status {
    case .notDetermined:
        let granted = try await eventStore.requestAccess(to: .event)
        print("Permission granted: \(granted)")
    case .denied, .restricted:
        // Guide user to Settings
        print("Permission denied. Please enable in System Preferences.")
    case .authorized:
        print("Permission already granted")
    @unknown default:
        print("Unknown permission status")
    }
}
```

#### 3. Performance Issues
```swift
// Use Instruments to profile performance
// Common performance bottlenecks:
// 1. Large database queries
// 2. AI response times
// 3. UI rendering on main thread
// 4. Memory leaks in reactive bindings

// Debugging tools
import os.signpost
let log = OSLog(subsystem: "com.app.dayplanner", category: "Performance")

func measurePerformance<T>(operation: String, block: () throws -> T) rethrows -> T {
    let signpostID = OSSignpostID(log: log)
    os_signpost(.begin, log: log, name: "Performance", signpostID: signpostID, 
                "%{public}s", operation)
    defer {
        os_signpost(.end, log: log, name: "Performance", signpostID: signpostID)
    }
    return try block()
}
```

## Release Process

### Version Management
```bash
# Update version numbers
# 1. Update CFBundleShortVersionString in Info.plist
# 2. Update CFBundleVersion (build number)
# 3. Tag release in git

git tag -a v0.1.0 -m "Release version 0.1.0"
git push origin v0.1.0
```

### Release Checklist
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Performance benchmarks met
- [ ] Security review completed
- [ ] UI/UX review completed
- [ ] Beta testing completed
- [ ] Release notes prepared
- [ ] App Store metadata updated (if applicable)

This development workflow ensures consistent, high-quality development practices while maintaining the architectural principles and performance requirements specified in the PRD.
