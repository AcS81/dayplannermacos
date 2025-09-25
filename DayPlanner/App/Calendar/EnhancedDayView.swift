// MARK: - Enhanced Day View

import SwiftUI

struct EnhancedDayView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Binding private var selectedDate: Date
    @Binding private var ghostSuggestions: [Suggestion]
    @Binding private var showingRecommendations: Bool
    @State private var showingBlockCreation = false
    @State private var creationTime: Date?
    @State private var draggedBlock: TimeBlock?
    @State private var selectedGhostIDs: Set<UUID> = []
    @State private var refreshTask: Task<Void, Never>? = nil
    
    // Constants for precise timeline sizing
    private let minuteHeight: CGFloat = 1.0 // 1 pixel per minute = perfect precision
    private let dayStartHour: Int = 0
    private let dayEndHour: Int = 24
    private let ghostRefreshInterval: UInt64 = 8_000_000_000 // 8 seconds

    init(
        selectedDate: Binding<Date>,
        ghostSuggestions: Binding<[Suggestion]> = .constant([]),
        showingRecommendations: Binding<Bool> = .constant(true)
    ) {
        _selectedDate = selectedDate
        _ghostSuggestions = ghostSuggestions
        _showingRecommendations = showingRecommendations
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Proportional timeline view where duration = visual height
            ScrollView {
                ProportionalTimelineView(
                    selectedDate: selectedDate,
                    blocks: allBlocksForDay,
                    draggedBlock: draggedBlock,
                    minuteHeight: minuteHeight,
                    onTap: { time in
                        creationTime = time
                        showingBlockCreation = true
                    },
                    onBlockDrag: { block, location in
                        draggedBlock = block
                    },
                    onBlockDrop: { block, newTime in
                        handleBlockDrop(block: block, newTime: newTime)
                        draggedBlock = nil
                    },
                    showGhosts: showingRecommendations,
                    ghostSuggestions: ghostSuggestions,
                    dayStartHour: dayStartHour,
                    selectedGhosts: $selectedGhostIDs,
                    onGhostToggle: toggleGhostSelection
                )
                .padding(.trailing, 2)
                .padding(.bottom, ghostAcceptanceInset)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(draggedBlock != nil) // Disable scroll when dragging an event
        }
        .overlay(alignment: .bottom) {
            if showingRecommendations && !ghostSuggestions.isEmpty {
                GhostAcceptanceBar(
                    totalCount: ghostSuggestions.count,
                    selectedCount: selectedGhostIDs.count,
                    onAcceptAll: acceptAllGhosts,
                    onAcceptSelected: acceptSelectedGhosts
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            dataManager.switchToDay(newValue)
            Task { @MainActor in
                await refreshGhosts(force: true)
            }
        }
        .onAppear {
            selectedDate = dataManager.appState.currentDay.date
            if showingRecommendations {
                startGhostRefresh(force: true)
            }
        }
        .onDisappear {
            stopGhostRefresh()
        }
        .onChange(of: showingRecommendations) { isEnabled in
            if isEnabled {
                startGhostRefresh(force: true)
            } else {
                stopGhostRefresh()
                selectedGhostIDs.removeAll()
            }
        }
        .sheet(isPresented: $showingBlockCreation) {
            BlockCreationSheet(
                suggestedTime: creationTime ?? Date(),
                onCreate: { block in
                    dataManager.addTimeBlock(block)
                    showingBlockCreation = false
                }
            )
        }
    }
    
    private var allBlocksForDay: [TimeBlock] {
        dataManager.appState.currentDay.blocks.sorted { $0.startTime < $1.startTime }
    }
    
    private func handleBlockDrop(block: TimeBlock, newTime: Date) {
        var updatedBlock = block
        updatedBlock.startTime = newTime
        dataManager.updateTimeBlock(updatedBlock)
    }

    private var ghostAcceptanceInset: CGFloat {
        (showingRecommendations && !ghostSuggestions.isEmpty) ? 96 : 24
    }

    private func toggleGhostSelection(_ suggestion: Suggestion) {
        if selectedGhostIDs.contains(suggestion.id) {
            selectedGhostIDs.remove(suggestion.id)
        } else {
            selectedGhostIDs.insert(suggestion.id)
        }
    }
}

// MARK: - Ghost Overlay Helpers

private extension EnhancedDayView {
    func startGhostRefresh(force: Bool = false) {
        stopGhostRefresh()
        refreshTask = Task { @MainActor in
            await refreshGhosts(force: force)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: ghostRefreshInterval)
                await refreshGhosts()
            }
        }
    }
    
    func stopGhostRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    @MainActor
    func refreshGhosts(force: Bool = false) async {
        guard showingRecommendations else { return }
        let rawSuggestions = await generateGhostSuggestions(for: selectedDate)
        var placedSuggestions = rawSuggestions
        assignTimes(to: &placedSuggestions, for: selectedDate)
        placedSuggestions = normalizeSuggestions(placedSuggestions)
        placedSuggestions.sort { $0.suggestedTime < $1.suggestedTime }
        if force || shouldUpdateGhosts(current: ghostSuggestions, new: placedSuggestions) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                ghostSuggestions = placedSuggestions
            }
            let validIDs = Set(placedSuggestions.map(\.id))
            selectedGhostIDs = selectedGhostIDs.intersection(validIDs)
        }
    }
    
    @MainActor
    func generateGhostSuggestions(for date: Date) async -> [Suggestion] {
        let gaps = computeGaps(for: date)
        let availableTime = gaps.reduce(0) { $0 + $1.duration }
        let guidance = dataManager.appState.pillars.filter { $0.isPrinciple }.map { $0.aiGuidanceText }
        let actionable = dataManager.appState.pillars.filter { $0.isActionable }
        let context = DayContext(
            date: date,
            existingBlocks: dataManager.appState.currentDay.blocks,
            currentEnergy: .daylight,
            preferredEmojis: ["🌊"],
            availableTime: availableTime,
            mood: dataManager.appState.currentDay.mood,
            weatherContext: dataManager.weatherService.getWeatherContext(),
            pillarGuidance: guidance,
            actionablePillars: actionable
        )
        do {
            return try await aiService.generateSuggestions(for: context)
        } catch {
            return AIService.mockSuggestions()
        }
    }
    
    func assignTimes(to suggestions: inout [Suggestion], for date: Date) {
        var gaps = computeGaps(for: date)
        guard !gaps.isEmpty else { return }
        let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
        for index in suggestions.indices {
            guard let gapIndex = gaps.firstIndex(where: { $0.duration >= suggestions[index].duration }) ?? gaps.indices.first else {
                continue
            }
            var suggestion = suggestions[index]
            var gap = gaps[gapIndex]
            if suggestion.duration > gap.duration {
                suggestion.duration = max(gap.duration - 120, 600) // leave small buffer, minimum 10 min
            }
            let anchorStart = isToday ? max(gap.start, Date()) : gap.start
            let startTime = snapToNearestFiveMinutes(anchorStart)
            suggestion.suggestedTime = startTime
            suggestions[index] = suggestion
            let consumptionEnd = startTime.addingTimeInterval(suggestion.duration + 60)
            if consumptionEnd < gap.end - 600 {
                gap.start = consumptionEnd
                gaps[gapIndex] = gap
            } else {
                gaps.remove(at: gapIndex)
            }
            if gaps.isEmpty { break }
        }
    }
    
    func computeGaps(for date: Date) -> [TimeGap] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let now = Date()
        let lowerBound = calendar.isDate(date, inSameDayAs: now) ? max(dayStart, now) : dayStart
        var gaps: [TimeGap] = []
        var cursor = lowerBound
        for block in allBlocksForDay {
            let blockStart = max(block.startTime, dayStart)
            if blockStart > cursor + 600 {
                let gapEnd = min(blockStart, dayEnd)
                gaps.append(TimeGap(start: cursor, end: gapEnd))
            }
            let blockEnd = min(block.endTime, dayEnd)
            cursor = max(cursor, blockEnd)
            if cursor >= dayEnd { break }
        }
        if dayEnd > cursor + 600 {
            gaps.append(TimeGap(start: cursor, end: dayEnd))
        }
        return gaps
    }
    
    func snapToNearestFiveMinutes(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let baseDate = calendar.date(from: components) else { return date }
        let minute = components.minute ?? 0
        let remainder = minute % 5
        let snappedMinute = minute - remainder
        return calendar.date(bySetting: .minute, value: snappedMinute, of: baseDate) ?? date
    }
    
    func normalizeSuggestions(_ suggestions: [Suggestion]) -> [Suggestion] {
        let existingMap = Dictionary(uniqueKeysWithValues: ghostSuggestions.map { (fingerprint(for: $0), $0.id) })
        return suggestions.map { suggestion in
            let key = fingerprint(for: suggestion)
            if let existingID = existingMap[key] {
                return Suggestion(
                    id: existingID,
                    title: suggestion.title,
                    duration: suggestion.duration,
                    suggestedTime: suggestion.suggestedTime,
                    energy: suggestion.energy,
                    emoji: suggestion.emoji,
                    explanation: suggestion.explanation,
                    confidence: suggestion.confidence
                )
            }
            return suggestion
        }
    }
    
    func fingerprint(for suggestion: Suggestion) -> String {
        let startKey = Int(suggestion.suggestedTime.timeIntervalSinceReferenceDate)
        return "\(suggestion.title.lowercased())|\(Int(suggestion.duration))|\(suggestion.energy.rawValue)|\(startKey)"
    }
    
    func shouldUpdateGhosts(current: [Suggestion], new: [Suggestion]) -> Bool {
        guard current.count == new.count else { return true }
        for (lhs, rhs) in zip(current, new) {
            if fingerprint(for: lhs) != fingerprint(for: rhs) {
                return true
            }
        }
        return false
    }
    
    func acceptAllGhosts() {
        acceptGhosts(ghostSuggestions)
    }
    
    func acceptSelectedGhosts() {
        let selected = ghostSuggestions.filter { selectedGhostIDs.contains($0.id) }
        if selected.isEmpty {
            acceptAllGhosts()
        } else {
            acceptGhosts(selected)
        }
    }
    
    func acceptGhosts(_ suggestionsToAccept: [Suggestion]) {
        guard !suggestionsToAccept.isEmpty else { return }
        let acceptedIDs = Set(suggestionsToAccept.map(\.id))
        for suggestion in suggestionsToAccept {
            dataManager.applySuggestion(suggestion)
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            ghostSuggestions.removeAll { acceptedIDs.contains($0.id) }
        }
        selectedGhostIDs.subtract(acceptedIDs)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await refreshGhosts(force: true)
        }
    }
    
    struct TimeGap {
        var start: Date
        var end: Date
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }
}

