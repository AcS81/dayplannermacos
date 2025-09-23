//
//  EventDetailsViews.swift
//  DayPlanner
//
//  Event Details Sheets and Related Components
//

import SwiftUI

// MARK: - Event Details Sheet

enum EventTab: String, CaseIterable {
    case details = "Details"
    case chains = "Chains"
    case duration = "Duration"
    
    var icon: String {
        switch self {
        case .details: return "info.circle"
        case .chains: return "link"
        case .duration: return "clock"
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
        case .chains:
            StaticEventChainsTab(
                block: block,
                allBlocks: allBlocks,
                onAddChain: { position in
                    addChainToEvent(position: position)
                }
            )
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
    
    private func addChainToEvent(position: ChainPosition) {
        let chainDuration: TimeInterval = 1800 // 30 minutes
        let chainName = position == .before ? "Prep for \(block.title)" : "Follow-up to \(block.title)"
        
        let newChain = Chain(
            name: chainName,
            blocks: [
                TimeBlock(
                    title: chainName,
                    startTime: Date(),
                    duration: chainDuration,
                    energy: block.energy,
                    emoji: block.emoji
                )
            ],
            flowPattern: .waterfall
        )
        
        let insertTime = position == .before 
            ? block.startTime.addingTimeInterval(-chainDuration - 300)
            : block.endTime.addingTimeInterval(300)
        
        dataManager.applyChain(newChain, startingAt: insertTime)
        dismiss()
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

struct StaticEventChainsTab: View {
    let block: TimeBlock
    let allBlocks: [TimeBlock]
    let onAddChain: (ChainPosition) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chain Operations")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Add activity sequences before or after this event")
                .font(.body)
                .foregroundStyle(.secondary)
            
            // Simple chain adding
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Add Before")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if canChainBefore {
                        HStack(spacing: 8) {
                            Button("Add Chain") {
                                onAddChain(.before)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Generate") {
                                generateAndStageChain(.before)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Text("No space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(chainBeforeStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                
                VStack(spacing: 8) {
                    Text("Add After")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if canChainAfter {
                        HStack(spacing: 8) {
                            Button("Add Chain") {
                                onAddChain(.after)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Generate") {
                                generateAndStageChain(.after)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Text("No space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(chainAfterStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            }
            
            Spacer()
        }
        .padding(24)
    }
    
    private var canChainBefore: Bool {
        calculateGapBefore() >= 300 // 5 minutes minimum
    }
    
    private var canChainAfter: Bool {
        calculateGapAfter() >= 300 // 5 minutes minimum
    }
    
    private var chainBeforeStatus: String {
        let gap = calculateGapBefore()
        if gap < 300 {
            return "Need 5min gap\n(\(Int(gap/60))min available)"
        }
        return "\(Int(gap/60)) minutes\navailable"
    }
    
    private var chainAfterStatus: String {
        let gap = calculateGapAfter()
        if gap < 300 {
            return "Need 5min gap\n(\(Int(gap/60))min available)"
        }
        return "\(Int(gap/60)) minutes\navailable"
    }
    
    private func calculateGapBefore() -> TimeInterval {
        let previousBlocks = allBlocks.filter { $0.endTime <= block.startTime && $0.id != block.id }
        guard let previousBlock = previousBlocks.max(by: { $0.endTime < $1.endTime }) else {
            let startOfDay = Calendar.current.startOfDay(for: block.startTime)
            return block.startTime.timeIntervalSince(startOfDay)
        }
        return block.startTime.timeIntervalSince(previousBlock.endTime)
    }
    
    private func calculateGapAfter() -> TimeInterval {
        let nextBlocks = allBlocks.filter { $0.startTime >= block.endTime && $0.id != block.id }
        guard let nextBlock = nextBlocks.min(by: { $0.startTime < $1.startTime }) else {
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: block.startTime) ?? block.endTime
            return endOfDay.timeIntervalSince(block.endTime)
        }
        return nextBlock.startTime.timeIntervalSince(block.endTime)
    }
    
    private func generateAndStageChain(_ position: ChainPosition) {
        // Generate appropriate chain based on context
        let availableTime = position == .before ? calculateGapBefore() : calculateGapAfter()
        
        // Create a context-appropriate chain
        let suggestedDuration = min(availableTime * 0.8, 3600) // Use 80% of available time, max 1 hour
        
        // Generate a time block that fits the context
        let chainBlock = TimeBlock(
            title: generateContextualActivity(for: block, position: position),
            startTime: position == .before ? 
                block.startTime.addingTimeInterval(-suggestedDuration) : 
                block.endTime,
            duration: suggestedDuration,
            energy: block.energy,
            emoji: selectContextualEmoji(for: block, position: position),
        )
        
        // Add to staged blocks (assuming access to data manager)
        // This would need to be passed down or accessed through environment
        // For now, we'll trigger the onAddChain callback which should handle staging
        onAddChain(position)
        
        // Note: chainBlock is created but not directly used here since we're using the callback
        _ = chainBlock
    }
    
    private func generateContextualActivity(for event: TimeBlock, position: ChainPosition) -> String {
        let eventTitle = event.title.lowercased()
        
        if position == .before {
            if eventTitle.contains("meeting") || eventTitle.contains("call") {
                return "Meeting Prep"
            } else if eventTitle.contains("workout") || eventTitle.contains("exercise") {
                return "Warm-up"
            } else if eventTitle.contains("work") || eventTitle.contains("project") {
                return "Focus Setup"
            } else {
                return "Preparation"
            }
        } else {
            if eventTitle.contains("meeting") || eventTitle.contains("call") {
                return "Follow-up Notes"
            } else if eventTitle.contains("workout") || eventTitle.contains("exercise") {
                return "Cool-down"
            } else if eventTitle.contains("work") || eventTitle.contains("project") {
                return "Wrap-up"
            } else {
                return "Transition"
            }
        }
    }
    
    private func selectContextualEmoji(for event: TimeBlock, position: ChainPosition) -> String {
        let eventEmoji = event.emoji
        
        if position == .before {
            switch eventEmoji {
            case "💼": return "📋"
            case "🏃‍♀️", "💪": return "🔥"
            case "👥": return "📝"
            default: return "⚡"
            }
        } else {
            switch eventEmoji {
            case "💼": return "✅"
            case "🏃‍♀️", "💪": return "🧘"
            case "👥": return "📝"
            default: return "🔄"
            }
        }
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

// MARK: - Chain Input Components

enum ChainPosition {
    case before, after
    
    var icon: String {
        switch self {
        case .before: return "arrow.left.to.line"
        case .after: return "arrow.right.to.line"  
        }
    }
    
    var label: String {
        switch self {
        case .before: return "Before"
        case .after: return "After"
        }
    }
}
