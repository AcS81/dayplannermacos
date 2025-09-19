//
//  PatternLearning.swift
//  DayPlanner
//
//  Intelligent pattern recognition and learning system
//

import Foundation
import SwiftUI

// MARK: - Pattern Learning Engine

/// Learns from user behavior to suggest optimal scheduling
@MainActor
class PatternLearningEngine: ObservableObject {
    @Published var detectedPatterns: [Pattern] = []
    @Published var insights: [Insight] = []
    @Published var confidence: Double = 0.0
    
    private var behaviorHistory: [BehaviorEvent] = []
    private let maxHistorySize = 1000
    
    // Debouncing mechanism
    private var analysisTask: Task<Void, Never>?
    private let analysisDebounceInterval: TimeInterval = 2.0 // 2 second debounce
    private var lastAnalysisTime: Date = .distantPast
    
    // Incremental analysis tracking
    private var lastAnalyzedEventCount = 0
    private var cachedPatterns: [Pattern] = []
    
    init() {
        loadPatterns()
    }
    
    // MARK: - Learning Methods
    
    /// Record a behavior event for pattern analysis
    func recordBehavior(_ event: BehaviorEvent) {
        behaviorHistory.append(event)
        
        // Keep history manageable
        if behaviorHistory.count > maxHistorySize {
            behaviorHistory.removeFirst(behaviorHistory.count - maxHistorySize)
        }
        
        // Debounced pattern analysis
        debouncedAnalyzePatterns()
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
        case .flow:
            // Check flow sequence alignment
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
            guard case .blockCompleted(let block, let success) = event.type,
                  block.flow == .crystal || block.flow == .water else { return nil }
            
            let hour = Calendar.current.component(.hour, from: event.timestamp)
            return (hour: hour, success: success)
        }
        
        if workingBlocks.count >= 10 {
            let successByHour = Dictionary(grouping: workingBlocks) { $0.hour }
                .mapValues { hourEvents in
                    let successCount = hourEvents.filter(\.success).count
                    return Double(successCount) / Double(hourEvents.count)
                }
            
            // Find peak performance hours
            let bestHours = successByHour
                .filter { $0.value > 0.7 }
                .sorted { $0.value > $1.value }
                .prefix(3)
            
            if !bestHours.isEmpty {
                let hourList = bestHours.map { "\($0.key):00" }.joined(separator: ", ")
                patterns.append(Pattern(
                    type: .temporal,
                    description: "Peak focus hours: \(hourList)",
                    confidence: bestHours.first?.value ?? 0.7,
                    suggestion: "Schedule important work during these hours",
                    data: ["hours": Array(bestHours.map(\.key))]
                ))
            }
        }
        
        // Analyze break patterns
        let breakEvents = behaviorHistory.filter {
            if case .blockCompleted(let block, _) = $0.type {
                return block.flow == .mist
            }
            return false
        }
        
        if breakEvents.count >= 5 {
            let avgBreakDuration = breakEvents.compactMap { event -> TimeInterval? in
                if case .blockCompleted(let block, _) = event.type {
                    return block.duration
                }
                return nil
            }.reduce(0, +) / Double(breakEvents.count)
            
            patterns.append(Pattern(
                type: .temporal,
                description: "Optimal break length: \(Int(avgBreakDuration/60)) minutes",
                confidence: 0.6,
                suggestion: "Take breaks of this length for better recovery",
                data: ["duration": avgBreakDuration]
            ))
        }
        
