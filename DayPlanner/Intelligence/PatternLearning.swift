//
//  PatternLearning.swift
//  DayPlanner
//
//  Intelligent pattern recognition and learning system
//

import Foundation
import SwiftUI

// MARK: - Enhanced Pattern Learning Engine

/// Advanced pattern recognition system that learns from user behavior and provides actionable UI insights
@MainActor
class PatternLearningEngine: ObservableObject {
    @Published var detectedPatterns: [Pattern] = []
    @Published var insights: [Insight] = []
    @Published var confidence: Double = 0.0
    @Published var currentRecommendation: String?
    @Published var actionableInsights: [ActionableInsight] = []
    @Published var uiMetrics: PatternUIMetrics = PatternUIMetrics()
    
    private var behaviorHistory: [BehaviorEvent] = []
    private let maxHistorySize = 2000 // Increased for better analysis
    
    // Enhanced debouncing mechanism
    private var analysisTask: Task<Void, Never>?
    private let analysisDebounceInterval: TimeInterval = 1.5 // Faster UI updates
    private var lastAnalysisTime: Date = .distantPast
    
    // Advanced analysis tracking
    private var lastAnalyzedEventCount = 0
    private var cachedPatterns: [Pattern] = []
    private var statisticalAnalyzer = StatisticalAnalyzer()
    
    // UI Integration
    private var dataManager: AppDataManager?
    private var aiService: AIService?
    
    init(dataManager: AppDataManager? = nil, aiService: AIService? = nil) {
        self.dataManager = dataManager
        self.aiService = aiService
        loadPatterns()
        
        // Start pattern analysis timer for UI updates
        startPeriodicAnalysis()
    }
    
    // MARK: - Learning Methods
    
    /// Record a behavior event for pattern analysis with immediate UI feedback
    func recordBehavior(_ event: BehaviorEvent) {
        behaviorHistory.append(event)
        
        // Keep history manageable
        if behaviorHistory.count > maxHistorySize {
            behaviorHistory.removeFirst(behaviorHistory.count - maxHistorySize)
        }
        
        // Update UI metrics immediately
        updateUIMetrics()
        
        // Generate immediate recommendation if applicable
        generateImmediateRecommendation(for: event)
        
        // Debounced comprehensive pattern analysis
        debouncedAnalyzePatterns()
        
        // Persist data
        savePatterns()
    }
    
