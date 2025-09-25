//
//  Models.swift
//  DayPlanner
//
//  Liquid Glass Data Models
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Core Data Models

/// A time block represents any activity in the day
struct TimeBlock: Identifiable, Codable, Equatable, Transferable {
    var id = UUID()
    var title: String
    var startTime: Date
    var duration: TimeInterval // in seconds
    var energy: EnergyType
    var emoji: String // Visual identifier - replaces old flow system
    var glassState: GlassState = .solid
    var position: CGPoint = .zero // for drag interactions
    var relatedGoalId: UUID? // Link to related goal
    var relatedPillarId: UUID? // Link to related pillar
    var notes: String? // Optional freeform notes
    var confirmationState: BlockConfirmationState = .scheduled
    
    // Computed properties
    var endTime: Date {
        startTime.addingTimeInterval(duration)
    }
    
    var durationMinutes: Int {
        Int(duration / 60)
    }
    
    // Time period this block belongs to
    var period: TimePeriod {
        let hour = Calendar.current.component(.hour, from: startTime)
        switch hour {
        case 6..<12:
            return .morning
        case 12..<18:
            return .afternoon
        default:
            return .evening
        }
    }
    
    // MARK: - Initializers
    
    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date,
        duration: TimeInterval,
        energy: EnergyType,
        emoji: String,
        glassState: GlassState = .solid,
        position: CGPoint = .zero,
        relatedGoalId: UUID? = nil,
        relatedPillarId: UUID? = nil,
        notes: String? = nil,
        confirmationState: BlockConfirmationState = .scheduled
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.duration = duration
        self.energy = energy
        self.emoji = emoji
        self.glassState = glassState
        self.position = position
        self.relatedGoalId = relatedGoalId
        self.relatedPillarId = relatedPillarId
        self.notes = notes
        self.confirmationState = confirmationState
    }
    
    // MARK: - Backward Compatibility & Migration
    
    private enum CodingKeys: String, CodingKey {
        case id, title, startTime, duration, energy, emoji, glassState, position, relatedGoalId, relatedPillarId, notes, confirmationState
        case flow // Old system - for backward compatibility
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Date.self, forKey: .startTime)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        energy = try container.decode(EnergyType.self, forKey: .energy)
        glassState = try container.decodeIfPresent(GlassState.self, forKey: .glassState) ?? .solid
        position = try container.decodeIfPresent(CGPoint.self, forKey: .position) ?? .zero
        relatedGoalId = try container.decodeIfPresent(UUID.self, forKey: .relatedGoalId)
        relatedPillarId = try container.decodeIfPresent(UUID.self, forKey: .relatedPillarId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        confirmationState = try container.decodeIfPresent(BlockConfirmationState.self, forKey: .confirmationState) ?? .scheduled
        
        // Handle migration from old flow system to emoji system
        if let existingEmoji = try container.decodeIfPresent(String.self, forKey: .emoji), !existingEmoji.isEmpty {
            emoji = existingEmoji
        } else if let oldFlow = try container.decodeIfPresent(FlowState.self, forKey: .flow) {
            // Migrate from old flow system
            emoji = oldFlow.rawValue
        } else {
            // Default emoji for very old data
            emoji = "📋"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(energy, forKey: .energy)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(glassState, forKey: .glassState)
        try container.encode(position, forKey: .position)
        try container.encodeIfPresent(relatedGoalId, forKey: .relatedGoalId)
        try container.encodeIfPresent(relatedPillarId, forKey: .relatedPillarId)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(confirmationState, forKey: .confirmationState)
    }
    
    // MARK: - Transferable Conformance
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .timeBlockData)
    }
}

extension UTType {
    static let timeBlockData = UTType(exportedAs: "com.dayplanner.timeblock")
}

/// Energy levels for different types of activities
enum EnergyType: String, Codable, CaseIterable {
    case sunrise = "🌅"    // High energy, sharp focus
    case daylight = "☀️"   // Steady energy, sustained work
    case moonlight = "🌙"  // Low energy, gentle activities
    
    var description: String {
        switch self {
        case .sunrise: return "Sharp Focus"
        case .daylight: return "Steady Work"  
        case .moonlight: return "Gentle Flow"
        }
    }
    
    var color: Color {
        switch self {
        case .sunrise: return .orange
        case .daylight: return .yellow
        case .moonlight: return .purple
        }
    }
}

/// Flow states that determine visual appearance
enum FlowState: String, Codable, CaseIterable {
    case crystal = "💎"    // Precise, structured activities
    case water = "🌊"      // Fluid, creative activities
    case mist = "☁️"       // Soft, contemplative activities
    
