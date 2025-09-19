# Testing Strategy & Test Plans

## Overview

This document outlines a comprehensive testing strategy for the Day Planner app, covering unit tests, integration tests, UI tests, performance tests, and AI-specific testing approaches.

## Testing Pyramid

```
    ┌─────────────────┐
    │   Manual Tests  │  ← Exploratory, usability, edge cases
    └─────────────────┘
         ┌─────────┐
         │ UI Tests│      ← Critical user flows, accessibility
         └─────────┘
      ┌─────────────┐
      │Integration  │     ← Service interactions, EventKit
      └─────────────┘
   ┌─────────────────┐
   │   Unit Tests    │    ← Business logic, data models, utilities
   └─────────────────┘
```

## Unit Testing

### Test Structure
```swift
// Example test class structure
import XCTest
@testable import DayPlanner

class EventRepositoryTests: XCTestCase {
    var repository: EventRepository!
    var mockDatabase: MockDatabase!
    
    override func setUp() {
        super.setUp()
        mockDatabase = MockDatabase()
        repository = SQLiteEventRepository(database: mockDatabase)
    }
    
    override func tearDown() {
        mockDatabase.clearAll()
        super.tearDown()
    }
    
    func testFetchEventsForDateRange() async throws {
        // Given
        let testEvents = createTestEvents()
        mockDatabase.insert(testEvents)
        
        let dateRange = DateInterval(
            start: Date().startOfDay,
            end: Date().endOfDay
        )
        
        // When
        let fetchedEvents = try await repository.fetchEvents(for: dateRange)
        
        // Then
        XCTAssertEqual(fetchedEvents.count, 3)
        XCTAssertEqual(fetchedEvents.first?.title, "Test Event 1")
    }
}
```

### Core Components to Test

#### 1. Data Models
```swift
class EventModelTests: XCTestCase {
    func testEventValidation() {
        let validEvent = Event(
            id: "test-id",
            title: "Test Event",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            // ... other properties
        )
        
        XCTAssertTrue(validEvent.isValid)
        XCTAssertEqual(validEvent.duration, 3600)
    }
    
    func testEventOverlapDetection() {
        let event1 = createEvent(start: "09:00", end: "10:00")
        let event2 = createEvent(start: "09:30", end: "10:30")
        
        XCTAssertTrue(event1.overlaps(with: event2))
    }
    
    func testChainBlockSequencing() {
        let chain = Chain(
            blocks: [
                ChainBlock(title: "Warmup", duration: 10, order: 0),
                ChainBlock(title: "Main", duration: 45, order: 1),
                ChainBlock(title: "Cooldown", duration: 5, order: 2)
            ]
        )
        
        let orderedBlocks = chain.orderedBlocks
        XCTAssertEqual(orderedBlocks.first?.title, "Warmup")
        XCTAssertEqual(orderedBlocks.last?.title, "Cooldown")
    }
}
```

#### 2. ViewModels
```swift
class DayPlannerViewModelTests: XCTestCase {
    var viewModel: DayPlannerViewModel!
    var mockCalendarService: MockCalendarService!
    var mockAIService: MockAIService!
    
    override func setUp() {
        super.setUp()
        mockCalendarService = MockCalendarService()
        mockAIService = MockAIService()
        viewModel = DayPlannerViewModel(
            calendarService: mockCalendarService,
            aiService: mockAIService
        )
    }
    
    func testEventStaging() async {
        // Given
        let suggestion = createTestSuggestion()
        
        // When
        await viewModel.stageSuggestion(suggestion)
        
        // Then
        XCTAssertEqual(viewModel.stagedEvents.count, 1)
        XCTAssertTrue(viewModel.stagedEvents.first?.isStaged == true)
    }
    
    func testEventCommit() async throws {
        // Given
        await viewModel.stageSuggestion(createTestSuggestion())
        mockCalendarService.shouldSucceed = true
        
        // When
        try await viewModel.commitStagedEvents()
        
        // Then
        XCTAssertTrue(viewModel.stagedEvents.isEmpty)
        XCTAssertEqual(mockCalendarService.committedEvents.count, 1)
    }
    
    func testUndoCommit() async throws {
        // Given
        try await viewModel.commitStagedEvents()
        
        // When
        try await viewModel.undoLastCommit()
        
        // Then
        XCTAssertTrue(mockCalendarService.deletedEventIds.contains("test-event-id"))
    }
}
```

