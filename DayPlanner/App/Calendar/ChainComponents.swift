// MARK: - Flow Glass Sidebar (Simplified)

import SwiftUI

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

// MARK: - Chain Option Card

struct ChainOptionCard: View {
    let chain: Chain
    let canAddBefore: Bool
    let canAddAfter: Bool
    let onAdd: (ChainPosition) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chain.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(chain.blocks.count) activities • \(chain.totalDurationMinutes)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if chain.completionCount >= 3 {
                    Text("Routine")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2), in: Capsule())
                        .foregroundStyle(.green)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if canAddBefore {
                    Button("Before") {
                        onAdd(.before)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                if canAddAfter {
                    Button("After") {
                        onAdd(.after)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                    }
                }
                .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Chain Creator Sheet

struct ChainCreatorSheet: View {
    let position: ChainPosition
    let baseBlock: TimeBlock
    let onChainCreated: (Chain) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var chainName = ""
    @State private var customDuration = 30
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Chain \(position == .before ? "Before" : "After") \(baseBlock.title)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chain Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("e.g. Prep routine, Cool down", text: $chainName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Duration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Slider(value: Binding(
                            get: { Double(customDuration) },
                            set: { customDuration = Int($0) }
                        ), in: 5...120, step: 5)
                        
                        Text("\(customDuration) min")
                            .font(.caption)
                            .frame(width: 50)
                    }
                }
                
                Spacer()
                
                Button("Create Chain") {
                    createChain()
                }
                .buttonStyle(.borderedProminent)
                .disabled(chainName.isEmpty)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .navigationTitle("Create Chain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private func createChain() {
        let newChain = Chain(
            name: chainName,
            blocks: [
                TimeBlock(
                    title: chainName,
                    startTime: Date(),
                    duration: TimeInterval(customDuration * 60),
                    energy: baseBlock.energy,
                    emoji: baseBlock.emoji
                )
            ],
            flowPattern: .waterfall,
            emoji: baseBlock.emoji
        )
        
        onChainCreated(newChain)
        dismiss()
    }
}

// MARK: - Generated Chains Sheet

struct GeneratedChainsSheet: View {
    let chains: [Chain]
    let baseBlock: TimeBlock
    let canAddBefore: Bool
    let canAddAfter: Bool
    let onChainSelected: (Chain, ChainPosition) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection
                
                if chains.isEmpty {
                    emptyStateSection
                } else {
                    chainsListSection
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Generated Chains")
            // .navigationBarTitleDisplayMode(.large) // Not available on macOS
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Generated Chain Suggestions")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("For event: \(baseBlock.title)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No chains generated")
                .font(.headline)
            
            Text("The AI couldn't generate suitable chain suggestions for this event.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private var chainsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(chains, id: \.id) { chain in
                    GeneratedChainCard(
                        chain: chain,
                        baseBlock: baseBlock,
                        canAddBefore: canAddBefore,
                        canAddAfter: canAddAfter,
                        onChainSelected: onChainSelected
                    )
                }
            }
        }
    }
}

// MARK: - Generated Chain Card

