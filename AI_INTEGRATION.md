# AI Integration Guide

## Overview

This document details the complete integration with LM Studio and local AI processing, including prompt engineering, context management, and performance optimization for the Day Planner app.

## LM Studio Integration

### Setup and Configuration

#### Model Selection
```swift
struct AIModelConfig {
    // Primary model for production
    static let primaryModel = "microsoft/DialoGPT-medium" // For development
    static let productionModel = "NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO" // 20B+ for production
    
    // Configuration parameters
    static let maxTokens = 4096
    static let temperature = 0.7
    static let topP = 0.9
    static let streamingEnabled = true
    static let contextWindow = 8192
}
```

#### Connection Manager
```swift
@MainActor
class LMStudioConnection: ObservableObject {
    @Published var isConnected = false
    @Published var modelInfo: ModelInfo?
    @Published var isLoading = false
    
    private let baseURL = "http://localhost:1234"
    private var urlSession: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.urlSession = URLSession(configuration: config)
    }
    
    func connect() async throws {
        let modelsURL = URL(string: "\(baseURL)/v1/models")!
        let (data, _) = try await urlSession.data(from: modelsURL)
        
        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        modelInfo = modelsResponse.data.first
        isConnected = true
    }
    
    func healthCheck() async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/v1/models")!
            let (_, response) = try await urlSession.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
```

### Core AI Service Implementation

```swift
class AIService: ObservableObject {
    private let connection = LMStudioConnection()
    private let contextManager = ContextManager()
    private let promptEngine = PromptEngine()
    private let responseParser = ResponseParser()
    
    // MARK: - Main Generation Methods
    
    func generateSuggestions(
        context: PlanningContext,
        type: SuggestionsType = .dailyPlanning
    ) async throws -> SuggestionResponse {
        
        let prompt = promptEngine.buildPrompt(for: type, context: context)
        let response = try await generateCompletion(
            prompt: prompt,
            streaming: true,
            maxTokens: 1500
        )
        
        return try responseParser.parseSuggestions(from: response.content)
    }
    
    func generateChainSuggestions(
        contextEvent: Event,
        position: ChainPosition,
        availableTime: TimeInterval
    ) async throws -> [ChainSuggestion] {
        
        let context = ChainContext(
            event: contextEvent,
            position: position,
            availableTime: availableTime,
            userPreferences: await contextManager.getUserPreferences(),
            recentChains: await contextManager.getRecentChains()
        )
        
        let prompt = promptEngine.buildChainPrompt(context: context)
        let response = try await generateCompletion(prompt: prompt, maxTokens: 800)
        
        return try responseParser.parseChainSuggestions(from: response.content)
    }
    
    func generateBackfill(
        for date: Date,
        knownEvents: [Event],
        hints: [String]
    ) async throws -> BackfillResponse {
        
        let patterns = await contextManager.getUserPatterns(around: date)
        let context = BackfillContext(
            date: date,
            knownEvents: knownEvents,
            hints: hints,
            patterns: patterns
        )
        
        let prompt = promptEngine.buildBackfillPrompt(context: context)
        let response = try await generateCompletion(prompt: prompt, maxTokens: 2000)
        
        return try responseParser.parseBackfill(from: response.content)
    }
    
    // MARK: - Core Generation Engine
    
    private func generateCompletion(
        prompt: String,
        streaming: Bool = false,
        maxTokens: Int = 1000
    ) async throws -> AIResponse {
        
        let messages = [
            ChatMessage(role: .system, content: SystemPrompts.base),
            ChatMessage(role: .user, content: prompt)
        ]
        
        let request = ChatCompletionRequest(
            model: AIModelConfig.primaryModel,
            messages: messages,
            temperature: AIModelConfig.temperature,
            maxTokens: maxTokens,
            stream: streaming
        )
        
        if streaming {
            return try await generateStreamingCompletion(request: request)
        } else {
            return try await generateStandardCompletion(request: request)
        }
    }
    
    private func generateStreamingCompletion(
        request: ChatCompletionRequest
    ) async throws -> AIResponse {
        
        let url = URL(string: "\(connection.baseURL)/v1/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (stream, _) = try await URLSession.shared.bytes(for: urlRequest)
        
        var fullContent = ""
        let startTime = Date()
        
        for try await line in stream.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            
            guard jsonString != "[DONE]" else { break }
            
            let chunk = try JSONDecoder().decode(StreamingChunk.self, from: jsonString.data(using: .utf8)!)
            
            if let content = chunk.choices.first?.delta.content {
                fullContent += content
                
                // Emit intermediate updates for UI
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .aiChunkReceived,
                        object: StreamingUpdate(
                            content: content,
                            fullContent: fullContent,
                            isComplete: false
                        )
                    )
                }
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return AIResponse(
            content: fullContent,
            processingTime: processingTime,
            tokenCount: estimateTokenCount(fullContent)
        )
    }
}
```

