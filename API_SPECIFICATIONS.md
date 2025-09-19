# API Specifications & Request/Response Patterns

## Overview

This document details all internal APIs, external integrations, and request/response patterns for the Day Planner app. All AI processing happens locally through LM Studio.

## Internal Service APIs

### 1. AI Service API

#### Base Configuration
```swift
struct AIServiceConfig {
    let baseURL = "http://localhost:1234"
    let model = "local-model"
    let maxTokens = 4096
    let temperature = 0.7
    let streamingEnabled = true
}
```

#### Generate Suggestions
```swift
// Request
struct SuggestionRequest {
    let context: PlanningContext
    let suggestionsType: SuggestionsType
    let maxSuggestions: Int = 5
}

struct PlanningContext {
    let currentDay: Date
    let existingEvents: [Event]
    let userPreferences: UserPreferences
    let recentActivity: [ActivitySummary]
    let weatherData: WeatherInfo?
    let pillars: [Pillar]
    let activeGoals: [Goal]
    let availableTimeSlots: [TimeSlot]
}

enum SuggestionsType {
    case dailyPlanning
    case gapFiller
    case chainSuggestions
    case backfill
}

// Response
struct SuggestionResponse {
    let suggestions: [Suggestion]
    let confidence: Double
    let processingTime: TimeInterval
    let explanation: String
}

struct Suggestion {
    let id: String
    let type: SuggestionType
    let content: SuggestionContent
    let explanation: String
    let confidence: Double
    let suggestedTimeSlot: TimeSlot?
}

enum SuggestionType {
    case event
    case chain
    case pillarActivity
    case goalTask
}

// API Method
protocol AIServiceProtocol {
    func generateSuggestions(request: SuggestionRequest) async throws -> SuggestionResponse
}
```

#### Chain Suggestions
```swift
// Request
struct ChainSuggestionRequest {
    let contextEvent: Event
    let position: ChainPosition
    let availableTime: TimeInterval
    let locationContext: String?
}

enum ChainPosition {
    case before
    case after
}

// Response
struct ChainSuggestionResponse {
    let suggestions: [ChainSuggestion]
    let processingTime: TimeInterval
}

struct ChainSuggestion {
    let id: String
    let name: String
    let blocks: [ChainBlock]
    let totalDuration: TimeInterval
    let explanation: String
    let confidence: Double
}
```

#### Backfill Generation
```swift
// Request
struct BackfillRequest {
    let targetDate: Date
    let knownEvents: [Event]
    let hints: [String]
    let userPatterns: [UserPattern]
}

struct UserPattern {
    let type: PatternType
    let frequency: Frequency
    let timeRange: TimeRange
    let confidence: Double
}

enum PatternType {
    case meal
    case commute
    case exercise
    case work
    case personal
}

// Response
struct BackfillResponse {
    let suggestedEvents: [Event]
    let confidence: Double
    let gaps: [TimeSlot]
    let explanation: String
}
```

#### Voice Processing
```swift
// Request
struct VoiceProcessingRequest {
    let audioData: Data
    let context: ConversationContext?
}

struct ConversationContext {
    let previousMessages: [AIMessage]
    let currentView: ViewContext
    let selectedEvents: [Event]
}

// Response  
struct VoiceProcessingResponse {
    let transcription: String
    let intent: Intent
    let response: String
    let suggestions: [Suggestion]?
}

struct Intent {
    let type: IntentType
    let confidence: Double
    let parameters: [String: Any]
}

enum IntentType {
    case createEvent
    case modifySchedule
    case askQuestion
    case createChain
    case setReminder
    case updateGoal
}
```

### 2. Calendar Service API

#### EventKit Integration
```swift
protocol CalendarServiceProtocol {
    func requestAccess() async throws -> Bool
    func fetchEvents(for dateRange: DateInterval) async throws -> [Event]
    func fetchCalendars() async throws -> [Calendar]
    func createEvent(_ event: EventRequest) async throws -> Event
    func updateEvent(_ event: Event) async throws -> Event
    func deleteEvent(id: String) async throws
    func commitBatch(_ operations: [CalendarOperation]) async throws -> BatchResult
}

// Request Models
struct EventRequest {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let calendarId: String
    let url: URL?
    let attendees: [String]?
}

struct CalendarOperation {
    let type: OperationType
    let eventId: String?
    let eventRequest: EventRequest?
}

enum OperationType {
    case create
    case update
    case delete
}

// Response Models
struct BatchResult {
    let successful: [String] // Event IDs
    let failed: [FailedOperation]
}

struct FailedOperation {
    let operation: CalendarOperation
    let error: Error
}
```