    var description: String {
        switch self {
        case .crystal: return "Structured"
        case .water: return "Creative"
        case .mist: return "Contemplative"
        }
    }
    
    var material: Material {
        switch self {
        case .crystal: return .ultraThinMaterial
        case .water: return .regularMaterial
        case .mist: return .thickMaterial
        }
    }
}

/// Glass visual states for animations
enum GlassState: Codable, CaseIterable {
    case solid      // Committed, stable
    case liquid     // Being dragged/manipulated
    case mist       // Suggested/staged
    case crystal    // AI-generated, pristine
    
    var opacity: Double {
        switch self {
        case .solid: return 1.0
        case .liquid: return 0.8
        case .mist: return 0.6
        case .crystal: return 0.9
        }
    }
}

/// Time periods for the three main panels
enum TimePeriod: String, Codable, CaseIterable {
    case morning = "Morning Mist"
    case afternoon = "Afternoon Flow"
    case evening = "Evening Glow"
    
    var timeRange: String {
        switch self {
        case .morning: return "6:00 AM - 12:00 PM"
        case .afternoon: return "12:00 PM - 6:00 PM"
        case .evening: return "6:00 PM - 12:00 AM"
        }
    }
    
    var tint: Color {
        switch self {
        case .morning: return Color(hue: 0.6, saturation: 0.3, brightness: 0.9)
        case .afternoon: return Color(hue: 0.1, saturation: 0.4, brightness: 0.95)
        case .evening: return Color(hue: 0.8, saturation: 0.5, brightness: 0.8)
        }
    }
}

// MARK: - Chain Models

/// A chain is a sequence of related time blocks
struct Chain: Identifiable, Codable {
    let id: UUID
    var name: String
    var blocks: [TimeBlock]
    var flowPattern: FlowPattern
    var completionCount: Int
    var isActive: Bool
    var createdAt: Date
    var lastCompletedAt: Date?
    var completionHistory: [Date] = []
    var routinePromptShown: Bool = false
    var emoji: String // Visual identifier shared with related goals/pillars
    var relatedGoalId: UUID? // Link to related goal
    var relatedPillarId: UUID? // Link to related pillar
    
    // Custom Codable implementation to handle missing fields gracefully
    private enum CodingKeys: String, CodingKey {
        case id, name, blocks, flowPattern, completionCount, isActive, createdAt, lastCompletedAt, completionHistory, routinePromptShown, emoji, relatedGoalId, relatedPillarId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        blocks = try container.decode([TimeBlock].self, forKey: .blocks)
        flowPattern = try container.decode(FlowPattern.self, forKey: .flowPattern)
        completionCount = try container.decode(Int.self, forKey: .completionCount)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastCompletedAt = try container.decodeIfPresent(Date.self, forKey: .lastCompletedAt)
        
        // Handle missing fields gracefully with defaults
        completionHistory = try container.decodeIfPresent([Date].self, forKey: .completionHistory) ?? []
        routinePromptShown = try container.decodeIfPresent(Bool.self, forKey: .routinePromptShown) ?? false
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "🔗"
        relatedGoalId = try container.decodeIfPresent(UUID.self, forKey: .relatedGoalId)
        relatedPillarId = try container.decodeIfPresent(UUID.self, forKey: .relatedPillarId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(blocks, forKey: .blocks)
        try container.encode(flowPattern, forKey: .flowPattern)
        try container.encode(completionCount, forKey: .completionCount)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastCompletedAt, forKey: .lastCompletedAt)
        try container.encode(completionHistory, forKey: .completionHistory)
        try container.encode(routinePromptShown, forKey: .routinePromptShown)
        try container.encode(emoji, forKey: .emoji)
        try container.encodeIfPresent(relatedGoalId, forKey: .relatedGoalId)
        try container.encodeIfPresent(relatedPillarId, forKey: .relatedPillarId)
    }
    
    init(id: UUID = UUID(), name: String, blocks: [TimeBlock], flowPattern: FlowPattern, completionCount: Int = 0, isActive: Bool = true, createdAt: Date = Date(), lastCompletedAt: Date? = nil, emoji: String = "🔗", relatedGoalId: UUID? = nil, relatedPillarId: UUID? = nil) {
        self.id = id
        self.name = name
        self.blocks = blocks
        self.flowPattern = flowPattern
        self.completionCount = completionCount
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastCompletedAt = lastCompletedAt
        self.emoji = emoji
        self.relatedGoalId = relatedGoalId
        self.relatedPillarId = relatedPillarId
    }
    
    var canBePromotedToRoutine: Bool {
        return completionCount >= 3 && !routinePromptShown && hasProperSpacing
    }
    
