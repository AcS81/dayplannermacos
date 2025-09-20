//
//  Storage.swift
//  DayPlanner
//
//  Simple JSON-based local storage for liquid glass data
//

import Foundation
import SwiftUI
import EventKit
import CoreLocation
import Speech
import AVFoundation

// MARK: - Shared DateFormatters

/// Shared DateFormatter instances to avoid recreation overhead
private struct DateFormatters {
    static let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// Simple, local-first data manager
@MainActor
class AppDataManager: ObservableObject {
    @Published var appState = AppState()
    @Published var isLoading = false
    @Published var lastSaved: Date?
    
    // Background actor for heavy I/O operations
    private let persistenceActor = PersistenceActor()
    
    // EventKit integration
    @Published var eventKitService = EventKitService()
    
    // Weather integration
    @Published var weatherService = WeatherService()
    
    // Intelligence and analysis
    @Published var vibeAnalyzer = VibeAnalyzer()
    @Published var patternEngine = PatternLearningEngine()
    
    // MARK: - Initialization
    
    init() {
        load()
        
        // Auto-save every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                self.save()
            }
        }
    }
    
    // MARK: - Save & Load
    
    func save() {
        Task {
            isLoading = true
            let result = await persistenceActor.saveAppState(appState)
            
            await MainActor.run {
                if result.success, let saveTime = result.lastSaved {
                    lastSaved = saveTime
                }
                isLoading = false
            }
        }
    }
    
    func load() {
        Task {
            isLoading = true
            
            if let loadedState = await persistenceActor.loadAppState() {
                await MainActor.run {
                    appState = loadedState
                    ensureTodayExists()
                    isLoading = false
                }
            } else {
                // First launch or load failed - create sample data
                await MainActor.run {
                    createSampleData()
                    isLoading = false
                }
                save() // Save the sample data
            }
        }
    }
    
    // MARK: - Time Block Operations
    
    func addTimeBlock(_ block: TimeBlock) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            appState.addBlock(block)
        }
        save()
    }
    
    func updateTimeBlock(_ block: TimeBlock) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            appState.updateBlock(block)
        }
        save()
    }
    
    func removeTimeBlock(_ blockId: UUID) {
        withAnimation(.easeOut(duration: 0.4)) {
            appState.removeBlock(blockId)
        }
        save()
    }
    
    func moveTimeBlock(_ block: TimeBlock, to newStartTime: Date) {
        var updatedBlock = block
        updatedBlock.startTime = newStartTime
        updateTimeBlock(updatedBlock)
    }
    
    // MARK: - Chain Operations
    
    func addChain(_ chain: Chain) {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            appState.recentChains.append(chain)
            
            // Keep only recent chains (max 20)
            if appState.recentChains.count > 20 {
                appState.recentChains.removeFirst()
            }
        }
        save()
    }
    
    // MARK: - Pillar Operations
    
    func addPillar(_ pillar: Pillar) {
        appState.pillars.append(pillar)
        save()
        
        // Award XP for creating a pillar
        appState.addXP(15, reason: "Created pillar: \(pillar.name)")
        
        // If auto-staging is enabled, start suggesting this pillar
        if pillar.autoStageEnabled {
            schedulePillarSuggestions(for: pillar)
        }
    }
    
    func updatePillar(_ pillar: Pillar) {
        if let index = appState.pillars.firstIndex(where: { $0.id == pillar.id }) {
            appState.pillars[index] = pillar
            save()
        }
    }
    
    func removePillar(_ pillarId: UUID) {
        appState.pillars.removeAll { $0.id == pillarId }
        save()
    }
    
    private func schedulePillarSuggestions(for pillar: Pillar) {
        // Only schedule suggestions for actionable pillars
        guard pillar.isActionable && pillar.autoStageEnabled else { return }
        
        // Find available time slots that match the pillar's preferences
        let availableSlots = findAvailableSlots(for: pillar)
        
        // Create staging suggestions based on pillar rules
        for slot in availableSlots.prefix(2) { // Limit to 2 suggestions per pillar
            let duration = min(slot.duration, pillar.maxDuration)
            if duration >= pillar.minDuration {
                let suggestedBlock = TimeBlock(
                    title: pillar.name,
                    startTime: slot.startTime,
                    duration: duration,
                    energy: .daylight, // Default, could be enhanced
                    flow: .crystal, // Default for pillar activities
                    explanation: "Auto-suggested based on \(pillar.name) pillar"
                )
                
                stageBlock(suggestedBlock, explanation: "Pillar suggestion: \(pillar.name)", stagedBy: "Pillar AI")
            }
        }
        
        // Set action bar message about pillar suggestions
        if !availableSlots.isEmpty {
            setActionBarMessage("I found \(availableSlots.count) good time slot\(availableSlots.count == 1 ? "" : "s") for your \(pillar.name) pillar. Want to add them?")
        }
    }
    
    /// Create enhanced context with pillar guidance for AI decisions
    func createEnhancedContext(date: Date = Date()) -> DayContext {
        let principleGuidance = appState.pillars
            .filter { $0.isPrinciple }
            .map { $0.aiGuidanceText }
        
        let actionablePillars = appState.pillars
            .filter { $0.isActionable }
        
        return DayContext(
            date: date,
            existingBlocks: appState.currentDay.blocks,
            currentEnergy: .daylight,
            preferredFlows: [.water],
            availableTime: 3600,
            mood: appState.currentDay.mood,
            weatherContext: weatherService.getWeatherContext(),
            pillarGuidance: principleGuidance,
            actionablePillars: actionablePillars
        )
    }
    
    private func findAvailableSlots(for pillar: Pillar) -> [TimeSlot] {
        var availableSlots: [TimeSlot] = []
        let calendar = Calendar.current
        let today = Date()
        
        // Check today and next few days
        for dayOffset in 0..<3 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            
            // Get existing blocks for that day
            let existingBlocks = appState.currentDay.blocks + appState.stagedBlocks
            
            // Check each preferred time window
            for timeWindow in pillar.preferredTimeWindows {
                guard let windowStart = calendar.date(bySettingHour: timeWindow.startHour, minute: timeWindow.startMinute, second: 0, of: targetDate),
                      let windowEnd = calendar.date(bySettingHour: timeWindow.endHour, minute: timeWindow.endMinute, second: 0, of: targetDate) else { continue }
                
                // Find gaps within this time window
                let gapsInWindow = findGaps(in: DateInterval(start: windowStart, end: windowEnd), existingBlocks: existingBlocks)
                
                for gap in gapsInWindow {
                    if gap.duration >= pillar.minDuration {
                        availableSlots.append(TimeSlot(
                            startTime: gap.start,
                            endTime: gap.end,
                            duration: gap.duration
                        ))
                    }
                }
            }
        }
        
        return availableSlots
    }
    
    private func findGaps(in interval: DateInterval, existingBlocks: [TimeBlock]) -> [DateInterval] {
        let blocksInInterval = existingBlocks.filter { block in
            block.startTime < interval.end && block.endTime > interval.start
        }.sorted { $0.startTime < $1.startTime }
        
        var gaps: [DateInterval] = []
        var currentTime = interval.start
        
        for block in blocksInInterval {
            if currentTime < block.startTime {
                gaps.append(DateInterval(start: currentTime, end: block.startTime))
            }
            currentTime = max(currentTime, block.endTime)
        }
        
        if currentTime < interval.end {
            gaps.append(DateInterval(start: currentTime, end: interval.end))
        }
        
        return gaps
    }
    
    struct TimeSlot {
        let startTime: Date
        let endTime: Date
        let duration: TimeInterval
    }
    
    func markChainCompleted(_ chainId: UUID) {
        guard let index = appState.recentChains.firstIndex(where: { $0.id == chainId }) else { return }
        
        appState.recentChains[index].completionCount += 1
        appState.recentChains[index].lastCompletedAt = Date()
        appState.recentChains[index].completionHistory.append(Date())
        
        // Check if this chain can be promoted to routine
        let chain = appState.recentChains[index]
        if chain.canBePromotedToRoutine {
            promptRoutinePromotion(for: chain)
        }
        
        save()
    }
    
    private func promptRoutinePromotion(for chain: Chain) {
        // Mark that we've shown the prompt to avoid spam
        if let index = appState.recentChains.firstIndex(where: { $0.id == chain.id }) {
            appState.recentChains[index].routinePromptShown = true
        }
        
        // In a real app, this would show UI to ask user
        // For now, we'll auto-promote with default settings
        promoteChainToRoutine(chain)
    }
    
    func promoteChainToRoutine(_ chain: Chain) {
        let routine = Routine(
            chainId: chain.id,
            name: "\(chain.name) Routine",
            adoptionScore: 0.7, // Start with good adoption since it was completed 3 times
            scheduleRules: inferScheduleRules(from: chain)
        )
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            appState.routines.append(routine)
        }
        
        // Award XP for establishing a routine
        appState.addXP(10, reason: "Established routine: \(routine.name)")
        
        save()
        
        print("✅ Promoted chain '\(chain.name)' to routine")
    }
    
    func dismissRoutinePromotion(for chainId: UUID) {
        if let index = appState.recentChains.firstIndex(where: { $0.id == chainId }) {
            appState.recentChains[index].routinePromptShown = true
        }
        save()
    }
    
    private func inferScheduleRules(from chain: Chain) -> [RoutineScheduleRule] {
        // Create a simple daily schedule rule based on completion history
        // In a real app, this could be more sophisticated
        
        if let lastCompleted = chain.lastCompletedAt {
            let hour = Calendar.current.component(.hour, from: lastCompleted)
            let timeWindow = TimeWindow(
                startHour: max(0, hour - 1),
                startMinute: 0,
                endHour: min(23, hour + 1),
                endMinute: 59
            )
            
            let rule = RoutineScheduleRule(
                timeOfDay: timeWindow,
                frequency: .daily,
                conditions: []
            )
            
            return [rule]
        }
        
        return []
    }
    
    func applyChain(_ chain: Chain, startingAt time: Date) {
        var currentTime = time
        var chainBlocks: [TimeBlock] = []
        
        // Create all chain blocks with proper time slots
        for chainBlock in chain.blocks {
            let newBlock = TimeBlock(
                title: chainBlock.title,
                startTime: currentTime,
                duration: chainBlock.duration,
                energy: chainBlock.energy,
                flow: chainBlock.flow,
                glassState: .mist, // Start as suggestion
                isStaged: true,
                stagedBy: "Chain Application",
                explanation: "Part of '\(chain.name)' chain"
            )
            
            chainBlocks.append(newBlock)
            currentTime = newBlock.endTime.addingTimeInterval(300) // 5-minute buffer
        }
        
        // Stage all blocks from the chain
        for block in chainBlocks {
            stageBlock(block, explanation: "Part of '\(chain.name)' chain (\(block.durationMinutes)m)", stagedBy: "Chain")
        }
        
        // Set action bar message for the entire chain
        let totalDuration = chainBlocks.reduce(0) { $0 + $1.durationMinutes }
        setActionBarMessage("I've staged the '\(chain.name)' chain (\(chainBlocks.count) activities, \(totalDuration)m total) starting at \(time.timeString). Ready to apply?")
    }
    
    // MARK: - PRD Staging & Commit System
    
    /// Stage a block for user approval (PRD requirement)
    func stageBlock(_ block: TimeBlock, explanation: String? = nil, stagedBy: String = "AI") {
        var stagedBlock = block
        stagedBlock.isStaged = true
        stagedBlock.stagedBy = stagedBy
        stagedBlock.explanation = explanation
        stagedBlock.glassState = .mist // PRD: staged items are mist
        
        appState.stagedBlocks.append(stagedBlock)
        save()
    }
    
    /// Commit all staged blocks to the actual day (PRD requirement)
    func commitAllStagedBlocks() {
        for var block in appState.stagedBlocks {
            block.isStaged = false
            block.glassState = .solid
            addTimeBlock(block)
        }
        appState.stagedBlocks.removeAll()
        appState.currentActionBarMessage = nil
        save()
    }
    
    /// Reject all staged blocks (PRD requirement)
    func rejectAllStagedBlocks() {
        appState.stagedBlocks.removeAll()
        appState.currentActionBarMessage = nil
        save()
    }
    
    /// Set Action Bar message with staged proposals (PRD requirement)
    func setActionBarMessage(_ message: String) {
        appState.currentActionBarMessage = message
        save()
    }
    
    func applySuggestion(_ suggestion: Suggestion) {
        let block = suggestion.toTimeBlock()
        stageBlock(block, explanation: suggestion.explanation, stagedBy: "Suggestion")
        setActionBarMessage("I suggest: \(suggestion.title) for \(suggestion.duration.minutes) minutes. This would help with your \(suggestion.flow.rawValue) energy flow.")
    }
    
    // MARK: - Legacy Staging Support (deprecated - use stageBlock instead)
    
    func stageSuggestion(_ suggestion: Suggestion) {
        // Convert to new staging system
        let block = suggestion.toTimeBlock()
        stageBlock(block, explanation: suggestion.explanation, stagedBy: "Legacy Suggestion")
        setActionBarMessage("I suggest: \(suggestion.title) for \(suggestion.duration.minutes) minutes. Does this work?")
    }
    
    func commitStagedItems() async {
        guard !appState.stagedBlocks.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Track committed items for potential undo
        let itemsToCommit = appState.stagedBlocks
        
        do {
            // Create events in EventKit if authorized
            if eventKitService.isAuthorized {
                _ = try await eventKitService.createEvents(from: appState.stagedBlocks)
            }
            
            // Update blocks with EventKit IDs and mark as committed
            for block in appState.stagedBlocks {
                var updatedBlock = block
                updatedBlock.glassState = GlassState.solid // Mark as committed
                updatedBlock.isStaged = false
                addTimeBlock(updatedBlock)
            }
            
            // Clear staging area using existing method
            appState.stagedBlocks.removeAll()
            appState.currentActionBarMessage = nil
            
            // Save to persistent storage
            save()
            
            print("✅ Committed \(itemsToCommit.count) items successfully")
            
        } catch {
            print("❌ Failed to commit to EventKit: \(error)")
            
            // Still save locally even if EventKit fails
            for block in appState.stagedBlocks {
                var updatedBlock = block
                updatedBlock.glassState = GlassState.solid
                updatedBlock.isStaged = false
                addTimeBlock(updatedBlock)
            }
            
            // Clear staging area
            appState.stagedBlocks.removeAll()
            appState.currentActionBarMessage = nil
            
            save()
        }
    }
    
    func undoStagedItems() {
        let count = appState.stagedBlocks.count
        // Use existing method to reject all staged blocks
        rejectAllStagedBlocks()
        
        print("✅ Undid \(count) staged items")
    }
    
    func rejectSuggestion(_ suggestion: Suggestion) {
        // Track rejection patterns for learning
        let rejectionPattern = "rejected:\(suggestion.title.lowercased())"
        if !appState.userPatterns.contains(rejectionPattern) {
            appState.userPatterns.append(rejectionPattern)
        }
        save()
    }
    
    // MARK: - Day Management
    
    func switchToDay(_ date: Date) {
        // Analyze current day before switching
        if !appState.currentDay.blocks.isEmpty {
            let context = DayContext(
                date: appState.currentDay.date,
                existingBlocks: appState.currentDay.blocks,
                currentEnergy: .daylight,
                preferredFlows: [.water],
                availableTime: 0,
                mood: appState.currentDay.mood,
                weatherContext: weatherService.getWeatherContext()
            )
            vibeAnalyzer.analyzeCurrentVibe(from: appState.currentDay, context: context)
        }
        
        // Save current day to historical data
        if let existingIndex = appState.historicalDays.firstIndex(where: { $0.id == appState.currentDay.id }) {
            appState.historicalDays[existingIndex] = appState.currentDay
        } else {
            appState.historicalDays.append(appState.currentDay)
        }
        save()
        
        // Load existing day data or create new day
        if let existingDay = appState.historicalDays.first(where: { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .day) }) {
            // Load existing day
            appState.currentDay = existingDay
        } else {
            // Create new day
            let newDay = Day(date: date)
            appState.currentDay = newDay
            // Store in historical data
            appState.historicalDays.append(newDay)
        }
        ensureTodayExists()
    }
    
    func updateDayMood(_ mood: GlassMood) {
        withAnimation(.easeInOut(duration: 1.0)) {
            appState.currentDay.mood = mood
        }
        save()
    }
    
    // MARK: - User Patterns & Learning
    
    func recordPattern(_ pattern: String) {
        let lowercasePattern = pattern.lowercased()
        if !appState.userPatterns.contains(lowercasePattern) {
            appState.userPatterns.append(lowercasePattern)
            
            // Keep patterns manageable
            if appState.userPatterns.count > 100 {
                appState.userPatterns.removeFirst()
            }
        }
        save()
    }
    
    func getUserPatternsForAI() -> String {
        appState.userPatterns.joined(separator: ", ")
    }
    
    // MARK: - Preferences
    
    func updatePreferences(_ preferences: UserPreferences) {
        appState.preferences = preferences
        save()
    }
    
    // MARK: - Export & Import
    
    func exportData() async -> URL? {
        return await persistenceActor.exportData(appState)
    }
    
    func importData(from url: URL) async throws {
        if let importedState = await persistenceActor.importData(from: url) {
            withAnimation(.easeInOut(duration: 0.8)) {
                appState = importedState
            }
            save()
        } else {
            throw NSError(domain: "ImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to import data"])
        }
    }
    
    // MARK: - Private Helpers
    
    private func ensureTodayExists() {
        let today = Date()
        let calendar = Calendar.current
        
        if !calendar.isDate(appState.currentDay.date, inSameDayAs: today) {
            // Create today's data
            appState.currentDay = Day(date: today)
        }
    }
    
    private func createSampleData() {
        appState = AppState()
        appState.currentDay = Day.sample()
        
        // Add some sample chains
        appState.recentChains = [
            Chain.sample(name: "Morning Energy"),
            Chain.sample(name: "Deep Work Session"),
            Chain.sample(name: "Evening Wind Down")
        ]
        
        // Add some learning patterns
        appState.userPatterns = [
            "prefers morning work",
            "likes creative afternoon",
            "needs evening rest"
        ]
        
        // Initialize XP/XXP with some starting values
        appState.userXP = 150 // Some initial knowledge
        appState.userXXP = 320 // Some initial work done
        
        // Add sample pillars
        appState.pillars = Pillar.samplePillars()
        
        // Add sample goals
        appState.goals = Goal.sampleGoals()
        
        // Add sample intake questions
        appState.intakeQuestions = IntakeQuestion.sampleQuestions()
        
        // Add some sample dream concepts
        appState.dreamConcepts = [
            DreamConcept(
                title: "Learn a new language",
                description: "User has mentioned wanting to learn Spanish multiple times",
                mentions: 3,
                relatedKeywords: ["spanish", "language", "travel", "culture"]
            ),
            DreamConcept(
                title: "Start a garden",
                description: "Mentioned interest in growing own vegetables",
                mentions: 2,
                relatedKeywords: ["garden", "vegetables", "healthy", "outdoor"]
            )
        ]
    }
    
    // MARK: - Goal Operations
    
    func addGoal(_ goal: Goal) {
        appState.goals.append(goal)
        save()
    }
    
    func updateGoal(_ goal: Goal) {
        if let index = appState.goals.firstIndex(where: { $0.id == goal.id }) {
            appState.goals[index] = goal
        }
        save()
    }
    
    func removeGoal(id: UUID) {
        appState.goals.removeAll { $0.id == id }
        save()
    }
    
    func toggleTaskCompletion(goalId: UUID, taskId: UUID) {
        if let goalIndex = appState.goals.firstIndex(where: { $0.id == goalId }) {
            for groupIndex in 0..<appState.goals[goalIndex].groups.count {
                if let taskIndex = appState.goals[goalIndex].groups[groupIndex].tasks.firstIndex(where: { $0.id == taskId }) {
                    appState.goals[goalIndex].groups[groupIndex].tasks[taskIndex].isCompleted.toggle()
                    
                    // Update goal progress based on completed tasks
                    updateGoalProgress(goalId: goalId)
                    break
                }
            }
        }
        save()
    }
    
    private func updateGoalProgress(goalId: UUID) {
        if let goalIndex = appState.goals.firstIndex(where: { $0.id == goalId }) {
            let goal = appState.goals[goalIndex]
            let allTasks = goal.groups.flatMap { $0.tasks }
            let completedTasks = allTasks.filter { $0.isCompleted }
            
            appState.goals[goalIndex].progress = allTasks.isEmpty ? 0.0 : Double(completedTasks.count) / Double(allTasks.count)
        }
    }
    
}

