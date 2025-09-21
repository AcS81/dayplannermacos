//
//  HelperViews.swift
//  DayPlanner
//
//  Helper Views and Utilities
//

import SwiftUI

// MARK: - Emoji Picker Button

struct EmojiPickerButton: View {
    @Binding var selectedEmoji: String
    @State private var showingEmojiPicker = false
    
    private let commonEmojis = [
        "🏛️", "💪", "🧠", "❤️", "🎯", "📚", "🏃‍♀️", "🍎",
        "💼", "🎨", "🌱", "⚡", "🔥", "🌊", "☀️", "🌙",
        "🎵", "📝", "💡", "🚀", "🏆", "🎪", "🌈", "⭐",
        "🔮", "💎", "🌸", "🍀", "🦋", "🌺", "🌻", "🌹"
    ]
    
    var body: some View {
        Button(action: {
            showingEmojiPicker.toggle()
        }) {
            Text(selectedEmoji.isEmpty ? "🏛️" : selectedEmoji)
                .font(.title2)
                .frame(width: 60, height: 40)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingEmojiPicker) {
            EmojiPickerView(selectedEmoji: $selectedEmoji, emojis: commonEmojis) {
                showingEmojiPicker = false
            }
        }
    }
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    let emojis: [String]
    let onSelection: () -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Emoji")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(action: {
                            selectedEmoji = emoji
                            onSelection()
                        }) {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(
                                    selectedEmoji == emoji ? 
                                        .blue.opacity(0.2) : 
                                        .clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
        }
        .padding(.vertical)
        .frame(width: 360)
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.title2)
                .opacity(0.6)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(.ultraThinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}

// MARK: - Right Rail View

struct RightRailView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var selectedSection: RightRailSection = .suggestions
    
    var body: some View {
        VStack(spacing: 0) {
            // Rail header
            RightRailHeader(selectedSection: $selectedSection)
            
            Divider()
            
            // Rail content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedSection {
                    case .manual:
                        ManualCreationSection()
                    case .suggestions:
                        SuggestionsSection()
                    case .reschedule:
                        RescheduleSection()
                    }
                }
                .padding()
            }
        }
        .background(.ultraThinMaterial.opacity(0.3))
    }
}

enum RightRailSection: String, CaseIterable {
    case manual = "Manual"
    case suggestions = "Suggestions"
    case reschedule = "Reschedule"
    
    var icon: String {
        switch self {
        case .manual: return "plus.circle"
        case .suggestions: return "sparkles"
        case .reschedule: return "clock.arrow.circlepath"
        }
    }
}

struct RightRailHeader: View {
    @Binding var selectedSection: RightRailSection
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(RightRailSection.allCases, id: \.self) { section in
                Button(action: { selectedSection = section }) {
                    VStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.system(size: 16))
                        
                        Text(section.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedSection == section ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedSection == section ? .blue.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Right Rail Sections

struct ManualCreationSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingBlockCreation = false
    @State private var showingChainCreation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Button(action: { showingBlockCreation = true }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("Time Block")
                        Spacer()
                    }
                    .padding()
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Button(action: { showingChainCreation = true }) {
                    HStack {
                        Image(systemName: "link")
                        Text("Chain")
                        Spacer()
                    }
                    .padding()
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "building.columns")
                        Text("Pillar")
                        Spacer()
                    }
                    .padding()
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingBlockCreation) {
            BlockCreationSheet(suggestedTime: Date()) { block in
                dataManager.addTimeBlock(block)
                showingBlockCreation = false
            }
        }
        .sheet(isPresented: $showingChainCreation) {
            ChainCreationView { chain in
                dataManager.addChain(chain)
                showingChainCreation = false
            }
        }
    }
}

struct SuggestionsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var suggestions: [Suggestion] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Suggestions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    generateSuggestions()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if suggestions.isEmpty {
                VStack(spacing: 8) {
                    Text("✨")
                        .font(.title2)
                        .opacity(0.5)
                    
                    Text("No suggestions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Get Suggestions") {
                        generateSuggestions()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        SuggestionRailCard(suggestion: suggestion) {
                            dataManager.applySuggestion(suggestion)
                            suggestions.removeAll { $0.id == suggestion.id }
                        }
                    }
                }
            }
        }
        .onAppear {
            if suggestions.isEmpty {
                generateSuggestions()
            }
        }
    }
    
    private func generateSuggestions() {
        isLoading = true
        
        Task {
            do {
                let context = DayContext(
                    date: Date(),
                    existingBlocks: dataManager.appState.currentDay.blocks,
                    currentEnergy: .daylight,
                    preferredEmojis: ["🌊"],
                    availableTime: 3600,
                    mood: dataManager.appState.currentDay.mood
                )
                
                let newSuggestions = try await aiService.generateSuggestions(for: context)
                
                await MainActor.run {
                    suggestions = newSuggestions
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    suggestions = AIService.mockSuggestions()
                    isLoading = false
                }
            }
        }
    }
}

struct RescheduleSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reschedule")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if incompletedBlocks.count > 0 {
                    Text("\(incompletedBlocks.count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.2), in: Capsule())
                        .foregroundColor(.red)
                }
            }
            
            if incompletedBlocks.isEmpty {
                VStack(spacing: 8) {
                    Text("✅")
                        .font(.title2)
                        .opacity(0.5)
                    
                    Text("All caught up!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(incompletedBlocks) { block in
                        RescheduleCard(block: block) {
                            rescheduleBlock(block)
                        }
                    }
                }
            }
        }
    }
    
    private var incompletedBlocks: [TimeBlock] {
        dataManager.appState.currentDay.blocks.filter { block in
            block.endTime < Date() && block.glassState != .solid
        }
    }
    
    private func rescheduleBlock(_ block: TimeBlock) {
        // Reschedule logic
        var updatedBlock = block
        updatedBlock.startTime = Date().addingTimeInterval(1800) // 30 minutes from now
        updatedBlock.glassState = .mist // Mark as rescheduled
        dataManager.updateTimeBlock(updatedBlock)
    }
}

// MARK: - Supporting Views

struct SuggestionRailCard: View {
    let suggestion: Suggestion
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Spacer()
                
                Text(suggestion.energy.rawValue)
                    .font(.caption2)
            }
            
            Text(suggestion.explanation)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(suggestion.duration.minutes)m")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2), in: Capsule())
                    
                    Text("at \(suggestion.suggestedTime.timeString)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(suggestion.emoji)
                    .font(.caption2)
                
                Spacer()
                
                Button("Add") {
                    onApply()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RescheduleCard: View {
    let block: TimeBlock
    let onReschedule: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(block.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Was: \(block.startTime.timeString)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Reschedule") {
                onReschedule()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(10)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
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
            let calendar = Calendar.current
            
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