## Prompt Engineering

### System Prompts
```swift
struct SystemPrompts {
    static let base = """
    You are an intelligent scheduling assistant for a day-planning app. You help users organize their time effectively while respecting their preferences and constraints.
    
    Key principles:
    - Suggest realistic, actionable activities
    - Consider time constraints and transitions
    - Respect user preferences and patterns
    - Provide clear, one-line explanations
    - Be concise and practical
    
    Always respond in valid JSON format as specified in the user prompt.
    """
    
    static let chainBuilder = """
    You are an expert at creating activity chains - sequences of related activities that flow naturally together.
    
    Guidelines for chains:
    - Consider natural transitions between activities
    - Include appropriate buffer time
    - Suggest realistic durations
    - Account for location changes
    - Consider energy levels and focus requirements
    """
    
    static let backfillSpecialist = """
    You are analyzing past days to reconstruct what likely happened based on patterns and hints.
    
    Guidelines:
    - Use typical daily patterns (meals, commute, work blocks)
    - Consider user's historical data
    - Fill gaps logically
    - Account for weekday vs weekend differences
    - Be conservative with assumptions
    """
}
```

### Dynamic Prompt Building
```swift
class PromptEngine {
    func buildPrompt(for type: SuggestionsType, context: PlanningContext) -> String {
        switch type {
        case .dailyPlanning:
            return buildDailyPlanningPrompt(context: context)
        case .gapFiller:
            return buildGapFillerPrompt(context: context)
        case .chainSuggestions:
            return buildChainSuggestionsPrompt(context: context)
        case .backfill:
            return buildBackfillPrompt(context: context)
        }
    }
    
    private func buildDailyPlanningPrompt(context: PlanningContext) -> String {
        let timeContext = formatTimeContext(context.availableSlots)
        let preferenceContext = formatPreferences(context.userPreferences)
        let goalContext = formatActiveGoals(context.activeGoals)
        let weatherContext = context.weather.map(formatWeatherContext) ?? ""
        
        return """
        Plan suggestions for \(context.currentDay.formatted(.dateTime.weekday().month().day())).
        
        Available time slots:
        \(timeContext)
        
        User preferences:
        \(preferenceContext)
        
        Active goals:
        \(goalContext)
        
        \(weatherContext)
        
        Existing events:
        \(formatExistingEvents(context.existingEvents))
        
        Suggest 3-5 activities that would be valuable for these time slots.
        
        Response format:
        {
            "suggestions": [
                {
                    "title": "Activity name",
                    "duration": 60,
                    "explanation": "One-line reason why this is suggested",
                    "timeSlot": {
                        "start": "10:00",
                        "end": "11:00"
                    },
                    "type": "pillar_activity|goal_task|routine|new_activity",
                    "confidence": 0.8,
                    "pillarId": "optional_pillar_id",
                    "goalId": "optional_goal_id"
                }
            ]
        }
        """
    }
    
    private func buildChainPrompt(context: ChainContext) -> String {
        let eventContext = formatEvent(context.event)
        let positionText = context.position == .before ? "before" : "after"
        let timeText = formatDuration(context.availableTime)
        
        return """
        Suggest activity chains to add \(positionText) this event:
        \(eventContext)
        
        Available time: \(timeText)
        
        Recent chains user has created:
        \(formatRecentChains(context.recentChains))
        
        Suggest 3-5 chains that would complement this event.
        
        Response format:
        {
            "chains": [
                {
                    "name": "Chain name",
                    "blocks": [
                        {
                            "title": "Block name",
                            "duration": 30,
                            "type": "activity|break|transition"
                        }
                    ],
                    "explanation": "Why this chain works well here",
                    "confidence": 0.8
                }
            ]
        }
        """
    }
}
```

