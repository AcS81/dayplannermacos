//
//  BackfillViews.swift
//  DayPlanner
//
//  Backfill and Timeline Views
//

import SwiftUI

// MARK: - Backfill View

struct EnhancedBackfillView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeframe: BackfillTimeframe = .today
    @State private var selectedDate = Date()
    @State private var isGeneratingBackfill = false
    @State private var backfillSuggestions: [TimeBlock] = []
    @State private var stagedBackfillBlocks: [TimeBlock] = []
    @State private var selectedViewMode: BackfillViewMode = .hybrid
    @State private var manualInputText = ""
    @State private var showingManualInput = false
    @State private var reconstructionQuality: Int = 80
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced header with more controls
            HStack {
                Text("Backfill Header")
                Spacer()
            }
            .padding()
            
            /*EnhancedBackfillHeader(
                selectedTimeframe: $selectedTimeframe,
                selectedDate: $selectedDate,
                selectedViewMode: $selectedViewMode,
                reconstructionQuality: $reconstructionQuality,
                isGenerating: isGeneratingBackfill,
                onGenerateBackfill: generateBackfillSuggestions,
                onToggleManualInput: { showingManualInput.toggle() }
            )*/
            
            Divider()
            
            // Main workspace with more real estate
            HSplitView {
                // Left: Large timeline workspace (70% of space)
                VStack(spacing: 0) {
                    Text("Enhanced Backfill Timeline - Coming Soon")
                        .padding()
                    
                    /*EnhancedBackfillTimeline(
                        date: selectedDate,
                        suggestions: backfillSuggestions,
                        stagedBlocks: stagedBackfillBlocks,
                        viewMode: selectedViewMode,
                        onBlockMove: { block, newTime in
                            moveBackfillBlock(block, to: newTime)
                        },
                        onBlockRemove: { block in
                            removeBackfillBlock(block)
                        },
                        onBlockEdit: { block in
                            editBackfillBlock(block)
                        }
                    )*/
                }
                .frame(minWidth: 600)
                
                // Right: Enhanced control panel (30% of space)
                VStack(spacing: 0) {
                    // AI suggestions section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("AI Reconstruction", systemImage: "sparkles")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(reconstructionQuality)% confidence")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(backfillSuggestions.prefix(8)) { suggestion in
                                    HStack {
                                        Text(suggestion.title)
                                        Spacer()
                                        Button("Add") { applySuggestion(suggestion) }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                    }
                                    .padding(8)
                                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding()
                    .background(.regularMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Manual input section (enhanced)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Manual Entry", systemImage: "pencil")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Quick Add") {
                                showQuickAddSheet()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        // Quick manual entry
                        TextField("Describe what happened...", text: $manualInputText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                        
                        HStack {
                            Button("Parse & Add") {
                                parseManualInput()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(manualInputText.isEmpty)
                            
                            Spacer()
                            
                            Button("Clear") {
                                manualInputText = ""
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        // Quick time block templates
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(quickTemplates, id: \.title) { template in
                                Button(action: { applyTemplate(template) }) {
                                    VStack(spacing: 4) {
                                        Text(template.icon)
                                            .font(.title2)
                                        Text(template.title)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(.thickMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    // Enhanced action buttons
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(stagedBackfillBlocks.count) events staged")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("Total: \(stagedTotalHours, specifier: "%.1f")h")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Button("Discard") {
                                discardBackfill()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Commit \(stagedBackfillBlocks.count) Events") {
                                commitBackfill()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(stagedBackfillBlocks.isEmpty)
                        }
                        
                        Button("Export to Calendar") {
                            exportToCalendar()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(.ultraThickMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                }
                .frame(minWidth: 350, idealWidth: 400)
                .padding()
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            generateBackfillSuggestions()
        }
    }
    
    // MARK: - Computed Properties
    
    private var stagedTotalHours: Double {
        let totalSeconds = stagedBackfillBlocks.reduce(0) { $0 + $1.duration }
        return totalSeconds / 3600
    }
    
    private var quickTemplates: [QuickTemplate] {
        [
            QuickTemplate(title: "Work", icon: "💼", duration: 8*3600, energy: .daylight, emoji: "💎"),
            QuickTemplate(title: "Meeting", icon: "👥", duration: 3600, energy: .daylight, emoji: "🌊"),
            QuickTemplate(title: "Lunch", icon: "🍽️", duration: 1800, energy: .daylight, emoji: "☁️"),
            QuickTemplate(title: "Break", icon: "☕", duration: 900, energy: .moonlight, emoji: "☁️"),
            QuickTemplate(title: "Travel", icon: "🚗", duration: 1800, energy: .moonlight, emoji: "☁️"),
            QuickTemplate(title: "Exercise", icon: "💪", duration: 3600, energy: .sunrise, emoji: "🌊")
        ]
    }
    
    // MARK: - Actions
    
    private func parseManualInput() {
        // Parse natural language input and create time blocks
        let input = manualInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        // Simple parsing logic - in real implementation would use AI
        let components = input.components(separatedBy: ",")
        
        for (index, component) in components.enumerated() {
            let title = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            
            let startHour = 9 + index * 2 // Spread throughout day
            let startTime = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
            
            let newBlock = TimeBlock(
                title: title,
                startTime: startTime,
                duration: 3600, // 1 hour default
                energy: .daylight,
                emoji: "💎",
            )
            
            stagedBackfillBlocks.append(newBlock)
        }
        
        manualInputText = ""
    }
    
    private func applyTemplate(_ template: QuickTemplate) {
        let startTime = Date() // Would be smarter about placement in real implementation
        
        let newBlock = TimeBlock(
            title: template.title,
            startTime: startTime,
            duration: template.duration,
            energy: template.energy,
            emoji: template.emoji,
        )
        
        stagedBackfillBlocks.append(newBlock)
    }
    
    private func showQuickAddSheet() {
        // Would show a detailed manual entry sheet
    }
    
    private func editSuggestion(_ suggestion: TimeBlock) {
        // Would show edit sheet for suggestion
    }
    
    private func editBackfillBlock(_ block: TimeBlock) {
        // Would show edit sheet for staged block
    }
    
    private func exportToCalendar() {
        // Export staged blocks to system calendar
    }
    
    // MARK: - Backfill Actions
    
    private func generateBackfillSuggestions() {
        isGeneratingBackfill = true
        
        Task {
            // Lightweight approach: focus on high-confidence events only
            let existingEvents = stagedBackfillBlocks
            let availableSlots = findAvailableTimeSlots(existing: existingEvents)
            
            // Generate only most confident activities based on existing data
            let aiGuessBlocks = createHighConfidenceReconstruction(
                for: selectedDate, 
                avoiding: existingEvents,
                inSlots: availableSlots
            )
            
            await MainActor.run {
                // Filter to only add events where we have high confidence and available slots
                backfillSuggestions = aiGuessBlocks.filter { suggested in
                    !existingEvents.contains { existing in
                        suggested.startTime < existing.endTime && suggested.endTime > existing.startTime
                    }
                }
                
                isGeneratingBackfill = false
            }
        }
    }
    
    private func findAvailableTimeSlots(existing: [TimeBlock]) -> [DateInterval] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        
        let sortedBlocks = existing.sorted { $0.startTime < $1.startTime }
        var availableSlots: [DateInterval] = []
        
        var currentTime = calendar.date(byAdding: .hour, value: 6, to: dayStart) ?? dayStart // Start at 6 AM
        
        for block in sortedBlocks {
            if currentTime < block.startTime {
                availableSlots.append(DateInterval(start: currentTime, end: block.startTime))
            }
            currentTime = max(currentTime, block.endTime)
        }
        
        // Add remaining time until end of reasonable day (22:00)
        let endOfReasonableDay = calendar.date(byAdding: .hour, value: 22, to: dayStart) ?? dayEnd
        if currentTime < endOfReasonableDay {
            availableSlots.append(DateInterval(start: currentTime, end: endOfReasonableDay))
        }
        
        return availableSlots.filter { $0.duration >= 1800 } // Only slots 30+ minutes
    }
    
    private func createHighConfidenceReconstruction(for date: Date, avoiding existingEvents: [TimeBlock], inSlots availableSlots: [DateInterval]) -> [TimeBlock] {
        let dayOfWeek = Calendar.current.component(.weekday, from: date)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        // High-confidence activities that most people do
        let highConfidenceActivities: [(title: String, duration: TimeInterval, energy: EnergyType, emoji: String, confidence: Double)] = isWeekend ? [
            ("Sleep in", 3600, .moonlight, "☁️", 0.9),
            ("Meals", 5400, .daylight, "☁️", 0.95),
            ("Personal time", 7200, .daylight, "🌊", 0.8),
            ("Evening activities", 5400, .moonlight, "🌊", 0.7)
        ] : [
            ("Morning routine", 3600, .sunrise, "💎", 0.9),
            ("Work time", 28800, .daylight, "💎", 0.85), // 8 hours
            ("Lunch", 3600, .daylight, "☁️", 0.9),
            ("Commute/travel", 3600, .moonlight, "☁️", 0.7),
            ("Dinner", 3600, .moonlight, "☁️", 0.9),
            ("Evening personal", 5400, .moonlight, "🌊", 0.6)
        ]
        
        var suggestions: [TimeBlock] = []
        let calendar = Calendar.current
        
        // Place high-confidence activities in available slots
        for slot in availableSlots.prefix(4) { // Max 4 suggestions to keep it manageable
            for activity in highConfidenceActivities {
                if activity.duration <= slot.duration && suggestions.count < 3 {
                    let startTime = findBestTimeInSlot(slot: slot, duration: activity.duration, isWeekend: isWeekend)
                    
                    suggestions.append(TimeBlock(
                        title: activity.title,
                        startTime: startTime,
                        duration: min(activity.duration, slot.duration),
                        energy: activity.energy,
                        emoji: activity.emoji,
                        glassState: .crystal,
                    ))
                    break
                }
            }
        }
        
        return suggestions
    }
    
    private func findBestTimeInSlot(slot: DateInterval, duration: TimeInterval, isWeekend: Bool) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: slot.start)
        
        // Smart placement based on activity type and time
        if hour < 9 && !isWeekend {
            return slot.start // Early morning activities start early
        } else if hour >= 12 && hour < 14 {
            return slot.start // Lunch time activities
        } else {
            // Center the activity in the available slot
            let centerOffset = (slot.duration - duration) / 2
            return slot.start.addingTimeInterval(centerOffset)
        }
    }
    
    private func applySuggestion(_ suggestion: TimeBlock) {
        stagedBackfillBlocks.append(suggestion)
    }
    
    // PRD: Create realistic day reconstruction (AI guess)
    private func createRealisticDayReconstruction(for date: Date) -> [TimeBlock] {
        let dayOfWeek = Calendar.current.component(.weekday, from: date)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        var blocks: [TimeBlock] = []
        let calendar = Calendar.current
        
        if isWeekend {
            // Weekend reconstruction
            blocks = [
                TimeBlock(title: "Sleep in", startTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date)!, duration: 3600, energy: .moonlight, emoji: "☁️"),
                TimeBlock(title: "Lazy breakfast", startTime: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: date)!, duration: 1800, energy: .sunrise, emoji: "☁️"),
                TimeBlock(title: "Personal time", startTime: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: date)!, duration: 7200, energy: .daylight, emoji: "🌊"),
                TimeBlock(title: "Lunch", startTime: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date)!, duration: 1800, energy: .daylight, emoji: "☁️"),
                TimeBlock(title: "Afternoon activities", startTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: date)!, duration: 5400, energy: .daylight, emoji: "🌊"),
                TimeBlock(title: "Dinner", startTime: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: date)!, duration: 2700, energy: .moonlight, emoji: "☁️"),
                TimeBlock(title: "Evening relaxation", startTime: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: date)!, duration: 3600, energy: .moonlight, emoji: "🌊")
            ]
        } else {
            // Weekday reconstruction
            blocks = [
                TimeBlock(title: "Morning routine", startTime: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: date)!, duration: 3600, energy: .sunrise, emoji: "💎"),
                TimeBlock(title: "Commute/Setup", startTime: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: date)!, duration: 1800, energy: .sunrise, emoji: "☁️"),
                TimeBlock(title: "Morning work block", startTime: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: date)!, duration: 7200, energy: .daylight, emoji: "💎"),
                TimeBlock(title: "Lunch break", startTime: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!, duration: 3600, energy: .daylight, emoji: "☁️"),
                TimeBlock(title: "Afternoon work", startTime: calendar.date(bySettingHour: 13, minute: 30, second: 0, of: date)!, duration: 9000, energy: .daylight, emoji: "🌊"),
                TimeBlock(title: "Wrap up work", startTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: date)!, duration: 3600, energy: .daylight, emoji: "💎"),
                TimeBlock(title: "Commute home", startTime: calendar.date(bySettingHour: 17, minute: 30, second: 0, of: date)!, duration: 1800, energy: .moonlight, emoji: "☁️"),
                TimeBlock(title: "Dinner", startTime: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: date)!, duration: 2700, energy: .moonlight, emoji: "☁️"),
                TimeBlock(title: "Evening personal time", startTime: calendar.date(bySettingHour: 20, minute: 30, second: 0, of: date)!, duration: 5400, energy: .moonlight, emoji: "🌊")
            ]
        }
        
        // Mark all as explanatory AI reconstructions
        return blocks.map { block in
            var updatedBlock = block
            updatedBlock.glassState = .crystal // AI-generated
            return updatedBlock
        }
    }
    
    private func moveBackfillBlock(_ block: TimeBlock, to newTime: Date) {
        if let index = stagedBackfillBlocks.firstIndex(where: { $0.id == block.id }) {
            stagedBackfillBlocks[index].startTime = newTime
        }
    }
    
    private func removeBackfillBlock(_ block: TimeBlock) {
        stagedBackfillBlocks.removeAll { $0.id == block.id }
    }
    
    private func commitBackfill() {
        // Save backfilled day to data manager
        for block in stagedBackfillBlocks {
            dataManager.addTimeBlock(block)
        }
        
        // Clear staging
        stagedBackfillBlocks.removeAll()
        dismiss()
    }
    
    private func discardBackfill() {
        stagedBackfillBlocks.removeAll()
    }
    
    private func createDefaultBackfillBlocks(for date: Date) -> [TimeBlock] {
        let startOfDay = date.startOfDay
        return [
            TimeBlock(
                title: "Morning Routine",
                startTime: Calendar.current.date(byAdding: .hour, value: 8, to: startOfDay)!,
                duration: 3600,
                energy: .sunrise,
                emoji: "☁️"
            ),
            TimeBlock(
                title: "Work Time",
                startTime: Calendar.current.date(byAdding: .hour, value: 10, to: startOfDay)!,
                duration: 14400, // 4 hours
                energy: .daylight,
                emoji: "💎"
            ),
            TimeBlock(
                title: "Lunch Break",
                startTime: Calendar.current.date(byAdding: .hour, value: 13, to: startOfDay)!,
                duration: 3600,
                energy: .daylight,
                emoji: "☁️"
            ),
            TimeBlock(
                title: "Afternoon Work",
                startTime: Calendar.current.date(byAdding: .hour, value: 15, to: startOfDay)!,
                duration: 10800, // 3 hours
                energy: .daylight,
                emoji: "💎"
            ),
            TimeBlock(
                title: "Evening Activities",
                startTime: Calendar.current.date(byAdding: .hour, value: 19, to: startOfDay)!,
                duration: 7200, // 2 hours
                energy: .moonlight,
                emoji: "🌊"
            )
        ]
    }
}