// MARK: - Preview Helper

// AppDataManager.preview is defined in Extensions.swift

// MARK: - Time Helpers

// Date extensions are defined in Extensions.swift
extension Date {
    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? self
    }
    
    func setting(hour: Int, minute: Int = 0) -> Date? {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self)
    }
}

// MARK: - EventKit Service

/// Service for integrating with system calendar via EventKit
@MainActor
class EventKitService: ObservableObject {
    @Published var isAuthorized = false
    @Published var isProcessing = false
    @Published var lastSyncTime: Date?
    
    private let eventStore = EKEventStore()
    
    init() {
        Task {
            await requestCalendarAccess()
        }
    }
    
    // MARK: - Authorization
    
    func requestCalendarAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .fullAccess:
            isAuthorized = true
        case .writeOnly:
            isAuthorized = true // Write-only is sufficient for our needs
        case .notDetermined:
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                isAuthorized = granted
            } catch {
                print("❌ Failed to request calendar access: \(error)")
                isAuthorized = false
            }
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    // MARK: - Event Creation
    
    func createEvent(from timeBlock: TimeBlock) async throws -> String {
        guard isAuthorized else {
            throw EventKitError.notAuthorized
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = timeBlock.title
        event.startDate = timeBlock.startTime
        event.endDate = timeBlock.endTime
        event.notes = "Created by DayPlanner\nEnergy: \(timeBlock.energy.description)\nFlow: \(timeBlock.flow.description)"
        
        // Use default calendar
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            lastSyncTime = Date()
            return event.eventIdentifier
        } catch {
            throw EventKitError.saveFailed(error)
        }
    }
    
    func createEvents(from timeBlocks: [TimeBlock]) async throws -> [String] {
        var eventIds: [String] = []
        
        for block in timeBlocks {
            let eventId = try await createEvent(from: block)
            eventIds.append(eventId)
        }
        
        return eventIds
    }
    
    func getDiagnostics() -> String {
        var diagnostics = "EventKit Service Diagnostics:\n"
        diagnostics += "Authorization: \(isAuthorized ? "✅ Granted" : "❌ Denied")\n"
        diagnostics += "Processing: \(isProcessing ? "⏳ Active" : "✅ Ready")\n"
        
        if let lastSync = lastSyncTime {
            diagnostics += "Last Sync: \(lastSync.formatted(.dateTime))\n"
        } else {
            diagnostics += "Last Sync: Never\n"
        }
        
        if isAuthorized {
            let calendars = eventStore.calendars(for: .event)
            diagnostics += "Available Calendars: \(calendars.count)\n"
            if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
                diagnostics += "Default Calendar: \(defaultCalendar.title)\n"
            }
        }
        
        return diagnostics
    }
}

