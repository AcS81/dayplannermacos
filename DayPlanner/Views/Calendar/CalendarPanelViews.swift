//
//  CalendarPanelViews.swift
//  DayPlanner
//
//  Calendar Panel and Timeline Components
//

import SwiftUI

// MARK: - Calendar Panel

struct CalendarPanel: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Binding var selectedDate: Date
    @Binding var showingMonthView: Bool
    @State private var showingPillarDay = false
    @State private var showingBackfillTemplates = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar header with elegant styling
            CalendarPanelHeader(
                selectedDate: $selectedDate,
                showingMonthView: $showingMonthView,
                showingBackfillTemplates: $showingBackfillTemplates,
                onPillarDayTap: { showingPillarDay = true }
            )
            
            // Month view (expandable/collapsible)
            if showingMonthView {
                MonthViewExpanded(selectedDate: $selectedDate, dataManager: dataManager)
                    .frame(height: 280)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingMonthView)
            }
            
            // Backfill templates dropdown (expandable/collapsible)
            if showingBackfillTemplates {
                BackfillTemplatesView(selectedDate: selectedDate)
                    .frame(height: 200)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingBackfillTemplates)
            }
            
            // Day view - enhanced with liquid glass styling
            EnhancedDayView(selectedDate: $selectedDate)
                .frame(maxHeight: .infinity)
        }
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.leading, 8)  // Moved further left
        .padding(.trailing, 4)
        .padding(.vertical, 12)
        .sheet(isPresented: $showingPillarDay) {
            PillarDayView()
                .environmentObject(dataManager)
                .environmentObject(aiService)
        }
    }
}

// MARK: - Calendar Panel Header

struct CalendarPanelHeader: View {
    @Binding var selectedDate: Date
    @Binding var showingMonthView: Bool
    @Binding var showingBackfillTemplates: Bool
    let onPillarDayTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    // Elegant navigation arrows positioned next to date
                    Button(action: previousDay) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(.blue.opacity(0.08), in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Text(dateFormatter.string(from: selectedDate))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Button(action: nextDay) {
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(.blue.opacity(0.08), in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Text("Calendar")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Month expand/collapse button
                Button(action: { 
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingMonthView.toggle()
                    }
                }) {
                    Image(systemName: showingMonthView ? "chevron.up.circle.fill" : "calendar.circle")
                        .font(.title2)
                        .foregroundStyle(showingMonthView ? .blue : .secondary)
                        .symbolEffect(.bounce, value: showingMonthView)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 16)
                
                // Action buttons with capsule style
                HStack(spacing: 6) {
                    Button("Pillar Day") {
                        onPillarDayTap()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
                    .help("Add missing pillar activities to today")
                    
                    Button("Backfill") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingBackfillTemplates.toggle()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func previousDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func nextDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        }
    }
}

// MARK: - Enhanced Day View

struct EnhancedDayView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @Binding var selectedDate: Date
    @State private var showingBlockCreation = false
    @State private var creationTime: Date?
    @State private var draggedBlock: TimeBlock?
    
    // Constants for precise timeline sizing
    private let minuteHeight: CGFloat = 1.0 // 1 pixel per minute = perfect precision
    
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
                            }
                        )
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(draggedBlock != nil) // Disable scroll when dragging an event
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            updateDataManagerDate()
        }
        .onAppear {
            selectedDate = dataManager.appState.currentDay.date
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
        return dataManager.appState.currentDay.blocks
    }
    
    private func handleBlockDrop(block: TimeBlock, newTime: Date) {
        var updatedBlock = block
        updatedBlock.startTime = newTime
        dataManager.updateTimeBlock(updatedBlock)
    }
    
    private func updateDataManagerDate() {
        dataManager.appState.currentDay.date = selectedDate
        dataManager.save()
    }
}

// MARK: - Calendar Tab View

struct CalendarTabView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var showingBackfill = false
    @Binding var selectedDate: Date // Receive shared date state
    
    var body: some View {
        HStack(spacing: 0) {
            // Main calendar area
            VStack(spacing: 0) {
                // Top controls
                CalendarControlsBar(onBackfillTap: { showingBackfill = true })
                
                // Day view with shared date state
                DayPlannerView(selectedDate: $selectedDate)
                    .frame(maxHeight: .infinity)
                
                // Month view docked below (HIDDEN FOR NOW)
                // MonthView()
                //     .frame(height: 200)
            }
            
            // Right rail
            RightRailView()
                .frame(width: 300)
        }
        .sheet(isPresented: $showingBackfill) {
            EnhancedBackfillView()
                .environmentObject(dataManager)
                .environmentObject(aiService)
        }
    }
}

// MARK: - Calendar Controls Bar

struct CalendarControlsBar: View {
    let onBackfillTap: () -> Void
    @State private var showingGapFiller = false
    
    var body: some View {
        HStack {
            Text("Today")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Gap Filler") {
                    showingGapFiller = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Backfill") {
                    onBackfillTap()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.5))
        .sheet(isPresented: $showingGapFiller) {
            GapFillerView()
        }
    }
}

// MARK: - Day Planner View

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
        .onChange(of: selectedDate) { oldValue, newValue in
            updateDataManagerDate()
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
