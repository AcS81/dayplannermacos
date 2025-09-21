//
//  AIService.swift
//  DayPlanner
//
//  Simple local AI service for LM Studio integration
//

import Foundation
import AVFoundation

// MARK: - Audio Permission Types

enum AudioPermissionStatus: Codable {
    case undetermined
    case denied
    case granted
    
    var description: String {
        switch self {
        case .undetermined: return "Not Determined"
        case .denied: return "Denied"
        case .granted: return "Granted"
        }
    }
}

// MARK: - Whisper Service

/// Whisper-based speech recognition service
@MainActor
class WhisperService: ObservableObject {
    @Published var isProcessing = false
    @Published var lastError: String?
    
    private let session: URLSession
    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    /// Transcribe audio file using Whisper API
    func transcribe(audioFileURL: URL, apiKey: String) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        guard !apiKey.isEmpty else {
            throw WhisperError.missingAPIKey
        }
        
        // Prepare multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let audioData = try Data(contentsOf: audioFileURL)
        let httpBody = createMultipartBody(boundary: boundary, audioData: audioData, fileName: "audio.m4a")
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WhisperError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw WhisperError.apiError(message)
                }
                throw WhisperError.httpError(httpResponse.statusCode)
            }
            
            let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
            return result.text
            
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    /// Create multipart form data
    private func createMultipartBody(boundary: String, audioData: Data, fileName: String) -> Data {
        var body = Data()
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add language field (optional)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}

// MARK: - Whisper Models

struct WhisperResponse: Codable {
    let text: String
}

enum WhisperError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Whisper API key not configured"
        case .invalidResponse:
            return "Invalid response from Whisper API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        case .fileNotFound:
            return "Audio file not found"
        }
    }
}

// MARK: - AI Service

/// Local AI service that communicates with LM Studio
@MainActor
class AIService: ObservableObject {
    @Published var isConnected = false
    @Published var isProcessing = false
    @Published var lastResponseTime: TimeInterval = 0
    
    private let baseURL = "http://localhost:1234"
    private let session: URLSession
    
    // Smart confidence thresholds for different actions
    private let confidenceThresholds = AIConfidenceThresholds()
    
    // Pattern learning integration
    private var patternEngine: PatternLearningEngine?
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false // Don't wait indefinitely
        config.allowsCellularAccess = false // Local network only
        self.session = URLSession(configuration: config)
        
