//
//  TodayGlass.swift
//  DayPlanner
//
//  The main three-panel today view with liquid glass time periods
//

import SwiftUI

// MARK: - Today Glass Main View

/// The primary surface showing today's schedule in three translucent time panels
struct TodayGlass: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var selectedPeriod: TimePeriod? = nil
    @State private var draggedBlock: TimeBlock? = nil
    @State private var showingBlockCreation = false
    @State private var creationLocation: CGPoint = .zero
    @State private var selectedBlock: TimeBlock? = nil
    @State private var showingBlockDetails = false
    @State private var showingChainCreation = false
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 16) {
                // Morning Mist Panel (6am - 12pm)
                TimePeriodPanel(
                    period: .morning,
                    blocks: dataManager.appState.currentDay.morningBlocks,
                    isSelected: selectedPeriod == .morning,
                    onBlockTap: handleBlockTap,
                    onBlockDrag: handleBlockDrag,
                    onPanelTap: { location in
                        handlePanelTap(period: .morning, location: location)
                    }
                )
                
                // Afternoon Flow Panel (12pm - 6pm)
                TimePeriodPanel(
                    period: .afternoon,
                    blocks: dataManager.appState.currentDay.afternoonBlocks,
                    isSelected: selectedPeriod == .afternoon,
                    onBlockTap: handleBlockTap,
                    onBlockDrag: handleBlockDrag,
                    onPanelTap: { location in
                        handlePanelTap(period: .afternoon, location: location)
                    }
                )
                
                // Evening Glow Panel (6pm - 12am)
                TimePeriodPanel(
                    period: .evening,
                    blocks: dataManager.appState.currentDay.eveningBlocks,
                    isSelected: selectedPeriod == .evening,
                    onBlockTap: handleBlockTap,
                    onBlockDrag: handleBlockDrag,
                    onPanelTap: { location in
                        handlePanelTap(period: .evening, location: location)
                    }
                )
            }
            .padding(20)
        }
        .background(
            TimeGradient(currentHour: Date().hour)
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showingBlockDetails) {
            if let block = selectedBlock {
                EventDetailSheet(
                    block: block,
                    onUpdate: { updatedBlock in
                        dataManager.updateTimeBlock(updatedBlock)
                    },
                    onDelete: {
                        dataManager.removeTimeBlock(block.id)
                        showingBlockDetails = false
                    },
                    onCreateChain: {
                        selectedBlock = block
                        showingBlockDetails = false
                        showingChainCreation = true
                    }
                )
            }
        }
        .sheet(isPresented: $showingChainCreation) {
            if let block = selectedBlock {
                ChainCreationFromBlock(
                    sourceBlock: block,
                    onCreate: { chain in
                        dataManager.addChain(chain)
                        showingChainCreation = false
                    }
                )
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleBlockTap(_ block: TimeBlock) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedPeriod = block.period
            selectedBlock = block
            showingBlockDetails = true
        }
    }
    
    private func handleBlockDrag(_ block: TimeBlock, location: CGPoint) {
        draggedBlock = block
        
        // Enhanced drag handling with better time calculation
        let _ = calculateTimeFromDragLocation(location, in: block.period)
        
        // Update block position for visual feedback
        var updatedBlock = block
        updatedBlock.position = location
        updatedBlock.glassState = .liquid // Show liquid state while dragging
        dataManager.updateTimeBlock(updatedBlock)
        
        // Block moved successfully
        dataManager.save()
    }
    
    private func handleBlockDrop(_ block: TimeBlock, location: CGPoint) {
        // Calculate the new time based on drop location
        let newTime = calculateTimeFromDragLocation(location, in: block.period)
        
        // Update the block with new timing
        var updatedBlock = block
        updatedBlock.startTime = newTime
        updatedBlock.glassState = .solid // Return to solid state
        updatedBlock.position = .zero // Reset position
        dataManager.updateTimeBlock(updatedBlock)
        
        // Clear dragged state
        draggedBlock = nil
        
        // Confirm the change
        dataManager.save()
    }
    
    private func calculateTimeFromDragLocation(_ location: CGPoint, in period: TimePeriod) -> Date {
        // More sophisticated time calculation
        let calendar = Calendar.current
        var startHour: Int
        
        switch period {
        case .morning:
            startHour = 6
        case .afternoon:
            startHour = 12
        case .evening:
            startHour = 18
        }
        
        // Estimate position within panel (assuming 400pt height for 6 hours)
        let normalizedY = max(0, min(1, location.y / 400))
        let hourOffset = Int(6.0 * normalizedY)
        let minuteOffset = Int((6.0 * normalizedY - Double(hourOffset)) * 60)
        
        let targetHour = startHour + hourOffset
        let targetMinute = (minuteOffset / 15) * 15 // Round to nearest 15 minutes
        
        let now = Date()
        return calendar.date(bySettingHour: targetHour, minute: targetMinute, second: 0, of: now) ?? now
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func handlePanelTap(period: TimePeriod, location: CGPoint) {
        creationLocation = location
        
        showingBlockCreation = true
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            selectedPeriod = period
        }
    }
    
    private func calculateTimeFromLocation(location: CGPoint, period: TimePeriod) -> Date {
        // Estimate time based on vertical position in panel
        let normalizedY = max(0, min(1, location.y / 400)) // Assuming ~400pt panel height
        
        var startHour: Int
        let totalHours: Int = 6
        
        switch period {
        case .morning:
            startHour = 6
        case .afternoon:
            startHour = 12
        case .evening:
            startHour = 18
        }
        
        let targetHour = startHour + Int(Double(totalHours) * normalizedY)
        let calendar = Calendar.current
        let now = Date()
        
        return calendar.date(bySettingHour: targetHour, minute: 0, second: 0, of: now) ?? now
    }
    
    private func timeForLocation(_ location: CGPoint) -> Date {
        // Convert tap location to time - simplified for now
        let hour = Int(6 + (location.y / 50)) // Rough calculation
        return Date().setting(hour: min(max(hour, 6), 23)) ?? Date()
    }
}

