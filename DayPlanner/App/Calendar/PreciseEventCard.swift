// MARK: - Fixed Position Event Card (Proper Layout)

import SwiftUI

struct FixedPositionEventCard: View {
    let block: TimeBlock
    let selectedDate: Date
    let dayStartHour: Int
    let isDragged: Bool
    let allBlocks: [TimeBlock]
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingDetails = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Spacer to push event to correct vertical position
            Spacer()
                .frame(height: topSpacerHeight)
            
            // Event card with proper layout (no absolute positioning)
            Button(action: { 
                showingDetails = true // No animation to prevent flashing
            }) {
                HStack(spacing: 8) {
                    // Energy and flow indicators  
                    VStack(spacing: 2) {
                        Text(block.energy.rawValue)
                            .font(.caption)
                        Text(block.emoji)
                            .font(.caption)
                    }
                    .opacity(0.8)
                    .frame(width: 25)
                    
                    // Block content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(durationBasedLineLimit)
                        
                        HStack(spacing: 4) {
                            Text(block.startTime.timeString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            
                            Text("\(block.durationMinutes)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            // Improved arrow that's not buggy
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.blue.opacity(0.6))
                        }
                        
                        // Show end time for longer events
                        if block.durationMinutes >= 60 {
                            Text("→ \(block.endTime.timeString)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
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
            .padding(.vertical, durationBasedPadding)
            .frame(height: eventHeight, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial.opacity(0.9))
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
            .offset(dragOffset)
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
            .sheet(isPresented: $showingDetails) {
                // Fixed event details sheet
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
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var eventHeight: CGFloat {
        // Height proportional to duration with minimum
        max(30, CGFloat(block.durationMinutes))
    }
    
    private var topSpacerHeight: CGFloat {
        // Calculate minutes from day start (6 AM) to event start
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayStartTime = calendar.date(byAdding: .hour, value: dayStartHour, to: dayStart) ?? dayStart
        let minutesFromDayStart = block.startTime.timeIntervalSince(dayStartTime) / 60
        return max(0, CGFloat(minutesFromDayStart))
    }
    
    private var durationBasedLineLimit: Int {
        switch block.durationMinutes {
        case 0..<30: return 1
        case 30..<90: return 2
        default: return 3
        }
    }
    
    private var durationBasedPadding: CGFloat {
        switch block.durationMinutes {
        case 0..<30: return 4
        case 30..<60: return 6
        default: return 8
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
    
    private func calculateNewTime(from translation: CGSize) -> Date {
        let minuteChange = Int(translation.height) // 1 pixel = 1 minute
        let newTime = calendar.date(byAdding: .minute, value: minuteChange, to: block.startTime) ?? block.startTime
        
        // Round to nearest 15-minute interval
        let minute = calendar.component(.minute, from: newTime)
        let roundedMinute = (minute / 15) * 15
        
        return calendar.date(bySettingHour: calendar.component(.hour, from: newTime), 
                           minute: roundedMinute, 
                           second: 0, 
                           of: newTime) ?? newTime
    }
}

// MARK: - Fixed Event Details Sheet (No NavigationView Issues)

struct FixedEventDetailsSheet: View {
    let block: TimeBlock
    let allBlocks: [TimeBlock]
    let onSave: (TimeBlock) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var editedBlock: TimeBlock
    @State private var activeTab: EventTab = .details
    @State private var showingDeleteConfirmation = false
    
    private let calendar = Calendar.current
    private let dayStartHour = 0
    
    init(block: TimeBlock, allBlocks: [TimeBlock], onSave: @escaping (TimeBlock) -> Void, onDelete: @escaping () -> Void) {
        self.block = block
        self.allBlocks = allBlocks
        self.onSave = onSave
        self.onDelete = onDelete
        self._editedBlock = State(initialValue: block)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Event Details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("✕") {
                    dismiss()
                }
                .font(.title3)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial.opacity(0.8))
            
            // Improved tab selector (no flashing)
            HStack(spacing: 4) {
                ForEach(EventTab.allCases, id: \.self) { tab in
                    Button(action: { activeTab = tab }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .medium))
                            
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(activeTab == tab ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(activeTab == tab ? .blue : .gray.opacity(0.2))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.4))
            
            // Tab content (no ScrollView to prevent conflicts)
            Group {
                switch activeTab {
                case .details:
                    EventDetailsTab(block: $editedBlock)
                case .connections:
                    EventConnectionsTab(block: $editedBlock)
                case .duration:
                    EventDurationTab(block: $editedBlock)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom actions
            HStack(spacing: 16) {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save Changes") {
                    onSave(editedBlock)
                }
                .buttonStyle(.borderedProminent)
                .disabled(editedBlock.title.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial.opacity(0.8))
        }
        .frame(width: 700, height: 600)
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 20)
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(block.title)'? This action cannot be undone.")
        }
    }
    
}

// MARK: - No Flash Event Details Sheet (Completely Static)

struct NoFlashEventDetailsSheet: View {
    let block: TimeBlock
    let allBlocks: [TimeBlock]
    let onSave: (TimeBlock) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var editedBlock: TimeBlock
    @State private var activeTab: EventTab = .details
    @State private var showingDeleteConfirmation = false
    
    private let calendar = Calendar.current
    
    init(block: TimeBlock, allBlocks: [TimeBlock], onSave: @escaping (TimeBlock) -> Void, onDelete: @escaping () -> Void) {
        self.block = block
        self.allBlocks = allBlocks
        self.onSave = onSave
        self.onDelete = onDelete
        self._editedBlock = State(initialValue: block)
    }
    
    var body: some View {
        // Fixed size container - no resizing, no flashing
        VStack(spacing: 0) {
            // Static header
            headerSection
            
            // Static tab selector - no animations
            staticTabSelector
            
            // Tab content without ScrollView (prevents layout conflicts)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            // Static bottom actions
            bottomActionsSection
        }
        .frame(width: 700, height: 600) // Fixed size - always fully expanded
        .background(.regularMaterial) // Solid background to prevent transparency flashing
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .transition(.identity) // No transition animations to prevent flashing
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete '\(block.title)'? This action cannot be undone.")
        }
    }
    
    // MARK: - Static Sections (No Animations)
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(block.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("Event Details")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("✕") {
                dismiss()
            }
            .font(.title3)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }
    
    private var staticTabSelector: some View {
        HStack(spacing: 3) {
            ForEach(EventTab.allCases, id: \.self) { tab in
                Button(action: { activeTab = tab }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(activeTab == tab ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40) // Fixed height
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(activeTab == tab ? .blue : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .details:
            StaticEventDetailsTab(block: $editedBlock)
        case .connections:
            EventConnectionsTab(block: $editedBlock)
        case .duration:
            StaticEventDurationTab(block: $editedBlock)
        }
    }
    
    private var bottomActionsSection: some View {
        HStack(spacing: 16) {
            Button("Delete", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            
            Button("Save Changes") {
                onSave(editedBlock)
            }
            .buttonStyle(.borderedProminent)
            .disabled(editedBlock.title.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }
    
}

// MARK: - Static Tab Components (No Flash Implementation)

struct StaticEventDetailsTab: View {
    @Binding var block: TimeBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title editing
            VStack(alignment: .leading, spacing: 8) {
                Text("Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                TextField("Activity title", text: $block.title)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            
            // Time and duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Timing")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    DatePicker("Start Time", selection: $block.startTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    HStack {
                        Text("Duration: \(block.durationMinutes) minutes")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("Ends at \(block.endTime.timeString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Energy and flow selection (simplified to prevent flashing)
            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 16) {
                    Picker("Energy", selection: $block.energy) {
                        ForEach(EnergyType.allCases, id: \.self) { energy in
                            Text("\(energy.rawValue) \(energy.description)").tag(energy)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Emoji", selection: $block.emoji) {
                        ForEach(["📋", "💎", "🌊", "☁️", "🎯", "💪", "🧠", "🎨"], id: \.self) { emoji in
                            Text(emoji).tag(emoji)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            Spacer()
        }
        .padding(24)
    }
}

struct EventConnectionsTab: View {
    @Binding var block: TimeBlock
    @EnvironmentObject private var dataManager: AppDataManager

    private var goals: [Goal] { dataManager.appState.goals }
    private var pillars: [Pillar] { dataManager.appState.pillars }
    private var selectedGoal: Goal? { goals.first { $0.id == block.relatedGoalId } }
    private var selectedPillar: Pillar? { pillars.first { $0.id == block.relatedPillarId } }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Connections")
                .font(.title3)
                .fontWeight(.semibold)

            connectionSection(
                title: "Goal alignment",
                icon: "target",
                selection: selectedGoal?.title ?? "No goal selected",
                description: selectedGoal?.description.isEmpty == false ? selectedGoal!.description : "Attach a goal so the assistant knows what this block advances."
            ) {
                Button("None") { block.relatedGoalId = nil }
                ForEach(goals) { goal in
                    Button(goal.title) { block.relatedGoalId = goal.id }
                }
            }

            connectionSection(
                title: "Pillar influence",
                icon: "building.columns",
                selection: selectedPillar?.name ?? "No pillar selected",
                description: selectedPillar?.description.isEmpty == false ? selectedPillar!.description : "Link a pillar to bias future suggestions toward this principle."
            ) {
                Button("None") { block.relatedPillarId = nil }
                ForEach(pillars) { pillar in
                    Button(pillar.name) { block.relatedPillarId = pillar.id }
                }
            }

            if let goal = selectedGoal {
                HStack(spacing: 8) {
                    Text("Accelerates")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(goal.title)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }
            }

            if let pillar = selectedPillar {
                HStack(spacing: 8) {
                    Text("Guided by")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pillar.name)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.12), in: Capsule())
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }

    @ViewBuilder
    private func connectionSection(title: String, icon: String, selection: String, description: String, @ViewBuilder menuContent: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)

            Menu {
                menuContent()
            } label: {
                selectionLabel(text: selection)
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func selectionLabel(text: String) -> some View {
        HStack {
            Text(text)
                .font(.callout)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }
}



struct StaticEventDurationTab: View {
    @Binding var block: TimeBlock
    
    private let presetDurations = [15, 30, 45, 60, 90, 120, 180, 240]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Duration Control")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Current duration display
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Duration")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("\(block.durationMinutes) minutes")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("Ends at \(block.endTime.timeString)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            
            // Preset duration buttons (simple, no complex layouts)
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Durations")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(presetDurations.prefix(4), id: \.self) { minutes in
                            durationButton(minutes: minutes)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(presetDurations.suffix(4), id: \.self) { minutes in
                            durationButton(minutes: minutes)
                        }
                    }
                }
            }
            
            // Simple duration slider
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom Duration: \(block.durationMinutes) minutes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Slider(
                    value: Binding(
                        get: { Double(block.durationMinutes) },
                        set: { block.duration = TimeInterval($0 * 60) }
                    ),
                    in: 15...240,
                    step: 15
                )
                .accentColor(.blue)
            }
            
            Spacer()
        }
        .padding(24)
    }
    
    @ViewBuilder
    private func durationButton(minutes: Int) -> some View {
        Button(action: { setDuration(minutes) }) {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("min")
                    .font(.caption2)
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(
                block.durationMinutes == minutes ? .blue.opacity(0.2) : .gray.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        block.durationMinutes == minutes ? .blue : .clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func setDuration(_ minutes: Int) {
        block.duration = TimeInterval(minutes * 60)
    }
}

// MARK: - Clean Event Card (No Flash, Perfect Position)

struct CleanEventCard: View {
    let block: TimeBlock
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingDetails = false
    
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
                    Text(block.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(block.startTime.timeString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        Text("\(block.durationMinutes)m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Simple info icon - no animation
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.blue.opacity(0.6))
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
        .padding(.horizontal, 12)
        .padding(.vertical, eventPadding)
        .frame(height: eventHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial.opacity(0.8))
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
        .offset(dragOffset)
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
        .sheet(isPresented: $showingDetails) {
            NoFlashEventDetailsSheet(
                block: block,
                allBlocks: dataManager.appState.currentDay.blocks,
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
    
    // MARK: - Computed Properties
    
    private var eventHeight: CGFloat {
        // Height based on duration, scaled appropriately
        let baseHeight: CGFloat = 30
        let durationMultiplier = max(1.0, CGFloat(block.durationMinutes) / 60.0)
        return baseHeight * durationMultiplier
    }
    
    private var eventPadding: CGFloat {
        block.durationMinutes >= 60 ? 8 : 4
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
    
    private func calculateNewTime(from translation: CGSize) -> Date {
        // Simple time calculation based on drag distance
        let pixelsPerHour: CGFloat = 60
        let hourChange = translation.height / pixelsPerHour
        let minuteChange = Int(hourChange * 60)
        
        let newTime = calendar.date(byAdding: .minute, value: minuteChange, to: block.startTime) ?? block.startTime
        
        // Round to nearest 15-minute interval
        let minute = calendar.component(.minute, from: newTime)
        let roundedMinute = (minute / 15) * 15
        
        return calendar.date(bySettingHour: calendar.component(.hour, from: newTime), 
                           minute: roundedMinute, 
                           second: 0, 
                           of: newTime) ?? newTime
    }
}

// MARK: - Enhanced Time Block Card

struct EnhancedTimeBlockCard: View {
    let block: TimeBlock
    let onTap: () -> Void
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    let allBlocks: [TimeBlock] // For chain gap checking
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingDetails = false
    @State private var activeTab: EventTab = .details
    
    var body: some View {
        VStack(spacing: 0) {
            // Main clickable event card (no edge resize)
            Button(action: { showingDetails = true }) {
            HStack(spacing: 10) {
                    // Energy & flow indicators
                VStack(spacing: 2) {
                    Text(block.energy.rawValue)
                        .font(.title3)
                    Text(block.emoji)
                        .font(.caption)
                }
                .opacity(0.8)
                
                    // Block content
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        Text(timeString(from: block.startTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        Text("\(block.durationMinutes)m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                            // Glass state indicator
                        Circle()
                            .fill(stateColor.opacity(0.8))
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .stroke(stateColor, lineWidth: 1)
                                    .scaleEffect(isDragging ? 1.5 : 1.0)
                            )
                    }
                }
                    
                    Spacer()
                    
                    // Quick action indicator
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.regularMaterial.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                borderColor.opacity(isDragging ? 1.0 : 0.6),
                                style: StrokeStyle(
                                    lineWidth: isDragging ? 2 : 1
                                )
                            )
                    )
                    .shadow(
                        color: stateColor.opacity(isDragging ? 0.3 : 0.1),
                        radius: isDragging ? 8 : 3,
                        y: isDragging ? 4 : 1
                    )
            )
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .offset(dragOffset)
            .gesture(
                // Single, clean drag gesture for moving events
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging { 
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDragging = true
                            }
                        }
                        dragOffset = value.translation
                        onDrag(value.location)
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isDragging = false
                            dragOffset = .zero
                        }
                        // Calculate proper new time based on drag distance
                        let newTime = calculateNewTime(from: value.translation)
                        onDrop(newTime)
                    }
            )
            // No animation to prevent flashing
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
    
    private var stateColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue  
        case .mist: return .purple
        case .crystal: return .cyan
        }
    }
    
    private var borderColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue
        case .mist: return .purple
        case .crystal: return .cyan
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func calculateNewTime(from translation: CGSize) -> Date {
        // Calculate time change based on vertical drag distance
        // Assume each 60 pixels = 1 hour (this can be adjusted)
        let pixelsPerHour: CGFloat = 60
        let hourChange = translation.height / pixelsPerHour
        
        // Convert to minutes for more precision
        let minuteChange = Int(hourChange * 60)
        
        // Apply the change to the current start time
        let newTime = Calendar.current.date(byAdding: .minute, value: minuteChange, to: block.startTime) ?? block.startTime
        
        // Round to nearest 15-minute interval for cleaner scheduling
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: newTime)
        let roundedMinute = (minute / 15) * 15
        
        return calendar.date(bySettingHour: calendar.component(.hour, from: newTime), 
                           minute: roundedMinute, 
                           second: 0, 
                           of: newTime) ?? newTime
    }
    
}

// MARK: - Event Details Sheet

enum EventTab: String, CaseIterable {
    case details = "Details"
    case connections = "Connections"
    case duration = "Duration"
    
    var icon: String {
        switch self {
        case .details: return "info.circle"
        case .connections: return "rectangle.connected.to.line.below"
        case .duration: return "clock"
        }
    }
}

struct EventDetailsSheet: View {
    let block: TimeBlock
    let activeTab: Binding<EventTab>
    let allBlocks: [TimeBlock]
    let onSave: (TimeBlock) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedBlock: TimeBlock
    @State private var showingDeleteConfirmation = false
    @State private var currentTab: EventTab = .details
    
    init(block: TimeBlock, activeTab: Binding<EventTab>, allBlocks: [TimeBlock], onSave: @escaping (TimeBlock) -> Void, onDelete: @escaping () -> Void) {
        self.block = block
        self.activeTab = activeTab
        self.allBlocks = allBlocks
        self.onSave = onSave
        self.onDelete = onDelete
        self._editedBlock = State(initialValue: block)
        self._currentTab = State(initialValue: activeTab.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Improved tab selector with liquid glass styling
                EventTabSelector(activeTab: $currentTab)
                
                Divider()
                    .opacity(0.3)
                
                // Tab content with smooth transitions
                ScrollView {
                    Group {
                        switch currentTab {
                        case .details:
                            EventDetailsTab(block: $editedBlock)
                        case .connections:
                            EventConnectionsTab(block: $editedBlock)
                        case .duration:
                            EventDurationTab(block: $editedBlock)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: currentTab)
                }
                .frame(maxHeight: .infinity)
                
                Divider()
                    .opacity(0.3)
                
                // Enhanced bottom actions with liquid glass styling
                HStack(spacing: 12) {
                    Button("Delete", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save Changes") {
                        onSave(editedBlock)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editedBlock.title.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .navigationTitle(block.title)
            .background(.ultraThinMaterial.opacity(0.3))
        }
        .frame(width: 700, height: 600) // Made wider and taller for better usability
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(block.title)'? This action cannot be undone.")
        }
    }
}

struct EventTabSelector: View {
    @Binding var activeTab: EventTab
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(EventTab.allCases, id: \.self) { tab in
                Button(action: { 
                    // Instant tab switching to fix delays
                    activeTab = tab
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(activeTab == tab ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44) // Fixed height prevents flashing
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(activeTab == tab ? .blue : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            .ultraThinMaterial.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: activeTab) // Faster, smoother animation
    }
}

struct EventDetailsTab: View {
    @Binding var block: TimeBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title editing
            VStack(alignment: .leading, spacing: 8) {
                Text("Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                TextField("Activity title", text: $block.title)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            
            // Time and duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Timing")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    DatePicker("Start Time", selection: $block.startTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    HStack {
                        Text("Duration: \(block.durationMinutes) minutes")
                            .font(.subheadline)
                    
                    Spacer()
                    
                        Text("Ends at \(block.endTime.timeString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Energy and flow selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Energy")
                            .font(.subheadline)
                        
                        Picker("Energy", selection: $block.energy) {
                            ForEach(EnergyType.allCases, id: \.self) { energy in
                                Label(energy.description, systemImage: energy.rawValue)
                                    .tag(energy)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flow")
                            .font(.subheadline)
                        
                        Picker("Emoji", selection: $block.emoji) {
                            ForEach(["📋", "💎", "🌊", "☁️", "🎯", "💪", "🧠", "🎨"], id: \.self) { emoji in
                                Text(emoji)
                                    .tag(emoji)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            
            
            Spacer()
        }
        .padding(24)
    }
}