#### Conflict Resolution
```swift
struct ConflictResolution {
    let conflicts: [ScheduleConflict]
    let resolution: ResolutionStrategy
}

struct ScheduleConflict {
    let existingEvent: Event
    let proposedEvent: Event
    let conflictType: ConflictType
    let severity: ConflictSeverity
}

enum ConflictType {
    case timeOverlap
    case locationConflict
    case travelTimeViolation
    case pillarRuleViolation
}

enum ConflictSeverity {
    case warning
    case error
    case blocking
}
```

### 3. Data Service API

#### Repository Pattern
```swift
protocol RepositoryProtocol {
    associatedtype Entity: Codable & Identifiable
    
    func fetchAll() async throws -> [Entity]
    func fetch(id: String) async throws -> Entity?
    func fetch(predicate: NSPredicate) async throws -> [Entity]
    func save(_ entity: Entity) async throws -> Entity
    func delete(id: String) async throws
    func delete(_ entity: Entity) async throws
}

// Specific Repository Protocols
protocol EventRepository: RepositoryProtocol where Entity == Event {
    func fetchEvents(for dateRange: DateInterval) async throws -> [Event]
    func fetchStagedEvents() async throws -> [Event]
    func commitStaged(eventIds: [String]) async throws -> [Event]
    func stageSuggestions(_ suggestions: [Suggestion]) async throws
}

protocol ChainRepository: RepositoryProtocol where Entity == Chain {
    func fetchUserChains() async throws -> [Chain]
    func fetchTemplates() async throws -> [Chain]
    func incrementUsage(chainId: String) async throws
    func promoteToRoutine(chainId: String) async throws -> Routine
}
```

#### Transaction Management
```swift
struct Transaction {
    let id: String
    let operations: [DatabaseOperation]
    let timestamp: Date
    let rollbackData: [String: Any]?
}

struct DatabaseOperation {
    let type: OperationType
    let tableName: String
    let recordId: String
    let data: [String: Any]
}

protocol TransactionManager {
    func beginTransaction() async throws -> Transaction
    func commitTransaction(_ transaction: Transaction) async throws
    func rollbackTransaction(_ transaction: Transaction) async throws
}
```

## External Integration APIs

### 1. Speech Framework Integration

#### Speech Recognition
```swift
struct SpeechRecognitionConfig {
    let locale: Locale = Locale.current
    let taskHint: SFSpeechRecognitionTaskHint = .dictation
    let shouldReportPartialResults: Bool = true
    let requiresOnDeviceRecognition: Bool = true
}

protocol SpeechServiceProtocol {
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus
    func startRecording() throws
    func stopRecording()
    func transcribe(audioFileURL: URL) async throws -> String
}

// Delegate Protocol
protocol SpeechServiceDelegate: AnyObject {
    func speechService(_ service: SpeechService, didReceivePartialTranscription: String)
    func speechService(_ service: SpeechService, didCompleteTranscription: String)
    func speechService(_ service: SpeechService, didEncounterError: Error)
}
```

#### Text-to-Speech
```swift
struct TTSConfig {
    let voice: AVSpeechSynthesisVoice?
    let rate: Float = 0.5
    let pitchMultiplier: Float = 1.0
    let volume: Float = 0.8
}

protocol TTSServiceProtocol {
    func speak(text: String, config: TTSConfig?) async throws
    func stopSpeaking()
    func pauseSpeaking()
    func resumeSpeaking()
    var isSpeaking: Bool { get }
}
```

### 2. Weather Integration (Optional)

```swift
struct WeatherRequest {
    let location: CLLocation
    let date: Date
    let includeHourly: Bool = true
}

struct WeatherResponse {
    let current: CurrentWeather
    let hourly: [HourlyWeather]?
    let alerts: [WeatherAlert]
}

struct CurrentWeather {
    let temperature: Double
    let condition: WeatherCondition
    let humidity: Double
    let windSpeed: Double
    let visibility: Double
}

enum WeatherCondition: String, CaseIterable {
    case clear = "clear"
    case cloudy = "cloudy"  
    case rain = "rain"
    case snow = "snow"
    case storm = "storm"
    case fog = "fog"
}
```