// MARK: - Time Period Panel

/// Individual time period panel (Morning, Afternoon, Evening)
struct TimePeriodPanel: View {
    let period: TimePeriod
    let blocks: [TimeBlock]
    let isSelected: Bool
    let onBlockTap: (TimeBlock) -> Void
    let onBlockDrag: (TimeBlock, CGPoint) -> Void
    let onPanelTap: (CGPoint) -> Void
    
    @State private var hoverLocation: CGPoint = .zero
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Panel header
            PanelHeader(period: period, blockCount: blocks.count)
            
            // Time blocks container
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(blocks) { block in
                        TimeBlockCard(
                            block: block,
                            onTap: { onBlockTap(block) },
                            onDrag: { location in
                                onBlockDrag(block, location)
                            }
                        )
                    }
                    
                    // Empty space indicator
                    if blocks.isEmpty {
                        EmptyPeriodView(period: period)
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollDisabled(false) // Allow scrolling in panels - they have fewer conflicts
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .background(
            PanelBackgroundView(
                period: period,
                isSelected: isSelected,
                isHovering: isHovering
            )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.3)) {
                isHovering = hovering
            }
        }
        .onTapGesture { location in
            onPanelTap(location)
        }
    }
}

// MARK: - Panel Header

/// Header for each time period panel
struct PanelHeader: View {
    let period: TimePeriod
    let blockCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(period.rawValue)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Block count indicator
                if blockCount > 0 {
                    Text("\(blockCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            
            Text(period.timeRange)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Time Block Card

/// Individual time block within a panel
struct TimeBlockCard: View {
    let block: TimeBlock
    let onTap: () -> Void
    let onDrag: (CGPoint) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isHovering = false
    @State private var showContextMenu = false
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Enhanced Energy & Flow indicators with descriptions
            VStack(spacing: 4) {
                Text(block.energy.rawValue)
                    .font(.title2)
                Text(block.emoji)
                    .font(.title3)
                
                if isHovering {
                    Text(block.energy.description)
                        .font(.caption2)
                        .foregroundColor(block.energy.color)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .frame(width: 60, alignment: .center)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(block.energy.color.opacity(isHovering ? 0.15 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(block.energy.color.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Enhanced Block content with more details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(block.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                }
                
                HStack(spacing: 8) {
                    Label(timeString(from: block.startTime), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(block.durationMinutes) min", systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Show period indicator
                    Text(block.period.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(block.period.tint.opacity(0.2))
                        .foregroundColor(block.period.tint)
                        .cornerRadius(4)
                }
                
            }
            
            Spacer()
            
            // Action buttons and indicators (show on hover)
            VStack(spacing: 4) {
                // Glass state indicator (always visible)
                Circle()
                    .fill(stateColor)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                    )
                    .help(stateDescription)
                
                // Quick action buttons (show on hover)
                if isHovering && !isDragging {
                    VStack(spacing: 2) {
                        Button(action: onTap) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("View details")
                        
                        Button(action: { 
                            // Quick duration adjustment
                            quickAdjustDuration(by: 15) 
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                        .help("Add 15 minutes")
                        
                        Button(action: { 
                            quickAdjustDuration(by: -15) 
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Remove 15 minutes")
                        
                        Menu {
                            Button("Edit Details", action: onTap)
                            Button("Duplicate") { duplicateEvent() }
                            Divider()
                            Button("Delete", role: .destructive) { deleteEvent() }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .help("More options")
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
        }
        .padding(12)
        .background(
            EnhancedBlockBackgroundView(
                block: block,
                isDragging: isDragging,
                isHovering: isHovering
            )
        )
        .overlay(
            // Resize handles (show on hover)
            VStack {
                Spacer()
                if isHovering && !isDragging {
                    HStack {
                        Spacer()
                        ResizeHandle(
                            onDrag: { translation in
                                handleResize(translation: translation)
                            }
                        )
                    }
                }
            }
        )
        .scaleEffect(isDragging ? 0.95 : (isHovering ? 1.02 : 1.0))
        .offset(dragOffset)
        .shadow(
            color: .black.opacity(isDragging ? 0.2 : (isHovering ? 0.1 : 0.05)),
            radius: isDragging ? 12 : (isHovering ? 6 : 3),
            x: 0,
            y: isDragging ? 8 : (isHovering ? 4 : 2)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture { onTap() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                .onChanged { value in
                    // Enhanced drag detection
                    let isVerticalDrag = abs(value.translation.height) > abs(value.translation.width * 0.5)
                    guard isVerticalDrag else { return }
                    
                    if !isDragging {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isDragging = true
                            isHovering = false // Hide hover state while dragging
                        }
                    }
                    
                    // Enhanced movement with better constraints
                    let constrainedTranslation = CGSize(
                        width: value.translation.width * 0.1, // Minimal horizontal movement
                        height: max(-300, min(300, value.translation.height))
                    )
                    dragOffset = constrainedTranslation
                    onDrag(value.location)
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isDragging = false
                        dragOffset = .zero
                    }
                }
        )
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDragging)
    }
    
    private var stateColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue
        case .mist: return .gray
        case .crystal: return .cyan
        }
    }
    
    private var stateDescription: String {
        switch block.glassState {
        case .solid: return "Committed event"
        case .liquid: return "Event in progress"
        case .mist: return "Suggested event"
        case .crystal: return "AI-created event"
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func quickAdjustDuration(by minutes: Int) {
        var updatedBlock = block
        let newDuration = max(15 * 60, updatedBlock.duration + TimeInterval(minutes * 60)) // Minimum 15 minutes
        updatedBlock.duration = newDuration
        dataManager.updateTimeBlock(updatedBlock)
    }
    
    private func duplicateEvent() {
        var duplicatedBlock = block
        duplicatedBlock.id = UUID()
        duplicatedBlock.title = "\(block.title) (Copy)"
        duplicatedBlock.startTime = block.endTime // Schedule right after original
        dataManager.addTimeBlock(duplicatedBlock)
    }
    
    private func deleteEvent() {
        dataManager.removeTimeBlock(block.id)
    }
    
    private func handleResize(translation: CGSize) {
        // Convert vertical translation to duration adjustment
        let durationAdjustment = TimeInterval((translation.height / 5)) * 60 // 5pt per minute
        let newDuration = max(15 * 60, block.duration + durationAdjustment) // Minimum 15 minutes
        
        if abs(newDuration - block.duration) >= 60 { // Only update if change is at least 1 minute
            var updatedBlock = block
            updatedBlock.duration = newDuration
            dataManager.updateTimeBlock(updatedBlock)
        }
    }
}

// MARK: - Resize Handle

/// Draggable handle for resizing events
struct ResizeHandle: View {
    let onDrag: (CGSize) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.secondary)
            .frame(width: 20, height: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.5))
                    .frame(width: 12, height: 2)
            )
            .scaleEffect(isDragging ? 1.2 : 1.0)
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                isDragging = true
                            }
                        }
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                        onDrag(value.translation)
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isDragging = false
                            dragOffset = .zero
                        }
                    }
            )
            .help("Drag to adjust duration")
    }
}

// MARK: - Background Views

/// Panel background with period-specific glass effects
struct PanelBackgroundView: View {
    let period: TimePeriod
    let isSelected: Bool
    let isHovering: Bool
    
    var body: some View {
        ZStack {
            // Base glass material
            RoundedRectangle(cornerRadius: 16)
                .fill(period.tint.opacity(0.1))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            // Selection highlight
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(period.tint, lineWidth: 2)
            }
            
            // Hover effect
            if isHovering {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.05))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}

/// Enhanced time block background with comprehensive visual states
struct EnhancedBlockBackgroundView: View {
    let block: TimeBlock
    let isDragging: Bool
    let isHovering: Bool
    
    var body: some View {
        ZStack {
            // Base material layer
            RoundedRectangle(cornerRadius: 12)
                .fill(baseMaterial)
            
            // Energy color accent (subtle)
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            block.energy.color.opacity(0.15),
                            block.energy.color.opacity(0.05),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // State-specific overlay
            if isDragging {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.primary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.primary.opacity(0.3), lineWidth: 2)
                    )
            } else if isHovering {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(hoverBorderColor, lineWidth: 1.5)
                    )
            }
            
            // Glass state border
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    borderColor,
                    style: borderStyle
                )
        }
    }
    
    private var baseMaterial: Material {
        if isDragging {
            return .regularMaterial
        } else if isHovering {
            return .ultraThinMaterial
        } else {
            return .regularMaterial // Default material since flow was replaced with emoji
        }
    }
    
    private var hoverBorderColor: Color {
        if isHovering {
            return block.energy.color.opacity(0.6)
        }
        return .clear
    }
    
    private var borderColor: Color {
        switch block.glassState {
        case .solid: 
            return isHovering ? .green.opacity(0.4) : .clear
        case .liquid: 
            return .blue.opacity(isDragging ? 0.8 : 0.6)
        case .mist: 
            return .gray.opacity(isDragging ? 0.7 : 0.5)
        case .crystal: 
            return .cyan.opacity(isDragging ? 0.9 : 0.7)
        }
    }
    
    private var borderStyle: StrokeStyle {
        switch block.glassState {
        case .solid: 
            return StrokeStyle(lineWidth: isHovering ? 1 : 0)
        case .liquid: 
            return StrokeStyle(lineWidth: isDragging ? 3 : 2)
        case .mist: 
            return StrokeStyle(lineWidth: isDragging ? 2 : 1, dash: [4, 4])
        case .crystal: 
            return StrokeStyle(lineWidth: isDragging ? 2.5 : 1.5)
        }
    }
}