### Context Management
```swift
class ContextManager {
    private let userKnowledgeRepo: UserKnowledgeRepository
    private let eventRepo: EventRepository
    private let preferenceRepo: PreferenceRepository
    
    func buildPlanningContext(for date: Date) async -> PlanningContext {
        async let events = eventRepo.fetchEvents(
            for: DateInterval(start: date.startOfDay, end: date.endOfDay)
        )
        async let preferences = getUserPreferences()
        async let patterns = getUserPatterns(around: date)
        async let goals = getActiveGoals()
        async let pillars = getActivePillars()
        async let weather = getWeatherContext(for: date)
        
        let availableSlots = await calculateAvailableSlots(
            events: try events,
            date: date,
            preferences: preferences
        )
        
        return PlanningContext(
            currentDay: date,
            existingEvents: try await events,
            userPreferences: await preferences,
            recentActivity: await getRecentActivity(days: 7),
            weatherData: await weather,
            pillars: await pillars,
            activeGoals: await goals,
            availableTimeSlots: availableSlots
        )
    }
    
    private func getUserPatterns(around date: Date) async -> [UserPattern] {
        // Analyze historical data to extract patterns
        let historicalEvents = try? await eventRepo.fetchEvents(
            for: DateInterval(
                start: date.addingTimeInterval(-30 * 24 * 3600), // 30 days back
                end: date
            )
        )
        
        return PatternAnalyzer.extractPatterns(from: historicalEvents ?? [])
    }
}
```

## Response Parsing

### JSON Response Parser
```swift
class ResponseParser {
    func parseSuggestions(from content: String) throws -> SuggestionResponse {
        // Clean the response - remove markdown, extra whitespace
        let cleanedContent = cleanAIResponse(content)
        
        do {
            let data = cleanedContent.data(using: .utf8) ?? Data()
            let parsed = try JSONDecoder().decode(SuggestionsJSON.self, from: data)
            
            let suggestions = parsed.suggestions.map { json in
                Suggestion(
                    id: UUID().uuidString,
                    type: SuggestionType(rawValue: json.type) ?? .event,
                    content: SuggestionContent(
                        title: json.title,
                        duration: TimeInterval(json.duration * 60),
                        description: json.explanation
                    ),
                    explanation: json.explanation,
                    confidence: json.confidence,
                    suggestedTimeSlot: json.timeSlot.map { slot in
                        TimeSlot(
                            startTime: parseTime(slot.start),
                            endTime: parseTime(slot.end)
                        )
                    }
                )
            }
            
            return SuggestionResponse(
                suggestions: suggestions,
                confidence: calculateOverallConfidence(suggestions),
                processingTime: 0, // Will be set by caller
                explanation: "Generated \(suggestions.count) suggestions"
            )
            
        } catch {
            // Fallback parsing for malformed JSON
            return try fallbackParsing(content: content)
        }
    }
    
    private func cleanAIResponse(_ content: String) -> String {
        // Remove markdown code blocks
        let withoutMarkdown = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        
        // Extract JSON from response
        if let jsonStart = withoutMarkdown.range(of: "{"),
           let jsonEnd = withoutMarkdown.range(of: "}", options: .backwards) {
            return String(withoutMarkdown[jsonStart.lowerBound...jsonEnd.upperBound])
        }
        
        return withoutMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

## Performance Optimization

### Streaming Implementation
```swift
class StreamingAIService {
    private var currentStream: AsyncThrowingStream<String, Error>?
    
    func generateWithStreaming(
        prompt: String,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        
        do {
            let request = buildStreamingRequest(prompt: prompt)
            let stream = try await createStream(request: request)
            
            var fullContent = ""
            
            for try await chunk in stream {
                fullContent += chunk
                await MainActor.run {
                    onChunk(chunk)
                }
            }
            
            await MainActor.run {
                onComplete(fullContent)
            }
            
        } catch {
            await MainActor.run {
                onError(error)
            }
        }
    }
}
```

### Caching Strategy
```swift
class AIResponseCache {
    private let cache = NSCache<NSString, CachedResponse>()
    private let maxAge: TimeInterval = 3600 // 1 hour
    
    init() {
        cache.countLimit = 100 // Max 100 cached responses
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB limit
    }
    
    func getCachedResponse(for key: String) -> CachedResponse? {
        guard let cached = cache.object(forKey: key as NSString),
              Date().timeIntervalSince(cached.timestamp) < maxAge else {
            return nil
        }
        return cached
    }
    
    func cacheResponse(_ response: AIResponse, for key: String) {
        let cached = CachedResponse(
            response: response,
            timestamp: Date()
        )
        
        cache.setObject(
            cached,
            forKey: key as NSString,
            cost: response.content.count
        )
    }
    
    func generateCacheKey(prompt: String, context: PlanningContext) -> String {
        // Create deterministic key from prompt and context
        let contextHash = context.hashValue
        let promptHash = prompt.hash
        return "\(promptHash)_\(contextHash)"
    }
}
```

### Background Processing
```swift
class BackgroundAIProcessor {
    private let queue = DispatchQueue(label: "ai.background", qos: .utility)
    private let aiService: AIService
    
    func precomputeSuggestions(for date: Date) {
        queue.async {
            Task {
                let context = await self.buildContext(for: date)
                let suggestions = try? await self.aiService.generateSuggestions(
                    context: context,
                    type: .dailyPlanning
                )
                
                if let suggestions = suggestions {
                    await self.cacheSuggestions(suggestions, for: date)
                }
            }
        }
    }
    