    private var hasProperSpacing: Bool {
        // PRD requirement: minimum 24h separation between completions
        guard completionHistory.count >= 3 else { return false }
        
        let sortedHistory = completionHistory.sorted()
        for i in 1..<sortedHistory.count {
            let timeDifference = sortedHistory[i].timeIntervalSince(sortedHistory[i-1])
            if timeDifference < 24 * 3600 { // Less than 24 hours
                return false
            }
        }
        return true
    }
    
    var totalDuration: TimeInterval {
        blocks.reduce(0) { $0 + $1.duration }
    }
    
    var totalDurationMinutes: Int {
        Int(totalDuration / 60)
    }
}

/// Visual patterns for chain animations
enum FlowPattern: String, Codable, CaseIterable {
    case waterfall = "waterfall"  // Sequential cascading
    case spiral = "spiral"        // Circular flow
    case ripple = "ripple"        // Radial expansion
    case wave = "wave"            // Undulating motion
    
    var description: String {
        switch self {
        case .waterfall: return "Sequential Flow"
        case .spiral: return "Circular Flow"
        case .ripple: return "Expanding Flow"
        case .wave: return "Rhythmic Flow"
        }
    }
}

// MARK: - Routine Models

/// A routine is a chain that has been promoted after 3+ completions
struct Routine: Identifiable, Codable {
    let id: UUID
    let chainId: UUID
    var name: String
    var adoptionScore: Double // How well-established this routine is (0.0 to 1.0)
    var scheduleRules: [RoutineScheduleRule]
    var isActive: Bool
    var createdAt: Date
    var lastSuggested: Date?
    
    init(id: UUID = UUID(), chainId: UUID, name: String, adoptionScore: Double = 0.5, scheduleRules: [RoutineScheduleRule] = [], isActive: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.chainId = chainId
        self.name = name
        self.adoptionScore = adoptionScore
        self.scheduleRules = scheduleRules
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

struct RoutineScheduleRule: Identifiable, Codable {
    let id: UUID
    var dayOfWeek: Set<Int>? // 1-7, Sunday = 1
    var timeOfDay: TimeWindow?
    var frequency: RoutineFrequency
    var conditions: [RoutineCondition]
    
    init(id: UUID = UUID(), dayOfWeek: Set<Int>? = nil, timeOfDay: TimeWindow? = nil, frequency: RoutineFrequency = .daily, conditions: [RoutineCondition] = []) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.timeOfDay = timeOfDay
        self.frequency = frequency
        self.conditions = conditions
    }
}

enum RoutineFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekdays = "Weekdays"
    case weekends = "Weekends"
    case specific = "Specific Days"
    
    var description: String { return rawValue }
}

enum RoutineCondition: String, Codable, CaseIterable {
    case weatherSunny = "When sunny"
    case weatherRainy = "When rainy"
    case afterActivity = "After specific activity"
    case beforeActivity = "Before specific activity"
    case energyHigh = "When energy is high"
    case energyLow = "When energy is low"
    
    var description: String { return rawValue }
}

// MARK: - Day Model

/// Represents a complete day with its mood and blocks
struct Day: Identifiable, Codable {
    let id: UUID
    var date: Date
    var blocks: [TimeBlock]
    var mood: GlassMood
    var completedBlocks: Int
    
    init(id: UUID = UUID(), date: Date, blocks: [TimeBlock] = [], mood: GlassMood = .crystal, completedBlocks: Int = 0) {
        self.id = id
        self.date = date
        self.blocks = blocks
        self.mood = mood
        self.completedBlocks = completedBlocks
    }
    
    // Computed properties for three time periods
    var morningBlocks: [TimeBlock] {
        blocks.filter { $0.period == .morning }.sorted { $0.startTime < $1.startTime }
    }
    
    var afternoonBlocks: [TimeBlock] {
        blocks.filter { $0.period == .afternoon }.sorted { $0.startTime < $1.startTime }
    }
    
    var eveningBlocks: [TimeBlock] {
        blocks.filter { $0.period == .evening }.sorted { $0.startTime < $1.startTime }
    }
    
    var completionPercentage: Double {
        guard !blocks.isEmpty else { return 0 }
        return Double(completedBlocks) / Double(blocks.count)
    }
}

/// Overall mood/theme of the day affecting glass appearance
enum GlassMood: String, Codable, CaseIterable {
    case crystal = "crystal"    // Clear, focused day
    case mist = "mist"          // Gentle, flowing day
    case prism = "prism"        // Creative, dynamic day
    case storm = "storm"        // Intense, challenging day
    