## WebSocket/Real-time Communication

### Action Bar Streaming
```swift
struct StreamingResponse {
    let messageId: String
    let chunk: String
    let isComplete: Bool
    let metadata: StreamingMetadata?
}

struct StreamingMetadata {
    let tokenCount: Int
    let processingTime: TimeInterval
    let confidence: Double?
}

protocol StreamingDelegate: AnyObject {
    func didReceiveChunk(_ chunk: StreamingResponse)
    func didCompleteStream(messageId: String, fullContent: String)
    func didEncounterError(_ error: Error, messageId: String)
}
```

## LM Studio API Integration

### Chat Completions
```http
POST http://localhost:1234/v1/chat/completions
Content-Type: application/json

{
    "model": "local-model",
    "messages": [
        {
            "role": "system",
            "content": "You are a helpful scheduling assistant."
        },
        {
            "role": "user", 
            "content": "Suggest activities for tomorrow morning"
        }
    ],
    "temperature": 0.7,
    "max_tokens": 1000,
    "stream": true
}
```

### Response Format
```json
{
    "id": "chatcmpl-abc123",
    "object": "chat.completion",
    "created": 1699472640,
    "model": "local-model",
    "choices": [
        {
            "index": 0,
            "message": {
                "role": "assistant",
                "content": "Here are some morning activity suggestions..."
            },
            "finish_reason": "stop"
        }
    ],
    "usage": {
        "prompt_tokens": 56,
        "completion_tokens": 120,
        "total_tokens": 176
    }
}
```

### Streaming Response Format
```json
{
    "id": "chatcmpl-abc123",
    "object": "chat.completion.chunk",
    "created": 1699472640,
    "model": "local-model", 
    "choices": [
        {
            "index": 0,
            "delta": {
                "content": "Here are"
            },
            "finish_reason": null
        }
    ]
}
```

## Error Handling Patterns

### Standard Error Response
```swift
struct APIError: Error, Codable {
    let code: String
    let message: String
    let details: [String: Any]?
    let timestamp: Date
    let recoverable: Bool
}

enum ServiceError: Error {
    case networkError(underlying: Error)
    case authenticationFailed
    case rateLimitExceeded
    case serviceUnavailable
    case invalidRequest(message: String)
    case dataCorrupted
    case modelNotLoaded
    case permissionDenied
}
```

### Error Recovery Strategies
```swift
protocol ErrorRecoveryStrategy {
    func canRecover(from error: Error) -> Bool
    func recover(from error: Error) async throws
}

class AIServiceRecovery: ErrorRecoveryStrategy {
    func canRecover(from error: Error) -> Bool {
        switch error {
        case ServiceError.networkError,
             ServiceError.serviceUnavailable:
            return true
        default:
            return false
        }
    }
    
    func recover(from error: Error) async throws {
        // Retry with exponential backoff
        // Fall back to cached responses
        // Switch to offline mode
    }
}
```

## Rate Limiting & Throttling

### Request Rate Limiting
```swift
class RateLimiter {
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private var requestTimes: [Date] = []
    
    func allowRequest() -> Bool {
        let now = Date()
        requestTimes = requestTimes.filter { 
            now.timeIntervalSince($0) < timeWindow 
        }
        
        if requestTimes.count < maxRequests {
            requestTimes.append(now)
            return true
        }
        return false
    }
}
```

## Performance Monitoring

### API Performance Metrics
```swift
struct PerformanceMetrics {
    let requestId: String
    let endpoint: String
    let startTime: Date
    let endTime: Date
    let responseSize: Int
    let success: Bool
    let error: Error?
}

protocol PerformanceMonitor {
    func recordRequest(_ metrics: PerformanceMetrics)
    func getAverageResponseTime(for endpoint: String) -> TimeInterval?
    func getErrorRate(for endpoint: String) -> Double?
}
```

## Security Considerations

### API Security
```swift
struct SecurityContext {
    let userAuthenticated: Bool
    let permissions: Set<Permission>
    let sessionId: String?
    let encryptionEnabled: Bool
}

enum Permission: String, CaseIterable {
    case readCalendar = "calendar.read"
    case writeCalendar = "calendar.write" 
    case recordAudio = "audio.record"
    case accessMicrophone = "microphone.access"
    case modifyUserData = "user.modify"
}
```

This comprehensive API specification covers all the request/response patterns needed to build the Day Planner app according to the PRD requirements.