#### 3. Services
```swift
class AIServiceTests: XCTestCase {
    var aiService: AIService!
    var mockConnection: MockLMStudioConnection!
    
    func testSuggestionGeneration() async throws {
        // Given
        mockConnection.mockResponse = mockSuggestionResponse()
        let context = createPlanningContext()
        
        // When
        let response = try await aiService.generateSuggestions(
            context: context,
            type: .dailyPlanning
        )
        
        // Then
        XCTAssertEqual(response.suggestions.count, 3)
        XCTAssertTrue(response.processingTime > 0)
        XCTAssertTrue(response.suggestions.allSatisfy { $0.confidence > 0.5 })
    }
    
    func testErrorHandling() async {
        // Given
        mockConnection.shouldFail = true
        let context = createPlanningContext()
        
        // When/Then
        await XCTAssertThrowsError(
            try await aiService.generateSuggestions(context: context, type: .dailyPlanning)
        ) { error in
            XCTAssertTrue(error is AIServiceError)
        }
    }
}
```

### Mock Objects
```swift
class MockCalendarService: CalendarServiceProtocol {
    var shouldSucceed = true
    var committedEvents: [Event] = []
    var deletedEventIds: [String] = []
    
    func commitStagedEvents(_ events: [StagedEvent]) async throws -> [Event] {
        guard shouldSucceed else {
            throw CalendarError.commitFailed
        }
        
        let committedEvents = events.map { $0.toEvent() }
        self.committedEvents.append(contentsOf: committedEvents)
        return committedEvents
    }
    
    func deleteEvent(id: String) async throws {
        guard shouldSucceed else {
            throw CalendarError.deleteFailed
        }
        deletedEventIds.append(id)
    }
}

class MockAIService: AIServiceProtocol {
    var mockSuggestions: [Suggestion] = []
    var shouldFail = false
    var processingDelay: TimeInterval = 0.1
    
    func generateSuggestions(context: PlanningContext) async throws -> SuggestionResponse {
        if shouldFail {
            throw AIServiceError.connectionFailed
        }
        
        await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        
        return SuggestionResponse(
            suggestions: mockSuggestions,
            confidence: 0.8,
            processingTime: processingDelay,
            explanation: "Mock suggestions"
        )
    }
}
```

## Integration Testing

### Calendar Integration Tests
```swift
class EventKitIntegrationTests: XCTestCase {
    var calendarService: CalendarService!
    var eventStore: EKEventStore!
    
    override func setUp() async throws {
        super.setUp()
        eventStore = EKEventStore()
        
        // Request calendar access for testing
        let granted = try await eventStore.requestAccess(to: .event)
        XCTAssertTrue(granted, "Calendar access required for integration tests")
        
        calendarService = CalendarService(eventStore: eventStore)
    }
    
    func testCreateAndFetchEvent() async throws {
        // Given
        let eventRequest = EventRequest(
            title: "Test Integration Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: "Test Location"
        )
        
        // When
        let createdEvent = try await calendarService.createEvent(eventRequest)
        let fetchedEvents = try await calendarService.fetchEvents(
            for: DateInterval(start: Date().startOfDay, end: Date().endOfDay)
        )
        
        // Then
        XCTAssertNotNil(createdEvent.sourceId)
        XCTAssertTrue(fetchedEvents.contains { $0.id == createdEvent.id })
        
        // Cleanup
        try await calendarService.deleteEvent(id: createdEvent.id)
    }
    
    func testBatchCommit() async throws {
        let events = (1...3).map { i in
            StagedEvent(
                title: "Batch Event \(i)",
                startTime: Date().addingTimeInterval(TimeInterval(i * 3600)),
                endTime: Date().addingTimeInterval(TimeInterval(i * 3600 + 1800))
            )
        }
        
        let operations = events.map { CalendarOperation.create(eventRequest: $0.toEventRequest()) }
        let result = try await calendarService.commitBatch(operations)
        
        XCTAssertEqual(result.successful.count, 3)
        XCTAssertTrue(result.failed.isEmpty)
        
        // Cleanup
        for eventId in result.successful {
            try await calendarService.deleteEvent(id: eventId)
        }
    }
}
```