// MARK: - Empty State

/// Enhanced empty period indicator with chain suggestions
struct EmptyPeriodView: View {
    let period: TimePeriod
    @State private var isHovering = false
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Period-specific icon
            Text(periodIcon)
                .font(.largeTitle)
                .opacity(isHovering ? 0.8 : 0.5)
            
            VStack(spacing: 4) {
                Text("Your \(period.rawValue.lowercased()) is open")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Tap anywhere to add activities")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Show chain suggestions when hovering
            if isHovering && !availableChains.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Or try these chains:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(availableChains.prefix(2)), id: \.id) { chain in
                        Button(action: {
                            applyChain(chain)
                        }) {
                            HStack(spacing: 6) {
                                Text(chain.flowPattern.emoji)
                                    .font(.caption2)
                                Text(chain.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(chain.totalDurationMinutes)min")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.blue.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isHovering && !availableChains.isEmpty ? 140 : 100)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(period.tint.opacity(isHovering ? 0.1 : 0.05))
                .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    period.tint.opacity(isHovering ? 0.4 : 0.2), 
                    style: StrokeStyle(lineWidth: 1, dash: [8, 8])
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.3)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isHovering)
    }
    
    private var periodIcon: String {
        switch period {
        case .morning: return "🌅"
        case .afternoon: return "☀️"
        case .evening: return "🌙"
        }
    }
    
    private var availableChains: [Chain] {
        dataManager.appState.recentChains.filter { chain in
            chain.isActive && !chain.blocks.isEmpty
        }
    }
    
    private func applyChain(_ chain: Chain) {
        // Apply the chain to this time period
        let baseTime = Date()
        var currentTime = baseTime
        
        for block in chain.blocks {
            var newBlock = block
            newBlock.id = UUID()
            newBlock.startTime = currentTime
            dataManager.addTimeBlock(newBlock)
            currentTime = newBlock.endTime
        }
        
        // Chain applied successfully
        dataManager.save()
    }
}


// MARK: - Event Detail Sheet

/// Comprehensive event details and editing interface
struct EventDetailSheet: View {
    let block: TimeBlock
    let onUpdate: (TimeBlock) -> Void
    let onDelete: () -> Void
    let onCreateChain: () -> Void
    