enum BackfillTimeframe: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case older = "Older"
}

enum BackfillViewMode: String, CaseIterable {
    case hybrid = "Hybrid"
    case timeline = "Timeline"
    case list = "List"
}

struct BackfillTemplate: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let duration: TimeInterval
    let confidence: Double
    let energy: EnergyType
    let emoji: String
}

struct QuickTemplate {
    let title: String
    let icon: String
    let duration: TimeInterval
    let energy: EnergyType
    let emoji: String
}

// MARK: - Chains Templates View

struct ChainsTemplatesView: View {
    let selectedDate: Date
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var templates: [ChainTemplate] = []
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Chain Templates")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Drag to timeline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templates) { template in
                        DraggableChainTemplate(template: template)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            generateTemplates()
        }
    }
    
    private func generateTemplates() {
        templates = [
            ChainTemplate(
                name: "Morning Routine",
                icon: "🌅",
                activities: ["Wake up routine", "Exercise", "Breakfast", "Plan day"],
                totalDuration: 120, // 2 hours
                energyFlow: [.sunrise, .sunrise, .daylight, .daylight]
            ),
            ChainTemplate(
                name: "Deep Work",
                icon: "🎯", 
                activities: ["Setup workspace", "Focus session", "Break", "Review"],
                totalDuration: 90, // 1.5 hours
                energyFlow: [.daylight, .daylight, .moonlight, .daylight]
            ),
            ChainTemplate(
                name: "Evening Wind-down",
                icon: "🌙",
                activities: ["Dinner", "Reflection", "Reading", "Sleep prep"],
                totalDuration: 150, // 2.5 hours  
                energyFlow: [.daylight, .moonlight, .moonlight, .moonlight]
            ),
            ChainTemplate(
                name: "Creative Flow",
                icon: "🎨",
                activities: ["Inspiration gathering", "Brainstorm", "Create", "Refine"],
                totalDuration: 180, // 3 hours
                energyFlow: [.daylight, .sunrise, .sunrise, .daylight]
            )
        ]
    }
}