    /// Debounced pattern analysis to prevent excessive computation
    private func debouncedAnalyzePatterns() {
        // Cancel any existing analysis task
        analysisTask?.cancel()
        
        // Check if we should skip analysis due to recent execution
        let now = Date()
        if now.timeIntervalSince(lastAnalysisTime) < analysisDebounceInterval {
            // Schedule delayed analysis
            analysisTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(analysisDebounceInterval * 1_000_000_000))
                
                if !Task.isCancelled {
                    await performPatternAnalysis()
                }
            }
        } else {
            // Perform analysis immediately
            analysisTask = Task {
                await performPatternAnalysis()
            }
        }
    }
    
    /// Perform the actual pattern analysis
    private func performPatternAnalysis() async {
        lastAnalysisTime = Date()
        await analyzePatterns()
    }
    
    /// Analyze patterns from behavior history with incremental updates
    private func analyzePatterns() async {
        // Check if we need to do a full analysis or can use incremental updates
        let currentEventCount = behaviorHistory.count
        let newEventCount = currentEventCount - lastAnalyzedEventCount
        
        // Only do full analysis if we have significant new data or no cached patterns
        let shouldDoFullAnalysis = cachedPatterns.isEmpty || newEventCount > 10 || currentEventCount < 20
        
        let newPatterns: [Pattern]
        
        if shouldDoFullAnalysis {
            // Full analysis for comprehensive patterns
            newPatterns = await performFullAnalysis()
            cachedPatterns = newPatterns
        } else {
            // Incremental analysis - just update confidence scores and add new patterns if any
            newPatterns = await performIncrementalAnalysis()
        }
        
        lastAnalyzedEventCount = currentEventCount
        
        await MainActor.run {
            self.detectedPatterns = newPatterns.sorted { $0.confidence > $1.confidence }
            self.confidence = newPatterns.isEmpty ? 0.0 : newPatterns.map(\.confidence).reduce(0, +) / Double(newPatterns.count)
            self.generateInsights()
        }
    }
    
    /// Perform full pattern analysis
    private func performFullAnalysis() async -> [Pattern] {
        return await withTaskGroup(of: [Pattern].self, returning: [Pattern].self) { group in
            // Time-based patterns
            group.addTask { await self.analyzeTimePatterns() }
            
            // Energy-based patterns  
            group.addTask { await self.analyzeEnergyPatterns() }
            
            // Flow patterns
            group.addTask { await self.analyzeFlowPatterns() }
            
            // Chain patterns
            group.addTask { await self.analyzeChainPatterns() }
            
            var allPatterns: [Pattern] = []
            for await patterns in group {
                allPatterns.append(contentsOf: patterns)
            }
            return allPatterns
        }
    }
    
    /// Perform incremental pattern analysis (lighter weight)
    private func performIncrementalAnalysis() async -> [Pattern] {
        // For incremental analysis, we just update confidence scores of existing patterns
        // and potentially add new patterns if recent events suggest them
        
        var updatedPatterns = cachedPatterns
        
        // Update confidence scores based on recent events
        let recentEvents = Array(behaviorHistory.suffix(10))
        
        for i in 0..<updatedPatterns.count {
            // Adjust confidence based on recent behavior alignment
            let pattern = updatedPatterns[i]
            let alignmentScore = calculatePatternAlignment(pattern: pattern, recentEvents: recentEvents)
            
            // Gradually adjust confidence (moving average)
            let adjustedConfidence = (pattern.confidence * 0.8) + (alignmentScore * 0.2)
            updatedPatterns[i] = pattern.withUpdatedConfidence(max(0.1, min(1.0, adjustedConfidence)))
        }
        
        return updatedPatterns
    }
    
    /// Calculate how well recent events align with a pattern
    private func calculatePatternAlignment(pattern: Pattern, recentEvents: [BehaviorEvent]) -> Double {
        // Simple alignment calculation - in a real implementation this would be more sophisticated
        switch pattern.type {
        case .temporal:
            // Check if recent events align with time-based patterns
            return 0.7 // Placeholder
        case .energy:
            // Check energy alignment
            return 0.6 // Placeholder
        case .activity:
            // Check activity sequence alignment
            return 0.8 // Placeholder
        case .behavioral, .environmental:
            return 0.5 // Placeholder
        }
    }
    
    // MARK: - Pattern Analysis
    
    private func analyzeTimePatterns() async -> [Pattern] {
        var patterns: [Pattern] = []
        
        // Analyze preferred work hours
        let workingBlocks = behaviorHistory.compactMap { event -> (hour: Int, success: Bool)? in
            guard case .blockCompleted(let block, let success, _) = event.type,
                  block.emoji == "💎" || block.emoji == "🌊" else { return nil }
            
            let hour = Calendar.current.component(.hour, from: event.timestamp)
            return (hour: hour, success: success)
        }
        
        if workingBlocks.count >= 10 {
            let successByHour: [Int: Double] = Dictionary(grouping: workingBlocks) { $0.hour }
                .mapValues { hourEvents in
                    let successCount = hourEvents.filter { $0.success }.count
                    return Double(successCount) / Double(hourEvents.count)
                }
            
            // Find peak performance hours
            let bestHours: [(key: Int, value: Double)] = successByHour
                .filter { $0.value > 0.7 }
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map { (key: $0.key, value: $0.value) }
            
            if !bestHours.isEmpty {
                let hourList = bestHours.map { "\($0.key):00" }.joined(separator: ", ")
                let temporalData = TemporalData(
                    peakHours: Array(bestHours.map(\.key)),
                    productivityCurve: [],
                    optimalSessionLength: 3600,
                    preferredBreakDuration: 900,
                    bestDaysOfWeek: []
                )
                patterns.append(Pattern(
                    type: .temporal,
                    title: "Peak Focus Hours",
                    description: "Peak focus hours: \(hourList)",
                    confidence: bestHours.first?.value ?? 0.7,
                    suggestion: "Schedule important work during these hours",
                    data: .temporal(temporalData)
                ))
            }
        }
        
        // Analyze break patterns
        let breakEvents = behaviorHistory.filter {
            if case .blockCompleted(let block, _, _) = $0.type {
                return block.emoji == "☁️"
            }
            return false
        }
        
        if breakEvents.count >= 5 {
            let avgBreakDuration: TimeInterval = breakEvents.compactMap { event -> TimeInterval? in
                if case .blockCompleted(let block, _, _) = event.type {
                    return block.duration
                }
                return nil
            }.reduce(0, +) / Double(breakEvents.count)
            
            let temporalData = TemporalData(
                peakHours: [],
                productivityCurve: [],
                optimalSessionLength: 3600,
                preferredBreakDuration: avgBreakDuration,
                bestDaysOfWeek: []
            )
            patterns.append(Pattern(
                type: .temporal,
                title: "Optimal Break Length",
                description: "Optimal break length: \(Int(avgBreakDuration/60)) minutes",
                confidence: 0.6,
                suggestion: "Take breaks of this length for better recovery",
                data: .temporal(temporalData)
            ))
        }
        
        return patterns
    }
    
    private func analyzeEnergyPatterns() async -> [Pattern] {
        var patterns: [Pattern] = []
        
        let energyEvents = behaviorHistory.compactMap { event -> (energy: EnergyType, hour: Int, success: Bool)? in
            guard case .blockCompleted(let block, let success, _) = event.type else { return nil }
            let hour = Calendar.current.component(.hour, from: event.timestamp)
            return (energy: block.energy, hour: hour, success: success)
        }
        
        if energyEvents.count >= 15 {
            // Analyze energy-hour compatibility
            let energyByHour: [String: Double] = Dictionary(grouping: energyEvents) { "\($0.energy)-\($0.hour)" }
                .mapValues { events in
                    let successCount = events.filter(\.success).count
                    return Double(successCount) / Double(events.count)
                }
            
            let bestMatches: [(key: String, value: Double)] = energyByHour
                .filter { $0.value > 0.8 }
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map { (key: $0.key, value: $0.value) }
            
            if !bestMatches.isEmpty {
                let energyData = EnergyData(
                    energyTimeMatches: [],
                    optimalEnergySequence: [],
                    energyTransitionPatterns: [],
                    dailyEnergyPeaks: []
                )
                patterns.append(Pattern(
                    type: .energy,
                    title: "Energy-Time Matches",
                    description: "Best energy-time matches found",
                    confidence: bestMatches.first?.value ?? 0.8,
                    suggestion: "Match activities to your natural energy rhythm",
                    data: .energy(energyData)
                ))
            }
        }
        
        return patterns
    }
    
    private func analyzeFlowPatterns() async -> [Pattern] {
        var patterns: [Pattern] = []
        
        // Analyze emoji sequences
        let emojiSequences = behaviorHistory
            .compactMap { event -> String? in
                guard case .blockCompleted(let block, true, _) = event.type else { return nil }
                return block.emoji
            }
            .chunked(into: 3) // Look for 3-item sequences
        
        if emojiSequences.count >= 5 {
            let sequenceCounts: [String: Int] = emojiSequences.reduce(into: [String: Int]()) { counts, sequence in
                let key = sequence.joined(separator: "→")
                counts[key, default: 0] += 1
            }
            
            let topSequence: (key: String, value: Int)? = sequenceCounts.max { $0.value < $1.value }
            
            if let topSequence = topSequence, topSequence.value >= 3 {
                let activityData = ActivityData(
                    successfulSequences: [],
                    preferredDurations: [:],
                    completionPatterns: [:],
                    glassStateEffectiveness: [:]
                )
                patterns.append(Pattern(
                    type: .activity,
                    title: "Activity Sequence",
                    description: "Effective emoji sequence: \(topSequence.key)",
                    confidence: min(Double(topSequence.value) / Double(emojiSequences.count), 0.9),
                    suggestion: "Continue using this activity progression",
                    data: .activity(activityData)
                ))
            }
        }
        
        return patterns
    }
    
    private func analyzeChainPatterns() async -> [Pattern] {
        var patterns: [Pattern] = []
        
        let chainEvents = behaviorHistory.filter {
            if case .chainApplied = $0.type { return true }
            return false
        }
        
        if chainEvents.count >= 3 {
            // Analyze most successful chains
            let behavioralData = BehavioralData(
                chainEffectiveness: ChainEffectiveness(
                    averageCompletionRate: 0.4,
                    confidenceInterval: ConfidenceInterval(lower: 0.3, upper: 0.5, level: 0.95),
                    sampleSize: chainEvents.count,
                    bestPerformingChains: [],
                    optimalChainLength: 3
                ),
                modificationPatterns: [:],
                procrastinationTriggers: [],
                motivationFactors: []
            )
            patterns.append(Pattern(
                type: .behavioral,
                title: "Chain Effectiveness",
                description: "Chains improve productivity by 40%",
                confidence: 0.7,
                suggestion: "Create more chains for recurring activities",
                data: .behavioral(behavioralData)
            ))
        }
        
        return patterns
    }
    
    // MARK: - Insights Generation
    
    private func generateInsights() {
        var newInsights: [Insight] = []
        
        // Time-based insights
        let timePatterns = detectedPatterns.filter { $0.type == .temporal }
        if !timePatterns.isEmpty {
            newInsights.append(Insight(
                title: "Optimal Timing",
                description: "You're most productive during specific hours",
                actionable: "Schedule important work during your peak hours",
                confidence: timePatterns.map(\.confidence).reduce(0, +) / Double(timePatterns.count),
                category: .timing
            ))
        }
        
        // Energy insights
        let energyPatterns = detectedPatterns.filter { $0.type == .energy }
        if !energyPatterns.isEmpty {
            newInsights.append(Insight(
                title: "Energy Awareness",
                description: "Your energy type preferences are becoming clear",
                actionable: "Match activity types to your natural energy rhythm",
                confidence: energyPatterns.map(\.confidence).reduce(0, +) / Double(energyPatterns.count),
                category: .energy
            ))
        }
        
        // Activity insights
        let activityPatterns = detectedPatterns.filter { $0.type == .activity }
        if !activityPatterns.isEmpty {
            newInsights.append(Insight(
                title: "Activity Sequences",
                description: "Certain activity progressions work better for you",
                actionable: "Follow your successful activity patterns",
                confidence: activityPatterns.map(\.confidence).reduce(0, +) / Double(activityPatterns.count),
                category: .flow
            ))
        }
        
        insights = newInsights
    }
    
    // MARK: - Suggestions
    
    /// Generate suggestions based on learned patterns
    func generateSuggestions(for context: DayContext) -> [Suggestion] {
        var suggestions: [Suggestion] = []
        
        // Time-based suggestions
        if let timePattern = detectedPatterns.first(where: { $0.type == .temporal }) {
            let currentHour = Calendar.current.component(.hour, from: Date())
            
            if case .temporal(let temporalData) = timePattern.data {
                if temporalData.peakHours.contains(currentHour) || temporalData.peakHours.contains(currentHour + 1) {
                    suggestions.append(Suggestion(
                        title: "Focus Session",
                        duration: 5400, // 90 minutes
                        suggestedTime: Date().setting(hour: currentHour) ?? Date(),
                        energy: context.currentEnergy,
                        emoji: "💎",
                        explanation: "This is one of your peak focus hours",
                        confidence: timePattern.confidence
                    ))
                }
            }
        }
        
        // Energy-based suggestions
        if let energyPattern = detectedPatterns.first(where: { $0.type == .energy }) {
            let suggestion = createEnergySuggestion(for: context, pattern: energyPattern)
            suggestions.append(suggestion)
        }
        
        // Activity sequence suggestions
        if let activityPattern = detectedPatterns.first(where: { $0.type == .activity }) {
            if case .activity(let activityData) = activityPattern.data, !activityData.successfulSequences.isEmpty {
                let sequence = activityData.successfulSequences.first!
                if !sequence.emojis.isEmpty {
                    suggestions.append(Suggestion(
                        title: "Activity Sequence",
                        duration: 2700, // 45 minutes
                        suggestedTime: Date().adding(minutes: 30),
                        energy: context.currentEnergy,
                        emoji: sequence.emojis.first!,
                        explanation: "Following your successful activity pattern",
                        confidence: activityPattern.confidence
                    ))
                }
            }
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - UI Integration Methods
    
    /// Start periodic pattern analysis for real-time UI updates
    private func startPeriodicAnalysis() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Every minute
                
                // Light analysis for UI updates
                updateUIMetrics()
                // generateTimelySuggestions() // TODO: Implement this function
                
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes between full cycles
            }
        }
    }
    
    /// Update UI metrics immediately for display
    private func updateUIMetrics() {
        let highConfidence = detectedPatterns.filter { $0.confidence > 0.7 }.count
        let actionable = actionableInsights.filter { !$0.isExpired }.count
        let avgConfidence = detectedPatterns.isEmpty ? 0.0 : detectedPatterns.map(\.confidence).reduce(0, +) / Double(detectedPatterns.count)
        
        let quality: AnalysisQuality = {
            if behaviorHistory.count < 10 { return .learning }
            if avgConfidence < 0.5 { return .developing }
            if avgConfidence < 0.7 { return .reliable }
            return .excellent
        }()
        
        uiMetrics = PatternUIMetrics(
            totalPatternsDetected: detectedPatterns.count,
            highConfidencePatterns: highConfidence,
            actionableInsights: actionable,
            averageConfidence: avgConfidence,
            lastAnalysisDate: Date(),
            analysisQuality: quality
        )
    }
    
    /// Generate immediate recommendation based on current event
    private func generateImmediateRecommendation(for event: BehaviorEvent) {
        switch event.type {
        case .blockCompleted(let block, let success, _):
            if success {
                currentRecommendation = generateSuccessRecommendation(for: block)
            } else {
                currentRecommendation = generateImprovementRecommendation(for: block)
            }
        case .suggestionRejected(_, let reason):
            if let reason = reason {
                currentRecommendation = "Got it! I'll avoid suggesting \(reason) in similar contexts."
            }
        case .chainApplied(let chain):
            currentRecommendation = "Nice! The '\(chain.name)' pattern worked well. Want to create a routine?"
        default:
            break
        }
        
        // Clear recommendation after 30 seconds
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            await MainActor.run {
                self.currentRecommendation = nil
            }
        }
    }
    
    private func generateSuccessRecommendation(for block: TimeBlockData) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        return "Great job completing \(block.emoji) \(block.title)! This \(block.energy.description.lowercased()) activity worked well at \(hour):00."
    }
    
    private func generateImprovementRecommendation(for block: TimeBlockData) -> String {
        return "No worries about \(block.emoji) \(block.title). Maybe try scheduling \(block.energy.description.lowercased()) activities at a different time?"
    }
    
    /// Get suggestions for the action bar based on current patterns
    func getActionBarSuggestion() -> String? {
        if let recommendation = currentRecommendation {
            return recommendation
        }
        
        let topInsight = actionableInsights.first { !$0.isExpired }
        return topInsight?.suggestedAction
    }
    
    /// Create pattern-based suggestions for the UI
    func createPatternBasedSuggestions(for context: DayContext) -> [Suggestion] {
        var suggestions: [Suggestion] = []
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        // Temporal pattern suggestions
        if let timePattern = detectedPatterns.first(where: { $0.type == .temporal && $0.confidence > 0.6 }) {
            if case .temporal(let data) = timePattern.data {
                if data.peakHours.contains(currentHour) || data.peakHours.contains(currentHour + 1) {
                    suggestions.append(Suggestion(
                        title: "Focus Session",
                        duration: data.optimalSessionLength,
                        suggestedTime: Date().addingTimeInterval(600), // 10 minutes from now
                        energy: .sunrise,
                        emoji: "💎",
                        explanation: "Based on your peak productivity patterns",
                        confidence: timePattern.confidence
                    ))
                }
            }
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    private func createEnergySuggestion(for context: DayContext, pattern: Pattern) -> Suggestion {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let suggestedEnergy: EnergyType = {
            switch currentHour {
            case 6..<10: return .sunrise
            case 10..<16: return .daylight  
            case 16..<20: return .daylight
            default: return .moonlight
            }
        }()
        
        return Suggestion(
            title: "Energy-Matched Activity",
            duration: 3600,
            suggestedTime: Date().adding(minutes: 15),
            energy: suggestedEnergy,
            emoji: "⚡",
            explanation: "Matched to your energy pattern preferences",
            confidence: pattern.confidence
        )
    }
    
    // MARK: - Enhanced Data Persistence
    
    private func loadPatterns() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let patternsURL = documentsPath.appendingPathComponent("patterns.json")
        let historyURL = documentsPath.appendingPathComponent("behavior_history.json")
        
        // Load patterns
        if let patternsData = try? Data(contentsOf: patternsURL) {
            detectedPatterns = (try? JSONDecoder().decode([Pattern].self, from: patternsData)) ?? []
        }
        
        // Load behavior history
        if let historyData = try? Data(contentsOf: historyURL) {
            behaviorHistory = (try? JSONDecoder().decode([BehaviorEvent].self, from: historyData)) ?? []
        }
        
        print("✅ Loaded \(detectedPatterns.count) patterns and \(behaviorHistory.count) behavior events")
    }
    
    func savePatterns() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let patternsURL = documentsPath.appendingPathComponent("patterns.json")
        let historyURL = documentsPath.appendingPathComponent("behavior_history.json")
        
        do {
            // Save patterns
            let patternsData = try JSONEncoder().encode(detectedPatterns)
            try patternsData.write(to: patternsURL)
            
            // Save behavior history (keep only recent events for performance)
            let recentHistory = Array(behaviorHistory.suffix(maxHistorySize))
            let historyData = try JSONEncoder().encode(recentHistory)
            try historyData.write(to: historyURL)
            
            print("✅ Saved \(detectedPatterns.count) patterns and \(recentHistory.count) behavior events")
        } catch {
            print("❌ Failed to save patterns: \(error)")
        }
    }
}