enum EventKitError: LocalizedError {
    case notAuthorized
    case eventNotFound
    case saveFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access not authorized. Please grant permission in System Preferences."
        case .eventNotFound:
            return "Event not found in calendar"
        case .saveFailed(let error):
            return "Failed to save event: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete event: \(error.localizedDescription)"
        }
    }
}

// MARK: - Weather Service

/// Service for providing weather context to AI suggestions
@MainActor
class WeatherService: ObservableObject {
    @Published var currentWeather: WeatherInfo?
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    
    private let locationManager = CLLocationManager()
    private var locationDelegate: WeatherLocationDelegate?
    
    init() {
        locationDelegate = WeatherLocationDelegate(service: self)
        locationManager.delegate = locationDelegate
        requestLocationPermission()
    }
    
    func requestLocationPermission() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            #if os(macOS)
            locationManager.requestAlwaysAuthorization()
            #else
            locationManager.requestWhenInUseAuthorization()
            #endif
        case .authorizedAlways:
            updateWeatherIfNeeded()
        #if !os(macOS)
        case .authorizedWhenInUse:
            updateWeatherIfNeeded()
        #endif
        case .denied, .restricted:
            setDefaultWeather()
        @unknown default:
            setDefaultWeather()
        }
    }
    
    func updateWeatherIfNeeded() {
        if let lastUpdate = lastUpdated,
           Date().timeIntervalSince(lastUpdate) < 3600 {
            return
        }
        
        Task {
            await fetchWeatherData()
        }
    }
    
    private func fetchWeatherData() async {
        #if os(macOS)
        guard locationManager.authorizationStatus == .authorizedAlways else {
            setDefaultWeather()
            return
        }
        #else
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            setDefaultWeather()
            return
        }
        #endif
        
        isLoading = true
        defer { isLoading = false }
        
        await simulateWeatherFetch()
    }
    
    private func simulateWeatherFetch() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let month = Calendar.current.component(.month, from: now)
        
        let weather = generateSeasonalWeather(hour: hour, month: month)
        
        currentWeather = weather
        lastUpdated = Date()
    }
    
    private func setDefaultWeather() {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let month = Calendar.current.component(.month, from: now)
        
        currentWeather = generateSeasonalWeather(hour: hour, month: month)
        lastUpdated = Date()
    }
    
    private func generateSeasonalWeather(hour: Int, month: Int) -> WeatherInfo {
        var baseTemp: Double
        
        switch month {
        case 12, 1, 2: baseTemp = 35 // Winter
        case 3, 4, 5: baseTemp = 60 // Spring
        case 6, 7, 8: baseTemp = 78 // Summer
        case 9, 10, 11: baseTemp = 65 // Fall
        default: baseTemp = 65
        }
        
        let timeAdjustment: Double
        switch hour {
        case 6..<10: timeAdjustment = -5
        case 12..<16: timeAdjustment = 8
        case 16..<20: timeAdjustment = 3
        default: timeAdjustment = -8
        }
        
        let temperature = baseTemp + timeAdjustment
        
        let conditions: [WeatherCondition]
        if temperature > 75 {
            conditions = [.sunny, .partlyCloudy]
        } else if temperature < 40 {
            conditions = [.snowy, .cloudy]
        } else {
            conditions = [.sunny, .partlyCloudy, .cloudy, .rainy]
        }
        
        let condition = conditions.randomElement() ?? .sunny
        
        return WeatherInfo(
            temperature: temperature,
            condition: condition,
            humidity: Int.random(in: 30...80),
            timestamp: Date()
        )
    }
    
    func getWeatherContext() -> String {
        guard let weather = currentWeather else {
            return "Weather: Unknown"
        }
        
        let suggestion = weather.condition.suggestion
        return "Weather: \(Int(weather.temperature))°F, \(weather.condition.rawValue) - \(suggestion)"
    }
    
    func shouldSuggestIndoor() -> Bool {
        guard let weather = currentWeather else { return false }
        return weather.condition == .rainy || weather.condition == .snowy || weather.temperature < 35 || weather.temperature > 90
    }
    
    func shouldSuggestOutdoor() -> Bool {
        guard let weather = currentWeather else { return false }
        return weather.condition == .sunny && weather.temperature > 55 && weather.temperature < 85
    }
}

