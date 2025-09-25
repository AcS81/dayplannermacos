// MARK: - Enhanced Goal Components

import SwiftUI

struct EnhancedGoalCard: View {
    let goal: Goal
    let onTap: () -> Void
    let onBreakdown: () -> Void
    let onToggleState: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Goal state indicator with click-to-toggle
            Button(action: onToggleState) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(goalStateColor)
                    .frame(width: 6, height: 24)
                    .overlay(
                        Text(goal.state.rawValue.prefix(1))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(.plain)
            .help("Toggle goal state: \(goal.state.rawValue)")
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(goal.emoji)
                        .font(.caption)
                    
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                }
                
                Text(goal.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("Importance: \(goal.importance)/5")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if goal.progress > 0 {
                        Text("Progress: \(Int(goal.progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    
                    if goal.needsBreakdown {
                        Text("Needs breakdown")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            if isHovering {
                HStack(spacing: 6) {
                    Button("Breakdown") {
                        onBreakdown()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("AI breakdown into chains/pillars/events")
                    
                    Button("Edit") {
                        onTap()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            } else {
                Circle()
                    .fill(goal.isActive ? .green : .orange)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial.opacity(isHovering ? 0.6 : 0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(goalStateColor.opacity(isHovering ? 0.4 : 0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in isHovering = hovering }
        .onTapGesture { onTap() }
    }
    
    private var goalStateColor: Color {
        switch goal.state {
        case .draft: return .orange
        case .on: return .green
        case .off: return .gray
        }
    }
}

struct EmptyGoalsCard: View {
    let onCreateGoal: () -> Void
    
    var body: some View {
        Button(action: onCreateGoal) {
            VStack(spacing: 12) {
                Text("🎯")
                    .font(.title)
                    .opacity(0.6)
                
                Text("Create Your First Goal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Goals help AI understand your priorities and create actionable plans")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("+ Create Goal")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(.green)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}

struct EnhancedGoalCreatorSheet: View {
    let onGoalCreated: (Goal) -> Void
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var goalTitle = ""
    @State private var goalDescription = ""
    @State private var importance = 3
    @State private var selectedState: GoalState = .draft
    @State private var selectedEmoji = "🎯"
    @State private var relatedPillarIds: [UUID] = []
    @State private var aiSuggestions = ""
    @State private var isGeneratingAI = false
    @State private var targetDate: Date?
    @State private var hasTargetDate = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Goal")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            TextField("Goal title", text: $goalTitle)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: goalTitle) { _, _ in
                                    generateAISuggestions()
                                }
                            
                            TextField("🎯", text: $selectedEmoji)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                        
                        TextField("Description (optional)", text: $goalDescription, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Importance: \(importance)/5")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Slider(value: Binding(
                                get: { Double(importance) },
                                set: { importance = Int($0) }
                            ), in: 1...5, step: 1)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("State")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("State", selection: $selectedState) {
                                ForEach(GoalState.allCases, id: \.self) { state in
                                    Text(state.rawValue).tag(state)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Set target date", isOn: $hasTargetDate)
                        
                        if hasTargetDate {
                            DatePicker("Target date", selection: Binding(
                                get: { targetDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date() },
                                set: { targetDate = $0 }
                            ), displayedComponents: .date)
                        }
                    }
                }
                
                // AI Suggestions
                if !aiSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Suggestions")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(aiSuggestions)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Goal") {
                        createGoal()
                    }
                    .disabled(goalTitle.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 700)
    }
    
    private func generateAISuggestions() {
        guard !goalTitle.isEmpty else { return }
        
        isGeneratingAI = true
        
        Task {
            do {
                let prompt = """
                User wants to create a goal: "\(goalTitle)"
                Description: "\(goalDescription)"
                
                Provide 2-3 sentence suggestion on:
                1. How to break this down into actionable steps
                2. What chains or pillars might support this goal
                3. Realistic timeline considerations
                
                Keep it encouraging and practical.
                """
                
                let context = DayContext(
                    date: Date(),
                    existingBlocks: [],
                    currentEnergy: .daylight,
                    preferredEmojis: ["🌊"],
                    availableTime: 3600,
                    mood: .crystal
                )
                
                let response = try await aiService.processMessage(prompt, context: context)
                
                await MainActor.run {
                    aiSuggestions = response.text
                    isGeneratingAI = false
                }
            } catch {
                await MainActor.run {
                    aiSuggestions = "Consider breaking this goal into smaller, specific actions you can track daily or weekly."
                    isGeneratingAI = false
                }
            }
        }
    }
    
    private func createGoal() {
        let newGoal = Goal(
            title: goalTitle,
            description: goalDescription,
            state: selectedState,
            importance: importance,
            groups: [],
            targetDate: hasTargetDate ? targetDate : nil,
            emoji: selectedEmoji,
            relatedPillarIds: relatedPillarIds
        )
        
        onGoalCreated(newGoal)
    }
}

struct AIGoalBreakdownSheet: View {
    let goal: Goal
    let onActionsGenerated: ([GoalBreakdownAction]) -> Void
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedGoal: Goal
    @State private var breakdownActions: [GoalBreakdownAction] = []
    @State private var isGenerating = true
    @State private var analysisText = ""
    
    init(goal: Goal, onActionsGenerated: @escaping ([GoalBreakdownAction]) -> Void) {
        self.goal = goal
        self.onActionsGenerated = onActionsGenerated
        self._editedGoal = State(initialValue: goal)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("AI Goal Breakdown")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Goal editing section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Goal Details")
                        .font(.headline)
                    
                    HStack {
                        TextField("Goal title", text: $editedGoal.title)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("🎯", text: $editedGoal.emoji)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                    
                    TextField("Description", text: $editedGoal.description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .onChange(of: editedGoal.description) { _, _ in
                            // Regenerate breakdown when description changes
                            regenerateBreakdown()
                        }
                }
                
                if isGenerating {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Analyzing '\(editedGoal.title)' for breakdown...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !analysisText.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("AI Analysis")
                                        .font(.headline)
                                    
                                    Text(analysisText)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .padding()
                                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested Actions")
                                    .font(.headline)
                                
                                ForEach(Array(breakdownActions.enumerated()), id: \.offset) { index, action in
                                    ActionCard(action: action, index: index)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Apply All & Update Goal") {
                            // Update the goal first
                            let updatedActions = breakdownActions + [.updateGoal(editedGoal)]
                            onActionsGenerated(updatedActions)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(breakdownActions.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Goal Breakdown")
        }
        .frame(width: 700, height: 600)
        .task {
            await generateBreakdown()
        }
    }
    
    private func generateBreakdown() async {
        // Simple AI-generated breakdown for now
        await MainActor.run {
            analysisText = "This goal can be achieved through consistent daily actions and strategic planning."
            
            // Create sample breakdown actions
            breakdownActions = [
                .createPillar(Pillar(
                    name: "Daily \(goal.title) Work",
                    description: "Daily activities supporting \(goal.title)",
                    frequency: .daily,
                    minDuration: 1800,
                    maxDuration: 7200,
                    preferredTimeWindows: [],
                    overlapRules: [],
                    quietHours: []
                )),
                .createChain(Chain(
                    name: "\(goal.title) Sprint",
                    blocks: [
                        TimeBlock(
                            title: "Plan \(goal.title)",
                            startTime: Date(),
                            duration: 1800,
                            energy: .daylight,
                            emoji: "💎"
                        ),
                        TimeBlock(
                            title: "Execute \(goal.title) tasks",
                            startTime: Date(),
                            duration: 3600,
                            energy: .daylight,
                            emoji: "🌊"
                        )
                    ],
                    flowPattern: .waterfall
                ))
            ]
            
            isGenerating = false
        }
    }
    
    private func regenerateBreakdown() {
        isGenerating = true
        Task {
            await generateBreakdown()
        }
    }
}

struct ActionCard: View {
    let action: GoalBreakdownAction
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(actionColor, in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(actionTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(actionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: actionIcon)
                .font(.title3)
                .foregroundStyle(actionColor)
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var actionTitle: String {
        switch action {
        case .createChain(let chain): return "Create Chain: \(chain.name)"
        case .createPillar(let pillar): return "Create Pillar: \(pillar.name)"
        case .createEvent(let block): return "Schedule: \(block.title)"
        case .updateGoal: return "Update Goal Structure"
        }
    }
    
    private var actionDescription: String {
        switch action {
        case .createChain(let chain): return "\(chain.blocks.count) activities, \(chain.totalDurationMinutes)min"
        case .createPillar(let pillar): return "\(pillar.frequencyDescription) pillar"
        case .createEvent(let block): return "\(block.durationMinutes) minutes"
        case .updateGoal: return "Enhance goal structure"
        }
    }
    
    private var actionIcon: String {
        switch action {
        case .createChain: return "link"
        case .createPillar: return "building.columns"
        case .createEvent: return "calendar.badge.plus"
        case .updateGoal: return "pencil.circle"
        }
    }
    
    private var actionColor: Color {
        switch action {
        case .createChain: return .blue
        case .createPillar: return .purple
        case .createEvent: return .green
        case .updateGoal: return .orange
        }
    }
}

struct GoalDetailSheet: View {
    let goal: Goal
    let onSave: (Goal) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedGoal: Goal
    @State private var showingDeleteAlert = false
    
    init(goal: Goal, onSave: @escaping (Goal) -> Void, onDelete: @escaping () -> Void) {
        self.goal = goal
        self.onSave = onSave
        self.onDelete = onDelete
        self._editedGoal = State(initialValue: goal)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Goal title", text: $editedGoal.title)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                    
                    TextField("Description", text: $editedGoal.description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Importance: \(editedGoal.importance)/5")
                            .font(.subheadline)
                        
                        Slider(value: Binding(
                            get: { Double(editedGoal.importance) },
                            set: { editedGoal.importance = Int($0) }
                        ), in: 1...5, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("State")
                            .font(.subheadline)
                        
                        Picker("State", selection: $editedGoal.state) {
                            ForEach(GoalState.allCases, id: \.self) { state in
                                Text(state.rawValue).tag(state)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                if goal.progress > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress: \(Int(goal.progress * 100))%")
                            .font(.subheadline)
                        
                        ProgressView(value: goal.progress)
                            .progressViewStyle(.linear)
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Delete Goal") {
                        showingDeleteAlert = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Button("Save Changes") {
                        onSave(editedGoal)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editedGoal.title.isEmpty)
                }
            }
            .padding(24)
            .navigationTitle("Edit Goal")
        }
        .frame(width: 600, height: 500)
        .alert("Delete Goal", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete '\(goal.title)'? This action cannot be undone.")
        }
    }
}

struct AuroraDreamCard: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("🌈 Dream Canvas")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Visualize your future")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [.orange.opacity(0.1), .pink.opacity(0.1), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.title2)
                .opacity(0.6)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(.ultraThinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}