### AI Integration Tests
```swift
class LMStudioIntegrationTests: XCTestCase {
    var aiService: AIService!
    
    override func setUp() async throws {
        super.setUp()
        
        // Verify LM Studio is running
        let connection = LMStudioConnection()
        let isHealthy = await connection.healthCheck()
        
        try XCTSkipUnless(isHealthy, "LM Studio must be running for integration tests")
        
        aiService = AIService(connection: connection)
    }
    
    func testRealAISuggestionGeneration() async throws {
        let context = PlanningContext(
            currentDay: Date(),
            existingEvents: [],
            userPreferences: createTestPreferences(),
            availableTimeSlots: [
                TimeSlot(startTime: Date(), endTime: Date().addingTimeInterval(3600))
            ]
        )
        
        let response = try await aiService.generateSuggestions(
            context: context,
            type: .dailyPlanning
        )
        
        XCTAssertFalse(response.suggestions.isEmpty)
        XCTAssertTrue(response.processingTime > 0)
        XCTAssertTrue(response.processingTime < 10.0) // Should complete within 10 seconds
    }
    
    func testStreamingResponse() async throws {
        var receivedChunks: [String] = []
        let expectation = XCTestExpectation(description: "Streaming complete")
        
        await aiService.generateWithStreaming(
            prompt: "Suggest a morning routine",
            onChunk: { chunk in
                receivedChunks.append(chunk)
            },
            onComplete: { full in
                XCTAssertEqual(full, receivedChunks.joined())
                expectation.fulfill()
            },
            onError: { error in
                XCTFail("Streaming failed: \(error)")
                expectation.fulfill()
            }
        )
        
        await fulfillment(of: [expectation], timeout: 15.0)
        XCTAssertFalse(receivedChunks.isEmpty)
    }
}
```

## UI Testing

### Critical User Flow Tests
```swift
class DayPlannerUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    func testCompletePlanningFlow() {
        // Navigate to day view
        let dayView = app.otherElements["DayPlannerView"]
        XCTAssertTrue(dayView.exists)
        
        // Interact with Action Bar
        let actionBar = app.otherElements["ActionBar"]
        let textInput = actionBar.textFields["MessageInput"]
        textInput.tap()
        textInput.typeText("I need to plan my morning")
        
        let sendButton = actionBar.buttons["SendMessage"]
        sendButton.tap()
        
        // Wait for AI response
        let suggestion = app.buttons.matching(identifier: "SuggestionCard").firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10.0))
        
        // Accept suggestion
        let acceptButton = suggestion.buttons["AcceptSuggestion"]
        acceptButton.tap()
        
        // Verify staging
        let stagedEvent = app.otherElements["StagedEvent"]
        XCTAssertTrue(stagedEvent.exists)
        
        // Commit staged event
        let commitButton = app.buttons["CommitStaged"]
        commitButton.tap()
        
        // Verify undo countdown
        let undoButton = app.buttons["UndoCommit"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 2.0))
        
        // Wait for commit completion
        XCTAssertTrue(undoButton.waitForNonExistence(timeout: 12.0))
        
        // Verify event appears in timeline
        let committedEvent = app.otherElements["CommittedEvent"]
        XCTAssertTrue(committedEvent.exists)
    }
    
    func testVoiceMode() {
        let actionBar = app.otherElements["ActionBar"]
        let voiceButton = actionBar.buttons["VoiceMode"]
        
        voiceButton.tap()
        
        // Verify voice mode UI
        let voiceIndicator = app.otherElements["VoiceRecordingIndicator"]
        XCTAssertTrue(voiceIndicator.exists)
        
        // Long press for hold-to-talk
        voiceButton.press(forDuration: 2.0)
        
        // Verify transcription appears
        let transcription = app.staticTexts["VoiceTranscription"]
        XCTAssertTrue(transcription.waitForExistence(timeout: 3.0))
    }
    
    func testChainCreation() {
        // Find an event and tap chain affordance
        let eventCard = app.otherElements["EventCard"].firstMatch
        XCTAssertTrue(eventCard.exists)
        
        let addChainButton = eventCard.buttons["AddChainAfter"]
        addChainButton.tap()
        
        // Verify chain suggestions appear
        let chainSuggestion = app.buttons["ChainSuggestion"].firstMatch
        XCTAssertTrue(chainSuggestion.waitForExistence(timeout: 5.0))
        
        // Select a chain suggestion
        chainSuggestion.tap()
        
        // Verify chain is staged
        let stagedChain = app.otherElements["StagedChain"]
        XCTAssertTrue(stagedChain.exists)
    }
}
```