        Task {
            await checkConnection()
            
            // Set up periodic connection monitoring
            await startConnectionMonitoring()
        }
    }
    
    // MARK: - Pattern Learning Integration
    
    func setPatternEngine(_ patternEngine: PatternLearningEngine) {
        self.patternEngine = patternEngine
    }
    
    private func startConnectionMonitoring() async {
        // Check connection every 30 seconds
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                await checkConnection()
            }
        }
    }
    
    // MARK: - Connection Management
    
    func checkConnection() async {
        do {
            let url = URL(string: "\(baseURL)/v1/models")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0 // Shorter timeout for connection check
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await MainActor.run {
                    isConnected = true
                }
                print("✅ AI Service connected to LM Studio at \(baseURL)")
            } else {
                await MainActor.run {
                    isConnected = false
                }
                print("❌ AI Service: HTTP error \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            await MainActor.run {
                isConnected = false
            }
            print("❌ AI Service connection failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Message Processing
    
    func processMessage(_ message: String, context: DayContext) async throws -> AIResponse {
        guard isConnected else {
            throw AIError.notConnected
        }
        
        isProcessing = true
        let startTime = Date()
        
        defer {
            isProcessing = false
            lastResponseTime = Date().timeIntervalSince(startTime)
        }
        
        // First, analyze the message to determine the best action type
        let actionAnalysis = try await analyzeMessageIntent(message, context: context)
        
        // Record this interaction for pattern learning
        recordInteractionForLearning(message: message, analysis: actionAnalysis, context: context)
        
        // Use appropriate processing based on confidence and intent
        let response: AIResponse
        switch actionAnalysis.recommendedAction {
        case .createEvent:
            response = try await processEventCreation(message, context: context, analysis: actionAnalysis)
        case .createGoal:
            response = try await processGoalCreation(message, context: context, analysis: actionAnalysis)
        case .createPillar:
            response = try await processPillarCreation(message, context: context, analysis: actionAnalysis)
        case .createChain:
            response = try await processChainCreation(message, context: context, analysis: actionAnalysis)
        case .suggestActivities:
            response = try await processActivitySuggestions(message, context: context, analysis: actionAnalysis)
        case .generalChat:
            response = try await processGeneralChat(message, context: context, analysis: actionAnalysis)
        }
        
        // Record the response for future learning
        recordResponseForLearning(response: response, originalMessage: message)
        
        return response
    }
    
    // MARK: - Pattern Learning Integration
    
    private func recordInteractionForLearning(message: String, analysis: MessageActionAnalysis, context: DayContext) {
        guard let patternEngine = patternEngine else { return }
        
        // Create behavior event for this interaction
        let behaviorEvent = BehaviorEvent(
            .blockCreated(TimeBlockData(
                id: UUID().uuidString,
                title: analysis.extractedEntities["activity"] ?? "AI Interaction",
                emoji: "🤖",
                energy: context.currentEnergy,
                duration: 0, // This is an interaction, not a time block
                period: getCurrentTimePeriod()
            )),
            context: EventContext(
                energyLevel: context.currentEnergy,
                mood: context.mood,
                weatherCondition: context.weatherContext
            )
        )
        
        patternEngine.recordBehavior(behaviorEvent)
    }
    
    private func recordResponseForLearning(response: AIResponse, originalMessage: String) {
        guard let patternEngine = patternEngine else { return }
        
        // Record successful AI actions for pattern improvement
        if let actionType = response.actionType, response.confidence > 0.7 {
            let behaviorEvent = BehaviorEvent(
                .suggestionAccepted(SuggestionData(
                    title: originalMessage.prefix(50).description,
                    emoji: "🤖",
                    energy: .daylight,
                    duration: 0,
                    confidence: response.confidence
                )),
                context: EventContext()
            )
            
            patternEngine.recordBehavior(behaviorEvent)
        }
    }
    
    private func getCurrentTimePeriod() -> TimePeriod {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return .morning
        case 12..<18: return .afternoon
        default: return .evening
        }
    }
    
    func generateSuggestions(for context: DayContext) async throws -> [Suggestion] {
        let message = "Suggest some activities for my day"
        let response = try await processMessage(message, context: context)
        return response.suggestions
    }
    
    /// Get suggestions based on user message and context (for Action Bar)
    func getSuggestions(for message: String, context: DayContext) async throws -> [Suggestion] {
        isProcessing = true
        defer { isProcessing = false }
        
        // Use the existing processMessage method to get AI response
        let response = try await processMessage(message, context: context)
        return response.suggestions
    }
    
    /// Generate chain suggestions based on event context and available gaps
    func generateChains(prompt: String, eventContext: TimeBlock, availableGapBefore: TimeInterval, availableGapAfter: TimeInterval) async throws -> [Chain] {
        isProcessing = true
        defer { isProcessing = false }
        
        let completion = try await generateCompletion(prompt: prompt)
        return try parseChainResponse(completion)
    }
    
    // MARK: - Smart Processing Methods
    
    private func analyzeMessageIntent(_ message: String, context: DayContext) async throws -> MessageActionAnalysis {
        // Get pattern-based insights
        let patternInsights = getPatternInsights()
        
        let intentAnalysisPrompt = """
        SMART INTENT ANALYSIS: Analyze this user message to determine the BEST action with HIGH ACCURACY: "\(message)"
        
        Context:
        - Current time: \(context.date.formatted(.dateTime.hour().minute()))
        - Existing blocks: \(context.existingBlocks.count)
        - Available time: \(Int(context.availableTime/3600)) hours
        - Current energy: \(context.currentEnergy.description)
        - Mood: \(context.mood.description)
        - Active pillars: \(context.actionablePillars.map(\.name).joined(separator: ", "))
        - Guiding principles: \(context.pillarGuidance.joined(separator: "; "))
        
        User Pattern Intelligence:
        \(patternInsights)
        
        SMART ANALYSIS GUIDELINES:
        1. SCHEDULING INDICATORS: "schedule", "book", "add", "create", "plan", "set up", "at 3pm", "tomorrow", "in 1 hour"
        2. GOAL INDICATORS: "want to achieve", "goal", "objective", "hope to", "work towards", "long-term"
        3. PILLAR INDICATORS: "routine", "habit", "principle", "always", "never", "believe in", "recurring"
        4. CHAIN INDICATORS: "sequence", "flow", "then", "after that", "routine", "steps"
        5. SUGGESTION INDICATORS: "what should", "ideas", "suggestions", "what to do", "recommend"
        
        CONFIDENCE BOOST FACTORS:
        - Specific time mentioned (+0.2)
        - Duration mentioned (+0.15)
        - Clear action verb (+0.1)
        - Matches user patterns (+0.1)
        - Urgency indicators (+0.1)
        
        Respond in this EXACT JSON format:
        {
            "intent": "Precise description of user intent",
            "confidence": 0.85,
            "recommendedAction": "create_event",
            "extractedEntities": {
                "activity": "specific activity name",
                "time": "extracted time or null",
                "duration": "extracted duration or estimated",
                "importance": "high/medium/low",
                "type": "actionable/principle for pillars"
            },
            "urgency": "high",
            "contextAlignment": 0.9,
            "patternAlignment": 0.8
        }
        
        UPDATED Action thresholds for better UX:
        - create_event: Scheduling specific activity (confidence ≥ 0.7)
        - create_goal: Long-term objective mentioned (confidence ≥ 0.8)
        - create_pillar: Recurring principle/habit (confidence ≥ 0.85)
        - create_chain: Multiple linked activities (confidence ≥ 0.75)
        - suggest_activities: Asking for ideas (confidence ≥ 0.6)
        - general_chat: Everything else (confidence < 0.6)
        
        BE BOLD with confidence when indicators are clear. Users want direct action, not constant suggestions.
        """
        
        let response = try await generateCompletion(prompt: intentAnalysisPrompt)
        return try parseActionAnalysis(response)
    }
    
    private func getPatternInsights() -> String {
        guard let patternEngine = patternEngine else {
            return "Pattern learning system initializing. Building intelligence about user preferences."
        }
        
        var insights: [String] = []
        
        // Add intelligence quality assessment
        let metrics = patternEngine.uiMetrics
        insights.append("Intelligence Quality: \(metrics.analysisQuality.description)")
        
        // Add high-confidence patterns with actionable details
        let highConfidencePatterns = patternEngine.detectedPatterns.filter { $0.confidence > 0.7 }
        if !highConfidencePatterns.isEmpty {
            insights.append("\nHigh-confidence patterns (\(highConfidencePatterns.count)):")
            for pattern in highConfidencePatterns.prefix(3) {
                insights.append("- \(pattern.emoji) \(pattern.title): \(pattern.suggestion)")
            }
        }
        
        // Add current smart recommendation with context
        if let recommendation = patternEngine.currentRecommendation {
            insights.append("\nSmart Recommendation: \(recommendation)")
        }
        
        // Add actionable insights with priority
        let actionableInsights = patternEngine.actionableInsights.filter { !$0.isExpired }.sorted { $0.priority > $1.priority }
        if !actionableInsights.isEmpty {
            insights.append("\nActionable Insights:")
            for insight in actionableInsights.prefix(2) {
                let priorityIcon = insight.priority >= 4 ? "🔥" : "💡"
                insights.append("- \(priorityIcon) \(insight.suggestedAction)")
            }
        }
        
        // Add success patterns that should boost confidence
        let successPatterns = patternEngine.detectedPatterns.filter { $0.confidence > 0.8 && $0.actionType == .opportunity }
        if !successPatterns.isEmpty {
            insights.append("\nSuccess Patterns (boost confidence for similar requests):")
            for pattern in successPatterns.prefix(2) {
                insights.append("- \(pattern.title) works well (\(Int(pattern.confidence * 100))% confidence)")
            }
        }
        
        // Add user preferences from patterns
        let preferences = extractUserPreferences()
        if !preferences.isEmpty {
            insights.append("\nUser Preferences: \(preferences)")
        }
        
        return insights.isEmpty ? "Building pattern intelligence. First few interactions help establish preferences." : insights.joined(separator: "\n")
    }
    
    private func extractUserPreferences() -> String {
        guard let patternEngine = patternEngine else { return "" }
        
        var preferences: [String] = []
        
        // Extract timing preferences
        let timePatterns = patternEngine.detectedPatterns.filter { $0.type == .temporal }
        if let bestTimePattern = timePatterns.first(where: { $0.confidence > 0.7 }) {
            if case .temporal(let data) = bestTimePattern.data {
                if !data.peakHours.isEmpty {
                    let hours = data.peakHours.prefix(2).map { "\($0):00" }.joined(separator: ", ")
                    preferences.append("Peak hours: \(hours)")
                }
            }
        }
        
        // Extract energy preferences
        let energyPatterns = patternEngine.detectedPatterns.filter { $0.type == .energy }
        if !energyPatterns.isEmpty {
            preferences.append("Has energy-time preferences")
        }
        
        // Extract activity preferences
        let activityPatterns = patternEngine.detectedPatterns.filter { $0.type == .activity }
        if !activityPatterns.isEmpty {
            preferences.append("Follows activity sequences")
        }
        
        return preferences.joined(separator: "; ")
    }
    
    private func processEventCreation(_ message: String, context: DayContext, analysis: MessageActionAnalysis) async throws -> AIResponse {
        let eventCreationPrompt = """
        Create a specific time block/event from this user request: "\(message)"
        
        Context: \(context.summary)
        Extracted entities: \(analysis.extractedEntities)
        Confidence: \(analysis.confidence)
        
        Analyze the message carefully and create a complete event with:
        1. Specific, clear title (max 30 chars)
        2. Smart start time based on context and available slots
        3. Realistic duration (15min - 4 hours)
        4. Energy level matching the activity type
        5. Activity-appropriate emoji
        6. Helpful explanation of timing choice
        
        Energy type mapping:
        - High-focus work, exercise, important meetings: "sunrise" 🌅
        - Regular work, meetings, active tasks: "daylight" ☀️
        - Rest, breaks, casual activities, wind-down: "moonlight" 🌙
        
        Time extraction from message:
        - Look for "at 3pm", "tomorrow", "in 1 hour", "now", etc.
        - Default to next available slot if no time specified
        - Round to 15-minute intervals
        
        Respond in this EXACT JSON format with ALL fields properly filled:
        {
            "response": "I'll create \(analysis.extractedEntities["activity"] ?? "this activity") for you",
            "event": {
                "title": "Specific activity title",
                "startTime": "2024-01-15T07:00:00Z",
                "duration": 1800,
                "energy": "sunrise",
                "emoji": "💪",
                "explanation": "Scheduled for optimal timing based on your context and available time"
            },
            "confidence": \(analysis.confidence)
        }
        
        Choose the best available time slot and energy level for this activity.
        """
        
        let response = try await generateCompletion(prompt: eventCreationPrompt)
        return try parseEventCreationResponse(response, analysis: analysis)
    }
    
    private func processGoalCreation(_ message: String, context: DayContext, analysis: MessageActionAnalysis) async throws -> AIResponse {
        let goalCreationPrompt = """
        Create a comprehensive goal from this user request: "\(message)"
        
        Context: \(context.summary)
        Extracted entities: \(analysis.extractedEntities)
        Confidence: \(analysis.confidence)
        
        Analyze the message and create a SMART goal with:
        1. Specific, clear title (max 30 chars)
        2. Detailed description explaining the outcome
        3. Importance level 1-5 based on urgency/impact indicators
        4. Realistic target date (3-12 months typically)
        5. Initial task breakdown to make it actionable
        6. Appropriate emoji for visual identification
        
        Look for importance indicators:
        - "critical/urgent/essential" = importance 5
        - "important/priority" = importance 4  
        - "want to/should" = importance 3
        - "nice to/would like" = importance 2
        - everything else = importance 3
        
        Respond in this EXACT JSON format with ALL fields properly filled:
        {
            "response": "I'll help you create a goal for \(analysis.extractedEntities["goal"] ?? "this objective")",
            "goal": {
                "title": "Specific goal title",
                "description": "Detailed description of what success looks like",
                "importance": 4,
                "targetDate": "2024-06-01T00:00:00Z",
                "emoji": "🎯 or goal-specific emoji",
                "relatedPillarIds": [],
                "groups": [
                    {
                        "name": "Group name",
                        "tasks": [
                            {
                                "title": "Specific actionable task",
                                "description": "Clear task description with deliverables",
                                "estimatedDuration": 3600,
                                "actionQuality": 4
                            }
                        ]
                    }
                ]
            },
            "confidence": \(analysis.confidence)
        }
        
        Make the goal actionable with concrete first steps. Choose an emoji that matches the goal domain.
        """
        
        let response = try await generateCompletion(prompt: goalCreationPrompt)
        return try parseGoalCreationResponse(response, analysis: analysis)
    }
    
    private func processPillarCreation(_ message: String, context: DayContext, analysis: MessageActionAnalysis) async throws -> AIResponse {
        let pillarCreationPrompt = """
        Create a pillar (core principle or actionable habit) from this user request: "\(message)"
        
        Context: \(context.summary)
        Extracted entities: \(analysis.extractedEntities)
        Confidence: \(analysis.confidence)
        
        Guidelines:
        - actionable: Creates scheduled activities (exercise, meditation, work blocks, etc.)
        - principle: Guides AI decisions but doesn't create events (values, beliefs, life rules)
        
        Analyze the message carefully and determine:
        1. Is this asking for a recurring activity (actionable) or a life principle (principle)?
        2. What's the appropriate frequency for actionable pillars?
        3. What emoji best represents this pillar?
        4. What time windows make sense for actionable pillars?
        
        Respond in this EXACT JSON format with ALL fields populated:
        {
            "response": "I'll create a \(analysis.extractedEntities["pillar_type"] ?? "pillar") for you",
            "pillar": {
                "name": "Specific pillar name (max 20 chars)",
                "description": "Detailed description explaining purpose and benefits",
                "type": "actionable or principle",
                "frequency": "daily, weekly, or as needed",
                "minDuration": 1800,
                "maxDuration": 3600,
                "preferredTimeWindows": [
                    {
                        "startHour": 7,
                        "startMinute": 0,
                        "endHour": 9,
                        "endMinute": 0
                    }
                ],
                "wisdomText": "Core principle text for principle types, null for actionable",
                "emoji": "🏛️ or activity-specific emoji"
            },
            "confidence": \(analysis.confidence)
        }
        
        Make the pillar practical and personally relevant. Choose emoji that matches the activity/principle.
        """
        
        let response = try await generateCompletion(prompt: pillarCreationPrompt)
        return try parsePillarCreationResponse(response, analysis: analysis)
    }
    
    private func processChainCreation(_ message: String, context: DayContext, analysis: MessageActionAnalysis) async throws -> AIResponse {
        let chainCreationPrompt = """
        Create a comprehensive activity chain from this user request: "\(message)"
        
        Context: \(context.summary)
        Extracted entities: \(analysis.extractedEntities)
        Confidence: \(analysis.confidence)
        
        Analyze the message and create a logical sequence with:
        1. Meaningful chain name (max 25 chars)
        2. 2-4 related activities that flow together
        3. Realistic durations (15min - 2 hours per activity)
        4. Appropriate energy progression
        5. Activity-specific emojis
        6. Flow pattern that matches the activities
        
        Energy levels (map to EnergyType):
        - 8-10: High energy, sharp focus (sunrise) 🌅
        - 5-7: Steady energy, sustained work (daylight) ☀️
        - 1-4: Low energy, gentle activities (moonlight) 🌙
        
        Flow patterns:
        - waterfall: Sequential building (prep→work→review)
        - spiral: Circular building (practice→apply→reflect→practice)
        - wave: Rhythm with breaks (work→break→work→break)
        - ripple: Expanding impact (small→medium→large)
        
        Respond in this EXACT JSON format with ALL fields populated:
        {
            "response": "I'll create a chain for \(analysis.extractedEntities["chain_name"] ?? "these activities")",
            "chain": {
                "name": "Descriptive chain name",
                "blocks": [
                    {
                        "title": "Specific activity title",
                        "duration": 1800,
                        "energy": "sunrise",
                        "emoji": "🌅"
                    },
                    {
                        "title": "Next logical activity",
                        "duration": 3600,
                        "energy": "daylight", 
                        "emoji": "💼"
                    }
                ],
                "flowPattern": "waterfall",
                "emoji": "🔗"
            },
            "confidence": \(analysis.confidence)
        }
        
        Make activities flow logically and choose appropriate emojis for each block.
        """
        
        let response = try await generateCompletion(prompt: chainCreationPrompt)
        return try parseChainCreationResponse(response, analysis: analysis)
    }
    
    private func processActivitySuggestions(_ message: String, context: DayContext, analysis: MessageActionAnalysis) async throws -> AIResponse {
        // Use the existing suggestion system but with enhanced context
        let prompt = buildEnhancedSuggestionPrompt(message: message, context: context, analysis: analysis)
        let response = try await generateCompletion(prompt: prompt)
        return try parseEnhancedSuggestionResponse(response, analysis: analysis)
    }
    
    private func processGeneralChat(_ message: String, context: DayContext, analysis: MessageActionAnalysis) async throws -> AIResponse {
        let generalChatPrompt = """
        Respond to this user message in a helpful, encouraging way: "\(message)"
        
        Context: \(context.summary)
        
        Provide a thoughtful response and suggest 1-2 activities if appropriate, but keep confidence low since this is general chat.
        
        Respond in this exact JSON format:
        {
            "response": "Your helpful response",
            "suggestions": [
                {
                    "title": "Optional suggestion",
                    "explanation": "Why this might help",
                    "duration": 1800,
                    "energy": "daylight",
                    "emoji": "💡",
                    "confidence": 0.4
                }
            ],
            "confidence": \(analysis.confidence)
        }
        """
        
        let response = try await generateCompletion(prompt: generalChatPrompt)
        return try parseEnhancedSuggestionResponse(response, analysis: analysis)
    }
    
    // MARK: - Private Methods
    
    private func buildPrompt(message: String, context: DayContext) -> String {
        let pillarGuidanceText = context.pillarGuidance.isEmpty ? 
            "" : "\n\nUser's Core Principles (guide all suggestions):\n\(context.pillarGuidance.joined(separator: "\n"))"
        
        let actionablePillarsText = context.actionablePillars.isEmpty ? 
            "" : "\n\nActionable Pillars to consider:\n\(context.actionablePillars.map { "- \($0.name): \($0.description)" }.joined(separator: "\n"))"
        
        return """
        You are a helpful day planning assistant. The user is planning their day and needs suggestions.
        
        Current context:
        - Date & Time: \(context.date.formatted(.dateTime.weekday().month().day().year().hour().minute()))
        - Current energy: \(context.currentEnergy.description)
        - Existing activities: \(context.existingBlocks.count)
        - Available time: \(Int(context.availableTime/3600)) hours
        - Mood: \(context.mood.description)
        \(context.weatherContext != nil ? "- Weather: \(context.weatherContext!)" : "")\(pillarGuidanceText)\(actionablePillarsText)
        
        User message: "\(message)"
        
        IMPORTANT: Always align suggestions with the user's core principles listed above. Consider:
        - Weather conditions for indoor/outdoor activities
        - User's guiding principles when making any suggestion
        - How actionable pillars might need time slots
        - The user's current energy and mood state
        
        Please provide a helpful response and exactly 2 activity suggestions in this exact JSON format:
        {
            "response": "Your helpful response text that acknowledges their principles",
            "suggestions": [
                {
                    "title": "Activity name",
                    "explanation": "Brief reason why this aligns with their principles and current context",
                    "duration": 60,
                    "energy": "sunrise|daylight|moonlight",
                    "emoji": "📋|💼|🎯|💡|🏃‍♀️|🍽️|etc",
                    "confidence": 0.8
                }
            ]
        }
        
        Keep suggestions principle-aligned, realistic and personalized.
        """
    }
    
    private func generateCompletion(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        
        let requestBody: [String: Any] = [
            "model": "openai/gpt-oss-20b",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a helpful day planning assistant. Always respond with valid JSON."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 1000,
            "stream": false
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.requestFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ AI Service HTTP error \(httpResponse.statusCode)")
            if httpResponse.statusCode == 404 {
                throw AIError.notConnected
            } else {
                throw AIError.requestFailed
            }
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = jsonResponse?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        return content ?? ""
    }
    
    private func parseResponse(_ content: String) throws -> AIResponse {
        // Clean up the response - sometimes models add markdown formatting
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to extract JSON from the response
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let parsed = try JSONDecoder().decode(AIResponseJSON.self, from: jsonData)
            
            let suggestions = parsed.suggestions.prefix(2).map { suggestionJSON in
                Suggestion(
                    title: suggestionJSON.title,
                    duration: TimeInterval(suggestionJSON.duration * 60), // Convert minutes to seconds
                    suggestedTime: Date(), // Will be set when applied
                    energy: EnergyType(rawValue: suggestionJSON.energy) ?? .daylight,
                    emoji: suggestionJSON.emoji,
                    explanation: suggestionJSON.explanation,
                    confidence: suggestionJSON.confidence
                )
            }
            
            return AIResponse(
                text: parsed.response,
                suggestions: suggestions,
                actionType: nil,
                createdItems: nil,
                confidence: 0.7
            )
            
        } catch {
            // Fallback: create a simple response if JSON parsing fails
            return AIResponse(
                text: cleanContent,
                suggestions: [],
                actionType: nil,
                createdItems: nil,
                confidence: 0.3
            )
        }
    }
    
    private func parseChainResponse(_ content: String) throws -> [Chain] {
        // Clean up the response - sometimes models add markdown formatting
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanContent.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let chainJSONArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            var chains: [Chain] = []
            
            for chainJSON in chainJSONArray ?? [] {
                guard let name = chainJSON["name"] as? String,
                      let emoji = chainJSON["emoji"] as? String,
                      let blocksJSON = chainJSON["blocks"] as? [[String: Any]] else {
                    continue
                }
                
                let _ = chainJSON["description"] as? String
                var blocks: [TimeBlock] = []
                
                for blockJSON in blocksJSON {
                    guard let title = blockJSON["title"] as? String,
                          let duration = blockJSON["duration"] as? TimeInterval,
                          let energyLevel = blockJSON["energyLevel"] as? Int,
                          let blockEmoji = blockJSON["emoji"] as? String else {
                        continue
                    }
                    
                    // Map energyLevel to EnergyType
                    let energy: EnergyType = energyLevel >= 8 ? .daylight : 
                                           energyLevel >= 5 ? .sunrise : .moonlight
                    
                    let timeBlock = TimeBlock(
                        title: title,
                        startTime: Date(),
                        duration: duration,
                        energy: energy,
                        emoji: blockEmoji
                    )
                    blocks.append(timeBlock)
                }
                
                let chain = Chain(
                    name: name,
                    blocks: blocks,
                    flowPattern: .waterfall,
                    emoji: emoji
                )
                chains.append(chain)
            }
            
            return chains
        } catch {
            throw AIError.invalidResponse
        }
    }
    
    // MARK: - New Parsing Methods
    
    private func parseActionAnalysis(_ content: String) throws -> MessageActionAnalysis {
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            guard let intent = parsed?["intent"] as? String,
                  let confidence = parsed?["confidence"] as? Double,
                  let actionString = parsed?["recommendedAction"] as? String,
                  let action = AIActionType(rawValue: actionString),
                  let entities = parsed?["extractedEntities"] as? [String: String],
                  let urgencyString = parsed?["urgency"] as? String,
                  let urgency = UrgencyLevel(rawValue: urgencyString),
                  let contextAlignment = parsed?["contextAlignment"] as? Double else {
                throw AIError.invalidResponse
            }
            
            return MessageActionAnalysis(
                intent: intent,
                confidence: confidence,
                recommendedAction: action,
                extractedEntities: entities,
                urgency: urgency,
                contextAlignment: contextAlignment
            )
            
        } catch {
            // Fallback to general chat if parsing fails
            return MessageActionAnalysis(
                intent: "General conversation",
                confidence: 0.3,
                recommendedAction: .generalChat,
                extractedEntities: [:],
                urgency: .low,
                contextAlignment: 0.5
            )
        }
    }
    
    private func parseEventCreationResponse(_ content: String, analysis: MessageActionAnalysis) throws -> AIResponse {
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            guard let response = parsed?["response"] as? String,
                  let eventData = parsed?["event"] as? [String: Any] else {
                throw AIError.invalidResponse
            }
            
            let suggestion = Suggestion(
                title: eventData["title"] as? String ?? "New Activity",
                duration: TimeInterval((eventData["duration"] as? Int ?? 1800)),
                suggestedTime: Date(),
                energy: EnergyType(rawValue: eventData["energy"] as? String ?? "daylight") ?? .daylight,
                emoji: eventData["emoji"] as? String ?? "📋",
                explanation: eventData["explanation"] as? String ?? "AI-generated activity",
                confidence: analysis.confidence
            )
            
            return AIResponse(
                text: response,
                suggestions: [suggestion],
                actionType: .createEvent,
                createdItems: [
                    CreatedItem(
                        type: .event,
                        id: UUID(),
                        title: suggestion.title,
                        data: suggestion
                    )
                ],
                confidence: analysis.confidence
            )
            
        } catch {
            return AIResponse(
                text: "I'll help you schedule that activity",
                suggestions: [],
                actionType: .createEvent,
                createdItems: nil,
                confidence: analysis.confidence
            )
        }
    }
    
    private func parseGoalCreationResponse(_ content: String, analysis: MessageActionAnalysis) throws -> AIResponse {
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            guard let response = parsed?["response"] as? String else {
                throw AIError.invalidResponse
            }
            
            return AIResponse(
                text: response,
                suggestions: [],
                actionType: .createGoal,
                createdItems: [
                    CreatedItem(
                        type: .goal,
                        id: UUID(),
                        title: "New Goal",
                        data: parsed?["goal"] as? [String: Any] ?? [:]
                    )
                ],
                confidence: analysis.confidence
            )
            
        } catch {
            return AIResponse(
                text: "I'll help you create that goal",
                suggestions: [],
                actionType: .createGoal,
                createdItems: nil,
                confidence: analysis.confidence
            )
        }
    }
    
    private func parsePillarCreationResponse(_ content: String, analysis: MessageActionAnalysis) throws -> AIResponse {
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            guard let response = parsed?["response"] as? String,
                  let pillarData = parsed?["pillar"] as? [String: Any] else {
                throw AIError.invalidResponse
            }
            
            // Enhance pillar data with proper defaults
            var enhancedPillarData = pillarData
            
            // Ensure all required fields are present with smart defaults
            if enhancedPillarData["name"] == nil { enhancedPillarData["name"] = "New Pillar" }
            if enhancedPillarData["description"] == nil { enhancedPillarData["description"] = "AI-created pillar" }
            if enhancedPillarData["type"] == nil { enhancedPillarData["type"] = "actionable" }
            if enhancedPillarData["frequency"] == nil { enhancedPillarData["frequency"] = "daily" }
            if enhancedPillarData["minDuration"] == nil { enhancedPillarData["minDuration"] = 1800 }
            if enhancedPillarData["maxDuration"] == nil { enhancedPillarData["maxDuration"] = 3600 }
            if enhancedPillarData["emoji"] == nil { enhancedPillarData["emoji"] = "🏛️" }
            if enhancedPillarData["preferredTimeWindows"] == nil { enhancedPillarData["preferredTimeWindows"] = [] }
            
            return AIResponse(
                text: response,
                suggestions: [],
                actionType: .createPillar,
                createdItems: [
                    CreatedItem(
                        type: .pillar,
                        id: UUID(),
                        title: enhancedPillarData["name"] as? String ?? "New Pillar",
                        data: enhancedPillarData
                    )
                ],
                confidence: analysis.confidence
            )
            
        } catch {
            // Fallback with basic pillar structure
            let fallbackPillarData: [String: Any] = [
                "name": "New Pillar",
                "description": "AI-created pillar",
                "type": "actionable",
                "frequency": "daily",
                "minDuration": 1800,
                "maxDuration": 3600,
                "emoji": "🏛️",
                "preferredTimeWindows": []
            ]
            
            return AIResponse(
                text: "I'll help you create that pillar",
                suggestions: [],
                actionType: .createPillar,
                createdItems: [
                    CreatedItem(
                        type: .pillar,
                        id: UUID(),
                        title: "New Pillar",
                        data: fallbackPillarData
                    )
                ],
                confidence: analysis.confidence
            )
        }
    }
    
    private func parseChainCreationResponse(_ content: String, analysis: MessageActionAnalysis) throws -> AIResponse {
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            guard let response = parsed?["response"] as? String,
                  let chainData = parsed?["chain"] as? [String: Any] else {
                throw AIError.invalidResponse
            }
            
            // Ensure chain data is properly structured
            var enhancedChainData = chainData
            
            // Validate and enhance blocks
            if let blocksData = chainData["blocks"] as? [[String: Any]] {
                let enhancedBlocks = blocksData.map { blockData -> [String: Any] in
                    var enhanced = blockData
                    
                    // Ensure all required fields are present
                    if enhanced["title"] == nil { enhanced["title"] = "Activity" }
                    if enhanced["duration"] == nil { enhanced["duration"] = 1800 }
                    if enhanced["energy"] == nil { enhanced["energy"] = "daylight" }
                    if enhanced["emoji"] == nil { enhanced["emoji"] = "🌊" }
                    
                    return enhanced
                }
                enhancedChainData["blocks"] = enhancedBlocks
            }
            
            // Ensure other required fields
            if enhancedChainData["name"] == nil { enhancedChainData["name"] = "New Chain" }
            if enhancedChainData["flowPattern"] == nil { enhancedChainData["flowPattern"] = "waterfall" }
            if enhancedChainData["emoji"] == nil { enhancedChainData["emoji"] = "🔗" }
            
            return AIResponse(
                text: response,
                suggestions: [],
                actionType: .createChain,
                createdItems: [
                    CreatedItem(
                        type: .chain,
                        id: UUID(),
                        title: enhancedChainData["name"] as? String ?? "New Chain",
                        data: enhancedChainData
                    )
                ],
                confidence: analysis.confidence
            )
            
        } catch {
            // Fallback with basic chain structure
            let fallbackChainData: [String: Any] = [
                "name": "Activity Chain",
                "blocks": [
                    [
                        "title": "Activity",
                        "duration": 1800,
                        "energy": "daylight",
                        "emoji": "🌊"
                    ]
                ],
                "flowPattern": "waterfall",
                "emoji": "🔗"
            ]
            
            return AIResponse(
                text: "I'll help you create that chain",
                suggestions: [],
                actionType: .createChain,
                createdItems: [
                    CreatedItem(
                        type: .chain,
                        id: UUID(),
                        title: "Activity Chain",
                        data: fallbackChainData
                    )
                ],
                confidence: analysis.confidence
            )
        }
    }
    
    private func buildEnhancedSuggestionPrompt(message: String, context: DayContext, analysis: MessageActionAnalysis) -> String {
        let pillarGuidanceText = context.pillarGuidance.isEmpty ? 
            "" : "\n\nUser's Core Principles (guide all suggestions):\n\(context.pillarGuidance.joined(separator: "\n"))"
        
        let actionablePillarsText = context.actionablePillars.isEmpty ? 
            "" : "\n\nActionable Pillars to consider:\n\(context.actionablePillars.map { "- \($0.name): \($0.description)" }.joined(separator: "\n"))"
        
        return """
        You are a helpful day planning assistant. The user is asking for suggestions: "\(message)"
        
        Current context:
        - Date & Time: \(context.date.formatted(.dateTime.weekday().month().day().year().hour().minute()))
        - Current energy: \(context.currentEnergy.description)
        - Existing activities: \(context.existingBlocks.count)
        - Available time: \(Int(context.availableTime/3600)) hours
        - Mood: \(context.mood.description)
        - Intent confidence: \(analysis.confidence)
        - Context alignment: \(analysis.contextAlignment)
        \(context.weatherContext != nil ? "- Weather: \(context.weatherContext!)" : "")\(pillarGuidanceText)\(actionablePillarsText)
        
        IMPORTANT: Always align suggestions with the user's core principles listed above. Consider:
        - Weather conditions for indoor/outdoor activities
        - User's guiding principles when making any suggestion
        - How actionable pillars might need time slots
        - The user's current energy and mood state
        - The confidence level - adjust suggestion quality accordingly
        
        Please provide a helpful response and exactly 2 activity suggestions in this exact JSON format:
        {
            "response": "Your helpful response text that acknowledges their principles",
            "suggestions": [
                {
                    "title": "Activity name",
                    "explanation": "Brief reason why this aligns with their principles and current context",
                    "duration": 60,
                    "energy": "sunrise|daylight|moonlight",
                    "emoji": "📋|💼|🎯|💡|🏃‍♀️|🍽️|etc",
                    "confidence": \(analysis.confidence)
                }
            ]
        }
        
        Keep suggestions principle-aligned, realistic and personalized.
        """
    }
    
    private func parseEnhancedSuggestionResponse(_ content: String, analysis: MessageActionAnalysis) throws -> AIResponse {
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let parsed = try JSONDecoder().decode(AIResponseJSON.self, from: jsonData)
            
            let suggestions = parsed.suggestions.prefix(2).map { suggestionJSON in
                Suggestion(
                    title: suggestionJSON.title,
                    duration: TimeInterval(suggestionJSON.duration * 60),
                    suggestedTime: Date(),
                    energy: EnergyType(rawValue: suggestionJSON.energy) ?? .daylight,
                    emoji: suggestionJSON.emoji,
                    explanation: suggestionJSON.explanation,
                    confidence: suggestionJSON.confidence
                )
            }
            
            return AIResponse(
                text: parsed.response,
                suggestions: suggestions,
                actionType: .suggestActivities,
                createdItems: nil,
                confidence: analysis.confidence
            )
            
        } catch {
            return AIResponse(
                text: cleanContent,
                suggestions: [],
                actionType: .suggestActivities,
                createdItems: nil,
                confidence: analysis.confidence
            )
        }
    }
}

