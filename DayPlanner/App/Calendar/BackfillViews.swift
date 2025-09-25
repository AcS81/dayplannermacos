// MARK: - Backfill View

import SwiftUI

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

struct BackfillTimeframeSelector: View {
    @Binding var selectedTimeframe: BackfillTimeframe
    @Binding var selectedDate: Date
    
    var body: some View {
        HStack {
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(BackfillTimeframe.allCases, id: \.self) { timeframe in
                    Text(timeframe.rawValue).tag(timeframe)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
            
            if selectedTimeframe == .older {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            
            Spacer()
            
            Text("Reconstruct what actually happened")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.5))
        .onChange(of: selectedTimeframe) {
            switch selectedTimeframe {
            case .today:
                selectedDate = Date()
            case .yesterday:
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            case .older:
                // Keep selected date
                break
            }
        }
    }
}

struct BackfillTimeline: View {
    let date: Date
    let suggestions: [TimeBlock]
    let stagedBlocks: [TimeBlock]
    let onBlockMove: (TimeBlock, Date) -> Void
    let onBlockRemove: (TimeBlock) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    BackfillHourSlot(
                        hour: hour,
                        date: date,
                        stagedBlocks: [],
                        onBlockMove: onBlockMove,
                        onBlockRemove: onBlockRemove
                    )
                }
            }
            .padding()
        }
        .background(.quaternary.opacity(0.1))
    }
    
    private func blocksForHour(_ block: TimeBlock, _ hour: Int) -> Bool {
        let blockHour = Calendar.current.component(.hour, from: block.startTime)
        return blockHour == hour
    }
}

struct BackfillHourSlot: View {
    let hour: Int
    let date: Date
    let stagedBlocks: [TimeBlock]
    let onBlockMove: (TimeBlock, Date) -> Void
    let onBlockRemove: (TimeBlock) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Hour label
            Text(String(format: "%02d:00", hour))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            // Content area
            VStack(alignment: .leading, spacing: 4) {
                ForEach(stagedBlocks) { block in
                    BackfillBlockView(
                        block: block,
                        onMove: { newTime in
                            onBlockMove(block, newTime)
                        },
                        onRemove: {
                            onBlockRemove(block)
                        }
                    )
                }
                
                // Drop zone for new blocks
                Rectangle()
                    .fill(.clear)
                    .frame(height: stagedBlocks.isEmpty ? 40 : 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Could trigger inline creation
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct BackfillBlockView: View {
    let block: TimeBlock
    let onMove: (Date) -> Void
    let onRemove: () -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(block.durationMinutes) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                )
        )
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .gesture(
            DragGesture()
                .onChanged { _ in
                    isDragging = true
                }
                .onEnded { value in
                    isDragging = false
                    // Calculate new time based on drag location
                    // For simplicity, just keep current time
                    onMove(block.startTime)
                }
        )
    }
}

struct BackfillSuggestionsPanel: View {
    let isGenerating: Bool
    let suggestions: [TimeBlock]
    let onGenerateSuggestions: () -> Void
    let onApplySuggestion: (TimeBlock) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Suggestions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    onGenerateSuggestions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isGenerating)
            }
            
            if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    
                    Text("Reconstructing your day...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            BackfillSuggestionCard(
                                block: suggestion,
                                onApply: {
                                    onApplySuggestion(suggestion)
                                }
                            )
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.7))
    }
}

struct BackfillSuggestionCard: View {
    let block: TimeBlock
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(block.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(block.energy.rawValue)
                    .font(.caption2)
            }
            