### Accessibility Testing
```swift
class AccessibilityTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launch()
    }
    
    func testVoiceOverAccessibility() {
        // Enable VoiceOver simulation
        app.accessibilityActivate()
        
        // Test Action Bar accessibility
        let actionBar = app.otherElements["ActionBar"]
        XCTAssertNotNil(actionBar.label)
        XCTAssertTrue(actionBar.isAccessibilityElement)
        
        // Test event cards
        let eventCard = app.otherElements["EventCard"].firstMatch
        XCTAssertNotNil(eventCard.accessibilityLabel)
        XCTAssertTrue(eventCard.accessibilityLabel!.contains("event"))
        
        // Test keyboard navigation
        app.typeKey(.tab, modifierFlags: [])
        let focusedElement = app.firstResponder
        XCTAssertNotNil(focusedElement.accessibilityLabel)
    }
    
    func testDynamicTypeSupport() {
        // Test with larger text sizes
        app.launchArguments.append("-UIPreferredContentSizeCategoryName")
        app.launchArguments.append("UICTContentSizeCategoryAccessibilityXXL")
        app.launch()
        
        let eventTitle = app.staticTexts["EventTitle"].firstMatch
        XCTAssertTrue(eventTitle.exists)
        
        // Verify text is not truncated with large font
        let frame = eventTitle.frame
        XCTAssertTrue(frame.height > 20) // Should be taller with larger font
    }
}
```

## Performance Testing

### Load Testing
```swift
class PerformanceTests: XCTestCase {
    var viewModel: DayPlannerViewModel!
    
    func testEventLoadingPerformance() {
        // Create large dataset
        let events = createLargeEventDataset(count: 1000)
        
        measure {
            viewModel.loadEvents(events)
        }
        
        // Performance baseline: should complete within 100ms
        // Measure will fail if significantly slower
    }
    
    func testAIResponseTime() async throws {
        let aiService = AIService()
        let context = createComplexPlanningContext()
        
        let startTime = Date()
        _ = try await aiService.generateSuggestions(context: context)
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Should meet performance budget from PRD
        XCTAssertLessThan(processingTime, 3.5) // 3.5s budget for Apple Silicon
    }
    
    func testMemoryUsage() {
        let initialMemory = getCurrentMemoryUsage()
        
        // Load large dataset
        let events = createLargeEventDataset(count: 10000)
        viewModel.loadEvents(events)
        
        let peakMemory = getCurrentMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        // Should not exceed reasonable memory increase (50MB)
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024)
    }
}
```

### Battery Usage Testing
```swift
class BatteryEfficiencyTests: XCTestCase {
    func testBackgroundProcessingEfficiency() async {
        let processor = BackgroundAIProcessor()
        let startBattery = getCurrentBatteryLevel()
        
        // Run background processing for 10 minutes
        await processor.runContinuousProcessing(duration: 600)
        
        let endBattery = getCurrentBatteryLevel()
        let batteryDrain = startBattery - endBattery
        
        // Should not drain more than 2% in 10 minutes
        XCTAssertLessThan(batteryDrain, 0.02)
    }
}
```

## AI-Specific Testing

### Prompt Engineering Tests
```swift
class PromptEngineTests: XCTestCase {
    var promptEngine: PromptEngine!
    
    func testPromptGeneration() {
        let context = createPlanningContext()
        let prompt = promptEngine.buildPrompt(for: .dailyPlanning, context: context)
        
        // Verify prompt structure
        XCTAssertTrue(prompt.contains("Available time slots"))
        XCTAssertTrue(prompt.contains("User preferences"))
        XCTAssertTrue(prompt.contains("Response format"))
        
        // Verify prompt length is within model limits
        let tokenCount = estimateTokenCount(prompt)
        XCTAssertLessThan(tokenCount, 4000) // Leave room for response
    }
    
    func testContextSummarization() {
        let largeContext = createLargePlanningContext(eventCount: 100)
        let summarized = promptEngine.summarizeContext(largeContext)
        
        XCTAssertLessThan(summarized.events.count, 20) // Should be condensed
        XCTAssertFalse(summarized.summary.isEmpty)
    }
}
```

