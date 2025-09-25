// MARK: - Day Planner View

import SwiftUI

struct DayPlannerView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @Binding var selectedDate: Date // Use shared date state
    @State private var showingBlockCreation = false
    @State private var creationTime: Date?
    @State private var draggedBlock: TimeBlock?
    
    var body: some View {
        VStack(spacing: 0) {
            // Date header
            DayViewHeader(selectedDate: $selectedDate)
            
            // Timeline view
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        HourSlot(
                            hour: hour,
                            blocks: blocksForHour(hour),
                            onTap: { time in
                                creationTime = time
                                showingBlockCreation = true
                            },
                            onBlockDrag: { block, location in
                                draggedBlock = block
                                // Handle block dragging
                            },
                            onBlockDrop: { block, newTime in
                                handleBlockDrop(block: block, newTime: newTime)
                                draggedBlock = nil // Clear drag state
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollDisabled(draggedBlock != nil) // Disable scroll when dragging an event
        }
        .onAppear {
            // Ensure selectedDate matches currentDay on appear
            selectedDate = dataManager.appState.currentDay.date
        }
        .sheet(isPresented: $showingBlockCreation) {
            BlockCreationSheet(
                suggestedTime: creationTime ?? Date(),
                onCreate: { block in
                    dataManager.addTimeBlock(block)
                    showingBlockCreation = false
                    creationTime = nil
                }
            )
        }
    }
    
    private func blocksForHour(_ hour: Int) -> [TimeBlock] {
        let calendar = Calendar.current
        let allBlocks = dataManager.appState.currentDay.blocks
        return allBlocks.filter { block in
            let blockHour = calendar.component(.hour, from: block.startTime)
            return blockHour == hour
        }
    }
    
    private func updateDataManagerDate() {
        // Update the current day in data manager when date changes
        if !Calendar.current.isDate(dataManager.appState.currentDay.date, inSameDayAs: selectedDate) {
            switchToDate(selectedDate)
        }
    }
    
    private func switchToDate(_ date: Date) {
        // Use the proper switchToDay method from data manager to preserve data
        dataManager.switchToDay(date)
    }
    
    private func handleBlockDrop(block: TimeBlock, newTime: Date) {
        // Update the block's start time
        var updatedBlock = block
        updatedBlock.startTime = newTime
        
        // Update the block in the data manager
        dataManager.updateTimeBlock(updatedBlock)
        
        // Clear the dragged block
        draggedBlock = nil
        
        // Provide haptic feedback
        #if os(iOS)
        HapticStyle.light.trigger()
        #endif
    }
}

struct DayViewHeader: View {
    @Binding var selectedDate: Date
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        HStack {
            // Previous day
            Button(action: previousDay) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Current date
            Text(selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // Next day
            Button(action: nextDay) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private func previousDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            updateDataManagerDate()
        }
    }
    
    private func nextDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            updateDataManagerDate()
        }
    }
    
    private func updateDataManagerDate() {
        // Update the current day in data manager when date changes
        if !Calendar.current.isDate(dataManager.appState.currentDay.date, inSameDayAs: selectedDate) {
            switchToDate(selectedDate)
        }
    }
    
    private func switchToDate(_ date: Date) {
        // Use the proper switchToDay method from data manager to preserve data
        dataManager.switchToDay(date)
    }
}

struct HourSlot: View {
    let hour: Int
    let blocks: [TimeBlock]
    let onTap: (Date) -> Void
    let onBlockDrag: (TimeBlock, CGPoint) -> Void
    let onBlockDrop: (TimeBlock, Date) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Hour label
            VStack {
                Text(hourString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
                
                if hour < 23 {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 1)
                        .frame(width: 50)
                }
            }
            
            // Content area
            VStack(alignment: .leading, spacing: 4) {
                ForEach(blocks) { block in
                    SimpleTimeBlockView(
                        block: block,
                        onDrag: { location in
                            onBlockDrag(block, location)
                        },
                        onDrop: { newTime in
                            onBlockDrop(block, newTime)
                        }
                    )
                }
                
                // Empty space for tapping
                if blocks.isEmpty {
                    Rectangle()
                        .fill(.clear)
                        .frame(height: 60)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let calendar = Calendar.current
                            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
                            onTap(date)
                        }
                }
                
                // Hour separator line
                if hour < 23 {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
    }
    
    private var hourString: String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.timeString
    }
}