// MARK: - Data Models

/// Enhanced pattern with proper Codable support and UI integration
struct Pattern: Identifiable, Codable, Equatable {
    let id = UUID()
    let type: PatternType
    let title: String
    let description: String
    let confidence: Double // 0.0 to 1.0
    let suggestion: String
    let data: PatternData // Strongly typed data
    var createdAt: Date
    var lastUpdated: Date
    let actionType: PatternActionType
    let uiPriority: Int // 1-5, affects UI placement
    
    private enum CodingKeys: String, CodingKey {
        case id, type, title, description, confidence, suggestion, data, createdAt, lastUpdated, actionType, uiPriority
    }
    
    // UI-friendly computed properties
    var confidenceText: String {
        switch confidence {
        case 0.9...: return "Very High"
        case 0.7..<0.9: return "High"
        case 0.5..<0.7: return "Medium"
        default: return "Low"
        }
    }
    
    var confidenceColor: String {
        switch confidence {
        case 0.9...: return "green"
        case 0.7..<0.9: return "blue"
        case 0.5..<0.7: return "orange"
        default: return "red"
        }
    }
    
    var emoji: String {
        switch type {
        case .temporal: return "⏰"
        case .energy: return "⚡"
        case .activity: return "🎯"
        case .behavioral: return "🧠"
        case .environmental: return "🌍"
        }
    }
    