    var description: String {
        switch self {
        case .crystal: return "Clear & Focused"
        case .mist: return "Gentle & Flowing"
        case .prism: return "Creative & Dynamic"
        case .storm: return "Intense & Challenging"
        }
    }
    
    var backgroundGradient: LinearGradient {
        switch self {
        case .crystal:
            return LinearGradient(colors: [.clear, .blue.opacity(0.1)], startPoint: .top, endPoint: .bottom)
        case .mist:
            return LinearGradient(colors: [.gray.opacity(0.1), .white.opacity(0.2)], startPoint: .top, endPoint: .bottom)
        case .prism:
            return LinearGradient(colors: [.purple.opacity(0.1), .pink.opacity(0.1), .orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .storm:
            return LinearGradient(colors: [.gray.opacity(0.2), .black.opacity(0.1)], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - AI Models

/// AI suggestion for time blocks
struct Suggestion: Identifiable, Codable {
    let id: UUID
    var title: String
    var duration: TimeInterval
    var suggestedTime: Date
    var energy: EnergyType
    var emoji: String
    var explanation: String
    var confidence: Double // 0.0 to 1.0
    var relatedGoalId: UUID? = nil
    var relatedPillarId: UUID? = nil
    
    init(id: UUID = UUID(), title: String, duration: TimeInterval, suggestedTime: Date, energy: EnergyType, emoji: String, explanation: String, confidence: Double, relatedGoalId: UUID? = nil, relatedPillarId: UUID? = nil) {
        self.id = id
        self.title = title
        self.duration = duration
        self.suggestedTime = suggestedTime
        self.energy = energy
        self.emoji = emoji
        self.explanation = explanation
        self.confidence = confidence
        self.relatedGoalId = relatedGoalId
        self.relatedPillarId = relatedPillarId
    }
    
    func toTimeBlock() -> TimeBlock {
        TimeBlock(
            title: title,
            startTime: suggestedTime,
            duration: duration,
            energy: energy,
            emoji: emoji,
            glassState: .crystal,
            relatedGoalId: relatedGoalId,
            relatedPillarId: relatedPillarId
        )
    }
}

/// Context for AI decision making
struct DayContext: Codable {
    let date: Date
    let existingBlocks: [TimeBlock]
    let currentEnergy: EnergyType
    let preferredEmojis: [String]
    let availableTime: TimeInterval
    let mood: GlassMood
    let weatherContext: String?
    let pillarGuidance: [String] // New: guidance from principle pillars
    let actionablePillars: [Pillar] // New: pillars that can create events
    
    init(date: Date, existingBlocks: [TimeBlock], currentEnergy: EnergyType, preferredEmojis: [String], availableTime: TimeInterval, mood: GlassMood, weatherContext: String? = nil, pillarGuidance: [String] = [], actionablePillars: [Pillar] = []) {
        self.date = date
        self.existingBlocks = existingBlocks
        self.currentEnergy = currentEnergy
        self.preferredEmojis = preferredEmojis
        self.availableTime = availableTime
        self.mood = mood
        self.weatherContext = weatherContext
        self.pillarGuidance = pillarGuidance
        self.actionablePillars = actionablePillars
    }
    
    var summary: String {
        var summary = """
        Date: \(date.formatted(date: .abbreviated, time: .omitted))
        Energy: \(currentEnergy.description)
        Blocks: \(existingBlocks.count)
        Available: \(Int(availableTime/3600))h
        Mood: \(mood.description)
        """
        
        if let weather = weatherContext {
            summary += "\nWeather: \(weather)"
        }
        
        if !pillarGuidance.isEmpty {
            summary += "\nGuiding principles: \(pillarGuidance.joined(separator: "; "))"
        }
        
        if !actionablePillars.isEmpty {
            summary += "\nActionable pillars: \(actionablePillars.map(\.name).joined(separator: ", "))"
        }
        
        return summary
    }
}

// MARK: - App State

/// Complete app state - simple and focused
struct AppState: Codable {
    var currentDay: Day = Day(date: Date())
    var historicalDays: [Day] = [] // Store previous days for persistence
    var recentChains: [Chain] = []
    var routines: [Routine] = [] // Promoted chains that became routines
    var userPatterns: [String] = [] // Simple pattern storage
    var preferences: UserPreferences = UserPreferences()
    var records: [Record] = []
    
    // XP/XXP System
    var userXP: Int = 0 // Knowledge about user
    var userXXP: Int = 0 // Work accomplished
    
    // Pillars and Goals (PRD requirements)
    var pillars: [Pillar] = []
    var goals: [Goal] = []
    var dreamConcepts: [DreamConcept] = []
    var intakeQuestions: [IntakeQuestion] = []
    
    // Helper methods
    mutating func addBlock(_ block: TimeBlock) {
        currentDay.blocks.append(block)
    }
    
    mutating func updateBlock(_ block: TimeBlock) {
        if let index = currentDay.blocks.firstIndex(where: { $0.id == block.id }) {
            currentDay.blocks[index] = block
        }
    }
    
    mutating func removeBlock(_ blockId: UUID) {
        currentDay.blocks.removeAll { $0.id == blockId }
    }
    
    // XP/XXP methods
    mutating func addXP(_ amount: Int, reason: String) {
        userXP += amount
        // Could log the reason for transparency
    }
    
    mutating func addXXP(_ amount: Int, reason: String) {
        userXXP += amount
        // Could log the reason for transparency
    }
}

enum BlockConfirmationState: String, Codable, CaseIterable {
    case scheduled
    case unconfirmed
    case confirmed
}

struct Record: Identifiable, Codable {
    var id = UUID()
    var blockId: UUID
    var title: String
    var startTime: Date
    var endTime: Date
    var notes: String?
    var energy: EnergyType
    var emoji: String
    var confirmedAt: Date = Date()
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

/// Simple user preferences
struct UserPreferences: Codable {
    var preferredStartTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    var preferredEndTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    var defaultBlockDuration: TimeInterval = 3600 // 1 hour
    var favoriteEnergy: EnergyType = .daylight
    var favoriteEmoji: String = "📋"
    var enableVoice: Bool = true
    var enableAnimations: Bool = true
    
    // PRD Required Settings  
    var showEphemeralInsights: Bool = true
    var safeMode: Bool = false // Safe Mode: only non-destructive suggestions
    
    // Calendar & Integration
    var eventKitEnabled: Bool = true
    var twoWaySync: Bool = true
    var respectCalendarPrivacy: Bool = true
    
    // History & Undo
    var keepUndoHistory: Bool = true
    var historyRetentionDays: Int = 30
    
    
    // AI API Configuration
    var openaiApiKey: String = ""
    var whisperApiKey: String = ""
    var customApiEndpoint: String = ""
}

// MARK: - Extensions for UI

// TimeBlock extensions are defined in Extensions.swift

extension Chain {
    /// Create a sample chain for previews
    static func sample(name: String = "Morning Routine") -> Chain {
        let blocks = [
            TimeBlock.sample(title: "Wake Up", hour: 7),
            TimeBlock.sample(title: "Exercise", hour: 8),
            TimeBlock.sample(title: "Breakfast", hour: 9)
        ]
        return Chain(name: name, blocks: blocks, flowPattern: .waterfall)
    }
}

extension Day {
    /// Create a sample day for previews
    static func sample() -> Day {
        var day = Day(date: Date())
        day.blocks = [
            TimeBlock.sample(title: "Morning Coffee", hour: 8),
            TimeBlock.sample(title: "Deep Work", hour: 9),
            TimeBlock.sample(title: "Lunch Break", hour: 12),
            TimeBlock.sample(title: "Meetings", hour: 14),
            TimeBlock.sample(title: "Creative Time", hour: 16),
            TimeBlock.sample(title: "Evening Walk", hour: 19)
        ]
        return day
    }
}

// MARK: - PRD Required Models

/// Pillar: Core life principles that guide all AI decisions - can be actionable (events) or principle (values/thoughts)
struct Pillar: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var type: PillarType // New: actionable vs principle
    var frequency: PillarFrequency
    var minDuration: TimeInterval // in seconds (only for actionable pillars)
    var maxDuration: TimeInterval // (only for actionable pillars)
    var preferredTimeWindows: [TimeWindow]
    var overlapRules: [OverlapRule]
    var quietHours: [TimeWindow] // When this pillar should not be suggested
    var eventConsiderationEnabled: Bool // New: for principles that inform AI but don't create events
    var wisdomText: String? // New: core wisdom/principles for AI guidance
    var color: CodableColor
    var emoji: String // Visual identifier shared with related goals/chains/events
    var relatedGoalId: UUID? // Link to related goal
    var lastEventDate: Date? // Track when pillar events were last created
    
    init(id: UUID = UUID(), name: String, description: String, type: PillarType = .actionable, frequency: PillarFrequency, minDuration: TimeInterval = 1800, maxDuration: TimeInterval = 7200, preferredTimeWindows: [TimeWindow] = [], overlapRules: [OverlapRule] = [], quietHours: [TimeWindow] = [], eventConsiderationEnabled: Bool = false, wisdomText: String? = nil, color: CodableColor = CodableColor(.blue), emoji: String = "🏛️", relatedGoalId: UUID? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.frequency = frequency
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.preferredTimeWindows = preferredTimeWindows
        self.overlapRules = overlapRules
        self.quietHours = quietHours
        self.eventConsiderationEnabled = eventConsiderationEnabled
        self.wisdomText = wisdomText
        self.color = color
        self.emoji = emoji
        self.relatedGoalId = relatedGoalId
        self.lastEventDate = nil
    }
    
    var frequencyDescription: String {
        switch frequency {
        case .daily: return "Daily"
        case .weekly(let count): return "\(count)x per week"
        case .monthly(let count): return "\(count)x per month"
        case .asNeeded: return "As needed"
        }
    }
    
    var isActionable: Bool {
        return type == .actionable
    }
    
    var isPrinciple: Bool {
        return type == .principle
    }
    
    /// Get the wisdom context for AI - combines description and wisdom text
    var aiGuidanceText: String {
        let base = description
        if let wisdom = wisdomText, !wisdom.isEmpty {
            return "\(base)\n\nCore principle: \(wisdom)"
        }
        return base
    }
}

enum PillarType: String, Codable, CaseIterable {
    case actionable = "Actionable" // Creates events/time blocks
    case principle = "Principle"   // Guides AI decisions but doesn't create events
    
    var description: String {
        switch self {
        case .actionable: return "Creates scheduled activities"
        case .principle: return "Guides AI decisions and suggestions"
        }
    }
    
    var icon: String {
        switch self {
        case .actionable: return "calendar.badge.plus"
        case .principle: return "lightbulb"
        }
    }
}

enum PillarFrequency: Codable, Hashable, CaseIterable {
    case daily
    case weekly(Int)
    case monthly(Int) 
    case asNeeded
    
    static var allCases: [PillarFrequency] {
        [.daily, .weekly(1), .monthly(1), .asNeeded]
    }
    
    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly(let count):
            return count == 1 ? "Weekly" : "\(count)x per week"
        case .monthly(let count):
            return count == 1 ? "Monthly" : "\(count)x per month"
        case .asNeeded:
            return "As needed"
        }
    }
}

struct TimeWindow: Codable {
    let startHour: Int // 0-23
    let startMinute: Int // 0-59
    let endHour: Int
    let endMinute: Int
    
    var description: String {
        let startTime = String(format: "%02d:%02d", startHour, startMinute)
        let endTime = String(format: "%02d:%02d", endHour, endMinute)
        return "\(startTime) - \(endTime)"
    }
}

enum OverlapRule: Codable {
    case cannotOverlap([String]) // Pillar names that cannot overlap
    case mustFollow(String) // Must come after this pillar
    case mustPrecede(String) // Must come before this pillar
    case requiresBuffer(TimeInterval) // Needs buffer time after
}

/// Goal: Draft / On / Off; groups & tasks > suggestions
struct Goal: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var state: GoalState
    var importance: Int // 1-5, AI uses this for scoring
    var groups: [GoalGroup]
    var createdAt: Date
    var targetDate: Date?
    var progress: Double // 0.0 to 1.0
    var emoji: String // Visual identifier shared with related pillars/chains/events
    var relatedPillarIds: [UUID] // Links to supporting pillars
    
    init(id: UUID = UUID(), title: String, description: String, state: GoalState, importance: Int, groups: [GoalGroup], createdAt: Date = Date(), targetDate: Date? = nil, progress: Double = 0.0, emoji: String = "🎯", relatedPillarIds: [UUID] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.state = state
        self.importance = importance
        self.groups = groups
        self.createdAt = createdAt
        self.targetDate = targetDate
        self.progress = progress
        self.emoji = emoji
        self.relatedPillarIds = relatedPillarIds
    }
    
    var isActive: Bool {
        state == .on
    }
    
    var needsBreakdown: Bool {
        return groups.isEmpty && state != .off
    }
}

// MARK: - Goal Breakdown Actions

enum GoalBreakdownAction {
    case createChain(Chain)
    case createPillar(Pillar)
    case createEvent(TimeBlock)
    case updateGoal(Goal)
}

enum GoalState: String, Codable, CaseIterable {
    case draft = "Draft"
    case on = "On"
    case off = "Off"
    
    var description: String {
        switch self {
        case .draft: return "Draft - preparation phase"
        case .on: return "On - actively working towards"
        case .off: return "Off - paused"
        }
    }
}

struct GoalGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var tasks: [GoalTask]
    
    init(id: UUID = UUID(), name: String, tasks: [GoalTask]) {
        self.id = id
        self.name = name
        self.tasks = tasks
    }
    var isCompleted: Bool {
        !tasks.isEmpty && tasks.allSatisfy { $0.isCompleted }
    }
}

struct GoalTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var isCompleted: Bool
    var estimatedDuration: TimeInterval?
    var suggestedChains: [UUID] // Chain IDs that help accomplish this task
    var actionQuality: Int // 1-5, AI scoring of how good this action is
    
    init(id: UUID = UUID(), title: String, description: String, isCompleted: Bool = false, estimatedDuration: TimeInterval? = nil, suggestedChains: [UUID], actionQuality: Int = 3) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.estimatedDuration = estimatedDuration
        self.suggestedChains = suggestedChains
        self.actionQuality = actionQuality
    }
}