struct DraggableChainTemplate: View {
    let template: ChainTemplate
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text(template.icon)
                .font(.title)
            
            Text(template.name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            HStack(spacing: 4) {
                Text("\(template.totalDuration)m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(template.activities.count) steps")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(12)
        .frame(width: 100, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .offset(dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    dragOffset = .zero
                    
                    // Create chain from template and apply to selected date
                    createChainFromTemplate()
                }
        )
    }
    
    private func createChainFromTemplate() {
        let chain = Chain(
            id: UUID(),
            name: template.name,
            blocks: template.activities.enumerated().map { index, activity in
                let startTime = Calendar.current.date(byAdding: .minute, value: index * 30, to: Date()) ?? Date()
                return TimeBlock(
                    title: activity,
                    startTime: startTime,
                    duration: (template.totalDuration * 60) / template.activities.count,
                    energy: template.energyFlow[index % template.energyFlow.count],
                    emoji: template.icon
                )
            }
        )
        
        dataManager.applyChain(chain, startingAt: Date())
    }
}

// MARK: - Backfill Templates View

struct BackfillTemplatesView: View {
    let selectedDate: Date
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var templates: [BackfillTemplate] = []
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("What likely happened on \(selectedDate.dayString)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Drag to timeline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templates) { template in
                        DraggableBackfillTemplate(template: template)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            generateTemplates()
        }
    }
    