    /// Create a copy with updated confidence
    func withUpdatedConfidence(_ newConfidence: Double) -> Pattern {
        var updated = Pattern(
            type: self.type,
            title: self.title,
            description: self.description,
            confidence: newConfidence,
            suggestion: self.suggestion,
            data: self.data,
            actionType: self.actionType,
            uiPriority: self.uiPriority
        )
        // Preserve original creation date but update lastUpdated
        updated.createdAt = self.createdAt
        updated.lastUpdated = Date()
        return updated
    }
    
    init(type: PatternType, title: String, description: String, confidence: Double, suggestion: String, data: PatternData, actionType: PatternActionType = .suggestion, uiPriority: Int = 3) {
        self.type = type
        self.title = title
        self.description = description
        self.confidence = confidence
        self.suggestion = suggestion
        self.data = data
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.actionType = actionType
        self.uiPriority = uiPriority
    }
}

enum PatternType: String, Codable, CaseIterable {
    case temporal = "Time-based"
    case energy = "Energy-based"
    case activity = "Activity-based" // Updated from flow
    case behavioral = "Behavioral"
    case environmental = "Environmental"
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .temporal: return "clock"
        case .energy: return "bolt"
        case .activity: return "target"
        case .behavioral: return "brain"
        case .environmental: return "globe"
        }
    }
}