    @State private var editedBlock: TimeBlock
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    init(block: TimeBlock, onUpdate: @escaping (TimeBlock) -> Void, onDelete: @escaping () -> Void, onCreateChain: @escaping () -> Void) {
        self.block = block
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onCreateChain = onCreateChain
        self._editedBlock = State(initialValue: block)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with visual indicators
                    EventHeaderSection(block: editedBlock)
                    
                    // Basic Information
                    EventBasicInfoSection(block: $editedBlock)
                    
                    // Timing Section
                    EventTimingSection(block: $editedBlock)
                    
                    // Properties Section
                    EventPropertiesSection(block: $editedBlock)
                    
                    // Chain Actions Section
                    EventChainActionsSection(onCreateChain: onCreateChain)
                    
                    // Danger Zone
                    EventDangerZoneSection(onDelete: {
                        showingDeleteConfirmation = true
                    })
                }
                .padding(20)
            }
            .navigationTitle("Event Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onUpdate(editedBlock)
                        dismiss()
                    }
                    .disabled(editedBlock.title.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 800)
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(block.title)'? This action cannot be undone.")
        }
    }
}

// MARK: - Event Detail Sections

struct EventHeaderSection: View {
    let block: TimeBlock
    
    var body: some View {
        HStack(spacing: 16) {
            // Large energy/flow indicators
            VStack(spacing: 8) {
                Text(block.energy.rawValue)
                    .font(.title)
                Text(block.energy.description)
                    .font(.caption)
                    .foregroundColor(block.energy.color)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(block.energy.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(block.energy.color.opacity(0.3))
                    )
            )
            
            VStack(spacing: 8) {
                Text(block.emoji)
                    .font(.title)
                Text("Flow") // Placeholder since flow was replaced with emoji
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.3)) // Default material since flow was replaced with emoji
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.secondary.opacity(0.2))
                    )
            )
            
            // Glass state indicator
            VStack(spacing: 8) {
                Circle()
                    .fill(glassStateColor)
                    .frame(width: 24, height: 24)
                Text(glassStateDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.secondary.opacity(0.2))
                    )
            )
        }
    }
    
    private var glassStateColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue
        case .mist: return .gray
        case .crystal: return .cyan
        }
    }
    
    private var glassStateDescription: String {
        switch block.glassState {
        case .solid: return "Committed"
        case .liquid: return "In Progress"
        case .mist: return "Suggested"
        case .crystal: return "AI Created"
        }
    }
}