struct WeatherInfo: Codable {
    let temperature: Double
    let condition: WeatherCondition
    let humidity: Int
    let timestamp: Date
}

enum WeatherCondition: String, Codable, CaseIterable {
    case sunny = "Sunny"
    case partlyCloudy = "Partly Cloudy" 
    case cloudy = "Cloudy"
    case rainy = "Rainy"
    case snowy = "Snowy"
    
    var suggestion: String {
        switch self {
        case .sunny: return "Great weather for outdoor activities"
        case .partlyCloudy: return "Good weather for any activity"
        case .cloudy: return "Good for indoor or outdoor activities"
        case .rainy: return "Perfect for indoor activities and cozy tasks"
        case .snowy: return "Great for indoor activities or winter sports"
        }
    }
    
    var emoji: String {
        switch self {
        case .sunny: return "☀️"
        case .partlyCloudy: return "⛅"
        case .cloudy: return "☁️"
        case .rainy: return "🌧️"
        case .snowy: return "🌨️"
        }
    }
}

private class WeatherLocationDelegate: NSObject, CLLocationManagerDelegate {
    weak var service: WeatherService?
    
    init(service: WeatherService) {
        self.service = service
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            service?.requestLocationPermission()
        }
    }
}


// MARK: - Animation Helpers

extension Animation {
    static let liquidGlass = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let ripple = Animation.easeOut(duration: 0.8)
    static let settle = Animation.spring(response: 1.2, dampingFraction: 0.7)
    static let flow = Animation.easeInOut(duration: 1.0)
}

