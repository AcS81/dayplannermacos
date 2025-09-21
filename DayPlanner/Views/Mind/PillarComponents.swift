//
//  PillarComponents.swift
//  DayPlanner
//
//  Pillar Creation and Management Views
//

import SwiftUI

struct CrystalPillarsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingPillarCreator = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Pillars", 
                subtitle: "Life foundations",
                systemImage: "building.columns.circle",
                gradient: LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing),
                onAction: { showingPillarCreator = true }
            )
            
            if dataManager.appState.pillars.isEmpty {
                EmptyPillarsCard {
                    showingPillarCreator = true
                }
            } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(dataManager.appState.pillars) { pillar in
                        EnhancedPillarCard(pillar: pillar)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPillarCreator) {
            ComprehensivePillarCreatorSheet { newPillar in
                dataManager.addPillar(newPillar)
                showingPillarCreator = false
            }
        }
    }
}

struct EmptyPillarsCard: View {
    let onCreatePillar: () -> Void
    
    var body: some View {
        Button(action: onCreatePillar) {
            VStack(spacing: 12) {
                Text("⛰️")
                    .font(.title)
                    .opacity(0.6)
                
                Text("Create Your First Pillar")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Pillars are recurring activities that AI can automatically schedule for you")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("+ Create Pillar")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.15), in: Capsule())
                    .foregroundStyle(.blue)
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

// MARK: - Comprehensive Pillar Creator

struct ComprehensivePillarEditorSheet: View {
    let pillar: Pillar
    let onPillarUpdated: (Pillar) -> Void
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var description: String
    @State private var type: PillarType
    @State private var frequency: PillarFrequency
    @State private var minDuration: TimeInterval
    @State private var maxDuration: TimeInterval
    @State private var eventConsiderationEnabled: Bool
    @State private var wisdomText: String
    @State private var emoji: String
    @State private var color: CodableColor
    
    init(pillar: Pillar, onPillarUpdated: @escaping (Pillar) -> Void) {
        self.pillar = pillar
        self.onPillarUpdated = onPillarUpdated
        self._name = State(initialValue: pillar.name)
        self._description = State(initialValue: pillar.description)
        self._type = State(initialValue: pillar.type)
        self._frequency = State(initialValue: pillar.frequency)
        self._minDuration = State(initialValue: pillar.minDuration)
        self._maxDuration = State(initialValue: pillar.maxDuration)
        self._eventConsiderationEnabled = State(initialValue: pillar.eventConsiderationEnabled)
        self._wisdomText = State(initialValue: pillar.wisdomText ?? "")
        self._emoji = State(initialValue: pillar.emoji)
        self._color = State(initialValue: pillar.color)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Edit Pillar")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Core life principle that guides your AI scheduling")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Name and Emoji
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Identity", subtitle: "Name and visual representation", systemImage: "person.circle", gradient: LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Emoji")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                EmojiPickerButton(selectedEmoji: $emoji)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                TextField("e.g., Exercise, Deep Work", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            TextField("What this pillar represents in your life", text: $description)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    // Type and Frequency
                    VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Behavior", subtitle: "How this pillar works", systemImage: "gearshape", gradient: LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing))
                        
                        Picker("Type", selection: $type) {
                            ForEach(PillarType.allCases, id: \.self) { pillarType in
                                Text(pillarType.rawValue).tag(pillarType)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text(type.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if type == .actionable {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Frequency")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Picker("Frequency", selection: $frequency) {
                                    ForEach(PillarFrequency.allCases, id: \.self) { freq in
                                        Text(freq.displayName).tag(freq)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Min Duration")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        Stepper("\(Int(minDuration/60))m", value: Binding(
                                            get: { Int(minDuration/60) },
                                            set: { minDuration = TimeInterval($0 * 60) }
                                        ), in: 5...240, step: 5)
                                        .font(.caption)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Max Duration")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        Stepper("\(Int(maxDuration/60))m", value: Binding(
                                            get: { Int(maxDuration/60) },
                                            set: { maxDuration = TimeInterval($0 * 60) }
                                        ), in: 15...480, step: 15)
                                        .font(.caption)
                                    }
                                }
                            }
                            
                        }
                        
                        if type == .principle {
                            Toggle("Consider for AI guidance", isOn: $eventConsiderationEnabled)
                                .font(.caption)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    // Wisdom Text (for principles)
                    if type == .principle {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Wisdom", subtitle: "Core principle for AI guidance", systemImage: "lightbulb", gradient: LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                            
                            TextField("The deeper meaning or principle behind this pillar", text: $wisdomText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
            // .navigationBarHidden(true) // Not available on macOS
        }
        // .navigationViewStyle(.stack) // Not available on macOS
        .frame(width: 600, height: 700)
        .overlay(alignment: .topTrailing) {
            Button("Done") {
                savePillar()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .overlay(alignment: .topLeading) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding()
        }
    }
    
    private func savePillar() {
        let updatedPillar = Pillar(
            id: pillar.id,
            name: name,
            description: description,
            type: type,
            frequency: frequency,
            minDuration: minDuration,
            maxDuration: maxDuration,
            preferredTimeWindows: pillar.preferredTimeWindows,
            overlapRules: pillar.overlapRules,
            quietHours: pillar.quietHours,
            eventConsiderationEnabled: eventConsiderationEnabled,
            wisdomText: wisdomText.isEmpty ? nil : wisdomText,
            color: color,
            emoji: emoji.isEmpty ? "🏛️" : emoji,
            relatedGoalId: pillar.relatedGoalId
        )
        
        onPillarUpdated(updatedPillar)
    }
}

struct ComprehensivePillarCreatorSheet: View {
    let onPillarCreated: (Pillar) -> Void
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var pillarName = ""
    @State private var pillarDescription = ""
    @State private var wisdomText = ""
    @State private var selectedFrequency: PillarFrequency = .daily
    @State private var minDuration = 30
    @State private var maxDuration = 120
    @State private var isPrincipleOnly = false
    @State private var selectedColor: Color = .blue
    @State private var selectedEmoji = "🏛️"
    @State private var relatedGoalId: UUID?
    @State private var isGeneratingAI = false
    @State private var aiSuggestions = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Basic info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Information")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 12) {
                            TextField("Pillar name", text: $pillarName)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: pillarName) { _, _ in
                                        generateAISuggestions()
                                }
                            
                            // Emoji picker
                            EmojiPickerButton(selectedEmoji: $selectedEmoji)
                        }
                        
                        TextField("Description", text: $pillarDescription, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                        
                        // Principle vs actionable toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Principle only (guides AI, doesn't create events)", isOn: $isPrincipleOnly)
                                        .font(.subheadline)
                            
                            if isPrincipleOnly {
                                TextField("Core wisdom/principle", text: $wisdomText, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...4)
                                    .help("This wisdom guides all AI decisions")
                            }
                        }
                    }
                    
