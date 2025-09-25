//
//  PreciseEventComponents.swift
//  DayPlanner
//
//  Precise Event Cards and Timeline Components
//

import SwiftUI

// MARK: - Precise Event Card

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
    @State private var showingChainOptions = false
    
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
    
    private func showChainSelector(position: ChainPosition) {
        // TODO: Implement chain selector
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
