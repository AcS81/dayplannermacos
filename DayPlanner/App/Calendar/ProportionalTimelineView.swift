// MARK: - Precise Timeline View (Exact Positioning)

import SwiftUI

struct ProportionalTimelineView: View {
    let selectedDate: Date
    let blocks: [TimeBlock]
    let draggedBlock: TimeBlock?
    let minuteHeight: CGFloat
    let onTap: (Date) -> Void
    let onBlockDrag: (TimeBlock, CGPoint) -> Void
    let onBlockDrop: (TimeBlock, Date) -> Void
    private let showGhosts: Bool
    private let ghostSuggestions: [Suggestion]
    private let onGhostToggle: (Suggestion) -> Void
    private let calendar = Calendar.current
    private let dayStartHour: Int
    private let dayEndHour: Int
    @Binding private var selectedGhosts: Set<UUID>
    
    init(
        selectedDate: Date,
        blocks: [TimeBlock],
        draggedBlock: TimeBlock?,
        minuteHeight: CGFloat,
        onTap: @escaping (Date) -> Void,
        onBlockDrag: @escaping (TimeBlock, CGPoint) -> Void,
        onBlockDrop: @escaping (TimeBlock, Date) -> Void,
        showGhosts: Bool = false,
        ghostSuggestions: [Suggestion] = [],
        dayStartHour: Int = 0,
        dayEndHour: Int = 24,
        selectedGhosts: Binding<Set<UUID>> = .constant([]),
        onGhostToggle: @escaping (Suggestion) -> Void = { _ in }
    ) {
        self.selectedDate = selectedDate
        self.blocks = blocks
        self.draggedBlock = draggedBlock
        self.minuteHeight = minuteHeight
        self.onTap = onTap
        self.onBlockDrag = onBlockDrag
        self.onBlockDrop = onBlockDrop
        self.showGhosts = showGhosts
        self.ghostSuggestions = ghostSuggestions
        self.dayStartHour = dayStartHour
        self.dayEndHour = dayEndHour
        _selectedGhosts = selectedGhosts
        self.onGhostToggle = onGhostToggle
    }
    