                    // Scheduling settings (only for actionable pillars)
                    if !isPrincipleOnly {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Scheduling")
                            .font(.headline)
                            .fontWeight(.semibold)
                                
                                Picker("Frequency", selection: $selectedFrequency) {
                                    Text("Daily").tag(PillarFrequency.daily)
                                    Text("3x per week").tag(PillarFrequency.weekly(3))
                                    Text("Weekly").tag(PillarFrequency.weekly(1))
                                    Text("As needed").tag(PillarFrequency.asNeeded)
                                }
                                .pickerStyle(.segmented)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                    Text("Duration: \(minDuration)-\(maxDuration) min")
                                        .font(.subheadline)
                                        
                                    HStack {
                                        Slider(value: Binding(
                                            get: { Double(minDuration) },
                                            set: { minDuration = Int($0) }
                                        ), in: 15...120, step: 15)
                                        Text("\(minDuration)m")
                                            .frame(width: 35)
                                    }
                                    
                                    HStack {
                                        Slider(value: Binding(
                                            get: { Double(maxDuration) },
                                            set: { maxDuration = Int($0) }
                                        ), in: 30...240, step: 15)
                                        Text("\(maxDuration)m")
                                            .frame(width: 35)
                                    }
                                }
                            }
                            
                        }
                    }
                    
                    // Goal relation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal Connection")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                        Picker("Related goal", selection: $relatedGoalId) {
                            Text("No goal connection").tag(nil as UUID?)
                            ForEach(dataManager.appState.goals) { goal in
                                Text(goal.title).tag(goal.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // AI suggestions
                    if !aiSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI Suggestions")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Text(aiSuggestions)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding()
                                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Color picker
                    ColorPicker("Pillar color", selection: $selectedColor)
                }
                .padding(24)
            }
            .navigationTitle("Create Pillar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create & Auto-populate") {
                        createPillarWithAI()
                    }
                .disabled(pillarName.isEmpty)
            }
            }
        }
        .frame(width: 600, height: 700)
    }
    
    private func generateAISuggestions() {
        guard !pillarName.isEmpty else { return }
        
        isGeneratingAI = true
        
        Task {
            let prompt = """
            User creating pillar: "\(pillarName)"
            
            Suggest optimal:
            - Description (1 sentence)
            - Frequency (daily/weekly/etc)
            - Duration range
            - Whether this should be principle-only or actionable
            
            Brief response.
            """
            
            do {
                let context = dataManager.createEnhancedContext()
                let response = try await aiService.processMessage(prompt, context: context)
                
                await MainActor.run {
                    aiSuggestions = response.text
                    isGeneratingAI = false
                }
            } catch {
                await MainActor.run {
                    aiSuggestions = "This looks like a good pillar. Consider if it should create events or just guide decisions."
                    isGeneratingAI = false
                }
            }
        }
    }
    
    private func createPillarWithAI() {
        Task {
            // First create basic pillar
            let newPillar = Pillar(
            name: pillarName,
                description: pillarDescription.isEmpty ? "AI will enhance this" : pillarDescription,
                type: isPrincipleOnly ? .principle : .actionable,
            frequency: selectedFrequency,
                minDuration: isPrincipleOnly ? 0 : TimeInterval(minDuration * 60),
                maxDuration: isPrincipleOnly ? 0 : TimeInterval(maxDuration * 60),
                eventConsiderationEnabled: true,
                wisdomText: isPrincipleOnly ? wisdomText : nil,
                color: CodableColor(selectedColor),
                emoji: selectedEmoji,
                relatedGoalId: relatedGoalId
            )
        
            // Then enhance with AI
            do {
                let enhancedPillar = try await enhancePillarWithAI(newPillar)
                
                await MainActor.run {
                    onPillarCreated(enhancedPillar)
                }
            } catch {
                await MainActor.run {
        onPillarCreated(newPillar)
                }
            }
        }
    }
    
    private func enhancePillarWithAI(_ pillar: Pillar) async throws -> Pillar {
        let context = dataManager.createEnhancedContext()
        let prompt = """
        Enhance this pillar based on user patterns:
        Name: \(pillar.name)
        Type: \(pillar.type.rawValue)
        
        User context: \(context.summary)
        
        Provide enhanced description and if principle, core wisdom text.
        """
        
        let response = try await aiService.processMessage(prompt, context: context)
        
        var enhanced = pillar
        enhanced.description = response.text
        if pillar.isPrinciple && enhanced.wisdomText?.isEmpty != false {
            enhanced.wisdomText = "Live by: \(response.text)"
        }
        
        return enhanced
    }
}