    private func generateTemplates() {
        let dayOfWeek = Calendar.current.component(.weekday, from: selectedDate)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        if isWeekend {
            templates = [
                BackfillTemplate(title: "Sleep in", icon: "🛏️", duration: 3600, confidence: 0.9, energy: .moonlight, emoji: "☁️"),
                BackfillTemplate(title: "Breakfast", icon: "🥞", duration: 1800, confidence: 0.95, energy: .sunrise, emoji: "☁️"),
                BackfillTemplate(title: "Personal projects", icon: "🎨", duration: 7200, confidence: 0.8, energy: .daylight, emoji: "🌊"),
                BackfillTemplate(title: "Errands", icon: "🛒", duration: 5400, confidence: 0.7, energy: .daylight, emoji: "💎"),
                BackfillTemplate(title: "Social time", icon: "👥", duration: 5400, confidence: 0.6, energy: .daylight, emoji: "🌊"),
                BackfillTemplate(title: "Evening relax", icon: "📺", duration: 7200, confidence: 0.8, energy: .moonlight, emoji: "☁️")
            ]
        } else {
            templates = [
                BackfillTemplate(title: "Morning routine", icon: "☕", duration: 3600, confidence: 0.9, energy: .sunrise, emoji: "💎"),
                BackfillTemplate(title: "Work session", icon: "💼", duration: 14400, confidence: 0.85, energy: .daylight, emoji: "💎"),
                BackfillTemplate(title: "Lunch break", icon: "🍽️", duration: 3600, confidence: 0.9, energy: .daylight, emoji: "☁️"),
                BackfillTemplate(title: "Meetings", icon: "👥", duration: 3600, confidence: 0.7, energy: .daylight, emoji: "🌊"),
                BackfillTemplate(title: "Commute", icon: "🚗", duration: 3600, confidence: 0.8, energy: .moonlight, emoji: "☁️"),
                BackfillTemplate(title: "Dinner", icon: "🍽️", duration: 2700, confidence: 0.9, energy: .moonlight, emoji: "☁️"),
                BackfillTemplate(title: "Evening wind-down", icon: "📚", duration: 5400, confidence: 0.7, energy: .moonlight, emoji: "🌊")
            ]
        }
    }
}