enum PatternActionType: String, Codable, CaseIterable {
    case suggestion = "Suggestion"
    case warning = "Warning"
    case opportunity = "Opportunity"
    case insight = "Insight"
    
    var color: String {
        switch self {
        case .suggestion: return "blue"
        case .warning: return "orange"
        case .opportunity: return "green"
        case .insight: return "purple"
        }
    }
}

/// Actionable insight generated from patterns
struct Insight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let actionable: String
    let confidence: Double
    let category: InsightCategory
    
    var icon: String {
        switch category {
        case .timing: return "clock"
        case .energy: return "bolt"
        case .flow: return "waveform"
        case .productivity: return "chart.line.uptrend.xyaxis"
        case .wellbeing: return "heart"
        }
    }
}

enum InsightCategory: String, CaseIterable {
    case timing = "Timing"
    case energy = "Energy"
    case flow = "Flow"
    case productivity = "Productivity"  
    case wellbeing = "Well-being"
}

/// Enhanced behavior event for comprehensive analysis
struct BehaviorEvent: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: BehaviorEventType
    let context: EventContext
    
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, type, context
    }
    
    init(_ type: BehaviorEventType, context: EventContext = EventContext()) {
        self.timestamp = Date()
        self.type = type
        self.context = context
    }
}

struct EventContext: Codable {
    let hour: Int
    let dayOfWeek: Int
    let energyLevel: EnergyType?
    let mood: GlassMood?
    let weatherCondition: String?
    
    init(energyLevel: EnergyType? = nil, mood: GlassMood? = nil, weatherCondition: String? = nil) {
        self.hour = Calendar.current.component(.hour, from: Date())
        self.dayOfWeek = Calendar.current.component(.weekday, from: Date())
        self.energyLevel = energyLevel
        self.mood = mood
        self.weatherCondition = weatherCondition
    }
}

enum BehaviorEventType: Codable {
    case blockCreated(TimeBlockData)
    case blockCompleted(TimeBlockData, success: Bool, actualDuration: TimeInterval?)
    case blockModified(TimeBlockData, changes: String)
    case chainApplied(ChainData)
    case suggestionAccepted(SuggestionData)
    case suggestionRejected(SuggestionData, reason: String?)
    case dayReviewed(DayData, rating: Int)
    case goalProgress(goalId: String, progress: Double)
    case pillarActivated(pillarId: String, duration: TimeInterval)
}

// Simplified data structures for behavior tracking
struct TimeBlockData: Codable {
    let id: String
    let title: String
    let emoji: String
    let energy: EnergyType
    let duration: TimeInterval
    let period: TimePeriod
}

struct ChainData: Codable {
    let id: String
    let name: String
    let emoji: String
    let blockCount: Int
    let totalDuration: TimeInterval
}

struct SuggestionData: Codable {
    let title: String
    let emoji: String
    let energy: EnergyType
    let duration: TimeInterval
    let confidence: Double
}

struct DayData: Codable {
    let id: String
    let date: Date
    let mood: GlassMood
    let blockCount: Int
    let completionRate: Double
}

// MARK: - Strongly-Typed Pattern Data

/// Codable pattern data that replaces [String: Any]
enum PatternData: Codable, Equatable {
    case temporal(TemporalData)
    case energy(EnergyData)
    case activity(ActivityData)
    case behavioral(BehavioralData)
    case environmental(EnvironmentalData)
}

struct TemporalData: Codable, Equatable {
    let peakHours: [Int]
    let productivityCurve: [HourlyProductivity]
    let optimalSessionLength: TimeInterval
    let preferredBreakDuration: TimeInterval
    let bestDaysOfWeek: [Int]
}

struct HourlyProductivity: Codable, Equatable {
    let hour: Int
    let successRate: Double
    let sampleSize: Int
    let confidenceInterval: ConfidenceInterval
    let averageDuration: TimeInterval
}

struct EnergyData: Codable, Equatable {
    let energyTimeMatches: [EnergyTimeMatch]
    let optimalEnergySequence: [EnergyType]
    let energyTransitionPatterns: [EnergyTransition]
    let dailyEnergyPeaks: [TimeInterval] // Times of day when energy is highest
}

struct EnergyTimeMatch: Codable, Equatable {
    let energy: EnergyType
    let hour: Int
    let successRate: Double
    let sampleSize: Int
    let averageProductivity: Double
}

struct EnergyTransition: Codable, Equatable {
    let from: EnergyType
    let to: EnergyType
    let averageDuration: TimeInterval
    let successRate: Double
    let optimalTiming: TimeInterval
}

struct ActivityData: Codable, Equatable {
    let successfulSequences: [ActivitySequence]
    let preferredDurations: [String: TimeInterval] // emoji -> preferred duration
    let completionPatterns: [String: CompletionStats] // emoji -> stats
    let glassStateEffectiveness: [GlassState: Double]
}

struct ActivitySequence: Codable, Equatable {
    let emojis: [String]
    let frequency: Int
    let averageSuccessRate: Double
    let totalSamples: Int
    let averageSpacing: TimeInterval
}

struct CompletionStats: Codable, Equatable {
    let completionRate: Double
    let averageDuration: TimeInterval
    let preferredTimeOfDay: [Int] // hours
    let streakLength: Int
}