// MARK: - Hour With Events (Simplified Layout)

struct HourWithEvents: View {
    let hour: Int
    let selectedDate: Date
    let blocks: [TimeBlock]
    let draggedBlock: TimeBlock?
    let onTap: (Date) -> Void
    let onBlockDrag: (TimeBlock, CGPoint) -> Void
    let onBlockDrop: (TimeBlock, Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var isHovering = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Events for this hour
            ForEach(blocks) { block in
                CleanEventCard(
                    block: block,
                    onDrag: { location in
                        onBlockDrag(block, location)
                    },
                    onDrop: { newTime in
                        onBlockDrop(block, newTime)
                    }
                )
            }
            
            // Empty space for creating new blocks
            if blocks.isEmpty {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHovering ? .blue.opacity(0.05) : hourBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        isHovering ? .blue.opacity(0.3) : .clear,
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                                    )
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let hourTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                        onTap(hourTime)
                    }
                    .onHover { hovering in
                        isHovering = hovering
                    }
            }
            
            // Hour separator line
            if hour < 23 {
                Rectangle()
                    .fill(.quaternary.opacity(0.2))
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(minHeight: 60) // Minimum hour height
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var hourBackgroundColor: Color {
        AstronomicalTimeCalculator.shared.getTimeColor(for: hour, date: selectedDate)
    }
}