struct GeneratedChainCard: View {
    let chain: Chain
    let baseBlock: TimeBlock
    let canAddBefore: Bool
    let canAddAfter: Bool
    let onChainSelected: (Chain, ChainPosition) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            descriptionRow
            blocksPreview
            actionButtons
        }
        .padding(16)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var headerRow: some View {
        HStack {
            Text(chain.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chain.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(chain.blocks.count) activities • \(chain.totalDurationMinutes)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var descriptionRow: some View {
        Text("Activity chain with \(chain.blocks.count) blocks")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    private var blocksPreview: some View {
        HStack(spacing: 8) {
            ForEach(chain.blocks.prefix(3), id: \.id) { block in
                HStack(spacing: 4) {
                    Text(block.emoji)
                        .font(.caption)
                    Text(block.title)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
            }
            
            if chain.blocks.count > 3 {
                Text("+\(chain.blocks.count - 3)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            if canAddBefore {
                Button("Add Before") {
                    onChainSelected(chain, .before)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if canAddAfter {
                Button("Add After") {
                    onChainSelected(chain, .after)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            Spacer()
        }
    }
}

struct EventDurationTab: View {
    @Binding var block: TimeBlock
    
    private let presetDurations = [15, 30, 45, 60, 90, 120, 180, 240]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            titleSection
            currentDurationSection
            presetDurationSection
            customDurationSection
            Spacer()
        }
        .padding(24)
    }
    
    private var titleSection: some View {
        Text("Duration Control")
            .font(.headline)
            .fontWeight(.semibold)
    }
    
    private var currentDurationSection: some View {
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
        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private var presetDurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Durations")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(presetDurations, id: \.self) { minutes in
                    presetDurationButton(minutes: minutes)
                }
            }
        }
    }
    
    private func presetDurationButton(minutes: Int) -> some View {
        Button(action: { setDuration(minutes) }) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("min")
                    .font(.caption)
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(
                block.durationMinutes == minutes ? .blue.opacity(0.2) : .gray.opacity(0.2),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        block.durationMinutes == minutes ? .blue : .clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var customDurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Duration")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                HStack {
                    Text("15 min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("4 hours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
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
        }
    }
    
    private func setDuration(_ minutes: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            block.duration = TimeInterval(minutes * 60)
        }
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

struct ChainInputButton: View {
    let position: ChainPosition
    let isActive: Bool
    let onToggle: () -> Void
    
    @State private var isHovering = false
    @State private var showingChainCreator = false
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                Image(systemName: isActive ? "chevron.up" : (position == .before ? "arrow.left.to.line" : "arrow.right.to.line"))
                    .font(.caption)
                    .fontWeight(.medium)
                
                if !isActive {
                    Text(position == .before ? "Before" : "After")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.blue.opacity(isHovering ? 0.2 : 0.12), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $showingChainCreator) {
            ChainInputPopover(position: position) { chainType in
                // Handle chain creation/selection
                showingChainCreator = false
            }
        }
    }
}

struct ChainInputPopover: View {
    let position: ChainPosition
    let onChainSelected: (ChainInputType) -> Void
    
    @State private var selectedTab: ChainInputTab = .existing
    @State private var customName = ""
    @State private var quickActivity = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Add \(position == .before ? "Before" : "After")")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Tab selector
            Picker("Input Type", selection: $selectedTab) {
                ForEach(ChainInputTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            
            // Content based on selection
            switch selectedTab {
            case .existing:
                ExistingChainsView { chain in
                    onChainSelected(.existing(chain))
                }
            case .quick:
                QuickActivitiesView { activity in
                    onChainSelected(.quick(activity))
                }
            case .custom:
                CustomChainInputView { name, duration in
                    onChainSelected(.custom(name: name, duration: duration))
                }
            }
        }
        .padding(16)
        .frame(width: 280, height: 200)
    }
}

enum ChainInputTab: String, CaseIterable {
    case existing = "Existing"
    case quick = "Quick"
    case custom = "Custom"
}

enum ChainInputType {
    case existing(Chain)
    case quick(String)
    case custom(name: String, duration: Int)
}

struct ExistingChainsView: View {
    let onSelect: (Chain) -> Void
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(dataManager.appState.recentChains.prefix(4)) { chain in
                    Button(action: { onSelect(chain) }) {
                        HStack {
                            Text(chain.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text("\(chain.blocks.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.gray.opacity(0.2), in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                }
                
                if dataManager.appState.recentChains.isEmpty {
                    Text("No existing chains")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                }
            }
        }
        .frame(maxHeight: 120)
    }
}

struct QuickActivitiesView: View {
    let onSelect: (String) -> Void
    
    private let quickActivities = [
        "Break", "Walk", "Snack", "Call", "Email", "Review",
        "Stretch", "Water", "Plan", "Tidy", "Note", "Think"
    ]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
            ForEach(quickActivities, id: \.self) { activity in
                Button(activity) {
                    onSelect(activity)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CustomChainInputView: View {
    let onCreate: (String, Int) -> Void
    
    @State private var activityName = ""
    @State private var duration = 15
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Activity")
                    .font(.caption)
                    .fontWeight(.medium)
                
                TextField("What to do?", text: $activityName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Duration")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Picker("Duration", selection: $duration) {
                        ForEach([5, 10, 15, 20, 30, 45], id: \.self) { minutes in
                            Text("\(minutes)m").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
                
                Spacer()
                
                Button("Create") {
                    onCreate(activityName, duration)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(activityName.isEmpty)
            }
        }
    }
}

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

// MARK: - Supporting Types & Views

enum ChainTabPosition {
    case start, end
}

struct ChainInfo {
    let name: String
    let position: Int
    let totalBlocks: Int
}

struct ChainAddTab: View {
    let position: ChainTabPosition
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if position == .start {
                    Image(systemName: "plus")
                        .font(.caption2)
                    Text("Chain")
                        .font(.caption2)
                } else {
                    Text("Chain")
                        .font(.caption2)
                    Image(systemName: "plus")
                        .font(.caption2)
                }
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.blue.opacity(0.1), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(0.9)
        .opacity(0.8)
    }
}

struct ChainSelectorView: View {
    let position: ChainTabPosition
    let baseBlock: TimeBlock
    let onChainSelected: (Chain) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var aiSuggestedChains: [Chain] = []
    @State private var isGenerating = false
    @State private var customChainName = ""
    @State private var customDuration = 30 // minutes
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Chain \(position == .start ? "Before" : "After") \(baseBlock.title)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if isGenerating {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        
                        Text("AI is suggesting relevant chains...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // AI suggested chains
                            if !aiSuggestedChains.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("AI Suggestions")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(aiSuggestedChains) { chain in
                                        ChainSuggestionCard(
                                            chain: chain,
                                            position: position,
                                            onSelect: { onChainSelected(chain) }
                                        )
                                    }
                                }
                            }
                            
                            // Existing chains
                            if !dataManager.appState.recentChains.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Your Chains")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(dataManager.appState.recentChains.prefix(5)) { chain in
                                        ExistingChainCard(
                                            chain: chain,
                                            onSelect: { onChainSelected(chain) }
                                        )
                                    }
                                }
                            }
                            
                            // Custom chain creation
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Create Custom Chain")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(spacing: 8) {
                                    TextField("Chain name (e.g., 'Morning Focus')", text: $customChainName)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    HStack {
                                        Text("Duration:")
                                        Slider(value: Binding(
                                            get: { Double(customDuration) },
                                            set: { customDuration = Int($0) }
                                        ), in: 15...180, step: 15)
                                        Text("\(customDuration)m")
                                            .frame(width: 30)
                                    }
                                    
                                    Button("Create & Add") {
                                        createCustomChain()
                                    }
                                    .disabled(customChainName.isEmpty)
                                    .buttonStyle(.borderedProminent)
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(8)
                                .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Add Chain")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
        .task {
            await generateChainSuggestions()
        }
    }
    
    @MainActor
    private func generateChainSuggestions() async {
        isGenerating = true
        
        let prompt = """
        Suggest 3-5 activity chains that would work well \(position == .start ? "before" : "after") this activity:
        
        Activity: \(baseBlock.title)
        Duration: \(baseBlock.durationMinutes) minutes
        Energy: \(baseBlock.energy.description)
        Emoji: \(baseBlock.emoji)
        Time: \(baseBlock.startTime.timeString)
        
        For each chain suggestion, provide:
        - Name (2-4 words)
        - 2-4 activity blocks with realistic durations
        - Total duration should be 30-120 minutes
        
        Make suggestions practical and complementary to the main activity.
        """
        
        do {
            let context = DayContext(
                date: baseBlock.startTime,
                existingBlocks: [baseBlock],
                currentEnergy: baseBlock.energy,
                preferredEmojis: [baseBlock.emoji],
                availableTime: 7200, // 2 hours
                mood: .crystal
            )
            
            let response = try await aiService.processMessage(prompt, context: context)
            
            // Parse response into chain suggestions (simplified)
            let suggestedChains = createChainsFromResponse(response.text)
            
            aiSuggestedChains = suggestedChains
        } catch {
            // Fallback suggestions
            aiSuggestedChains = createDefaultChainSuggestions()
        }
        
        isGenerating = false
    }
    
    private func createChainsFromResponse(_ response: String) -> [Chain] {
        // Simplified chain creation from AI response
        // In a real implementation, this would parse structured JSON
        return [
            Chain(
                name: "\(baseBlock.title) Prep",
                blocks: [
                    TimeBlock(
                        title: "Prepare materials",
                        startTime: Date(),
                        duration: 900,
                        energy: baseBlock.energy,
                        emoji: "💎"
                    ),
                    TimeBlock(
                        title: "Quick review",
                        startTime: Date(),
                        duration: 600,
                        energy: baseBlock.energy,
                        emoji: "☁️"
                    )
                ],
                flowPattern: .waterfall
            ),
            Chain(
                name: "\(baseBlock.title) Follow-up",
                blocks: [
                    TimeBlock(
                        title: "Review outcomes",
                        startTime: Date(),
                        duration: 900,
                        energy: .daylight,
                        emoji: "☁️"
                    ),
                    TimeBlock(
                        title: "Next steps",
                        startTime: Date(),
                        duration: 1200,
                        energy: .daylight,
                        emoji: "💎"
                    )
                ],
                flowPattern: .waterfall
            )
        ]
    }
    
    private func createDefaultChainSuggestions() -> [Chain] {
        if position == .start {
            return [
                Chain(
                    name: "Warm-up Sequence",
                    blocks: [
                        TimeBlock(title: "Prepare space", startTime: Date(), duration: 600, energy: .daylight, emoji: "☁️"),
                        TimeBlock(title: "Mental prep", startTime: Date(), duration: 900, energy: .daylight, emoji: "💎")
                    ],
                    flowPattern: .waterfall
                ),
                Chain(
                    name: "Energy Boost",
                    blocks: [
                        TimeBlock(title: "Quick movement", startTime: Date(), duration: 300, energy: .sunrise, emoji: "🌊"),
                        TimeBlock(title: "Hydrate", startTime: Date(), duration: 300, energy: .daylight, emoji: "☁️")
                    ],
                    flowPattern: .ripple
                )
            ]
        } else {
            return [
                Chain(
                    name: "Cool Down",
                    blocks: [
                        TimeBlock(title: "Reflect", startTime: Date(), duration: 600, energy: .daylight, emoji: "☁️"),
                        TimeBlock(title: "Organize", startTime: Date(), duration: 900, energy: .daylight, emoji: "💎")
                    ],
                    flowPattern: .waterfall
                ),
                Chain(
                    name: "Transition",
                    blocks: [
                        TimeBlock(title: "Quick break", startTime: Date(), duration: 300, energy: .moonlight, emoji: "☁️"),
                        TimeBlock(title: "Prepare next", startTime: Date(), duration: 600, energy: .daylight, emoji: "💎")
                    ],
                    flowPattern: .wave
                )
            ]
        }
    }
    
    private func createCustomChain() {
        let newChain = Chain(
            name: customChainName,
            blocks: [
                TimeBlock(
                    title: customChainName,
                    startTime: Date(),
                    duration: TimeInterval(customDuration * 60), // Convert minutes to seconds
                    energy: baseBlock.energy,
                    emoji: baseBlock.emoji
                )
            ],
            flowPattern: .waterfall
        )
        
        // Save the chain to the data manager for future reuse
        dataManager.addChain(newChain)
        
        // Call the completion handler to attach the chain
        onChainSelected(newChain)
        
        // Clear the input and dismiss
        customChainName = ""
        customDuration = 30
        dismiss()
        
        // Show success feedback
        print("✅ Created and attached custom chain: \(newChain.name) (\(customDuration)m)")
    }
}

struct ChainSuggestionCard: View {
    let chain: Chain
    let position: ChainTabPosition
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(chain.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(chain.totalDurationMinutes)m")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.2), in: Capsule())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(chain.blocks.prefix(3)) { block in
                    HStack {
                        Text("• \(block.title)")
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(block.durationMinutes)m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if chain.blocks.count > 3 {
                    Text("+ \(chain.blocks.count - 3) more activities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Button("Add \(position == .start ? "Before" : "After")") {
                onSelect()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ExistingChainCard: View {
    let chain: Chain
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(chain.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(chain.blocks.count) activities • \(chain.totalDurationMinutes)m")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if chain.completionCount >= 3 {
                Text("Routine")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.2), in: Capsule())
                    .foregroundColor(.green)
            }
            
            Button("Use") {
                onSelect()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct MonthView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var selectedDates: Set<Date> = []
    @State private var currentMonth = Date()
    @State private var dateSelectionRange: (start: Date?, end: Date?) = (nil, nil)
    @State private var showingMultiDayInsight = false
    @State private var multiDayInsight = ""
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 12) {
            // Month header
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(dateFormatter.string(from: currentMonth))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            // Selection info
            if selectedDates.count > 1 {
                HStack {
                    Text("\(selectedDates.count) days selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Clear") {
                        clearSelection()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 16)
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Weekday headers
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(height: 20)
                }
                
                // Calendar days
                ForEach(monthDays, id: \.self) { date in
                    if let date = date {
                        EnhancedDayCell(
                            date: date,
                            isSelected: selectedDates.contains(date),
                            isInRange: isDateInSelectionRange(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                            onTap: {
                                handleDayTap(date)
                            }
                        )
                    } else {
                        Rectangle()
                            .fill(.clear)
                            .frame(height: 32)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Multi-day insight view
            if showingMultiDayInsight && !multiDayInsight.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AI Insight")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("✕") {
                            showingMultiDayInsight = false
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                    }
                    
                    ScrollView {
                        Text(multiDayInsight)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.5))
        .onChange(of: selectedDates) {
            updateMultiDayInsight()
        }
    }
    
    private var monthDays: [Date?] {
        guard let monthStart = calendar.dateInterval(of: .month, for: currentMonth)?.start else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        
        var days: [Date?] = []
        
        // Add empty cells for days before month start
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add days of the month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // MARK: - Day Selection Logic
    
    private func handleDayTap(_ date: Date) {
        // Always switch to the clicked day first
        dataManager.switchToDay(date)
        
        if selectedDates.isEmpty {
            // First selection
            selectedDates.insert(date)
            dateSelectionRange.start = date
        } else if selectedDates.count == 1 {
            // Second selection - create range
            let existingDate = selectedDates.first!
            let startDate = min(date, existingDate)
            let endDate = max(date, existingDate)
            
            selectedDates.removeAll()
            
            // Add all dates in range
            var currentDate = startDate
            while currentDate <= endDate {
                selectedDates.insert(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            dateSelectionRange = (startDate, endDate)
        } else {
            // Reset selection
            selectedDates.removeAll()
            selectedDates.insert(date)
            dateSelectionRange = (date, nil)
        }
    }
    
    private func clearSelection() {
        selectedDates.removeAll()
        dateSelectionRange = (nil, nil)
        showingMultiDayInsight = false
        multiDayInsight = ""
    }
    
    private func isDateInSelectionRange(_ date: Date) -> Bool {
        guard let start = dateSelectionRange.start,
              let end = dateSelectionRange.end else { return false }
        return date >= start && date <= end
    }
    
    // MARK: - AI Multi-Day Insights
    
    private func updateMultiDayInsight() {
        guard selectedDates.count > 1 else {
            showingMultiDayInsight = false
            return
        }
        
        let sortedDates = selectedDates.sorted()
        guard let startDate = sortedDates.first,
              let endDate = sortedDates.last else { return }
        
        Task {
            await generateMultiDayInsight(start: startDate, end: endDate)
        }
    }
    
    @MainActor
    private func generateMultiDayInsight(start: Date, end: Date) async {
        let now = Date()
        let isPastPeriod = end < now
        let dayCount = selectedDates.count
        let daysFromNow = Calendar.current.dateComponents([.day], from: now, to: start).day ?? 0
        
        let prompt: String
        if isPastPeriod {
            // PRD: Past period - reflection text on wins/blockers
            prompt = """
            Reflect on the \(dayCount)-day period from \(start.formatted(.dateTime.month().day())) to \(end.formatted(.dateTime.month().day())).
            
            Analyze this time period and provide:
            1. Key wins and accomplishments during this period
            2. Main blockers or challenges that came up  
            3. Patterns or insights about productivity/energy
            4. Brief assessment of how the time was used
            
            Keep it concise - 2-3 sentences focusing on wins and blockers.
            """
        } else {
            // PRD: Future period - possible goals to be in-progress by that time
            prompt = """
            Looking at a future \(dayCount)-day period starting \(daysFromNow) days from now (\(start.formatted(.dateTime.month().day())) to \(end.formatted(.dateTime.month().day()))).
            
            Given this time delta, suggest what goals could be achieved or in-progress by that time:
            - Realistic goals for a \(dayCount)-day period
            - Projects that could be started or completed
            - Skills or habits that could be developed
            - Meaningful milestones to work towards
            
            Keep it motivating and actionable (2-3 sentences max).
            """
        }
        
        do {
            let context = DayContext(
                date: start,
                existingBlocks: dataManager.appState.currentDay.blocks,
                currentEnergy: .daylight,
                preferredEmojis: ["🌊"],
                availableTime: TimeInterval(dayCount * 24 * 3600),
                mood: dataManager.appState.currentDay.mood
            )
            
            let response = try await aiService.processMessage(prompt, context: context)
            
            multiDayInsight = response.text
            withAnimation(.easeInOut(duration: 0.3)) {
                showingMultiDayInsight = true
            }
        } catch {
            multiDayInsight = isPastPeriod
                ? "This was a \(dayCount)-day period. Reflect on what you accomplished and learned."
                : "In \(daysFromNow) days, you could make significant progress on your goals. Consider what you'd like to achieve by then."
            
            withAnimation(.easeInOut(duration: 0.3)) {
                showingMultiDayInsight = true
            }
        }
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

struct EnhancedDayCell: View {
    let date: Date
    let isSelected: Bool
    let isInRange: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isCurrentMonth ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(backgroundView)
                .overlay(overlayView)
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundView: some View {
        Group {
            if isSelected {
                Circle()
                    .fill(.blue.opacity(0.3))
            } else if isInRange {
                Rectangle()
                    .fill(.blue.opacity(0.1))
            } else {
                Circle()
                    .fill(.clear)
            }
        }
    }
    
    private var overlayView: some View {
        Group {
            if isSelected {
                Circle()
                    .strokeBorder(.blue, lineWidth: 2)
            } else if isInRange {
                Rectangle()
                    .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
            } else {
                Circle()
                    .strokeBorder(.clear, lineWidth: 0)
            }
        }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isCurrentMonth ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? .blue : .clear)
                        .opacity(isSelected ? 0.2 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? .blue : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chains Templates View

struct ChainsTemplatesView: View {
    let selectedDate: Date
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var templates: [ChainTemplate] = []
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Chain Templates")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Drag to timeline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templates) { template in
                        DraggableChainTemplate(template: template)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            generateTemplates()
        }
    }
    
    private func generateTemplates() {
        templates = [
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
}

struct DraggableChainTemplate: View {
    let template: ChainTemplate
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text(template.icon)
                .font(.title)
            
            Text(template.name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            HStack(spacing: 4) {
                Text("\(template.totalDuration)m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(template.activities.count) steps")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(12)
        .frame(width: 100, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .offset(dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    dragOffset = .zero
                    
                    // Create chain from template and apply to selected date
                    createChainFromTemplate()
                }
        )
    }
    
    private func createChainFromTemplate() {
        let chain = Chain(
            id: UUID(),
            name: template.name,
            blocks: template.activities.enumerated().map { index, activity in
                let startTime = Calendar.current.date(byAdding: .minute, value: index * 30, to: Date()) ?? Date()
                return TimeBlock(
                    title: activity,
                    startTime: startTime,
                    duration: TimeInterval((template.totalDuration * 60) / template.activities.count),
                    energy: template.energyFlow[index % template.energyFlow.count],
                    emoji: template.icon
                )
            },
            flowPattern: .waterfall
        )
        
        dataManager.applyChain(chain, startingAt: Date())
    }
}