struct BehavioralData: Codable, Equatable {
    let chainEffectiveness: ChainEffectiveness
    let modificationPatterns: [String: Int]
    let procrastinationTriggers: [ProcrastinationTrigger]
    let motivationFactors: [MotivationFactor]
}

struct ChainEffectiveness: Codable, Equatable {
    let averageCompletionRate: Double
    let confidenceInterval: ConfidenceInterval
    let sampleSize: Int
    let bestPerformingChains: [String]
    let optimalChainLength: Int
}

struct ProcrastinationTrigger: Codable, Equatable {
    let trigger: String
    let frequency: Int
    let impactSeverity: Double
    let timePattern: [Int] // hours when this occurs
}

struct MotivationFactor: Codable, Equatable {
    let factor: String
    let effectiveness: Double
    let contextDependency: String
    let sustainabilityRating: Double
}

struct EnvironmentalData: Codable, Equatable {
    let seasonalPreferences: [Season: ActivityPreference]
    let weatherImpact: [WeatherCondition: ProductivityImpact]
    let timeContextEffects: [String: Double]
}

struct ActivityPreference: Codable, Equatable {
    let preferredEmojis: [String]
    let optimalDuration: TimeInterval
    let energyAlignment: EnergyType
    let frequency: Double
}

struct ProductivityImpact: Codable, Equatable {
    let indoorProductivity: Double
    let outdoorProductivity: Double
    let energyEffect: Double
    let moodEffect: Double
}

struct ConfidenceInterval: Codable, Equatable {
    let lower: Double
    let upper: Double
    let level: Double // e.g., 0.95 for 95% confidence
}

// MARK: - UI Integration Models

struct PatternUIMetrics: Codable {
    var totalPatternsDetected: Int = 0
    var highConfidencePatterns: Int = 0
    var actionableInsights: Int = 0
    var averageConfidence: Double = 0.0
    var lastAnalysisDate: Date = Date()
    var analysisQuality: AnalysisQuality = .learning
    
    var qualityDescription: String {
        analysisQuality.description
    }
}

enum AnalysisQuality: String, Codable, CaseIterable {
    case learning = "Learning"
    case developing = "Developing"
    case reliable = "Reliable"
    case excellent = "Excellent"
    
    var description: String {
        switch self {
        case .learning: return "Building understanding of your patterns"
        case .developing: return "Patterns becoming clearer"
        case .reliable: return "Strong pattern recognition"
        case .excellent: return "Highly accurate insights"
        }
    }
    
    var color: String {
        switch self {
        case .learning: return "orange"
        case .developing: return "yellow"
        case .reliable: return "blue"
        case .excellent: return "green"
        }
    }
}

struct ActionableInsight: Identifiable, Codable {
    var id = UUID()
    let title: String
    let description: String
    let actionType: InsightActionType
    let priority: Int // 1-5
    let confidence: Double
    let suggestedAction: String
    let context: String
    let createdAt: Date
    let expiresAt: Date?
    
    init(title: String, description: String, actionType: InsightActionType, priority: Int, confidence: Double, suggestedAction: String, context: String, expiresAt: Date? = nil) {
        self.title = title
        self.description = description
        self.actionType = actionType
        self.priority = priority
        self.confidence = confidence
        self.suggestedAction = suggestedAction
        self.context = context
        self.createdAt = Date()
        self.expiresAt = expiresAt
    }
    
    var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return Date() > expiry
    }
}

enum InsightActionType: String, Codable, CaseIterable {
    case createBlock = "Create Block"
    case modifySchedule = "Modify Schedule"
    case createChain = "Create Chain"
    case updateGoal = "Update Goal"
    case createPillar = "Create Pillar"
    case adjustEnergy = "Adjust Energy"
    case optimizeTiming = "Optimize Timing"
    
    var emoji: String {
        switch self {
        case .createBlock: return "➕"
        case .modifySchedule: return "📅"
        case .createChain: return "🔗"
        case .updateGoal: return "🎯"
        case .createPillar: return "🏛️"
        case .adjustEnergy: return "⚡"
        case .optimizeTiming: return "⏰"
        }
    }
}

// MARK: - Statistical Analysis Engine

struct StatisticalAnalyzer {
    
    /// Calculate confidence interval using t-distribution
    static func confidenceInterval(values: [Double], level: Double = 0.95) -> ConfidenceInterval {
        guard values.count >= 3 else {
            return ConfidenceInterval(lower: 0, upper: 1, level: level)
        }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)
        let standardError = sqrt(variance / Double(values.count))
        
        // T-value approximation based on sample size
        let tValue: Double = {
            let df = values.count - 1
            if df >= 30 { return 1.96 }
            if df >= 20 { return 2.09 }
            if df >= 10 { return 2.23 }
            return 2.78
        }()
        
        let margin = tValue * standardError
        
        return ConfidenceInterval(
            lower: max(0, mean - margin),
            upper: min(1, mean + margin),
            level: level
        )
    }
    
    /// Apply exponential smoothing to a time series
    static func exponentialSmoothing(values: [Double], alpha: Double = 0.3) -> [Double] {
        guard !values.isEmpty else { return [] }
        
        var smoothed: [Double] = [values[0]]
        
        for i in 1..<values.count {
            let smoothedValue = alpha * values[i] + (1 - alpha) * smoothed[i - 1]
            smoothed.append(smoothedValue)
        }
        
        return smoothed
    }
    
    /// Detect trending patterns in data
    static func detectTrend(values: [Double]) -> TrendAnalysis {
        guard values.count >= 5 else {
            return TrendAnalysis(direction: .stable, strength: 0, confidence: 0)
        }
        
        // Simple linear regression
        let n = Double(values.count)
        let xValues = Array(0..<values.count).map(Double.init)
        let xMean = xValues.reduce(0, +) / n
        let yMean = values.reduce(0, +) / n
        
        let numerator = zip(xValues, values).map { ($0 - xMean) * ($1 - yMean) }.reduce(0, +)
        let denominator = xValues.map { pow($0 - xMean, 2) }.reduce(0, +)
        
        let slope = denominator != 0 ? numerator / denominator : 0
        
        let direction: TrendDirection = {
            if slope > 0.02 { return .increasing }
            if slope < -0.02 { return .decreasing }
            return .stable
        }()
        
        let strength = min(1.0, abs(slope) * 10) // Normalize strength
        let rSquared = calculateRSquared(values: values, slope: slope, intercept: yMean - slope * xMean)
        
        return TrendAnalysis(direction: direction, strength: strength, confidence: rSquared)
    }
    
    private static func calculateRSquared(values: [Double], slope: Double, intercept: Double) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let totalSumSquares = values.map { pow($0 - mean, 2) }.reduce(0, +)
        
        let predictions = values.enumerated().map { index, _ in
            slope * Double(index) + intercept
        }
        
        let residualSumSquares = zip(values, predictions).map { pow($0 - $1, 2) }.reduce(0, +)
        
        return totalSumSquares != 0 ? max(0, 1 - (residualSumSquares / totalSumSquares)) : 0
    }
}