// MARK: - Data Models

struct AIResponse {
    let text: String
    let suggestions: [Suggestion]
    let actionType: AIActionType?
    let createdItems: [CreatedItem]?
    let confidence: Double
}

struct CreatedItem {
    let type: CreatedItemType
    let id: UUID
    let title: String
    let data: Any // Will be cast to specific types
}

enum CreatedItemType: String, Codable {
    case event = "event"
    case goal = "goal"
    case pillar = "pillar"
    case chain = "chain"
}

enum AIActionType: String, Codable {
    case createEvent = "create_event"
    case createGoal = "create_goal"
    case createPillar = "create_pillar"
    case createChain = "create_chain"
    case suggestActivities = "suggest_activities"
    case generalChat = "general_chat"
}

struct MessageActionAnalysis {
    let intent: String
    let confidence: Double
    let recommendedAction: AIActionType
    let extractedEntities: [String: String]
    let urgency: UrgencyLevel
    let contextAlignment: Double
}

enum UrgencyLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case immediate = "immediate"
}

struct AIConfidenceThresholds {
    let createEventThreshold: Double = 0.8
    let createGoalThreshold: Double = 0.85
    let createPillarThreshold: Double = 0.9
    let createChainThreshold: Double = 0.75
    let suggestActivitiesThreshold: Double = 0.6
    let generalChatThreshold: Double = 0.3
    