    private var currentHour: Int {
        calendar.component(.hour, from: Date())
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Time labels column with precise minute markers
            TimeLabelsColumn(
                selectedDate: selectedDate,
                dayStartHour: dayStartHour,
                dayEndHour: dayEndHour
            )
            .frame(width: 80)
            
            // Precise timeline canvas with astronomical hour colors
            ZStack(alignment: .topLeading) {
                // Background grid with astronomical colors
                TimelineCanvas(
                    selectedDate: selectedDate,
                    dayStartHour: dayStartHour,
                    dayEndHour: dayEndHour,
                    onTap: onTap
                )
                
                // Events positioned at exact times
                ForEach(blocks) { block in
                    PreciseEventCard(
                        block: block,
                        selectedDate: selectedDate,
                        dayStartHour: dayStartHour,
                        minuteHeight: minuteHeight,
                        isDragged: draggedBlock?.id == block.id,
                        allBlocks: blocks,
                        onDrag: { location in
                            onBlockDrag(block, location)
                        },
                        onDrop: { newTime in
                            onBlockDrop(block, newTime)
                        }
                    )
                }
                
                if showGhosts && !ghostSuggestions.isEmpty {
                    GhostOverlay(
                        selectedDate: selectedDate,
                        dayStartHour: dayStartHour,
                        minuteHeight: minuteHeight,
                        suggestions: ghostSuggestions,
                        selectedGhosts: $selectedGhosts,
                        onToggle: onGhostToggle
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func blocksForHour(_ hour: Int, blocks: [TimeBlock]) -> [TimeBlock] {
        return blocks.filter { block in
            let blockHour = calendar.component(.hour, from: block.startTime)
            return blockHour == hour
        }
    }
    
    private func hourLabel(for hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        switch hour {
        case 6: return "🌅 \(formatter.string(from: date))"    // Sunrise
        case 12: return "☀️ \(formatter.string(from: date))"   // Noon sun
        case 18: return "🌇 \(formatter.string(from: date))"   // Sunset
        case 21: return "🌙 \(formatter.string(from: date))"   // Evening moon
        case 0: return "🌛 \(formatter.string(from: date))"    // Midnight crescent
        default: return formatter.string(from: date)
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        return calendar.component(.hour, from: Date()) == hour &&
               calendar.isDate(selectedDate, inSameDayAs: Date())
    }
    
    private func hourBackgroundColor(for hour: Int) -> Color {
        AstronomicalTimeCalculator.shared.getTimeColor(for: hour, date: selectedDate)
    }
    
    @ViewBuilder
    private func currentTimeIndicator(for hour: Int) -> some View {
        if isCurrentHour(hour) {
            let now = Date()
            let minute = calendar.component(.minute, from: now)
            let offsetY = CGFloat(minute) // 1 pixel per minute
            
            HStack(spacing: 8) {
                Rectangle()
                    .fill(.blue)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .opacity(0.8)
                    .shadow(color: .blue, radius: 1)
                
                Text("now")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .opacity(0.9)
            }
            .offset(y: offsetY)
        }
    }
}

// MARK: - Precise Timeline Components

struct TimeLabelsColumn: View {
    let selectedDate: Date
    let dayStartHour: Int
    let dayEndHour: Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(dayStartHour..<dayEndHour, id: \.self) { hour in
                VStack(spacing: 0) {
                    // Hour label at top
                    Text(hourLabel(for: hour))
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(isCurrentHour(hour) ? .blue : .primary)
                        .frame(height: 15, alignment: .bottom)
                    
                    // Quarter hour markers
                    VStack(spacing: 0) {
                        ForEach([15, 30, 45], id: \.self) { minute in
                            HStack {
                                Spacer()
                                Text(":\(minute)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(height: 15)
                        }
                    }
                }
                .frame(height: 60) // 60 pixels per hour
            }
        }
    }
    
    private func hourLabel(for hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        switch hour {
        case 6: return "🌅 \(formatter.string(from: date))"    // Sunrise
        case 12: return "☀️ \(formatter.string(from: date))"   // Noon sun
        case 18: return "🌇 \(formatter.string(from: date))"   // Sunset
        case 21: return "🌙 \(formatter.string(from: date))"   // Evening moon
        case 0: return "🌛 \(formatter.string(from: date))"    // Midnight crescent
        default: return formatter.string(from: date)
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        return calendar.component(.hour, from: Date()) == hour &&
               calendar.isDate(selectedDate, inSameDayAs: Date())
    }
}

struct TimelineCanvas: View {
    let selectedDate: Date
    let dayStartHour: Int
    let dayEndHour: Int
    let onTap: (Date) -> Void
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(dayStartHour..<dayEndHour, id: \.self) { hour in
                Rectangle()
                    .fill(hourBackgroundColor(for: hour))
                    .frame(height: 60) // 60 pixels per hour (1 pixel per minute)
                    .overlay(
                        // Quarter hour grid lines
                        VStack(spacing: 0) {
                            ForEach([15, 30, 45], id: \.self) { minute in
                                Rectangle()
                                    .fill(.quaternary.opacity(0.1))
                                    .frame(height: 1)
                                    .frame(maxWidth: .infinity)
                                    .offset(y: CGFloat(minute - 15))
                            }
                        },
                        alignment: .top
                    )
                    .overlay(
                        // Current time indicator
                        currentTimeIndicator(for: hour),
                        alignment: .topLeading
                    )
                    .overlay(
                        // Hour separator
                        Rectangle()
                            .fill(.quaternary.opacity(0.3))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let hourTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                        onTap(hourTime)
                    }
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        let hourTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                        return handleTimeslotDrop(providers: providers, at: hourTime)
                    }
            }
        }
    }
    
    private func hourBackgroundColor(for hour: Int) -> Color {
        AstronomicalTimeCalculator.shared.getTimeColor(for: hour, date: selectedDate)
    }
    
    @ViewBuilder
    private func currentTimeIndicator(for hour: Int) -> some View {
        if isCurrentHour(hour) {
            let now = Date()
            let minute = calendar.component(.minute, from: now)
            let offsetY = CGFloat(minute) // 1 pixel per minute
            
            HStack(spacing: 8) {
                Rectangle()
                    .fill(.blue)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .opacity(0.8)
                    .shadow(color: .blue, radius: 1)
                
                Text("now")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .opacity(0.9)
            }
            .offset(y: offsetY)
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        return calendar.component(.hour, from: Date()) == hour &&
               calendar.isDate(selectedDate, inSameDayAs: Date())
    }
    
    private func handleTimeslotDrop(providers: [NSItemProvider], at time: Date) -> Bool {
        for provider in providers {
            provider.loadObject(ofClass: NSString.self) { item, error in
                if let payload = item as? String, error == nil {
                    DispatchQueue.main.async {
                        self.processDroppedItem(payload: payload, at: time)
                    }
                }
            }
        }
        return true
    }
    
    private func processDroppedItem(payload: String, at time: Date) {
        // Handle backfill template drops
        if payload.hasPrefix("backfill_template:") {
            let parts = payload.dropFirst("backfill_template:".count).components(separatedBy: "|")
            if parts.count >= 5 {
                let title = parts[0]
                let duration = TimeInterval(Int(parts[1]) ?? 3600)
                let energy = EnergyType(rawValue: parts[2]) ?? .daylight
                let emoji = parts[3]
                
                // Create enhanced title with AI context
                let enhancedTitle = aiService.enhanceEventTitle(originalTitle: title, time: time, duration: duration)
                
                let newBlock = TimeBlock(
                    title: enhancedTitle,
                    startTime: time,
                    duration: duration,
                    energy: energy,
                    emoji: emoji
                )
                
                dataManager.addTimeBlock(newBlock)
            }
        }
        // Handle todo item drops
        else if payload.hasPrefix("todo_item:") {
            let parts = payload.dropFirst("todo_item:".count).components(separatedBy: "|")
            if parts.count >= 4 {
                let title = parts[0]
                let _ = parts[1] // UUID - we don't need it for the time block
                let dueDateString = parts[2]
                let isCompleted = Bool(parts[3]) ?? false
                
                // Don't create time blocks for completed todos
                guard !isCompleted else { return }
                
                // Create enhanced title with AI context
                let enhancedTitle = aiService.enhanceEventTitle(originalTitle: title, time: time, duration: 3600)
                
                let newBlock = TimeBlock(
                    title: enhancedTitle,
                    startTime: time,
                    duration: 3600, // Default 1 hour for todo items
                    energy: .daylight,
                    emoji: "📝"
                )
                
                dataManager.addTimeBlock(newBlock)
            }
        }
    }
    
    struct PreciseEventCard: View {
    let block: TimeBlock
    let selectedDate: Date
    let dayStartHour: Int
    let minuteHeight: CGFloat
    let isDragged: Bool
    let allBlocks: [TimeBlock]
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingDetails = false
    @State private var isHovering = false
    @State private var activeGapContext: GapEdgeContext?
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            HStack(spacing: 8) {
                // Energy and flow indicators
                VStack(spacing: 1) {
                    Text(block.energy.rawValue)
                        .font(.caption)
                    Text(block.emoji)
                        .font(.caption2)
                }
                .opacity(0.8)
                .frame(width: 25)
                
                // Block content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if !block.emoji.isEmpty {
                            Text(block.emoji)
                                .font(.caption)
                        }
                        
                        Text(block.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(durationBasedLineLimit)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        Text(block.startTime.preciseTwoLineTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        Text("\(block.durationMinutes)m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Simplified hover info
                        if isHovering && !isDragging {
                            Text("Tap for details")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .italic()
                        }
                        
                        // Info icon
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.blue.opacity(0.6))
                    }
                    
                    // Show end time for longer events
                    if block.durationMinutes >= 45 {
                        Text("→ \(block.endTime.preciseTwoLineTime)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if linkedGoal != nil || linkedPillar != nil {
                        HStack(spacing: 6) {
                            if let goal = linkedGoal {
                                connectionBadge(title: goal.title, color: .blue, systemImage: "target")
                            }
                            if let pillar = linkedPillar {
                                connectionBadge(title: pillar.name, color: .purple, systemImage: "building.columns")
                            }
                            Spacer()
                        }
                    }
                }
                
                Spacer()
                
                // Glass state indicator
                Circle()
                    .fill(stateColor)
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(height: eventHeight, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            borderColor, 
                            style: StrokeStyle(
                                lineWidth: 1
                            )
                        )
                )
        )
        .scaleEffect(isDragging ? 0.98 : 1.0)
        .offset(x: dragOffset.width, y: dragOffset.height + yPosition)
        .overlay(alignment: .leading) {
            if showLeadingGapButton {
                gapEdgeButton(for: .leading)
                    .offset(x: -18, y: edgeButtonVerticalOffset)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .trailing) {
            if showTrailingGapButton {
                gapEdgeButton(for: .trailing)
                    .offset(x: 18, y: edgeButtonVerticalOffset)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            if block.confirmationState == .confirmed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(6)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                    }
                    dragOffset = value.translation
                    onDrag(value.location)
                }
                .onEnded { value in
                    isDragging = false
                    dragOffset = .zero
                    
                    let newTime = calculateNewTime(from: value.translation)
                    onDrop(newTime)
                }
        )
        .sheet(item: $activeGapContext) { context in
            BlockCreationSheet(
                suggestedTime: context.startTime,
                initialTitle: defaultTitle(for: context),
                initialEnergy: block.energy,
                initialEmoji: block.emoji.isEmpty ? "🌊" : block.emoji,
                initialDuration: context.clampedInitialDuration,
                minimumDurationMinutes: context.minimumDurationMinutes,
                maxDurationMinutes: context.maximumDurationMinutes
            ) { newBlock in
                var createdBlock = newBlock
                createdBlock.startTime = context.startTime
                let clampedMinutes = context.clampDurationMinutes(newBlock.durationMinutes)
                createdBlock.duration = TimeInterval(clampedMinutes * 60)
                createdBlock.glassState = .mist
                dataManager.addTimeBlock(createdBlock)
                activeGapContext = nil
            }
        }
        .sheet(isPresented: $showingDetails) {
            NoFlashEventDetailsSheet(
                block: block,
                allBlocks: allBlocks,
                onSave: { updatedBlock in
                    dataManager.updateTimeBlock(updatedBlock)
                    showingDetails = false
                },
                onDelete: {
                    dataManager.removeTimeBlock(block.id)
                    showingDetails = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }
    
    // MARK: - Precise Positioning
    
    private var yPosition: CGFloat {
        // Calculate exact Y position based on start time
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayStartTime = calendar.date(byAdding: .hour, value: dayStartHour, to: dayStart) ?? dayStart
        let totalMinutesFromStart = block.startTime.timeIntervalSince(dayStartTime) / 60
        return CGFloat(totalMinutesFromStart) * minuteHeight
    }
    
    private var eventHeight: CGFloat {
        // Height exactly proportional to duration
        CGFloat(block.durationMinutes) * minuteHeight
    }
    
    private var durationBasedLineLimit: Int {
        switch block.durationMinutes {
        case 0..<30: return 1
        case 30..<90: return 2
        default: return 3
        }
    }
    
    private var stateColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue
        case .mist: return .orange
        case .crystal: return .cyan
        }
    }
    
    private var borderColor: Color {
        switch block.glassState {
        case .solid: return .clear
        case .liquid: return .blue.opacity(0.6)
        case .mist: return .orange.opacity(0.5)
        case .crystal: return .cyan.opacity(0.7)
        }
    }
    
    private var linkedGoal: Goal? {
        dataManager.appState.goals.first { $0.id == block.relatedGoalId }
    }
    
    private var linkedPillar: Pillar? {
        dataManager.appState.pillars.first { $0.id == block.relatedPillarId }
    }
    
    private func connectionBadge(title: String, color: Color, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }
    
    private func calculateNewTime(from translation: CGSize) -> Date {
        // Precise time calculation using minute height
        let minuteChange = Int(translation.height / minuteHeight)
        let newTime = calendar.date(byAdding: .minute, value: minuteChange, to: block.startTime) ?? block.startTime
        
        // Round to nearest 15-minute interval for clean scheduling
        let minute = calendar.component(.minute, from: newTime)
        let roundedMinute = (minute / 15) * 15
        
        return calendar.date(bySettingHour: calendar.component(.hour, from: newTime), 
                           minute: roundedMinute, 
                           second: 0, 
                           of: newTime) ?? newTime
    }

    private var edgeButtonVerticalOffset: CGFloat {
        max(0, eventHeight / 2 - 12)
    }

    private var showLeadingGapButton: Bool {
        isHovering && !isDragging && leadingGapContext != nil
    }
    
    private var showTrailingGapButton: Bool {
        isHovering && !isDragging && trailingGapContext != nil
    }
    
    private var sortedBlocks: [TimeBlock] {
        allBlocks.sorted { $0.startTime < $1.startTime }
    }
    
    private var blockIndex: Int? {
        sortedBlocks.firstIndex(where: { $0.id == block.id })
    }
    
    private var previousBlock: TimeBlock? {
        guard let index = blockIndex, index > 0 else { return nil }
        return sortedBlocks[index - 1]
    }
    
    private var nextBlock: TimeBlock? {
        guard let index = blockIndex, index < sortedBlocks.count - 1 else { return nil }
        return sortedBlocks[index + 1]
    }
    
    private var timelineStart: Date {
        let dayStart = calendar.startOfDay(for: selectedDate)
        return calendar.date(byAdding: .hour, value: dayStartHour, to: dayStart) ?? dayStart
    }
    
    private var timelineEnd: Date {
        calendar.date(byAdding: .day, value: 1, to: timelineStart) ?? timelineStart.addingTimeInterval(24 * 3600)
    }
    
    private var leadingGapContext: GapEdgeContext? {
        let previousEnd = previousBlock?.endTime ?? timelineStart
        let start = max(previousEnd, timelineStart)
        let end = block.startTime
        let duration = end.timeIntervalSince(start)
        guard duration >= 600 else { return nil }
        return GapEdgeContext(edge: .leading, startTime: start, duration: duration)
    }
    
    private var trailingGapContext: GapEdgeContext? {
        let start = block.endTime
        let nextStart = nextBlock?.startTime ?? timelineEnd
        let end = min(nextStart, timelineEnd)
        let duration = end.timeIntervalSince(start)
        guard duration >= 600 else { return nil }
        return GapEdgeContext(edge: .trailing, startTime: start, duration: duration)
    }
    
    private func gapEdgeButton(for edge: GapEdgeContext.Edge) -> some View {
        Button {
            openGapEditor(for: edge)
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .help(edge == .leading ? "Plan something before this block" : "Plan something after this block")
    }
    
    private func openGapEditor(for edge: GapEdgeContext.Edge) {
        switch edge {
        case .leading:
            activeGapContext = leadingGapContext
        case .trailing:
            activeGapContext = trailingGapContext
        }
    }
    
    private func defaultTitle(for context: GapEdgeContext) -> String {
        switch context.edge {
        case .leading:
            return "Prep: \(block.title)"
        case .trailing:
            return "Wrap: \(block.title)"
        }
    }

}

fileprivate struct GapEdgeContext: Identifiable {
    enum Edge {
        case leading
        case trailing
    }
    let id = UUID()
    let edge: Edge
    let startTime: Date
    let duration: TimeInterval
    
    var maximumDurationMinutes: Int {
        max(10, Int(duration / 60))
    }

    var minimumDurationMinutes: Int {
        10
    }
    
    var clampedInitialDuration: Int {
        maximumDurationMinutes
    }
    
    func clampDurationMinutes(_ minutes: Int) -> Int {
        max(minimumDurationMinutes, min(minutes, maximumDurationMinutes))
    }
}