// MARK: - Background Persistence Actor

/// Actor for handling heavy I/O operations off the main thread
actor PersistenceActor {
    private let fileManager = FileManager.default
    private lazy var documentsDirectory: URL = {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()
    
    private lazy var appDataURL: URL = {
        documentsDirectory.appendingPathComponent("DayPlannerData.json")
    }()
    
    private lazy var backupDirectory: URL = {
        let url = documentsDirectory.appendingPathComponent("Backups")
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    
    // Throttling mechanism
    private var lastSaveTime: Date = .distantPast
    private var pendingSave: Task<Void, Never>?
    private let saveThrottleInterval: TimeInterval = 1.0 // 1 second throttle
    
    /// Save app state with throttling to prevent excessive writes
    func saveAppState(_ appState: AppState) async -> (success: Bool, lastSaved: Date?) {
        // Cancel any pending save
        pendingSave?.cancel()
        
        // Check if we should throttle this save
        let now = Date()
        if now.timeIntervalSince(lastSaveTime) < saveThrottleInterval {
            // Schedule a delayed save
            pendingSave = Task {
                try? await Task.sleep(nanoseconds: UInt64(saveThrottleInterval * 1_000_000_000))
                if !Task.isCancelled {
                    _ = await performSave(appState)
                }
            }
            return (success: true, lastSaved: nil) // Return success but no timestamp
        }
        
        return await performSave(appState)
    }
    
    private func performSave(_ appState: AppState) async -> (success: Bool, lastSaved: Date?) {
        do {
            let data = try JSONEncoder().encode(appState)
            try data.write(to: appDataURL)
            let saveTime = Date()
            lastSaveTime = saveTime
            
            // Create backup if needed
            if await shouldCreateBackup() {
                await createDailyBackup(data: data)
            }
            
            return (success: true, lastSaved: saveTime)
        } catch {
            print("❌ Failed to save app data: \(error)")
            return (success: false, lastSaved: nil)
        }
    }
    
    /// Load app state from disk
    func loadAppState() async -> AppState? {
        guard fileManager.fileExists(atPath: appDataURL.path) else {
            return nil // No existing data
        }
        
        do {
            let data = try Data(contentsOf: appDataURL)
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            print("❌ Failed to load app data: \(error)")
            return nil
        }
    }
    
    /// Export data to a file
    func exportData(_ appState: AppState) async -> URL? {
        let timestamp = DateFormatters.exportFormatter.string(from: Date())
        let exportURL = documentsDirectory.appendingPathComponent("DayPlanner_Export_\(timestamp).json")
        
        do {
            let data = try JSONEncoder().encode(appState)
            try data.write(to: exportURL)
            return exportURL
        } catch {
            print("❌ Failed to export data: \(error)")
            return nil
        }
    }
    
    /// Import data from a file
    func importData(from url: URL) async -> AppState? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            print("❌ Failed to import data: \(error)")
            return nil
        }
    }
    
    // MARK: - Backup Management
    
    private func shouldCreateBackup() async -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let lastBackupDate = await getLastBackupDate()
        
        return lastBackupDate == nil || !Calendar.current.isDate(lastBackupDate!, inSameDayAs: today)
    }
    
    private func createDailyBackup(data: Data) async {
        let dateString = DateFormatters.backupFormatter.string(from: Date())
        let backupURL = backupDirectory.appendingPathComponent("backup_\(dateString).json")
        
        do {
            try data.write(to: backupURL)
            // Removed automatic cleanup - backups are kept indefinitely
        } catch {
            print("❌ Failed to create backup: \(error)")
        }
    }
    
    private func getLastBackupDate() async -> Date? {
        do {
            let backupFiles = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            let sortedFiles = backupFiles.sorted { file1, file2 in
                let date1 = try? file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                let date2 = try? file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                return date1 ?? Date.distantPast > date2 ?? Date.distantPast
            }
            
            return try sortedFiles.first?.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        } catch {
            return nil
        }
    }
    
    private func cleanOldBackups() async {
        do {
            let backupFiles = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
            
            for file in backupFiles {
                let resourceValues = try file.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = resourceValues.contentModificationDate,
                   modificationDate < thirtyDaysAgo {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("❌ Failed to clean old backups: \(error)")
        }
    }
}