struct EventBasicInfoSection: View {
    @Binding var block: TimeBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Event Information")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Title:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    TextField("Event title", text: $block.title)
                        .textFieldStyle(.roundedBorder)
                }
                
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.5))
            )
        }
    }
}

struct EventTimingSection: View {
    @Binding var block: TimeBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timing")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Start:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    DatePicker("Start time", selection: $block.startTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                
                HStack {
                    Text("Duration:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Stepper("\(block.durationMinutes) minutes", 
                           value: Binding(
                               get: { block.durationMinutes },
                               set: { newValue in 
                                   block.duration = TimeInterval(newValue * 60)
                               }
                           ),
                           in: 5...480,
                           step: 15)
                }
                
                HStack {
                    Text("Ends:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Text(formatTime(block.endTime))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.5))
            )
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EventPropertiesSection: View {
    @Binding var block: TimeBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Properties")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Energy Type Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Energy Level")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(EnergyType.allCases, id: \.self) { energy in
                            Button(action: {
                                block.energy = energy
                            }) {
                                VStack(spacing: 4) {
                                    Text(energy.rawValue)
                                        .font(.title2)
                                    Text(energy.description)
                                        .font(.caption2)
                                        .foregroundColor(energy.color)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(block.energy == energy ? energy.color.opacity(0.2) : .clear)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(
                                                    block.energy == energy ? energy.color : .secondary.opacity(0.3),
                                                    lineWidth: block.energy == energy ? 2 : 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Emoji Selection (replaces Flow State)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Visual Identifier")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        let commonEmojis = ["🎯", "💡", "📚", "🏃‍♂️", "🧘‍♀️", "🎨", "💻", "📞"]
                        ForEach(commonEmojis, id: \.self) { emoji in
                            Button(action: {
                                block.emoji = emoji
                            }) {
                                Text(emoji)
                                    .font(.title2)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(block.emoji == emoji ? .blue.opacity(0.2) : .clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(
                                                        block.emoji == emoji ? .blue : .secondary.opacity(0.3),
                                                        lineWidth: block.emoji == emoji ? 2 : 1
                                                    )
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.5))
            )
        }
    }
}

struct EventChainActionsSection: View {
    let onCreateChain: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chain Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                Button(action: onCreateChain) {
                    HStack {
                        Image(systemName: "link")
                        Text("Create Chain from Event")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.blue.opacity(0.3))
                            )
                    )
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Create a chain to group related activities together")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.5))
            )
        }
    }
}

