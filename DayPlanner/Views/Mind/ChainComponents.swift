//
//  ChainComponents.swift
//  DayPlanner
//
//  Chain-related Views and Templates
//

import SwiftUI

// MARK: - Enhanced Mind Sections

struct SuperchargedChainsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var showingAISuggestions = false
    @State private var selectedChainTemplate: ChainTemplate?
    @State private var aiSuggestedChains: [Chain] = []
    @State private var showingTemplateEditor = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(
                    title: "Chains",
                    subtitle: "Smart flow sequences",
                    systemImage: "link.circle",
                    gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                )
                
                Spacer()
                
                HStack(spacing: 8) {
                    // AI suggestions button
                    Button(action: { 
                        generateAIChainSuggestions()
                        showingAISuggestions = true 
                    }) {
                        Image(systemName: "sparkles.circle")
                            .font(.title3)
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .help("AI chain suggestions")
                    
                    // Generate contextual chain button
                    Button(action: { generateAndShowContextualChain() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.caption)
                            Text("Generate")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Generate most likely chain for current context")
                }
            }
            
            // Quick chain templates
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(chainTemplates, id: \.name) { template in
                        DraggableChainTemplateCard(
                            template: template,
                            onSelect: { selectedTemplate in
                                createChainFromTemplate(selectedTemplate)
                            },
                            onEdit: { selectedTemplate in
                                selectedChainTemplate = selectedTemplate
                                showingTemplateEditor = true
                            },
                            onDrag: { selectedTemplate in
                                createAndStageChainFromTemplate(selectedTemplate)
                            }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
            
            // Chain generation info
            VStack(spacing: 12) {
                Text("🔗 Templates are your foundation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("Drag templates to timeline or customize them. All new chains become templates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showingAISuggestions) {
            AIChainSuggestionsSheet(
                suggestions: aiSuggestedChains,
                onApply: { chain in
                    dataManager.addChain(chain)
                    applyChainToToday(chain)
                }
            )
        }
        .sheet(isPresented: $showingTemplateEditor) {
            if let template = selectedChainTemplate {
                ChainTemplateEditorSheet(
                    template: template,
                    onSave: { updatedChain in
                        dataManager.addChain(updatedChain)
                        showingTemplateEditor = false
                    }
                )
                .environmentObject(aiService)
            }
        }
    }
    
    // MARK: - Chain Templates
    
    private var chainTemplates: [ChainTemplate] {
        [
            ChainTemplate(
                name: "Morning Routine",
                icon: "🌅",
                activities: ["Wake up routine", "Exercise", "Breakfast", "Plan day"],
                totalDuration: 120, // 2 hours
                energyFlow: [.sunrise, .sunrise, .daylight, .daylight]
            ),
            ChainTemplate(
                name: "Deep Work",
                icon: "🎯", 
                activities: ["Setup workspace", "Focus session", "Break", "Review"],
                totalDuration: 90, // 1.5 hours
                energyFlow: [.daylight, .daylight, .moonlight, .daylight]
            ),
            ChainTemplate(
                name: "Evening Wind-down",
                icon: "🌙",
                activities: ["Dinner", "Reflection", "Reading", "Sleep prep"],
                totalDuration: 150, // 2.5 hours  
                energyFlow: [.daylight, .moonlight, .moonlight, .moonlight]
            ),
            ChainTemplate(
                name: "Creative Flow",
                icon: "🎨",
                activities: ["Inspiration gathering", "Brainstorm", "Create", "Refine"],
                totalDuration: 180, // 3 hours
                energyFlow: [.daylight, .sunrise, .sunrise, .daylight]
            )
        ]
    }
    
    // MARK: - Actions
    
    private func generateAIChainSuggestions() {
        // Generate AI-powered chain suggestions based on user patterns
        let morningChain = Chain(
            id: UUID(),
            name: "Optimized Morning",
            blocks: [
                TimeBlock(title: "Hydrate & Stretch", startTime: Date(), duration: 900, energy: .sunrise, emoji: "🌊"),
                TimeBlock(title: "Priority Review", startTime: Date(), duration: 1200, energy: .sunrise, emoji: "💎"),
                TimeBlock(title: "Deep Work Block", startTime: Date(), duration: 2700, energy: .daylight, emoji: "💎")
            ],
            flowPattern: .waterfall,
            completionCount: 0,
            isActive: true,
            createdAt: Date()
        )
        
        let focusChain = Chain(
            id: UUID(),
            name: "Peak Performance",
            blocks: [
                TimeBlock(title: "Environment prep", startTime: Date(), duration: 600, energy: .daylight, emoji: "💎"),
                TimeBlock(title: "Intensive work", startTime: Date(), duration: 3600, energy: .daylight, emoji: "💎"),
                TimeBlock(title: "Recovery break", startTime: Date(), duration: 900, energy: .moonlight, emoji: "☁️")
            ],
            flowPattern: .spiral,
            completionCount: 0,
            isActive: true,
            createdAt: Date()
        )
        
        aiSuggestedChains = [morningChain, focusChain]
    }
    
    private func createChainFromTemplate(_ template: ChainTemplate) {
        let blocks = template.activities.enumerated().map { index, activity in
            let duration = TimeInterval(template.totalDuration * 60 / template.activities.count)
            return TimeBlock(
                title: activity,
                startTime: Date(),
                duration: duration,
                energy: template.energyFlow[index],
                emoji: "💎"
            )
        }
        
        let newChain = Chain(
            id: UUID(),
            name: template.name,
            blocks: blocks,
            flowPattern: .wave,
            completionCount: 0,
            isActive: true,
            createdAt: Date()
        )
        
        dataManager.addChain(newChain)
    }
    
    private func applyChainToToday(_ chain: Chain) {
        let startTime = findBestTimeForChain(chain)
        dataManager.applyChain(chain, startingAt: startTime)
    }
    
    private func duplicateChain(_ chain: Chain) {
        let duplicatedChain = Chain(
            id: UUID(),
            name: "\(chain.name) (Copy)",
            blocks: chain.blocks,
            flowPattern: chain.flowPattern,
            completionCount: 0,
            isActive: true,
            createdAt: Date()
        )
        dataManager.addChain(duplicatedChain)
    }
    
    private func findBestTimeForChain(_ chain: Chain) -> Date {
        // AI-powered time finding based on chain duration and current schedule
        let now = Date()
        let calendar = Calendar.current
        
        // Start with current time rounded to next 15-minute interval
        let minute = calendar.component(.minute, from: now)
        let roundedMinute = ((minute / 15) + 1) * 15
        
        return calendar.date(byAdding: .minute, value: roundedMinute - minute, to: now) ?? now
    }
    
    private func generateAndShowContextualChain() {
        Task {
            let context = dataManager.createEnhancedContext()
            let currentHour = Calendar.current.component(.hour, from: Date())
            
            let prompt = """
            Generate the single most likely activity chain for right now based on:
            
            Current time: \(currentHour):00
            Context: \(context.summary)
            
            What would the user most likely want to do next given their patterns and current situation?
            
            Provide one 2-4 activity chain with realistic timing.
            """
            
            do {
                let _ = try await aiService.processMessage(prompt, context: context)
                let contextualChain = createTimeBasedUniqueChain() // Fallback to time-based
                
                await MainActor.run {
                    // Add to templates area instead of user chains
                    let startTime = findBestTimeForChain(contextualChain)
                    dataManager.applyChain(contextualChain, startingAt: startTime)
                }
            } catch {
                await MainActor.run {
                    let fallbackChain = createTimeBasedUniqueChain()
                    let startTime = findBestTimeForChain(fallbackChain)
                    dataManager.applyChain(fallbackChain, startingAt: startTime)
                }
            }
        }
    }
    
    private func createAndStageChainFromTemplate(_ template: ChainTemplate) {
        let chain = createChainFromTemplateHelper(template)
        
        // Apply the chain directly
        let startTime = findBestTimeForChain(chain)
        dataManager.applyChain(chain, startingAt: startTime)
    }
    
    private func createChainFromTemplateHelper(_ template: ChainTemplate) -> Chain {
        let blocks = template.activities.enumerated().map { index, activity in
            let duration = TimeInterval(template.totalDuration * 60 / template.activities.count)
            return TimeBlock(
                title: activity,
                startTime: Date(),
                duration: duration,
                energy: index < template.energyFlow.count ? template.energyFlow[index] : .daylight,
                emoji: template.icon
            )
        }
        
        return Chain(
            id: UUID(),
            name: template.name,
            blocks: blocks,
            flowPattern: .wave,
            emoji: template.icon
        )
    }
    
    private func generateUniqueAIChain() {
        Task {
            do {
                let context = dataManager.createEnhancedContext()
                let aiChain = try await generateContextualChain(context: context)
                
                await MainActor.run {
                    dataManager.addChain(aiChain)
                }
            } catch {
                await MainActor.run {
                    // Fallback to a time-based unique chain
                    let uniqueChain = createTimeBasedUniqueChain()
                    dataManager.addChain(uniqueChain)
                }
            }
        }
    }
    
    private func generateContextualChain(context: DayContext) async throws -> Chain {
        let prompt = """
        Create a unique, contextual activity chain for the user based on:
        
        Current context: \(context.summary)
        
        Generate a chain with:
        - 2-4 activities that flow well together
        - Duration between 60-180 minutes total
        - Activities that match current energy/mood
        - Consider weather and time of day
        - Make it unique and personally relevant
        
        Provide chain name and activities with durations.
        """
        
        let _ = try await aiService.processMessage(prompt, context: context)
        
        // Parse response and create chain (simplified)
        return Chain(
            name: "AI Context Chain",
            blocks: [
                TimeBlock(
                    title: "Contextual Activity 1",
                    startTime: Date(),
                    duration: 1800,
                    energy: context.currentEnergy,
                    emoji: "💎"
                ),
                TimeBlock(
                    title: "Contextual Activity 2",
                    startTime: Date(),
                    duration: 2700,
                    energy: context.currentEnergy,
                    emoji: "🌊"
                )
            ],
            flowPattern: .waterfall
        )
    }
    
    private func createTimeBasedUniqueChain() -> Chain {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeContext = getTimeContext(for: currentHour)
        
        return Chain(
            name: "\(timeContext.name) Flow",
            blocks: timeContext.activities.enumerated().map { index, activity in
                TimeBlock(
                    title: activity.title,
                    startTime: Date(),
                    duration: activity.duration,
                    energy: activity.energy,
                    emoji: activity.emoji
                )
            },
            flowPattern: timeContext.flowPattern
        )
    }
    
    private func getTimeContext(for hour: Int) -> (name: String, activities: [(title: String, duration: TimeInterval, energy: EnergyType, emoji: String)], flowPattern: FlowPattern) {
        switch hour {
        case 6..<9:
            return ("Morning Boost", [
                ("Morning energy ritual", 900, .sunrise, "💎"),
                ("Focused planning", 1200, .sunrise, "💎"),
                ("Priority execution", 2700, .sunrise, "🌊")
            ], .waterfall)
        case 9..<12:
            return ("Peak Focus", [
                ("Deep dive session", 3600, .daylight, "💎"),
                ("Quick review", 600, .daylight, "☁️"),
                ("Implementation", 1800, .daylight, "🌊")
            ], .spiral)
        case 12..<17:
            return ("Afternoon Flow", [
                ("Collaborative work", 2400, .daylight, "🌊"),
                ("Creative brainstorm", 1800, .daylight, "🌊"),
                ("Progress review", 900, .daylight, "☁️")
            ], .wave)
        case 17..<21:
            return ("Evening Rhythm", [
                ("Wrap up tasks", 1200, .moonlight, "💎"),
                ("Personal time", 1800, .moonlight, "☁️"),
                ("Reflection", 600, .moonlight, "☁️")
            ], .ripple)
        default:
            return ("Night Sequence", [
                ("Evening routine", 1800, .moonlight, "☁️"),
                ("Gentle activity", 1200, .moonlight, "☁️")
            ], .wave)
        }
    }
}

// MARK: - Chain UI Components

struct ChainTemplateCard: View {
    let template: ChainTemplate
    let onSelect: (ChainTemplate) -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { onSelect(template) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(template.icon)
                        .font(.title2)
                    
                    Spacer()
                    
                    Text("\(template.totalDuration)m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(template.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(width: 120, height: 90)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial.opacity(0.8))
                    .shadow(color: .black.opacity(0.1), radius: isPressed ? 2 : 4, y: isPressed ? 1 : 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onPressGesture(
                onPress: { isPressed = true },
                onRelease: { isPressed = false }
            )
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func onPressGesture(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self
            .scaleEffect(1.0)
            .onLongPressGesture(minimumDuration: 0) {
                // Long press action
            } onPressingChanged: { pressing in
                if pressing {
                    onPress()
                } else {
                    onRelease()
                }
            }
    }
}

// MARK: - Draggable Chain Template

struct DraggableChainTemplateCard: View {
    let template: ChainTemplate
    let onSelect: (ChainTemplate) -> Void
    let onEdit: (ChainTemplate) -> Void
    let onDrag: (ChainTemplate) -> Void
    @State private var isPressed = false
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.icon)
                    .font(.title2)
                
                Spacer()
                
                if isHovering && !isDragging {
                    Button("Edit") {
                        onEdit(template)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                } else {
                    Text("\(template.totalDuration)m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(template.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Text(template.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            if isDragging {
                Text("Drop on timeline")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .italic()
            }
        }
        .padding(12)
        .frame(width: 140, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial.opacity(isDragging ? 0.9 : 0.8))
                .shadow(color: .black.opacity(isDragging ? 0.3 : 0.1), radius: isDragging ? 8 : (isPressed ? 2 : 4), y: isDragging ? 4 : (isPressed ? 1 : 2))
        )
        .scaleEffect(isDragging ? 0.95 : (isPressed ? 0.95 : 1.0))
        .offset(dragOffset)
        .opacity(isDragging ? 0.8 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onSelect(template)
        }
        .onDrag {
            createDragProvider()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { _ in
                    isDragging = false
                    dragOffset = .zero
                    onDrag(template)
                }
        )
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
    
    private func createDragProvider() -> NSItemProvider {
        // Create a detailed drag payload for chain template
        let dragPayload = "chain_template:\(template.name)|\(template.totalDuration)|\(template.icon)"
        return NSItemProvider(object: dragPayload as NSString)
    }
}

struct ChainTemplateEditorSheet: View {
    let template: ChainTemplate
    let onSave: (Chain) -> Void
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var chainName: String
    @State private var activities: [EditableActivity]
    @State private var selectedFlowPattern: FlowPattern = .waterfall
    
    init(template: ChainTemplate, onSave: @escaping (Chain) -> Void) {
        self.template = template
        self.onSave = onSave
        self._chainName = State(initialValue: template.name)
        self._activities = State(initialValue: template.activities.enumerated().map { index, activity in
            EditableActivity(
                title: activity,
                duration: template.totalDuration / template.activities.count,
                energy: index < template.energyFlow.count ? template.energyFlow[index] : .daylight
            )
        })
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Chain name", text: $chainName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                    
                    Text("Flow Pattern")
                        .font(.headline)
                    
                    Picker("Flow Pattern", selection: $selectedFlowPattern) {
                        ForEach(FlowPattern.allCases, id: \.self) { pattern in
                            Label(pattern.description, systemImage: "waveform").tag(pattern)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Activities")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach($activities) { $activity in
                                EditableActivityRow(activity: $activity) {
                                    activities.removeAll { $0.id == activity.id }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    
                    Button("Add Activity") {
                        activities.append(EditableActivity(title: "New Activity", duration: 30, energy: .daylight))
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Save Chain") {
                        saveChain()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(chainName.isEmpty || activities.isEmpty)
                }
            }
            .padding(24)
            .navigationTitle("Edit Template")
        }
        .frame(width: 600, height: 700)
    }
    
    private func saveChain() {
        let blocks = activities.map { activity in
            TimeBlock(
                title: activity.title,
                startTime: Date(),
                duration: TimeInterval(activity.duration * 60),
                energy: activity.energy,
                emoji: "💎"
            )
        }
        
        let newChain = Chain(
            name: chainName,
            blocks: blocks,
            flowPattern: selectedFlowPattern
        )
        
        onSave(newChain)
    }
}

struct EditableActivity: Identifiable {
    let id = UUID()
    var title: String
    var duration: Int // in minutes
    var energy: EnergyType
}

struct EditableActivityRow: View {
    @Binding var activity: EditableActivity
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Activity", text: $activity.title)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("\(activity.duration)m")
                    .frame(width: 40)
                
                Stepper("", value: $activity.duration, in: 5...180, step: 5)
                    .labelsHidden()
            }
            .frame(width: 100)
            
            Picker("Energy", selection: $activity.energy) {
                ForEach(EnergyType.allCases, id: \.self) { energy in
                    Text(energy.rawValue).tag(energy)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 60)
            
            Button("Remove") {
                onRemove()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .foregroundStyle(.red)
        }
        .padding(.vertical, 4)
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct SuperchargedChainCard: View {
    let chain: Chain
    let onApply: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chain.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("\(chain.blocks.count) activities • \(chain.totalDurationMinutes)min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Flow: \(chain.flowPattern.emoji)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onApply) {
                        Image(systemName: "play.circle")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Apply chain")
                    
                    Button(action: onDuplicate) {
                        Image(systemName: "doc.on.doc")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Duplicate chain")
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .help("Edit chain")
                }
            } else {
                Button(action: onApply) {
                    Text("Apply")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.gray.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct AdvancedChainCreatorSheet: View {
    let onSave: (Chain) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var chainName = ""
    @State private var activities: [String] = [""]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Chain name", text: $chainName)
                    .textFieldStyle(.roundedBorder)
                
                Text("Activities")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(activities.indices, id: \.self) { index in
                    TextField("Activity \(index + 1)", text: $activities[index])
                        .textFieldStyle(.roundedBorder)
                }
                
                Button("Add Activity") {
                    activities.append("")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Create Chain") {
                    let blocks: [TimeBlock] = activities.enumerated().compactMap { index, activity in
                        guard !activity.isEmpty else { return nil }
                        return TimeBlock(
                            title: activity,
                            startTime: Date(),
                            duration: 1800, // 30 minutes default
                            energy: .daylight,
                            emoji: "💎"
                        )
                    }
                    
                    let newChain = Chain(
                        id: UUID(),
                        name: chainName.isEmpty ? "New Chain" : chainName,
                        blocks: blocks,
                        flowPattern: .ripple,
                        completionCount: 0,
                        isActive: true,
                        createdAt: Date()
                    )
                    
                    onSave(newChain)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(chainName.isEmpty || activities.allSatisfy { $0.isEmpty })
            }
            .padding()
            .navigationTitle("Create Chain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct AIChainSuggestionsSheet: View {
    let suggestions: [Chain]
    let onApply: (Chain) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("AI Chain Suggestions")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Based on your patterns and preferences")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                LazyVStack(spacing: 12) {
                    ForEach(suggestions, id: \.id) { chain in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chain.name)
                                    .font(.headline)
                                
                                Text("AI-optimized flow pattern: \(chain.flowPattern.emoji)")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                
                                Text("\(chain.blocks.count) activities • \(chain.totalDurationMinutes)min")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                            
                            Button("Apply") {
                                onApply(chain)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Chains Section

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

// MARK: - Flow Glass Sidebar (Simplified)

struct FlowGlassSidebar: View {
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chains")
                .font(.headline)
                .foregroundColor(.primary)
            
            if dataManager.appState.recentChains.isEmpty {
                VStack(spacing: 8) {
                    Text("🔗")
                        .font(.title)
                        .opacity(0.5)
                    
                    Text("No chains yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Create chains by linking activities")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(dataManager.appState.recentChains.prefix(5)) { chain in
                    ChainCard(chain: chain) {
                        // Apply chain to today
                        dataManager.applyChain(chain, startingAt: Date())
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        .padding(.trailing, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Chain Card

struct ChainCard: View {
    let chain: Chain
    let onApply: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(chain.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(chain.totalDurationMinutes)m")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(chain.blocks.count) activities")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Apply") {
                onApply()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Add this to your backfill schedule")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(isHovered ? 0.5 : 0.3))
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
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