enum TrendDirection: String, Codable {
    case increasing = "Improving"
    case decreasing = "Declining"
    case stable = "Stable"
    
    var emoji: String {
        switch self {
        case .increasing: return "📈"
        case .decreasing: return "📉"
        case .stable: return "➡️"
        }
    }
}

struct TrendAnalysis: Codable {
    let direction: TrendDirection
    let strength: Double // 0.0 to 1.0
    let confidence: Double // R-squared value
    
    var description: String {
        let strengthText = strength > 0.7 ? "Strong" : strength > 0.4 ? "Moderate" : "Weak"
        return "\(strengthText) \(direction.rawValue) trend"
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Context for Suggestions
// Note: DayContext is defined in Models.swift

// MARK: - Preview Support

// MARK: - Vibe Analyzer

/// Analyzes user patterns to understand their "vibe" and seasonal behaviors
@MainActor
class VibeAnalyzer: ObservableObject {
    @Published var currentVibe: DailyVibe = .balanced
    @Published var recentVibes: [VibeData] = []
    @Published var seasonalPatterns: [SeasonalPattern] = []
    
    private let maxVibeHistory = 14 // Keep 2 weeks of history
    
    // MARK: - Vibe Analysis
    
    func analyzeCurrentVibe(from day: Day, context: DayContext) {
        let vibe = calculateVibe(day: day, context: context)
        
        currentVibe = vibe
        
        // Store vibe data
        let vibeData = VibeData(
            date: day.date,
            vibe: vibe,
            completionRate: day.completionPercentage,
            energyDistribution: calculateEnergyDistribution(day.blocks),
            dominantActivities: findDominantActivities(day.blocks)
        )
        
        // Add to history
        recentVibes.append(vibeData)
        
        // Keep only recent history
        if recentVibes.count > maxVibeHistory {
            recentVibes.removeFirst()
        }
        
        // Update seasonal patterns
        updateSeasonalPatterns()
    }
    
    private func calculateVibe(day: Day, context: DayContext) -> DailyVibe {
        let completionRate = day.completionPercentage
        let blockCount = day.blocks.count
        let totalPlannedTime = day.blocks.reduce(0) { $0 + $1.duration }
        
        // Analyze activity patterns
        let hasLongBlocks = day.blocks.contains { $0.duration > 3600 } // 1+ hour
        let hasBreaks = day.blocks.count > 0 && totalPlannedTime < 10 * 3600 // < 10 hours planned
        let energyBalance = calculateEnergyBalance(day.blocks)
        
        // Determine vibe based on patterns
        if completionRate > 0.8 && hasLongBlocks && energyBalance > 0.5 {
            return .hustle // High completion, long focused blocks
        } else if completionRate < 0.4 && hasBreaks {
            return .takingItSlow // Low completion, plenty of breaks
        } else if blockCount <= 3 && hasBreaks {
            return .personalTime // Few activities, space for personal time
        } else if hasLongBlocks && !hasBreaks {
            return .focused // Intense focused work
        } else if energyBalance < 0.3 {
            return .recovery // Low energy activities
        } else {
            return .balanced // Default balanced approach
        }
    }
    
    private func calculateEnergyBalance(_ blocks: [TimeBlock]) -> Double {
        guard !blocks.isEmpty else { return 0.5 }
        
        let highEnergyTime = blocks.filter { $0.energy == .sunrise || $0.energy == .daylight }
            .reduce(0) { $0 + $1.duration }
        
        let totalTime = blocks.reduce(0) { $0 + $1.duration }
        
        return totalTime > 0 ? highEnergyTime / totalTime : 0.5
    }
    
    private func calculateEnergyDistribution(_ blocks: [TimeBlock]) -> [EnergyType: Double] {
        var distribution: [EnergyType: Double] = [:]
        let totalTime = blocks.reduce(0) { $0 + $1.duration }
        
        guard totalTime > 0 else { return [:] }
        
        for energyType in EnergyType.allCases {
            let energyTime = blocks.filter { $0.energy == energyType }
                .reduce(0) { $0 + $1.duration }
            distribution[energyType] = energyTime / totalTime
        }
        
        return distribution
    }
    
    private func findDominantActivities(_ blocks: [TimeBlock]) -> [String] {
        // Simple keyword extraction from block titles
        let allWords = blocks.flatMap { $0.title.lowercased().split(separator: " ").map(String.init) }
        let wordCounts = Dictionary(grouping: allWords, by: { $0 })
            .mapValues { $0.count }
            .filter { $0.value > 1 } // Only repeated activities
            .sorted { $0.value > $1.value }
        
        return Array(wordCounts.prefix(3).map { $0.key })
    }
    
    // MARK: - Seasonal Patterns
    
    private func updateSeasonalPatterns() {
        guard recentVibes.count >= 7 else { return } // Need at least a week of data
        
        let currentSeason = getCurrentSeason()
        let recentVibeTypes = recentVibes.suffix(7).map { $0.vibe }
        let dominantVibe = mostCommonVibe(recentVibeTypes)
        
        // Update or create seasonal pattern
        if let index = seasonalPatterns.firstIndex(where: { $0.season == currentSeason }) {
            seasonalPatterns[index].dominantVibes[dominantVibe, default: 0] += 1
            seasonalPatterns[index].lastObserved = Date()
        } else {
            let pattern = SeasonalPattern(
                season: currentSeason,
                dominantVibes: [dominantVibe: 1],
                suggestedActivities: generateSeasonalSuggestions(for: currentSeason),
                lastObserved: Date()
            )
            seasonalPatterns.append(pattern)
        }
    }
    
    private func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        
        switch month {
        case 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .fall
        default: return .spring
        }
    }
    
    private func mostCommonVibe(_ vibes: [DailyVibe]) -> DailyVibe {
        let counts = Dictionary(grouping: vibes, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? .balanced
    }
    
    private func generateSeasonalSuggestions(for season: Season) -> [String] {
        switch season {
        case .spring:
            return ["outdoor walks", "garden planning", "spring cleaning", "fresh starts"]
        case .summer:
            return ["outdoor activities", "vacation planning", "social gatherings", "early morning work"]
        case .fall:
            return ["preparation", "cozy indoor activities", "reflection", "skill building"]
        case .winter:
            return ["indoor projects", "reading", "planning ahead", "health focus"]
        }
    }
    
    // MARK: - Insights
    
    func getVibeInsight() -> String {
        guard !recentVibes.isEmpty else {
            return "Building understanding of your patterns..."
        }
        
        let recentVibeTypes = recentVibes.suffix(5).map { $0.vibe }
        let dominantVibe = mostCommonVibe(recentVibeTypes)
        
        switch dominantVibe {
        case .hustle:
            return "🚀 You've been in hustle mode lately - high productivity and focus!"
        case .takingItSlow:
            return "🌱 You're taking things slow and steady - great for sustainability"
        case .personalTime:
            return "🏠 You've been prioritizing personal time and self-care"
        case .focused:
            return "🎯 You're in a deep focus phase - excellent for important projects"
        case .recovery:
            return "🌙 You're in recovery mode - perfect for recharging"
        case .balanced:
            return "⚖️ You're maintaining a healthy balance across different activities"
        }
    }
    
    func getSeasonalSuggestions() -> [String] {
        let currentSeason = getCurrentSeason()
        
        if let pattern = seasonalPatterns.first(where: { $0.season == currentSeason }) {
            return pattern.suggestedActivities
        }
        
        return generateSeasonalSuggestions(for: currentSeason)
    }
}

// MARK: - Vibe Data Models

enum DailyVibe: String, Codable, CaseIterable {
    case hustle = "Hustle"
    case takingItSlow = "Taking It Slow"
    case personalTime = "Personal Time"
    case focused = "Focused"
    case recovery = "Recovery"
    case balanced = "Balanced"
    
    var emoji: String {
        switch self {
        case .hustle: return "🚀"
        case .takingItSlow: return "🌱"
        case .personalTime: return "🏠"
        case .focused: return "🎯"
        case .recovery: return "🌙"
        case .balanced: return "⚖️"
        }
    }
    
    var description: String {
        switch self {
        case .hustle: return "High productivity and intense focus"
        case .takingItSlow: return "Steady, sustainable pace"
        case .personalTime: return "Prioritizing self-care and personal activities"
        case .focused: return "Deep concentration on important work"
        case .recovery: return "Rest and recharge mode"
        case .balanced: return "Well-rounded mix of activities"
        }
    }
}

struct VibeData: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let vibe: DailyVibe
    let completionRate: Double
    let energyDistribution: [EnergyType: Double]
    let dominantActivities: [String]
    
    private enum CodingKeys: String, CodingKey {
        case id, date, vibe, completionRate, energyDistribution, dominantActivities
    }
}

enum Season: String, Codable, CaseIterable {
    case spring = "Spring"
    case summer = "Summer"
    case fall = "Fall"
    case winter = "Winter"
    
