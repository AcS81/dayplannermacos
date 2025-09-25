// MARK: - Calendar Panel

import SwiftUI

struct CalendarPanel: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Binding var selectedDate: Date
    @Binding var showingMonthView: Bool
    @State private var showingTodoList = false // Default to hiding todo list
    @State private var showingRecommendations = true
    @State private var ghostSuggestions: [Suggestion] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar header with elegant styling
            CalendarPanelHeader(
                selectedDate: $selectedDate,
                showingMonthView: $showingMonthView,
                showingRecommendations: $showingRecommendations,
                showingTodoList: $showingTodoList,
                ghostCount: ghostSuggestions.count,
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
            
            // Day view - enhanced with liquid glass styling (only show when not in month view)
            if !showingMonthView {
                EnhancedDayView(
                    selectedDate: $selectedDate,
                    ghostSuggestions: $ghostSuggestions,
                    showingRecommendations: $showingRecommendations
                )
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
        .padding(.bottom, 96)
        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.leading, 8)  // Moved further left
        .padding(.trailing, 4)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            CalendarChatBar()
                .padding(.horizontal, 32)
                .padding(.bottom, 18)
        }
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