    func shouldCreateEvent(confidence: Double) -> Bool {
        return confidence >= createEventThreshold
    }
    
    func shouldCreateGoal(confidence: Double) -> Bool {
        return confidence >= createGoalThreshold
    }
    
    func shouldCreatePillar(confidence: Double) -> Bool {
        return confidence >= createPillarThreshold
    }
    
    func shouldCreateChain(confidence: Double) -> Bool {
        return confidence >= createChainThreshold
    }
    
    func shouldSuggestActivities(confidence: Double) -> Bool {
        return confidence >= suggestActivitiesThreshold
    }
}

private struct AIResponseJSON: Codable {
    let response: String
    let suggestions: [SuggestionJSON]
}

private struct SuggestionJSON: Codable {
    let title: String
    let explanation: String
    let duration: Int // in minutes
    let energy: String
    let emoji: String
    let confidence: Double
}

// MARK: - Errors

enum AIError: LocalizedError {
    case notConnected
    case requestFailed
    case invalidResponse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "AI service is not connected. Please start LM Studio and load a model."
        case .requestFailed:
            return "Failed to process AI request"
        case .invalidResponse:
            return "Received invalid response from AI service"
        case .timeout:
            return "AI request timed out"
        }
    }
}

// MARK: - Testing & Development

extension AIService {
    /// Create mock suggestions for testing when AI isn't available
    static func mockSuggestions() -> [Suggestion] {
        [
            Suggestion(
                title: "Morning Coffee & Planning",
                duration: 1800, // 30 minutes
                suggestedTime: Date().setting(hour: 8) ?? Date(),
                energy: .sunrise,
                emoji: "☕",
                explanation: "Start your day mindfully",
                confidence: 0.9
            ),
            Suggestion(
                title: "Deep Work Session",
                duration: 5400, // 90 minutes  
                suggestedTime: Date().setting(hour: 9) ?? Date(),
                energy: .sunrise,
                emoji: "💼",
                explanation: "Take advantage of morning focus",
                confidence: 0.8
            )
        ]
    }
    
