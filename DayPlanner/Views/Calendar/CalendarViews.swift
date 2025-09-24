//
//  CalendarViews.swift
//  DayPlanner
//
//  Calendar-related views extracted from DayPlannerApp.swift
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
    @State private var showingChainsTemplates = false
    @State private var showingTodoList = false // Default to hiding todo list
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar header with elegant styling
            CalendarPanelHeader(
                selectedDate: $selectedDate,
                showingMonthView: $showingMonthView,
                showingBackfillTemplates: $showingBackfillTemplates,
                showingChainsTemplates: $showingChainsTemplates,
                showingTodoList: $showingTodoList,
                onPillarDayTap: { showingPillarDay = true },
                isDefaultMonthView: true, // Month view is shown by default
                onBackToCalendar: {
                    // Return to monthly calendar view
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingMonthView = true
                    }
                }
            )
            
            // Month view (expandable/collapsible) - switches to hourly view on day click
            if showingMonthView {
                MonthViewExpanded(
                    selectedDate: $selectedDate, 
                    dataManager: dataManager,
                    onDayClick: {
                        // Switch to hourly view when a day is clicked
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingMonthView = false
                            showingTodoList = false // Hide todo list when switching to day view
                        }
                    }
                )
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
            
            // Chains templates dropdown (expandable/collapsible)
            if showingChainsTemplates {
                ChainsTemplatesView(selectedDate: selectedDate)
                    .frame(height: 200)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingChainsTemplates)
            }
            
            // Day view - enhanced with liquid glass styling (only show when not in month view)
            if !showingMonthView {
                EnhancedDayView(selectedDate: $selectedDate)
                    .frame(maxHeight: showingTodoList ? nil : .infinity)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingMonthView)
            }
            
            // To-Do section (expandable/collapsible from bottom)
            if showingTodoList {
                TodoListView()
                    .frame(height: 300)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .bottom))
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingTodoList)
            }
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
    @Binding var showingChainsTemplates: Bool
    @Binding var showingTodoList: Bool
    let onPillarDayTap: () -> Void
    let isDefaultMonthView: Bool // Track if month view is shown by default
    let onBackToCalendar: (() -> Void)? // Callback to return to calendar view
    
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
                // Back to calendar button - show when in day view mode
                if !showingMonthView {
                    Button(action: { 
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            onBackToCalendar?()
                        }
                    }) {
                        Image(systemName: "calendar.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .symbolEffect(.bounce, value: !showingMonthView)
                    }
                    .buttonStyle(.plain)
                }
                
                // Month expand/collapse button - only show when not default view and in month view
                if !isDefaultMonthView && showingMonthView {
                    Button(action: { 
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingMonthView.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .symbolEffect(.bounce, value: showingMonthView)
                    }
                    .buttonStyle(.plain)
                }
                
                // To-Do expand/collapse button
                Button(action: { 
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingTodoList.toggle()
                    }
                }) {
                    Image(systemName: showingTodoList ? "chevron.down.circle.fill" : "checklist")
                        .font(.title2)
                        .foregroundStyle(showingTodoList ? .blue : .secondary)
                        .symbolEffect(.bounce, value: showingTodoList)
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
                    
                    Button("Chains") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingChainsTemplates.toggle()
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