/// Dream Builder: recurring desires/themes captured from chats and calendar notes
struct DreamConcept: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var mentions: Int // How many times user has mentioned this
    var lastMentioned: Date
    var relatedKeywords: [String]
    var canMergeWith: [UUID] // Other dream concept IDs
    var hasBeenPromotedToGoal: Bool
    
    init(id: UUID = UUID(), title: String, description: String, mentions: Int = 1, lastMentioned: Date = Date(), relatedKeywords: [String] = [], canMergeWith: [UUID] = [], hasBeenPromotedToGoal: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.mentions = mentions
        self.lastMentioned = lastMentioned
        self.relatedKeywords = relatedKeywords
        self.canMergeWith = canMergeWith
        self.hasBeenPromotedToGoal = hasBeenPromotedToGoal
    }
    
    var priority: Double {
        // Simple priority based on mentions and recency
        let recencyFactor = max(0.1, 1.0 - (Date().timeIntervalSince(lastMentioned) / (30 * 24 * 3600))) // 30 days
        return Double(mentions) * recencyFactor
    }
}

/// Intake Q&A: short, targeted questions; long‑press any card for "what the AI thinks"
struct IntakeQuestion: Identifiable, Codable {
    let id: UUID
    var question: String
    var category: IntakeCategory
    var answer: String?
    var answeredAt: Date?
    var importance: Int // 1-5
    var aiInsight: String? // What AI thinks about this answer
    