            HStack {
                Text("\(block.durationMinutes)m")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.2), in: Capsule())
                
                Text(block.emoji)
                    .font(.caption2)
                
                Spacer()
                
                Button("Add") {
                    onApply()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct BackfillActionsBar: View {
    let hasChanges: Bool
    let onCommit: () -> Void
    let onDiscard: () -> Void
    
    var body: some View {
        HStack {
            if hasChanges {
                Text("\(hasChanges ? "Changes ready to save" : "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if hasChanges {
                HStack(spacing: 12) {
                    Button("Discard") {
                        onDiscard()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save to Calendar") {
                        onCommit()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
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

struct BackfillTemplate: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let duration: TimeInterval
    let confidence: Double
    let energy: EnergyType
    let emoji: String
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

// MARK: - Pillar Day View

struct PillarDayView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @State private var missingPillars: [Pillar] = []
    @State private var suggestedEvents: [TimeBlock] = []
    @State private var isAnalyzing = false
    @State private var analysisText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Intelligent pillar activity scheduling without removing existing events")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                if isAnalyzing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Analyzing pillar needs...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if !analysisText.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Analysis")
                                        .font(.headline)
                                    
                                    Text(analysisText)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .padding()
                                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            
                            if !missingPillars.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("⚠️ Overdue Pillars")
                                            .font(.headline)
                                            .foregroundStyle(.orange)
                                        
                                        Spacer()
                                        
                                        Text("Need attention")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    ForEach(missingPillars) { pillar in
                                        MissingPillarCard(pillar: pillar) {
                                            createPillarEvent(for: pillar)
                                        }
                                    }
                                }
                            }
                            
                            if !suggestedEvents.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("📅 Ready to Schedule")
                                            .font(.headline)
                                            .foregroundStyle(.green)
                                        
                                        Spacer()
                                        
                                        Text("Drag to timeline or click Add")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    ForEach(suggestedEvents) { event in
                                        DraggableSuggestedEventCard(event: event) {
                                            stagePillarEvent(event)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
                    HStack {
                        Button("Refresh Analysis") {
                            analyzePillarNeeds()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        if !suggestedEvents.isEmpty {
                            Button("Add All (\(suggestedEvents.count))") {
                                addAllPillarEvents()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pillar Day")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            analyzePillarNeeds()
        }
    }
    
    private func analyzePillarNeeds() {
        isAnalyzing = true
        
        Task {
            let actionablePillars = dataManager.appState.pillars.filter(\.isActionable)
            var missing: [Pillar] = []
            var suggestions: [TimeBlock] = []
            
            let now = Date()
            
            for pillar in actionablePillars {
                let daysSinceLastEvent = pillar.lastEventDate?.timeIntervalSince(now) ?? -99999999
                let needsEvent = shouldCreateEventForPillar(pillar, daysSince: daysSinceLastEvent / 86400)
                
                if needsEvent {
                    missing.append(pillar)
                }
            }
            
            // Generate suggested events for missing pillars (separate from just listing them)
            for pillar in missing {
                if let timeSlot = findBestTimeSlot(for: pillar) {
                    let suggestedEvent = TimeBlock(
                        title: pillar.name,
                        startTime: timeSlot.startTime,
                        duration: pillar.minDuration,
                        energy: .daylight,
                        emoji: pillar.emoji,
                        relatedPillarId: pillar.id
                    )
                    suggestions.append(suggestedEvent)
                }
            }
            
            await MainActor.run {
                missingPillars = missing
                suggestedEvents = suggestions
                analysisText = generateAnalysisText(missingCount: missing.count, totalPillars: actionablePillars.count)
                isAnalyzing = false
            }
        }
    }
    
    private func shouldCreateEventForPillar(_ pillar: Pillar, daysSince: Double) -> Bool {
        switch pillar.frequency {
        case .daily:
            return daysSince <= -1 // More than 1 day ago
        case .weekly(let count):
            let expectedInterval = 7.0 / Double(count)
            return daysSince <= -expectedInterval
        case .monthly(let count):
            let expectedInterval = 30.0 / Double(count)
            return daysSince <= -expectedInterval
        case .asNeeded:
            return daysSince <= -7 // Weekly check for as-needed items
        }
    }
    
    private func findBestTimeSlot(for pillar: Pillar) -> (startTime: Date, duration: TimeInterval)? {
        let calendar = Calendar.current
        let today = Date()
        
        // Check preferred time windows
        for window in pillar.preferredTimeWindows {
            if let windowStart = calendar.date(bySettingHour: window.startHour, minute: window.startMinute, second: 0, of: today) {
                // Check if this slot is available
                if isTimeSlotAvailable(start: windowStart, duration: pillar.minDuration) {
                    return (startTime: windowStart, duration: pillar.minDuration)
                }
            }
        }
        
        // Fallback: find any available slot
        return findNextAvailableSlot(duration: pillar.minDuration)
    }
    
    private func isTimeSlotAvailable(start: Date, duration: TimeInterval) -> Bool {
        let end = start.addingTimeInterval(duration)
        let allBlocks = dataManager.appState.currentDay.blocks
        
        return !allBlocks.contains { block in
            let blockInterval = DateInterval(start: block.startTime, end: block.endTime)
            let checkInterval = DateInterval(start: start, end: end)
            return blockInterval.intersects(checkInterval)
        }
    }
    
    private func findNextAvailableSlot(duration: TimeInterval) -> (startTime: Date, duration: TimeInterval)? {
        let calendar = Calendar.current
        let now = Date()
        let roundedNow = calendar.date(byAdding: .minute, value: 15 - calendar.component(.minute, from: now) % 15, to: now) ?? now
        
        var searchTime = roundedNow
        let endOfDay = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now
        
        while searchTime < endOfDay {
            if isTimeSlotAvailable(start: searchTime, duration: duration) {
                return (startTime: searchTime, duration: duration)
            }
            searchTime = calendar.date(byAdding: .minute, value: 30, to: searchTime) ?? searchTime
        }
        
        return nil
    }
    
    private func generateAnalysisText(missingCount: Int, totalPillars: Int) -> String {
        if missingCount == 0 {
            return "🎉 All your pillars are up to date! Your consistency is paying off."
        } else {
            return "📊 Found \(missingCount) of \(totalPillars) pillars that need attention based on their frequency settings."
        }
    }
    
    private func createPillarEvent(for pillar: Pillar) {
        if let suggestion = suggestedEvents.first(where: { $0.title == pillar.name }) {
            stagePillarEvent(suggestion)
        }
    }
    
    private func stagePillarEvent(_ event: TimeBlock) {
        dataManager.addTimeBlock(event)
        suggestedEvents.removeAll { $0.id == event.id }
    }
    
    private func addAllPillarEvents() {
        for event in suggestedEvents {
            stagePillarEvent(event)
        }
        
        dismiss()
    }
}

struct MissingPillarCard: View {
    let pillar: Pillar
    let onCreateEvent: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text(pillar.emoji)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pillar.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(pillar.frequencyDescription) - overdue")
                    .font(.caption)
                    .foregroundStyle(.orange)
                
                if let lastEvent = pillar.lastEventDate {
                    Text("Last: \(lastEvent.dayString)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button("Schedule") {
                onCreateEvent()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DraggableSuggestedEventCard: View {
    let event: TimeBlock
    let onAdd: () -> Void
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        HStack(spacing: 12) {
            // Emoji from related pillar or event
            Text(event.emoji.isEmpty ? "📅" : event.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Text(event.startTime.timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(event.durationMinutes)m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
            }
            
            Spacer()
            
            if !isDragging {
                Button("Add") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("Drop on timeline")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .italic()
            }
        }
        .padding(12)
        .background(.green.opacity(isDragging ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.green.opacity(isDragging ? 0.6 : 0.3), lineWidth: isDragging ? 2 : 1)
        )
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .offset(dragOffset)
        .opacity(isDragging ? 0.8 : 1.0)
        .onDrag {
            createEventDragProvider()
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
                    // Stage the event when drag ends
                    onAdd()
                }
        )
    }
    
    private func createEventDragProvider() -> NSItemProvider {
        // Stage the event immediately when drag starts
        dataManager.addTimeBlock(event)
        return NSItemProvider(object: event.title as NSString)
    }
}