// MARK: - Simple Time Block View (Replacement for old complex TimeBlockView)

struct SimpleTimeBlockView: View {
    let block: TimeBlock
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingDetails = false
    @State private var activeTab: EventTab = .details
    
    var body: some View {
        // Fixed draggable event card with proper gesture priority
        VStack(spacing: 0) {
                HStack(spacing: 8) {
                    // Energy and flow indicators
                    VStack(spacing: 2) {
                        Text(block.energy.rawValue)
                            .font(.caption)
                        Text(block.emoji)
                            .font(.caption)
                    }
                .opacity(0.8)
                    
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
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        
                                HStack {
                                    Text(block.startTime.timeString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(block.durationMinutes) min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                        
                        // Quick visual indicator of what's available
                        if canAddChainBefore || canAddChainAfter {
                            Text("⛓️")
                                    .font(.caption2)
                                .opacity(0.6)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Glass state indicator
                    Circle()
                        .fill(stateColor)
                        .frame(width: 6, height: 6)
                
                // Click to open details indicator
                Button(action: { showingDetails = true }) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
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
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .offset(dragOffset)
            .contentShape(Rectangle()) // Ensure entire area is draggable
            .highPriorityGesture(
                // Exclusive drag gesture that overrides scroll
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
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
                        withAnimation(.spring(response: 0.5)) {
                            isDragging = false
                            dragOffset = .zero
                        }
                        
                        // Calculate new time based on drag distance
                        let newTime = calculateNewTime(from: value.translation)
                        onDrop(newTime)
                    }
            )
            // No animation to prevent flashing
        }
        .sheet(isPresented: $showingDetails) {
            NoFlashEventDetailsSheet(
                block: block,
                allBlocks: getAllBlocks(),
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
    
    private var canAddChainBefore: Bool {
        let gap = calculateGapBefore()
        return gap >= 300 // 5 minutes minimum
    }
    
    private var canAddChainAfter: Bool {
        let gap = calculateGapAfter()
        return gap >= 300 // 5 minutes minimum
    }
    
    private func getAllBlocks() -> [TimeBlock] {
        return dataManager.appState.currentDay.blocks
    }
    
    private func calculateGapBefore() -> TimeInterval {
        let allBlocks = getAllBlocks()
        let previousBlocks = allBlocks.filter { $0.endTime <= block.startTime && $0.id != block.id }
        guard let previousBlock = previousBlocks.max(by: { $0.endTime < $1.endTime }) else {
            // No previous event, gap to start of day
            let startOfDay = Calendar.current.startOfDay(for: block.startTime)
            return block.startTime.timeIntervalSince(startOfDay)
        }
        
        return block.startTime.timeIntervalSince(previousBlock.endTime)
    }
    
    private func calculateGapAfter() -> TimeInterval {
        let allBlocks = getAllBlocks()
        let nextBlocks = allBlocks.filter { $0.startTime >= block.endTime && $0.id != block.id }
        guard let nextBlock = nextBlocks.min(by: { $0.startTime < $1.startTime }) else {
            // No next event, gap to end of day
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: block.startTime) ?? block.endTime
            return endOfDay.timeIntervalSince(block.endTime)
        }
        
        return nextBlock.startTime.timeIntervalSince(block.endTime)
    }
    
    private func calculateNewTime(from translation: CGSize) -> Date {
        // Calculate time change based on vertical drag distance
        // Assume each 60 pixels = 1 hour (adjustable)
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
    
    private func showChainSelector(position: ChainPosition) {
        // This will be handled by the EventDetailsSheet's onAddChain closure
        // which is called from the EventChainsTab
        print("Chain selector triggered for \(position) position - handled by details sheet")
    }
}

// MARK: - Block Creation Sheet


struct BlockCreationSheet: View {
    let suggestedTime: Date
    private let maxDurationMinutes: Int?
    private let minimumDurationMinutes: Int
    let onCreate: (TimeBlock) -> Void
    
    @State private var title: String
    @State private var selectedEnergy: EnergyType
    @State private var selectedEmoji: String
    @State private var duration: Int
    @State private var notes: String
    @Environment(\.dismiss) private var dismiss
    
    init(
        suggestedTime: Date,
        initialTitle: String = "",
        initialEnergy: EnergyType = .daylight,
        initialEmoji: String = "🌊",
        initialDuration: Int = 60,
        initialNotes: String = "",
        minimumDurationMinutes: Int = 15,
        maxDurationMinutes: Int? = nil,
        onCreate: @escaping (TimeBlock) -> Void
    ) {
        self.suggestedTime = suggestedTime
        self.minimumDurationMinutes = max(5, minimumDurationMinutes)
        if let maxDurationMinutes {
            self.maxDurationMinutes = max(self.minimumDurationMinutes, maxDurationMinutes)
        } else {
            self.maxDurationMinutes = nil
        }
        self.onCreate = onCreate
        let upperBound = self.maxDurationMinutes ?? 240
        let clampedDuration = max(self.minimumDurationMinutes, min(initialDuration, upperBound))
        _title = State(initialValue: initialTitle)
        _selectedEnergy = State(initialValue: initialEnergy)
        _selectedEmoji = State(initialValue: initialEmoji)
        _duration = State(initialValue: clampedDuration)
        _notes = State(initialValue: initialNotes)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Title input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity")
                        .font(.headline)
                    
                    TextField("What would you like to do?", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                
                // Energy selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Energy Level")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(EnergyType.allCases, id: \.self) { energy in
                            Button(action: { selectedEnergy = energy }) {
                                VStack(spacing: 4) {
                                    Text(energy.rawValue)
                                        .font(.title2)
                                    Text(energy.description)
                                        .font(.caption)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    selectedEnergy == energy ? energy.color.opacity(0.2) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selectedEnergy == energy ? energy.color : .gray.opacity(0.3),
                                            lineWidth: selectedEnergy == energy ? 2 : 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Flow selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity Type")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(["📋", "💎", "🌊", "☁️", "🎯", "💪", "🧠", "🎨"], id: \.self) { emoji in
                            Button(action: { selectedEmoji = emoji }) {
                                VStack(spacing: 4) {
                                    Text(emoji)
                                        .font(.title2)
                                    Text("Activity")
                                        .font(.caption)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    selectedEmoji == emoji ? .blue.opacity(0.2) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selectedEmoji == emoji ? .blue : .gray.opacity(0.3),
                                            lineWidth: selectedEmoji == emoji ? 2 : 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Duration slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration: \(duration) minutes")
                        .font(.headline)
                    
                    Slider(
                        value: Binding(
                            get: { Double(duration) },
                            set: { duration = Int($0) }
                        ),
                        in: Double(minimumDurationMinutes)...Double(maxDurationMinutes ?? 240),
                        step: 1
                    )
                    .accentColor(.blue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2))
                        )
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("New Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        let block = TimeBlock(
                            title: title,
                            startTime: suggestedTime,
                            duration: TimeInterval(duration * 60),
                            energy: selectedEnergy,
                            emoji: selectedEmoji,
                            glassState: .mist,
                            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                        )
                        onCreate(block)
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct TimeframeSelectorView: View {
    @Binding var selection: TimeframeSelector
    
    var body: some View {
        Picker("Timeframe", selection: $selection) {
            ForEach(TimeframeSelector.allCases, id: \.self) { timeframe in
                Text(timeframe.rawValue).tag(timeframe)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

struct ChainsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingChainCreator = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chains")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Create Chain") {
                    showingChainCreator = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if dataManager.appState.recentChains.isEmpty {
                VStack(spacing: 8) {
                    Text("🔗")
                        .font(.title)
                        .opacity(0.5)
                    
                    Text("No chains yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Create chains to build reusable activity sequences")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(dataManager.appState.recentChains) { chain in
                        ChainRowView(chain: chain) {
                            // Apply chain to today
                            dataManager.applyChain(chain, startingAt: Date())
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingChainCreator) {
            ChainCreationView { newChain in
                dataManager.addChain(newChain)
                showingChainCreator = false
            }
        }
    }
}

struct ChainRowView: View {
    let chain: Chain
    let onApply: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chain.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(chain.blocks.count) activities • \(chain.totalDurationMinutes) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Apply") {
                onApply()
            }
            .buttonStyle(.bordered)
            .help("Add this suggestion to your schedule")
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(isHovered ? 0.2 : 0.1))
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onApply()
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

struct ChainCreationView: View {
    let onCreate: (Chain) -> Void
    
    @State private var chainName = ""
    @State private var selectedPattern: FlowPattern = .waterfall
    @State private var chainBlocks: [TimeBlock] = []
    @State private var showingBlockEditor = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chain Name")
                        .font(.headline)
                    
                    TextField("Enter chain name", text: $chainName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flow Pattern")
                        .font(.headline)
                    
                    Picker("Pattern", selection: $selectedPattern) {
                        ForEach(FlowPattern.allCases, id: \.self) { pattern in
                            Text(pattern.description).tag(pattern)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(flowPatternExplanation(for: selectedPattern))
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
                            blocks: chainBlocks,
                            flowPattern: selectedPattern
                        )
                        onCreate(newChain)
    }
    .disabled(chainName.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private func flowPatternExplanation(for pattern: FlowPattern) -> String {
        switch pattern {
        case .waterfall:
            return "Activities cascade smoothly from one to the next, building momentum naturally."
        case .spiral:
            return "Activities follow a circular flow, building energy through repeated cycles."
        case .ripple:
            return "Activities create expanding waves of energy, perfect for creative or dynamic work."
        case .wave:
            return "Activities rise and fall in intensity, allowing for natural rhythm and recovery."
        }
    }
    
    private func addNewBlock() {
        let newBlock = TimeBlock(
            title: "Activity \(chainBlocks.count + 1)",
            startTime: Date(),
            duration: 1800, // 30 minutes default
            energy: .daylight,
            emoji: "🌊",
            glassState: .crystal
        )
        chainBlocks.append(newBlock)
    }
}

struct ChainBlockEditRow: View {
    let block: TimeBlock
    let index: Int
    let onUpdate: (TimeBlock) -> Void
    let onRemove: () -> Void
    
    @State private var editedBlock: TimeBlock
    
    init(block: TimeBlock, index: Int, onUpdate: @escaping (TimeBlock) -> Void, onRemove: @escaping () -> Void) {
        self.block = block
        self.index = index
        self.onUpdate = onUpdate
        self.onRemove = onRemove
        self._editedBlock = State(initialValue: block)
    }
    
    var body: some View {
        HStack {
            Text("\(index).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
            
            TextField("Activity title", text: $editedBlock.title)
                .textFieldStyle(.roundedBorder)
                .onChange(of: editedBlock.title) { _, _ in
                    onUpdate(editedBlock)
                }
            
            Stepper("\(editedBlock.durationMinutes)m", 
                   value: Binding(
                       get: { Double(editedBlock.duration/60) },
                       set: { newValue in
                           editedBlock.duration = TimeInterval(newValue * 60)
                           onUpdate(editedBlock)
                       }
                   ), 
                   in: 5...480, 
                   step: 5)
                .frame(width: 80)
            
            Button("Remove") {
                onRemove()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .foregroundColor(.red)
        }
        .padding(.vertical, 2)
    }
}

struct PillarsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingPillarCreator = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pillars")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Pillar") {
                    showingPillarCreator = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if dataManager.appState.pillars.isEmpty {
                VStack(spacing: 8) {
                    Text("⛰️")
                        .font(.title)
                        .opacity(0.5)
                    
                    Text("No pillars yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Create pillars to define your routine categories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(dataManager.appState.pillars) { pillar in
                        PillarRowView(pillar: pillar)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPillarCreator) {
            PillarCreationView { newPillar in
                dataManager.appState.pillars.append(newPillar)
                dataManager.save()
                showingPillarCreator = false
            }
        }
    }
}

struct PillarRowView: View {
    let pillar: Pillar
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(pillar.color.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pillar.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(pillar.frequencyDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PillarCreationView: View {
    let onCreate: (Pillar) -> Void
    
    @State private var name = ""
    @State private var description = ""
    @State private var frequency: PillarFrequency = .daily
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.headline)
                    TextField("e.g., Exercise, Work, Rest", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                    TextField("Brief description", text: $description)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Frequency")
                        .font(.headline)
                    
                    Picker("Frequency", selection: $frequency) {
                        Text("Daily").tag(PillarFrequency.daily)
                        Text("3x per week").tag(PillarFrequency.weekly(3))
                        Text("As needed").tag(PillarFrequency.asNeeded)
                    }
                    .pickerStyle(.segmented)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Create Pillar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newPillar = Pillar(
                            name: name,
                            description: description,
                            frequency: frequency,
                            minDuration: 1800, // 30 minutes
                            maxDuration: 7200, // 2 hours
                            preferredTimeWindows: [],
                            overlapRules: [],
                            quietHours: []
                        )
                        onCreate(newPillar)
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

struct GoalsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingGoalCreator = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Goals")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("New Goal") {
                    showingGoalCreator = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if dataManager.appState.goals.isEmpty {
                VStack(spacing: 8) {
                    Text("🎯")
                        .font(.title)
                        .opacity(0.5)
                    
                    Text("No goals yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Set goals to get AI suggestions for achieving them")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(dataManager.appState.goals) { goal in
                        GoalRowView(goal: goal)
                    }
                }
            }
        }
        .sheet(isPresented: $showingGoalCreator) {
            GoalCreationView { newGoal in
                dataManager.appState.goals.append(newGoal)
                dataManager.save()
                showingGoalCreator = false
            }
        }
    }
}

struct GoalRowView: View {
    let goal: Goal
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(goal.state.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(stateColor.opacity(0.2), in: Capsule())
                        .foregroundColor(stateColor)
                    
                    Text("Importance: \(goal.importance)/5")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if goal.progress > 0 {
                ProgressView(value: goal.progress)
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var stateColor: Color {
        switch goal.state {
        case .draft: return .orange
        case .on: return .green
        case .off: return .gray
        }
    }
}

struct GoalCreationView: View {
    let onCreate: (Goal) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var importance = 3
    @State private var state: GoalState = .draft
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal Title")
                        .font(.headline)
                    TextField("e.g., Learn Swift Programming", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                    TextField("Brief description of your goal", text: $description)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Importance: \(importance)/5")
                        .font(.headline)
                    Slider(value: Binding(
                        get: { Double(importance) },
                        set: { importance = Int($0) }
                    ), in: 1...5, step: 1)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Initial State")
                        .font(.headline)
                    
                    Picker("State", selection: $state) {
                        ForEach(GoalState.allCases, id: \.self) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Goal Breakdown Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Break Down Into Actions")
                        .font(.headline)
                    
                    Text("Convert your goal into actionable steps:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("→ Create Pillar") {
                            createPillarFromGoal()
                        }
                        .buttonStyle(.bordered)
                        .help("Create a recurring pillar based on this goal")
                        
                        Button("→ Create Chain") {
                            createChainFromGoal()
                        }
                        .buttonStyle(.bordered)
                        .help("Create a sequence of activities for this goal")
                        
                        Button("→ Create Event") {
                            createEventFromGoal()
                        }
                        .buttonStyle(.bordered)
                        .help("Schedule a specific time block for this goal")
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Create Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newGoal = Goal(
                            title: title,
                            description: description,
                            state: state,
                            importance: importance,
                            groups: []
                        )
                        onCreate(newGoal)
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func createPillarFromGoal() {
        let _ = Pillar(
            name: title,
            description: "Supporting pillar for: \(description)",
            frequency: .weekly(2),
            minDuration: 1800, // 30 minutes
            maxDuration: 7200, // 2 hours
            preferredTimeWindows: [],
            overlapRules: [],
            quietHours: []
        )
        // This would ideally show a pillar creation sheet, but for now just create directly
        // In a real app, you'd want to let users customize the pillar
    }
    
    private func createChainFromGoal() {
        let _ = Chain(
            name: "\(title) Chain",
            blocks: [
                TimeBlock(
                    title: "Plan \(title)",
                    startTime: Date(),
                    duration: 1800, // 30 minutes
                    energy: .daylight,
                    emoji: "💎"
                ),
                TimeBlock(
                    title: "Execute \(title)",
                    startTime: Date(),
                    duration: 3600, // 60 minutes
                    energy: .daylight,
                    emoji: "🌊"
                )
            ],
            flowPattern: .waterfall
        )
        // This would ideally show a chain creation sheet, but for now just create directly
    }
    
    private func createEventFromGoal() {
        let _ = TimeBlock(
            title: title,
            startTime: Date(),
            duration: 3600, // 60 minutes default
            energy: .daylight,
            emoji: "🌊"
        )
        // This would ideally show a time block creation sheet
    }
}

struct DreamBuilderSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var selectedConcepts: Set<UUID> = []
    @State private var showingMergeView = false
    @State private var showingDreamChat = false
    
    // Cached sorted concepts to prevent expensive re-sorting on every view update
    private var sortedDreamConcepts: [DreamConcept] {
        dataManager.appState.dreamConcepts.sorted { $0.priority > $1.priority }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dream Builder")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !selectedConcepts.isEmpty {
                    Button("Merge (\(selectedConcepts.count))") {
                        showingMergeView = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Button("Dream Chat") {
                    showingDreamChat = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if dataManager.appState.dreamConcepts.isEmpty {
                VStack(spacing: 8) {
                    Text("✨")
                        .font(.title)
                        .opacity(0.5)
                    
                    Text("No dreams captured yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("As you chat with AI, recurring desires will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Start Dream Chat") {
                        showingDreamChat = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sortedDreamConcepts) { concept in
                        EnhancedDreamConceptView(
                            concept: concept,
                            isSelected: selectedConcepts.contains(concept.id),
                            onToggleSelection: {
                                if selectedConcepts.contains(concept.id) {
                                    selectedConcepts.remove(concept.id)
                                } else {
                                    selectedConcepts.insert(concept.id)
                                }
                            },
                            onConvertToGoal: {
                                convertConceptToGoal(concept)
                            },
                            onShowMergeOptions: {
                                showMergeOptions(for: concept)
                            }
                        )
                    }
                }
                
                if !selectedConcepts.isEmpty {
                    Button("Clear Selection") {
                        selectedConcepts.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .sheet(isPresented: $showingMergeView) {
            DreamMergeView(
                concepts: selectedConcepts.compactMap { id in
                    dataManager.appState.dreamConcepts.first { $0.id == id }
                },
                onMerge: { mergedConcept in
                    mergeConcepts(selectedConcepts, into: mergedConcept)
                    selectedConcepts.removeAll()
                    showingMergeView = false
                }
            )
            .environmentObject(aiService)
        }
        .sheet(isPresented: $showingDreamChat) {
            DreamChatView()
                .environmentObject(dataManager)
                .environmentObject(aiService)
        }
    }
    
    private func convertConceptToGoal(_ concept: DreamConcept) {
        let newGoal = Goal(
            title: concept.title,
            description: concept.description,
            state: .draft,
            importance: min(5, max(1, Int(concept.priority))),
            groups: []
        )
        dataManager.appState.goals.append(newGoal)
        
        // Mark concept as promoted
        if let index = dataManager.appState.dreamConcepts.firstIndex(where: { $0.id == concept.id }) {
            dataManager.appState.dreamConcepts[index].hasBeenPromotedToGoal = true
        }
        
        dataManager.save()
    }
    
    private func showMergeOptions(for concept: DreamConcept) {
        // Show which concepts this can merge with
        selectedConcepts.insert(concept.id)
        for mergeableId in concept.canMergeWith {
            selectedConcepts.insert(mergeableId)
        }
    }
    
    private func mergeConcepts(_ conceptIds: Set<UUID>, into mergedConcept: DreamConcept) {
        // Remove individual concepts
        dataManager.appState.dreamConcepts.removeAll { conceptIds.contains($0.id) }
        
        // Add merged concept
        dataManager.appState.dreamConcepts.append(mergedConcept)
        dataManager.save()
    }
}

struct EnhancedDreamConceptView: View {
    let concept: DreamConcept
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onConvertToGoal: () -> Void
    let onShowMergeOptions: () -> Void
    
    @State private var showingAIThoughts = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(concept.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Mentioned \(concept.mentions) times")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !concept.relatedKeywords.isEmpty {
                    Text(concept.relatedKeywords.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                // Mergeable indicators
                if !concept.canMergeWith.isEmpty {
                    Text("Can merge with \(concept.canMergeWith.count) other concept\(concept.canMergeWith.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .onTapGesture {
                            onShowMergeOptions()
                        }
                }
            }
            
            Spacer()
            
            VStack(spacing: 6) {
                if !concept.hasBeenPromotedToGoal {
                    Button("Make Goal") {
                        onConvertToGoal()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Text("Goal Created")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                // Priority indicator
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(index < Int(concept.priority) ? .orange : .gray.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? .blue.opacity(0.1) : .gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? .blue : .clear, lineWidth: 1)
                )
        )
        .onLongPressGesture {
            showingAIThoughts = true
        }
        .popover(isPresented: $showingAIThoughts) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Thoughts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Priority Score: \(String(format: "%.1f", concept.priority))")
                    .font(.subheadline)
                
                Text("This concept shows up frequently in your conversations and aligns with your stated interests. The AI thinks this could be developed into a concrete goal with specific action steps.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if !concept.relatedKeywords.isEmpty {
                    Text("Related: \(concept.relatedKeywords.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(width: 300, height: 150)
        }
    }
}