    init(id: UUID = UUID(), question: String, category: IntakeCategory, answer: String? = nil, answeredAt: Date? = nil, importance: Int = 3, aiInsight: String? = nil) {
        self.id = id
        self.question = question
        self.category = category
        self.answer = answer
        self.answeredAt = answeredAt
        self.importance = importance
        self.aiInsight = aiInsight
    }
    
    var isAnswered: Bool {
        answer != nil && !(answer?.isEmpty ?? true)
    }
}

enum IntakeCategory: String, Codable, CaseIterable {
    case routine = "Routine"
    case preferences = "Preferences"
    case constraints = "Constraints"
    case goals = "Goals"
    case energy = "Energy Patterns"
    case context = "Context"
    
    var description: String {
        switch self {
        case .routine: return "Daily routines and habits"
        case .preferences: return "Likes and dislikes"
        case .constraints: return "Time and resource limitations"
        case .goals: return "Aspirations and objectives"
        case .energy: return "Energy levels throughout the day"
        case .context: return "Life context and situation"
        }
    }
}

// MARK: - Helper Types

/// Codable wrapper for SwiftUI Color
struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(_ color: Color) {
        // This is a simplified approach - in practice you'd need more sophisticated color extraction
        self.red = 0.5
        self.green = 0.5
        self.blue = 1.0
        self.alpha = 1.0
    }
    
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Sample Data Extensions