    func precomputeChains(for events: [Event]) {
        queue.async {
            for event in events {
                Task {
                    let chains = try? await self.aiService.generateChainSuggestions(
                        contextEvent: event,
                        position: .after,
                        availableTime: 3600 // 1 hour
                    )
                    
                    if let chains = chains {
                        await self.cacheChains(chains, for: event)
                    }
                }
            }
        }
    }
}
```

## Error Handling & Fallbacks

### Robust Error Handling
```swift
enum AIServiceError: LocalizedError {
    case modelNotLoaded
    case connectionFailed
    case responseTimeout
    case invalidResponse(String)
    case rateLimitExceeded
    case contextTooLarge
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "AI model is not loaded in LM Studio"
        case .connectionFailed:
            return "Cannot connect to LM Studio"
        case .responseTimeout:
            return "AI response timed out"
        case .invalidResponse(let details):
            return "Invalid AI response: \(details)"
        case .rateLimitExceeded:
            return "Too many AI requests"
        case .contextTooLarge:
            return "Context exceeds model limits"
        }
    }
    
    var recoveryOptions: [AIRecoveryOption] {
        switch self {
        case .modelNotLoaded:
            return [.startLMStudio, .useCachedResponse]
        case .connectionFailed:
            return [.retry, .useCachedResponse, .offlineMode]
        case .responseTimeout:
            return [.retry, .reduceContext]
        case .invalidResponse:
            return [.retry, .fallbackParser]
        case .rateLimitExceeded:
            return [.waitAndRetry, .useCachedResponse]
        case .contextTooLarge:
            return [.reduceContext, .summarizeContext]
        }
    }
}

enum AIRecoveryOption {
    case retry
    case startLMStudio
    case useCachedResponse  
    case offlineMode
    case waitAndRetry
    case reduceContext
    case summarizeContext
    case fallbackParser
}
```

### Fallback Mechanisms
```swift
class AIServiceWithFallbacks {
    private let primaryService: AIService
    private let cache: AIResponseCache
    private let ruleBasedFallback: RuleBasedSuggestionEngine
    
    func generateSuggestions(
        context: PlanningContext
    ) async throws -> SuggestionResponse {
        
        // Try cached response first
        let cacheKey = cache.generateCacheKey(prompt: "", context: context)
        if let cached = cache.getCachedResponse(for: cacheKey) {
            return cached.response
        }
        
        do {
            // Try AI service
            let response = try await primaryService.generateSuggestions(
                context: context,
                type: .dailyPlanning
            )
            
            // Cache successful response
            cache.cacheResponse(response, for: cacheKey)
            return response
            
        } catch let error as AIServiceError {
            // Try recovery options
            for option in error.recoveryOptions {
                if let recovered = try? await attemptRecovery(option, context: context) {
                    return recovered
                }
            }
            
            // Ultimate fallback: rule-based suggestions
            return ruleBasedFallback.generateSuggestions(context: context)
        }
    }
}
```

## Testing & Validation

### AI Service Testing
```swift
class AIServiceTests: XCTestCase {
    var aiService: AIService!
    var mockConnection: MockLMStudioConnection!
    
    override func setUp() {
        super.setUp()
        mockConnection = MockLMStudioConnection()
        aiService = AIService(connection: mockConnection)
    }
    
    func testSuggestionGeneration() async throws {
        // Setup mock response
        mockConnection.mockResponse = """
        {
            "suggestions": [
                {
                    "title": "Morning workout",
                    "duration": 45,
                    "explanation": "Great way to start the day",
                    "confidence": 0.8,
                    "type": "pillar_activity"
                }
            ]
        }
        """
        
        let context = createTestContext()
        let response = try await aiService.generateSuggestions(
            context: context,
            type: .dailyPlanning
        )
        
        XCTAssertEqual(response.suggestions.count, 1)
        XCTAssertEqual(response.suggestions.first?.content.title, "Morning workout")
    }
    
    func testStreamingResponse() async throws {
        var receivedChunks: [String] = []
        
        await aiService.generateWithStreaming(
            prompt: "Test prompt",
            onChunk: { chunk in
                receivedChunks.append(chunk)
            },
            onComplete: { full in
                XCTAssertEqual(full, receivedChunks.joined())
            },
            onError: { error in
                XCTFail("Unexpected error: \(error)")
            }
        )
        
        XCTAssertFalse(receivedChunks.isEmpty)
    }
}
```

This comprehensive AI integration guide provides everything needed to implement the local AI features while maintaining performance, reliability, and user experience standards defined in the PRD.