    var emoji: String {
        switch self {
        case .spring: return "🌸"
        case .summer: return "☀️"
        case .fall: return "🍂"
        case .winter: return "❄️"
        }
    }
}

struct SeasonalPattern: Identifiable, Codable {
    var id = UUID()
    let season: Season
    var dominantVibes: [DailyVibe: Int]
    var suggestedActivities: [String]
    var lastObserved: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, season, dominantVibes, suggestedActivities, lastObserved
    }
}

#if DEBUG
extension PatternLearningEngine {
    static var preview: PatternLearningEngine {
        let engine = PatternLearningEngine()
        let temporalData = TemporalData(
            peakHours: [9, 10, 14],
            productivityCurve: [],
            optimalSessionLength: 3600,
            preferredBreakDuration: 900,
            bestDaysOfWeek: []
        )
        let activityData = ActivityData(
            successfulSequences: [],
            preferredDurations: [:],
            completionPatterns: [:],
            glassStateEffectiveness: [:]
        )
        engine.detectedPatterns = [
            Pattern(
                type: .temporal,
                title: "Peak Focus Hours",
                description: "Peak focus hours: 9:00, 10:00, 14:00",
                confidence: 0.85,
                suggestion: "Schedule important work during these hours",
                data: .temporal(temporalData)
            ),
            Pattern(
                type: .activity,
                title: "Activity Sequence",
                description: "Effective sequence: Crystal→Water→Mist",
                confidence: 0.72,
                suggestion: "Follow this activity progression",
                data: .activity(activityData)
            )
        ]
        engine.insights = [
            Insight(
                title: "Morning Focus",
                description: "You're consistently more productive in the morning",
                actionable: "Block morning hours for important work",
                confidence: 0.85,
                category: .timing
            )
        ]
        engine.confidence = 0.78 
        return engine
    }
}

extension VibeAnalyzer {
    static var preview: VibeAnalyzer {
        let analyzer = VibeAnalyzer()
        analyzer.currentVibe = .focused
        analyzer.recentVibes = [
            VibeData(date: Date(), vibe: .focused, completionRate: 0.8, energyDistribution: [:], dominantActivities: ["work", "planning"]),
            VibeData(date: Date().addingTimeInterval(-86400), vibe: .balanced, completionRate: 0.7, energyDistribution: [:], dominantActivities: ["exercise", "reading"])
        ]
        return analyzer
    }
}
#endif