        return patterns
    }
    
    private func analyzeEnergyPatterns() async -> [Pattern] {
        var patterns: [Pattern] = []
        
        let energyEvents = behaviorHistory.compactMap { event -> (energy: EnergyType, hour: Int, success: Bool)? in
            guard case .blockCompleted(let block, let success) = event.type else { return nil }
            let hour = Calendar.current.component(.hour, from: event.timestamp)
            return (energy: block.energy, hour: hour, success: success)
        }
        
        if energyEvents.count >= 15 {
            // Analyze energy-hour compatibility
            let energyByHour = Dictionary(grouping: energyEvents) { "\($0.energy)-\($0.hour)" }
                .mapValues { events in
                    let successCount = events.filter(\.success).count
                    return Double(successCount) / Double(events.count)
                }
            
            let bestMatches = energyByHour
                .filter { $0.value > 0.8 }
                .sorted { $0.value > $1.value }
                .prefix(3)
            
            if !bestMatches.isEmpty {
                patterns.append(Pattern(
                    type: .energy,
                    description: "Best energy-time matches found",
                    confidence: bestMatches.first?.value ?? 0.8,
                    suggestion: "Match activities to your natural energy rhythm",
                    data: ["matches": bestMatches.map(\.key)]
                ))
            }
        }
        
        return patterns
    }
    
    private func analyzeFlowPatterns() async -> [Pattern] {
        var patterns: [Pattern] = []
        
        // Analyze flow sequences
        let flowSequences = behaviorHistory
            .compactMap { event -> FlowState? in
                guard case .blockCompleted(let block, true) = event.type else { return nil }
                return block.flow
            }
            .chunked(into: 3) // Look for 3-item sequences
        
        if flowSequences.count >= 5 {
            let sequenceCounts = flowSequences.reduce(into: [String: Int]()) { counts, sequence in
                let key = sequence.map(\.rawValue).joined(separator: "→")
                counts[key, default: 0] += 1
            }
            
            let topSequence = sequenceCounts.max { $0.value < $1.value }
            
            if let topSequence = topSequence, topSequence.value >= 3 {
                patterns.append(Pattern(
                    type: .flow,
                    description: "Effective flow sequence: \(topSequence.key)",
                    confidence: min(Double(topSequence.value) / Double(flowSequences.count), 0.9),
                    suggestion: "Continue using this activity progression",
                    data: ["sequence": topSequence.key, "count": topSequence.value]
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
            patterns.append(Pattern(
                type: .behavioral,
                description: "Chains improve productivity by 40%",
                confidence: 0.7,
                suggestion: "Create more chains for recurring activities",
                data: ["improvement": 0.4]
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
        
        // Flow insights
        let flowPatterns = detectedPatterns.filter { $0.type == .flow }
        if !flowPatterns.isEmpty {
            newInsights.append(Insight(
                title: "Flow Sequences",
                description: "Certain activity progressions work better for you",
                actionable: "Follow your successful flow patterns",
                confidence: flowPatterns.map(\.confidence).reduce(0, +) / Double(flowPatterns.count),
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
        if let timePattern = detectedPatterns.first(where: { $0.type == .temporal }),
           let hours = timePattern.data["hours"] as? [Int] {
            let currentHour = Calendar.current.component(.hour, from: Date())
            
            if hours.contains(currentHour) || hours.contains(currentHour + 1) {
                suggestions.append(Suggestion(
                    title: "Focus Session",
                    duration: 5400, // 90 minutes
                    suggestedTime: Date().setting(hour: currentHour) ?? Date(),
                    energy: context.currentEnergy,
                    flow: .crystal,
                    explanation: "This is one of your peak focus hours",
                    confidence: timePattern.confidence
                ))
            }
        }
        
        // Energy-based suggestions
        if let energyPattern = detectedPatterns.first(where: { $0.type == .energy }) {
            let suggestion = createEnergySuggestion(for: context, pattern: energyPattern)
            suggestions.append(suggestion)
        }
        
        // Flow sequence suggestions
        if let flowPattern = detectedPatterns.first(where: { $0.type == .flow }),
           let sequence = flowPattern.data["sequence"] as? String {
            let flows = sequence.components(separatedBy: "→").compactMap { FlowState(rawValue: $0) }
            
            if let nextFlow = flows.first {
                suggestions.append(Suggestion(
                    title: "\(nextFlow.description.capitalized) Activity",
                    duration: 2700, // 45 minutes
                    suggestedTime: Date().adding(minutes: 30),
                    energy: context.currentEnergy,
                    flow: nextFlow,
                    explanation: "Following your successful activity pattern",
                    confidence: flowPattern.confidence
                ))
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
            flow: context.preferredFlows.first ?? .water,
            explanation: "Matched to your energy pattern preferences",
            confidence: pattern.confidence
        )
    }
    
    // MARK: - Data Persistence
    
    private func loadPatterns() {
        // Load from UserDefaults or file storage
        // For now, we'll start with empty patterns
    }
    
    func savePatterns() {
        // Save patterns to persistent storage
        // Implementation would depend on chosen storage method
    }
}

// MARK: - Data Models

/// Represents a detected behavioral pattern
struct Pattern: Identifiable {
    let id = UUID()
    let type: PatternType
    let description: String
    let confidence: Double // 0.0 to 1.0
    let suggestion: String
    let data: [String: Any] // Additional pattern data
    
    var confidenceText: String {
        switch confidence {
        case 0.9...: return "Very High"
        case 0.7..<0.9: return "High"
        case 0.5..<0.7: return "Medium"
        default: return "Low"
        }
    }
    
    /// Create a copy of this pattern with updated confidence
    func withUpdatedConfidence(_ newConfidence: Double) -> Pattern {
        return Pattern(
            type: self.type,
            description: self.description,
            confidence: newConfidence,
            suggestion: self.suggestion,
            data: self.data
        )
    }
}

enum PatternType: String, CaseIterable {
    case temporal = "Time-based"
    case energy = "Energy-based"
    case flow = "Flow-based"
    case behavioral = "Behavioral"
    case environmental = "Environmental"
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

/// Individual behavior event for analysis
struct BehaviorEvent {
    let timestamp: Date
    let type: BehaviorEventType
    
    init(_ type: BehaviorEventType) {
        self.timestamp = Date()
        self.type = type
    }
}

enum BehaviorEventType {
    case blockCreated(TimeBlock)
    case blockCompleted(TimeBlock, success: Bool)
    case blockModified(TimeBlock, changes: String)
    case chainApplied(Chain)
    case suggestionAccepted(Suggestion)
    case suggestionRejected(Suggestion)
    case dayReviewed(Day, rating: Int)
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
    var id = UUID()
    let date: Date
    let vibe: DailyVibe
    let completionRate: Double
    let energyDistribution: [EnergyType: Double]
    let dominantActivities: [String]
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
}

#if DEBUG
extension PatternLearningEngine {
    static var preview: PatternLearningEngine {
        let engine = PatternLearningEngine()
        engine.detectedPatterns = [
            Pattern(
                type: .temporal,
                description: "Peak focus hours: 9:00, 10:00, 14:00",
                confidence: 0.85,
                suggestion: "Schedule important work during these hours",
                data: ["hours": [9, 10, 14]]
            ),
            Pattern(
                type: .flow,
                description: "Effective sequence: Crystal→Water→Mist",
                confidence: 0.72,
                suggestion: "Follow this activity progression",
                data: ["sequence": "Crystal→Water→Mist"]
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