struct TimeWindowCreatorSheet: View {
    let onWindowCreated: (TimeWindow) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var endHour = 10
    @State private var endMinute = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Time Window")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("When is this activity best scheduled?")
                    .font(.subheadline)
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Time")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        HStack {
                            Picker("Hour", selection: $startHour) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour):00").tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 80)
                            
                            Picker("Minute", selection: $startMinute) {
                                ForEach([0, 15, 30, 45], id: \.self) { minute in
                                    Text(":\(String(format: "%02d", minute))").tag(minute)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("End Time")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        HStack {
                            Picker("Hour", selection: $endHour) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour):00").tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 80)
                            
                            Picker("Minute", selection: $endMinute) {
                                ForEach([0, 15, 30, 45], id: \.self) { minute in
                                    Text(":\(String(format: "%02d", minute))").tag(minute)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)
                        }
                    }
                }
            }
            
            Text("Current window: \(String(format: "%02d:%02d", startHour, startMinute)) - \(String(format: "%02d:%02d", endHour, endMinute))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add Window") {
                    let newWindow = TimeWindow(
                        startHour: startHour,
                        startMinute: startMinute,
                        endHour: endHour,
                        endMinute: endMinute
                    )
                    onWindowCreated(newWindow)
                }
                .buttonStyle(.borderedProminent)
                .disabled(endHour < startHour || (endHour == startHour && endMinute <= startMinute))
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EnhancedPillarCard: View {
    let pillar: Pillar
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var isHovering = false
    @State private var showingPillarDetail = false
    
    var body: some View {
        Button(action: { showingPillarDetail = true }) {
            VStack(spacing: 8) {
                // Pillar emoji
                Text(pillar.emoji)
                    .font(.title2)
                    .frame(height: 24)
                
                Text(pillar.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                // Frequency status
                VStack(spacing: 2) {
                    Text(pillar.frequencyDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(isHovering ? 0.6 : 0.3), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(pillar.color.color.opacity(isHovering ? 0.5 : 0.2), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        // No animation to prevent flashing
        .onHover { hovering in 
            isHovering = hovering 
        }
        .sheet(isPresented: $showingPillarDetail) {
            ComprehensivePillarEditorSheet(pillar: pillar) { updatedPillar in
                dataManager.updatePillar(updatedPillar)
            }
        }
    }
}

struct PillarCrystalCard: View {
    let pillar: Pillar
    @State private var isHovering = false
    @State private var showingPillarDetail = false
    
    var body: some View {
        Button(action: { showingPillarDetail = true }) {
            VStack(spacing: 8) {
                // Crystal icon
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.6), .pink.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                
                Text(pillar.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(isHovering ? 0.5 : 0.3), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.purple.opacity(isHovering ? 0.4 : 0.2), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in isHovering = hovering }
        .sheet(isPresented: $showingPillarDetail) {
            Text("Pillar Detail - \(pillar.name)")
                .padding()
        }
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