struct DraggableBackfillTemplate: View {
    let template: BackfillTemplate
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text(template.icon)
                .font(.title)
            
            Text(template.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            HStack(spacing: 4) {
                Text("\(template.duration.minutes)m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(Int(template.confidence * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .frame(width: 100, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial.opacity(isDragging ? 0.9 : 0.7))
                .shadow(color: .black.opacity(isDragging ? 0.2 : 0.1), radius: isDragging ? 8 : 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.green.opacity(template.confidence), lineWidth: 2)
        )
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .offset(dragOffset)
        .opacity(isDragging ? 0.8 : 1.0)
        .onDrag {
            createTimeBlockFromTemplate()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { _ in
                    isDragging = false
                    dragOffset = .zero
                    // Drop handled by onDrag provider
                }
        )
    }
    
    private func createTimeBlockFromTemplate() -> NSItemProvider {
        let _ = TimeBlock(
            title: template.title,
            startTime: Date(),
            duration: template.duration,
            energy: template.energy,
            emoji: template.emoji
        )
        
        // Create a more detailed drag payload
        let dragPayload = "backfill_template:\(template.title)|\(Int(template.duration))|\(template.energy.rawValue)|\(template.emoji)|\(template.confidence)"
        
        return NSItemProvider(object: dragPayload as NSString)
    }
}

// MARK: - Gap Filler View

struct GapFillerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var gapSuggestions: [GapSuggestion] = []
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Find time for micro-tasks in your schedule gaps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if isAnalyzing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        
                        Text("Analyzing your schedule...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else if gapSuggestions.isEmpty {
                    VStack(spacing: 16) {
                        Text("🔍")
                            .font(.title)
                        
                        Text("No gaps found")
                            .font(.headline)
                        
                        Text("Your schedule looks full! Try refreshing or checking a different day.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Analyze Again") {
                            analyzeGaps()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(gapSuggestions) { suggestion in
                                GapSuggestionCard(suggestion: suggestion) {
                                    applyGapSuggestion(suggestion)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Gap Filler")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            analyzeGaps()
        }
    }
    
    private func analyzeGaps() {
        isAnalyzing = true
        
        Task {
            let gaps = findScheduleGaps()
            let suggestions = await generateGapSuggestions(for: gaps)
            
            await MainActor.run {
                gapSuggestions = suggestions
                isAnalyzing = false
            }
        }
    }
    
    private func findScheduleGaps() -> [ScheduleGap] {
        let allBlocks = dataManager.appState.currentDay.blocks
        let sortedBlocks = allBlocks.sortedByTime
        var gaps: [ScheduleGap] = []
        
        // If no blocks exist, treat the whole day as gaps
        if sortedBlocks.isEmpty {
            // Create gaps for typical work hours
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            gaps.append(ScheduleGap(
                startTime: calendar.date(byAdding: .hour, value: 9, to: startOfDay)!,
                duration: 3600 * 8 // 8 hour work day
            ))
            return gaps
        }
        
        // Find gaps between existing blocks
        for i in 0..<sortedBlocks.count - 1 {
            let currentEnd = sortedBlocks[i].endTime
            let nextStart = sortedBlocks[i + 1].startTime
            
            let gapDuration = nextStart.timeIntervalSince(currentEnd)
            if gapDuration >= 900 { // 15+ minute gaps
                gaps.append(ScheduleGap(
                    startTime: currentEnd,
                    duration: gapDuration
                ))
            }
        }
        
        return gaps
    }
    
    private func generateGapSuggestions(for gaps: [ScheduleGap]) async -> [GapSuggestion] {
        var suggestions: [GapSuggestion] = []
        
        // Always provide some suggestions even if no gaps found
        if gaps.isEmpty {
            // Create default suggestions for an empty schedule
            let defaultTasks = [
                MicroTask(title: "Quick email check", estimatedDuration: 900),
                MicroTask(title: "Plan tomorrow", estimatedDuration: 1200),
                MicroTask(title: "Organize workspace", estimatedDuration: 1800)
            ]
            
            let now = Date()
            for (index, task) in defaultTasks.enumerated() {
                let startTime = Calendar.current.date(byAdding: .hour, value: index + 1, to: now) ?? now
                suggestions.append(GapSuggestion(
                    task: task,
                    startTime: startTime,
                    duration: task.estimatedDuration
                ))
            }
            return suggestions
        }
        
        for gap in gaps {
            let gapMinutes = Int(gap.duration / 60)
            let taskSuggestions = generateTasksForDuration(gapMinutes)
            
            for task in taskSuggestions {
                suggestions.append(GapSuggestion(
                    task: task,
                    startTime: gap.startTime,
                    duration: min(gap.duration, task.estimatedDuration)
                ))
            }
        }
        
        return suggestions
    }
    
    private func generateTasksForDuration(_ minutes: Int) -> [MicroTask] {
        switch minutes {
        case 15..<30:
            return [
                MicroTask(title: "Quick email check", estimatedDuration: 900),
                MicroTask(title: "Tidy workspace", estimatedDuration: 900),
                MicroTask(title: "Stretch break", estimatedDuration: 600)
            ]
        case 30..<60:
            return [
                MicroTask(title: "Review daily goals", estimatedDuration: 1800),
                MicroTask(title: "Quick workout", estimatedDuration: 1800),
                MicroTask(title: "Meal prep", estimatedDuration: 2400)
            ]
        default:
            return [
                MicroTask(title: "Short walk", estimatedDuration: 600),
                MicroTask(title: "Mindfulness moment", estimatedDuration: 300)
            ]
        }
    }
    
    private func applyGapSuggestion(_ suggestion: GapSuggestion) {
        let newBlock = TimeBlock(
            title: suggestion.task.title,
            startTime: suggestion.startTime,
            duration: suggestion.duration,
            energy: .daylight,
            emoji: "🌊",
            glassState: .liquid
        )
        
        dataManager.addTimeBlock(newBlock)
        
        // Remove the applied suggestion
        if let index = gapSuggestions.firstIndex(where: { $0.id == suggestion.id }) {
            gapSuggestions.remove(at: index)
        }
        
        dismiss()
    }
}

struct ScheduleGap {
    let startTime: Date
    let duration: TimeInterval
}

struct MicroTask {
    let title: String
    let estimatedDuration: TimeInterval
}

struct GapSuggestion: Identifiable {
    let id = UUID()
    let task: MicroTask
    let startTime: Date
    let duration: TimeInterval
}

struct GapSuggestionCard: View {
    let suggestion: GapSuggestion
    let onApply: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(suggestion.startTime.timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(suggestion.duration / 60))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Add") {
                onApply()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}