struct EventDangerZoneSection: View {
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Danger Zone")
                .font(.headline)
                .foregroundColor(.red)
            
            Button(action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Event")
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.red.opacity(0.3))
                        )
                )
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.5))
        )
    }
}

// MARK: - Chain Creation from Block

struct ChainCreationFromBlock: View {
    let sourceBlock: TimeBlock
    let onCreate: (Chain) -> Void
    
    @State private var chainName = ""
    @State private var selectedPattern: FlowPattern = .waterfall
    @State private var additionalBlocks: [TimeBlock] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chain Name")
                        .font(.headline)
                    
                    TextField("Enter chain name", text: $chainName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Starting with: \(sourceBlock.title)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Text("This event will be the first activity in your chain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.blue.opacity(0.1))
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flow Pattern")
                        .font(.headline)
                    
                    Picker("Pattern", selection: $selectedPattern) {
                        ForEach(FlowPattern.allCases, id: \.self) { pattern in
                            Text(pattern.description).tag(pattern)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(flowPatternDescription(selectedPattern))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Create Chain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newChain = Chain(
                            name: chainName,
                            blocks: [sourceBlock] + additionalBlocks,
                            flowPattern: selectedPattern
                        )
                        onCreate(newChain)
                        dismiss()
                    }
                    .disabled(chainName.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            chainName = "\(sourceBlock.title) Chain"
        }
    }
    
    private func flowPatternDescription(_ pattern: FlowPattern) -> String {
        switch pattern {
        case .waterfall: return "Activities cascade smoothly from one to the next"
        case .spiral: return "Activities follow a circular flow, building energy"
        case .ripple: return "Activities create expanding waves of energy"
        case .wave: return "Activities rise and fall in intensity naturally"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TodayGlass_Previews: PreviewProvider {
    static var previews: some View {
        TodayGlass()
            .frame(width: 1200, height: 800)
    }
}
#endif