// MARK: - Enhanced Hour Slot

struct EnhancedHourSlot: View {
    let hour: Int
    let selectedDate: Date
    let blocks: [TimeBlock]
    let onTap: (Date) -> Void
    let onBlockDrag: (TimeBlock, CGPoint) -> Void
    let onBlockDrop: (TimeBlock, Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var isHovering = false
    
    private var hourTime: Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        return calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? dayStart
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: hourTime)
    }
    
    private var isCurrentHour: Bool {
        Calendar.current.component(.hour, from: Date()) == hour &&
        Calendar.current.isDate(selectedDate, inSameDayAs: Date())
    }
    
    private var isCurrentMinute: Bool {
        let now = Date()
        let currentHour = Calendar.current.component(.hour, from: now)
        return currentHour == hour && Calendar.current.isDate(selectedDate, inSameDayAs: now)
    }
    
    private var currentTimeOffset: CGFloat {
        guard isCurrentMinute else { return 0 }
        let now = Date()
        let minute = Calendar.current.component(.minute, from: now)
        return CGFloat(minute) * 0.8 // Rough positioning within hour slot
    }
    
    private var dayNightBackground: Color {
        AstronomicalTimeCalculator.shared.getTimeColor(for: hour, date: selectedDate)
    }
    
    private var timeLabel: String {
        switch hour {
        case 6: return "🌅 \(timeString)"
        case 18: return "🌅 \(timeString)"
        case 0: return "🌙 \(timeString)"
        default: return timeString
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time label with enhanced styling and day/night indicators
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeLabel)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(isCurrentHour ? .blue : .primary)
                
                if isCurrentHour {
                    Circle()
                        .fill(.blue)
                        .frame(width: 4, height: 4)
                        .overlay(
                            Circle()
                                .stroke(.blue, lineWidth: 1)
                                .scaleEffect(1.5)
                                .opacity(0.3)
                        )
                }
            }
            .frame(width: 60, alignment: .trailing)
            
            // Hour content area
            VStack(alignment: .leading, spacing: 4) {
                ForEach(blocks) { block in
                    EnhancedTimeBlockCard(
                        block: block,
                        onTap: { },
                        onDrag: { location in
                            onBlockDrag(block, location)
                        },
                        onDrop: { newTime in
                            onBlockDrop(block, newTime)
                        },
                        allBlocks: blocksForCurrentDay()
                    )
                }
                
                // Empty space for creating new blocks
                if blocks.isEmpty {
                    Rectangle()
                        .fill(.clear)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHovering ? .blue.opacity(0.05) : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            isHovering ? .blue.opacity(0.3) : .clear,
                                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                                        )
                                )
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTap(hourTime)
                        }
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isHovering = hovering
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                // Current time line indicator
                isCurrentMinute ?
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(.blue)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .opacity(0.8)
                        
                        Text("now")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .opacity(0.9)
                    }
                    .offset(y: currentTimeOffset - 20)
                    : nil,
                alignment: .topLeading
            )
        }
        .padding(.vertical, 4)
        .background(
            Group {
                if isCurrentHour {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.blue.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(dayNightBackground)
                }
            }
        )
    }
    
    private func blocksForCurrentDay() -> [TimeBlock] {
        // Return all blocks for the current day for gap checking
        return dataManager.appState.currentDay.blocks
    }
}