### Response Parsing Tests
```swift
class ResponseParserTests: XCTestCase {
    var parser: ResponseParser!
    
    func testValidJSONParsing() throws {
        let jsonResponse = """
        {
            "suggestions": [
                {
                    "title": "Morning workout",
                    "duration": 45,
                    "explanation": "Start day with energy",
                    "confidence": 0.8
                }
            ]
        }
        """
        
        let response = try parser.parseSuggestions(from: jsonResponse)
        XCTAssertEqual(response.suggestions.count, 1)
        XCTAssertEqual(response.suggestions.first?.content.title, "Morning workout")
    }
    
    func testMalformedJSONRecovery() throws {
        let malformedResponse = """
        Here are some suggestions:
        {
            "suggestions": [
                {"title": "Workout", "duration": 45}
            ]
        }
        Additional text...
        """
        
        // Should still parse successfully using fallback
        let response = try parser.parseSuggestions(from: malformedResponse)
        XCTAssertEqual(response.suggestions.count, 1)
    }
}
```

## Test Data & Utilities

### Test Data Factories
```swift
class TestDataFactory {
    static func createEvent(
        title: String = "Test Event",
        start: String = "09:00",
        end: String = "10:00",
        date: Date = Date()
    ) -> Event {
        let startTime = date.setting(hour: Int(start.prefix(2))!, minute: Int(start.suffix(2))!)
        let endTime = date.setting(hour: Int(end.prefix(2))!, minute: Int(end.suffix(2))!)
        
        return Event(
            id: UUID().uuidString,
            sourceId: nil,
            title: title,
            startTime: startTime!,
            endTime: endTime!,
            status: .active,
            isStaged: false
        )
    }
    
    static func createPlanningContext(
        date: Date = Date(),
        existingEvents: [Event] = [],
        availableSlots: Int = 3
    ) -> PlanningContext {
        let slots = (0..<availableSlots).map { i in
            TimeSlot(
                startTime: date.addingTimeInterval(TimeInterval(i * 3600)),
                endTime: date.addingTimeInterval(TimeInterval(i * 3600 + 1800))
            )
        }
        
        return PlanningContext(
            currentDay: date,
            existingEvents: existingEvents,
            userPreferences: UserPreferences.default,
            recentActivity: [],
            weatherData: nil,
            pillars: [],
            activeGoals: [],
            availableTimeSlots: slots
        )
    }
}
```

## Test Execution

### Test Schemes Configuration
```xml
<!-- DayPlannerTests.xctestplan -->
<?xml version="1.0" encoding="UTF-8"?>
<TestPlan version="1.0">
    <Name>DayPlannerTests</Name>
    <TestTargets>
        <TestTarget>
            <Name>DayPlannerUnitTests</Name>
            <SkippedTests>
                <!-- Skip integration tests in unit test run -->
                <Test Identifier="LMStudioIntegrationTests"/>
                <Test Identifier="EventKitIntegrationTests"/>
            </SkippedTests>
        </TestTarget>
    </TestTargets>
</TestPlan>
```

### Continuous Integration
```bash
#!/bin/bash
# ci_test.sh - Continuous Integration test script

echo "🧪 Running Day Planner Test Suite"

# Unit tests (fast)
echo "Running unit tests..."
xcodebuild test \
  -project DayPlanner.xcodeproj \
  -scheme DayPlanner \
  -destination "platform=macOS" \
  -testPlan UnitTests \
  -quiet

# Integration tests (if LM Studio available)
if curl -s http://localhost:1234/v1/models > /dev/null; then
    echo "Running integration tests..."
    xcodebuild test \
      -project DayPlanner.xcodeproj \
      -scheme DayPlanner \
      -destination "platform=macOS" \
      -testPlan IntegrationTests \
      -quiet
else
    echo "⚠️ Skipping integration tests - LM Studio not available"
fi

# UI tests (headless)
echo "Running UI tests..."
xcodebuild test \
  -project DayPlanner.xcodeproj \
  -scheme DayPlanner \
  -destination "platform=macOS" \
  -testPlan UITests \
  -quiet

echo "✅ Test suite completed"
```

## Testing Checklist

### Pre-Release Testing
- [ ] All unit tests passing (>95% coverage)
- [ ] Integration tests with EventKit working
- [ ] AI service integration functional
- [ ] Critical user flows tested in UI
- [ ] Performance benchmarks met
- [ ] Accessibility requirements validated
- [ ] Memory leaks identified and fixed
- [ ] Battery usage within acceptable limits
- [ ] Error handling and edge cases covered

This comprehensive testing strategy ensures the Day Planner app meets all quality and performance requirements specified in the PRD.