extension Pillar {
    static func samplePillars() -> [Pillar] {
        [
            Pillar(
                name: "Exercise",
                description: "Physical activity and fitness",
                frequency: .daily,
                minDuration: 1800, // 30 minutes
                maxDuration: 7200, // 2 hours
                preferredTimeWindows: [
                    TimeWindow(startHour: 6, startMinute: 0, endHour: 8, endMinute: 0),
                    TimeWindow(startHour: 17, startMinute: 0, endHour: 19, endMinute: 0)
                ],
                overlapRules: [.requiresBuffer(900)], // 15 min buffer
                quietHours: [
                    TimeWindow(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)
                ],
                color: CodableColor(.orange)
            ),
            Pillar(
                name: "Deep Work",
                description: "Focused, uninterrupted work sessions",
                frequency: .daily,
                minDuration: 3600, // 1 hour
                maxDuration: 14400, // 4 hours
                preferredTimeWindows: [
                    TimeWindow(startHour: 9, startMinute: 0, endHour: 12, endMinute: 0)
                ],
                overlapRules: [.cannotOverlap(["Meetings", "Social"])],
                quietHours: [
                    TimeWindow(startHour: 19, startMinute: 0, endHour: 9, endMinute: 0)
                ],
                color: CodableColor(.blue)
            ),
            Pillar(
                name: "Rest",
                description: "Relaxation and recovery time",
                frequency: .daily,
                minDuration: 1800, // 30 minutes
                maxDuration: 10800, // 3 hours
                preferredTimeWindows: [
                    TimeWindow(startHour: 19, startMinute: 0, endHour: 22, endMinute: 0)
                ],
                overlapRules: [.mustFollow("Work")],
                quietHours: [],
                color: CodableColor(.purple)
            )
        ]
    }
}