    /// Test the connection and basic functionality
    func runDiagnostics() async -> String {
        var diagnostics = "AI Service Diagnostics:\n"
        
        // Test connection
        await checkConnection()
        diagnostics += "Connection: \(isConnected ? "✅ Connected" : "❌ Not Connected")\n"
        
        if isConnected {
            // Test basic request
            do {
                let testContext = DayContext(
                    date: Date(),
                    existingBlocks: [],
                    currentEnergy: .daylight,
                    preferredEmojis: ["🌊"],
                    availableTime: 3600,
                    mood: .crystal
                )
                
                let _ = try await processMessage("Hello", context: testContext)
                diagnostics += "AI Response: ✅ Working\n"
                diagnostics += "Response Time: \(String(format: "%.2f", lastResponseTime))s\n"
            } catch {
                diagnostics += "AI Response: ❌ \(error.localizedDescription)\n"
            }
        }
        
        return diagnostics
    }
    
    /// Enhance an event title with AI-generated context-aware details
    func enhanceEventTitle(originalTitle: String, time: Date, duration: TimeInterval) -> String {
        // Simple enhancement with contextual emojis only, no duration/time info
        if originalTitle.lowercased().contains("breakfast") {
            return "🥐 \(originalTitle)"
        } else if originalTitle.lowercased().contains("lunch") {
            return "🥪 \(originalTitle)"
        } else if originalTitle.lowercased().contains("dinner") {
            return "🍽️ \(originalTitle)"
        } else if originalTitle.lowercased().contains("meeting") {
            return "📋 \(originalTitle)"
        } else if originalTitle.lowercased().contains("exercise") || originalTitle.lowercased().contains("workout") {
            return "💪 \(originalTitle)"
        } else if originalTitle.lowercased().contains("work") || originalTitle.lowercased().contains("deep") {
            return "🎯 \(originalTitle)"
        } else {
            return originalTitle
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension AIService {
    static var preview: AIService {
        let service = AIService()
        service.isConnected = true
        return service
    }
}
#endif

// MARK: - Speech Service

import Speech
import AVFoundation

/// Complete speech recognition and text-to-speech service using Whisper
@MainActor
class SpeechService: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    @Published var partialText = ""
    @Published var authorizationStatus: AudioPermissionStatus = .undetermined
    @Published var lastError: String?
    
    private var audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingTask: Task<Void, Never>?
    private var whisperService: WhisperService?
    private var speechRecognizer: SFSpeechRecognizer?
    
    // TTS
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
        speechRecognizer = SFSpeechRecognizer()
        speechRecognizer?.delegate = self
        whisperService = WhisperService()
        
        // Setup audio session
        setupAudioSession()
        
        Task {
            await requestPermissions()
        }
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async {
        // Request microphone permission on macOS
        #if os(macOS)
        let micStatus = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run {
            authorizationStatus = micStatus ? .granted : .denied
        }
        #else
        let micStatus = await AVAudioApplication.requestRecordPermission()
        await MainActor.run {
            authorizationStatus = AVAudioApplication.shared.recordPermission == .granted ? .granted : .denied
        }
        #endif
        
        print("🎤 Microphone permissions: \(micStatus)")
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastError = "Failed to setup audio session: \(error.localizedDescription)"
            print("❌ Audio session error: \(error)")
        }
        #else
        // macOS doesn't use AVAudioSession
        print("🎤 Audio session setup (macOS - no configuration needed)")
        #endif
    }
    
    // MARK: - Speech Recognition with Whisper
    
    func startListening() async throws {
        guard authorizationStatus == .granted else {
            throw SpeechError.notAuthorized
        }
        
        // Stop any existing recording
        await stopListening()
        
        // Create temporary file for recording
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(UUID().uuidString).m4a")
        
        // Setup audio file
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        do {
            audioFile = try AVAudioFile(forWriting: tempURL, settings: settings)
        } catch {
            throw SpeechError.cannotCreateRequest
        }
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self, let audioFile = self.audioFile else { return }
            try? audioFile.write(from: buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        await MainActor.run {
            isListening = true
            partialText = ""
            transcribedText = ""
            lastError = nil
        }
        
        print("🎤 Started recording for Whisper transcription")
    }
    
    func stopListening() async {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        await MainActor.run {
            isListening = false
        }
        
        // Process recorded audio with Whisper
        if let audioFile = audioFile {
            recordingTask = Task {
                await processWithWhisper(audioFileURL: audioFile.url)
            }
        }
        
        audioFile = nil
        print("🎤 Stopped recording, processing with Whisper...")
    }
    
    private func processWithWhisper(audioFileURL: URL) async {
        // Get API keys from UserDefaults (since we can't access dataManager from here)
        let whisperKey = UserDefaults.standard.string(forKey: "whisperApiKey") ?? ""
        let openaiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
        
        let keyToUse = !whisperKey.isEmpty ? whisperKey : openaiKey
        
        if keyToUse.isEmpty {
            await MainActor.run {
                lastError = "No API key configured for Whisper"
            }
            return
        }
        
        guard let whisperService = whisperService else {
            await MainActor.run {
                lastError = "Whisper service not available"
            }
            return
        }
        
        do {
            let transcription = try await whisperService.transcribe(audioFileURL: audioFileURL, apiKey: keyToUse)
            
            await MainActor.run {
                transcribedText = transcription
                lastError = nil
            }
            
            print("🎤 Whisper transcription: \(transcription)")
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: audioFileURL)
            
        } catch {
            await MainActor.run {
                lastError = "Whisper transcription error: \(error.localizedDescription)"
            }
            print("❌ Whisper error: \(error)")
        }
    }
    
    // MARK: - Text to Speech
    
    func speak(text: String, rate: Float = 0.5, pitch: Float = 1.0, volume: Float = 1.0) {
        // Stop any current speech
        stopSpeaking()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        
        currentUtterance = utterance
        speechSynthesizer.speak(utterance)
        
        isSpeaking = true
        
        print("🔊 Speaking: \(text.prefix(50))...")
    }
    
    func stopSpeaking() {
        // Use nonisolated to avoid QoS priority inversion
        Task.detached(priority: .userInitiated) {
            let wasSpeaking = await MainActor.run {
                return self.speechSynthesizer.isSpeaking
            }
            
            if wasSpeaking {
                await MainActor.run {
                    _ = self.speechSynthesizer.stopSpeaking(at: .immediate)
                }
            }
            
            await MainActor.run {
                self.currentUtterance = nil
                self.isSpeaking = false
            }
        }
    }
    
    func pauseSpeaking() {
        Task.detached(priority: .userInitiated) {
            let wasSpeaking = await MainActor.run {
                return self.speechSynthesizer.isSpeaking
            }
            
            if wasSpeaking {
                await MainActor.run {
                    _ = self.speechSynthesizer.pauseSpeaking(at: .immediate)
                }
            }
        }
    }
    
    func continueSpeaking() {
        Task.detached(priority: .userInitiated) {
            let wasPaused = await MainActor.run {
                return self.speechSynthesizer.isPaused
            }
            
            if wasPaused {
                await MainActor.run {
                    _ = self.speechSynthesizer.continueSpeaking()
                }
            }
        }
    }
    
    // MARK: - Utility
    
    var canStartListening: Bool {
        return authorizationStatus == .granted && !isListening && speechRecognizer?.isAvailable == true
    }
    
    var canSpeak: Bool {
        return !isSpeaking
    }
    
    func getDiagnostics() -> String {
        var diagnostics = "Speech Service Diagnostics:\n"
        diagnostics += "Speech Authorization: \(authorizationStatus)\n"
        diagnostics += "Recognizer Available: \(speechRecognizer?.isAvailable ?? false)\n"
        diagnostics += "On-device Support: \(speechRecognizer?.supportsOnDeviceRecognition ?? false)\n"
        diagnostics += "Currently Listening: \(isListening)\n"
        diagnostics += "Currently Speaking: \(isSpeaking)\n"
        diagnostics += "Audio Engine Running: \(audioEngine.isRunning)\n"
        
        if let error = lastError {
            diagnostics += "Last Error: \(error)\n"
        }
        
        return diagnostics
    }
}

// MARK: - Speech Recognizer Delegate

@MainActor
extension SpeechService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available && isListening {
                lastError = "Speech recognizer became unavailable"
                await stopListening()
            }
        }
    }
}

// MARK: - Speech Synthesizer Delegate

@MainActor
extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentUtterance = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        // Keep isSpeaking true when paused
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentUtterance = nil
        }
    }
}

// MARK: - Speech Errors

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case cannotCreateRequest
    case audioEngineFailure
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please grant permission in System Preferences."
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .cannotCreateRequest:
            return "Cannot create speech recognition request"
        case .audioEngineFailure:
            return "Audio engine failed to start"
        }
    }
}

// MARK: - Extensions

#if DEBUG
extension SpeechService {
    static var preview: SpeechService {
        let service = SpeechService()
        service.authorizationStatus = .granted
        return service
    }
}
#endif