extension Goal {
    static func sampleGoals() -> [Goal] {
        [
            Goal(
                title: "Launch Side Project",
                description: "Build and launch my productivity app",
                state: .on,
                importance: 5,
                groups: [
                    GoalGroup(
                        name: "Development",
                        tasks: [
                            GoalTask(
                                title: "Complete MVP features",
                                description: "Build core functionality",
                                estimatedDuration: 3600 * 40, // 40 hours
                                suggestedChains: [],
                                actionQuality: 5
                            ),
                            GoalTask(
                                title: "User testing",
                                description: "Get feedback from beta users",
                                estimatedDuration: 3600 * 8, // 8 hours
                                suggestedChains: [],
                                actionQuality: 4
                            )
                        ]
                    ),
                    GoalGroup(
                        name: "Marketing",
                        tasks: [
                            GoalTask(
                                title: "Create landing page",
                                description: "Build a simple landing page",
                                estimatedDuration: 3600 * 6, // 6 hours
                                suggestedChains: [],
                                actionQuality: 3
                            )
                        ]
                    )
                ],
                targetDate: Calendar.current.date(byAdding: .month, value: 3, to: Date())
            ),
            Goal(
                title: "Improve Health",
                description: "Get in better physical shape",
                state: .on,
                importance: 4,
                groups: [
                    GoalGroup(
                        name: "Exercise",
                        tasks: [
                            GoalTask(
                                title: "Morning runs",
                                description: "Run 3x per week",
                                suggestedChains: [],
                                actionQuality: 4
                            ),
                            GoalTask(
                                title: "Strength training",
                                description: "Gym 2x per week",
                                suggestedChains: [],
                                actionQuality: 4
                            )
                        ]
                    )
                ],
                targetDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())
            )
        ]
    }
}

extension IntakeQuestion {
    static func sampleQuestions() -> [IntakeQuestion] {
        [
            IntakeQuestion(
                question: "What time do you usually have dinner?",
                category: .routine,
                importance: 4,
                aiInsight: "Knowing meal times helps schedule around energy dips and social commitments"
            ),
            IntakeQuestion(
                question: "Which days do you typically commute to work?",
                category: .constraints,
                importance: 5,
                aiInsight: "Commute days affect available time blocks and energy patterns"
            ),
            IntakeQuestion(
                question: "When do you feel most energetic and focused?",
                category: .energy,
                importance: 5,
                aiInsight: "Peak energy times should be reserved for your most important work"
            ),
            IntakeQuestion(
                question: "Do you prefer to exercise before or after work?",
                category: .preferences,
                importance: 3,
                aiInsight: "Exercise timing affects both energy levels and schedule constraints"
            )
        ]
    }
}

// MARK: - Extensions for Enhanced UI

enum TimeframeSelector: String, CaseIterable {
    case now = "Now"
    case lastTwoWeeks = "Last 2 weeks"
    case custom = "Custom"
    
    /// Short title for compact display in the new split view
    var shortTitle: String {
        switch self {
        case .now: return "Now"
        case .lastTwoWeeks: return "2wks"
        case .custom: return "Custom"
        }
    }
}

extension FlowPattern {
    /// Emoji representation for visual display
    var emoji: String {
        switch self {
        case .waterfall: return "⬇️"
        case .spiral: return "🌀" 
        case .ripple: return "〰️"
        case .wave: return "🌊"
        }
    }
}

// MARK: - Chain Templates

/// Chain templates for quick creation
struct ChainTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let activities: [String]
    let totalDuration: Int // in minutes
    let energyFlow: [EnergyType]
    
    var description: String {
        "\(activities.count) activities • \(totalDuration)min"
    }
}

// MARK: - Backfill Support

enum BackfillViewMode: String, CaseIterable {
    case timeline = "Timeline"
    case hybrid = "Hybrid"
    case list = "List"
    
    var icon: String {
        switch self {
        case .timeline: return "clock"
        case .hybrid: return "squares.below.rectangle"
        case .list: return "list.bullet"
        }
    }
}

struct QuickTemplate {
    let title: String
    let icon: String
    let duration: TimeInterval
    let energy: EnergyType
    let emoji: String
}
