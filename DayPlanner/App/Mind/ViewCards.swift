// MARK: - Section Components

import SwiftUI

struct SectionHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let gradient: LinearGradient
    let onAction: (() -> Void)?
    
    init(title: String, subtitle: String, systemImage: String, gradient: LinearGradient, onAction: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.gradient = gradient
        self.onAction = onAction
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(gradient)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if let onAction = onAction {
                Button(action: onAction) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct EnhancedChainCard: View {
    let chain: Chain
    @State private var isHovering = false
    @State private var showingChainDetail = false
    
    var body: some View {
        Button(action: { showingChainDetail = true }) {
            HStack(spacing: 12) {
                // Chain flow indicator with better styling
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(chainFlowColor)
                        .frame(width: 6, height: 24)
                    
                    Text("\(chain.blocks.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(chain.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 6) {
                        Text("\(chain.blocks.count) steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        Text("\(chain.totalDurationMinutes)m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Flow pattern name instead of emoji
                        Text(chain.flowPattern.description)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(chainFlowColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(chainFlowColor)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(isHovering ? 0.6 : 0.4), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(chainFlowColor.opacity(isHovering ? 0.4 : 0.15), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in isHovering = hovering }
        .sheet(isPresented: $showingChainDetail) {
            ChainDetailView(chain: chain)
        }
    }
    
    private var chainFlowColor: Color {
        switch chain.flowPattern {
        case .waterfall: return .blue
        case .spiral: return .purple
        case .ripple: return .cyan
        case .wave: return .teal
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

struct GoalMistCard: View {
    let goal: Goal
    @State private var isHovering = false
    @State private var showingGoalDetail = false
    
    var body: some View {
        Button(action: { showingGoalDetail = true }) {
            HStack(spacing: 10) {
                // Goal state indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(goalStateColor)
                    .frame(width: 4, height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(goal.state.rawValue)
                            .font(.caption2)
                            .foregroundStyle(goalStateColor)
                        
                        Spacer()
                        
                        // Progress visualization
                        if goal.isActive {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        } else {
                            Circle()
                                .fill(.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(isHovering ? 0.4 : 0.2), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(goalStateColor.opacity(isHovering ? 0.3 : 0.1), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in isHovering = hovering }
        .sheet(isPresented: $showingGoalDetail) {
            Text("Goal Detail - \(goal.title)")
                .padding()
        }
    }
    
    private var goalStateColor: Color {
        switch goal.state {
        case .draft: return .orange
        case .on: return .green
        case .off: return .gray
        }
    }
}

// MARK: - Mind Tab View

struct MindTabView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var selectedTimeframe: TimeframeSelector = .now
    
    var body: some View {
        VStack(spacing: 16) {
            // Timeframe selector
            TimeframeSelectorView(selection: $selectedTimeframe)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Pillars section
                    PillarsSection()
                    
                    // Goals section
                    GoalsSection()
                    
                    // Dream Builder section
                    DreamBuilderSection()
                    
                    // Intake section
                    IntakeSection()
                }
                .padding()
            }
        }
    }
}

// MARK: - Dream Merge View

struct DreamMergeView: View {
    let concepts: [DreamConcept]
    let onMerge: (DreamConcept) -> Void
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var mergedTitle = ""
    @State private var mergedDescription = ""
    @State private var isGeneratingMerge = false
    @State private var aiSuggestion = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Merge \(concepts.count) dream concepts into one goal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Show concepts being merged
                VStack(alignment: .leading, spacing: 8) {
                    Text("Merging:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ForEach(concepts) { concept in
                        HStack {
                            Text(concept.title)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(concept.mentions)× mentioned")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                // AI-generated merge suggestion
                if !aiSuggestion.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Suggestion")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(aiSuggestion)
                            .font(.body)
                            .padding()
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                // Merged concept form
                VStack(alignment: .leading, spacing: 12) {
                    Text("Merged Concept")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Title", text: $mergedTitle)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description", text: $mergedDescription, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Merge Dreams")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merge") {
                        performMerge()
                    }
                    .disabled(mergedTitle.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 500)
        .task {
            await generateMergeSuggestion()
        }
    }
    
    private func generateMergeSuggestion() async {
        isGeneratingMerge = true
        
        let conceptTitles = concepts.map(\.title).joined(separator: ", ")
        let allKeywords = Set(concepts.flatMap(\.relatedKeywords)).joined(separator: ", ")
        
        let prompt = """
        The user wants to merge these dream concepts into one unified goal:
        Concepts: \(conceptTitles)
        Related keywords: \(allKeywords)
        
        Suggest:
        1. A unified title that captures the essence of all concepts
        2. A description that explains how these relate to each other
        3. Suggested first steps or chains to make progress
        
        Keep it concise and actionable.
        """
        
        do {
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
                aiSuggestion = response.text
                // Try to extract suggested title from response
                if mergedTitle.isEmpty {
                    mergedTitle = extractTitleFromResponse(response.text) ?? conceptTitles
                }
                isGeneratingMerge = false
            }
        } catch {
            await MainActor.run {
                aiSuggestion = "These concepts seem related and could form a meaningful goal together."
                mergedTitle = conceptTitles
                isGeneratingMerge = false
            }
        }
    }
    
    private func extractTitleFromResponse(_ response: String) -> String? {
        // Simple extraction - look for common patterns
        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            if line.lowercased().contains("title:") {
                return line.replacingOccurrences(of: "title:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
    
    private func performMerge() {
        let allKeywords = Set(concepts.flatMap(\.relatedKeywords))
        let totalMentions = concepts.reduce(0) { $0 + $1.mentions }
        
        let mergedConcept = DreamConcept(
            title: mergedTitle,
            description: mergedDescription.isEmpty ? aiSuggestion : mergedDescription,
            mentions: totalMentions,
            lastMentioned: Date(),
            relatedKeywords: Array(allKeywords),
            canMergeWith: [],
            hasBeenPromotedToGoal: false
        )
        
        onMerge(mergedConcept)
    }
}

// MARK: - Dream Chat View

struct DreamChatView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var chatMessages: [DreamChatMessage] = []
    @State private var currentMessage = ""
    @State private var isProcessing = false
    @State private var extractedConcepts: [DreamConcept] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat area
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatMessages) { message in
                            DreamChatBubble(message: message)
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Input area
                HStack(spacing: 12) {
                    TextField("Share your dreams and aspirations...", text: $currentMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button("Send") {
                        sendMessage()
                    }
                    .disabled(currentMessage.isEmpty || isProcessing)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial)
                
                // Extracted concepts preview
                if !extractedConcepts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dreams extracted from conversation:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(extractedConcepts) { concept in
                                    ConceptPill(concept: concept) {
                                        saveConcept(concept)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(.blue.opacity(0.1))
                }
            }
            .navigationTitle("Dream Chat")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveExtractedConcepts()
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 700, height: 600)
        .onAppear {
            startDreamConversation()
        }
    }
    
    private func startDreamConversation() {
        let welcomeMessage = DreamChatMessage(
            text: "Let's explore your dreams and aspirations! Tell me about things you've been wanting to do, learn, or achieve. I'll help identify patterns and turn them into actionable goals.",
            isUser: false,
            timestamp: Date()
        )
        chatMessages.append(welcomeMessage)
    }
    
    private func sendMessage() {
        guard !currentMessage.isEmpty else { return }
        
        // Add user message
        let userMessage = DreamChatMessage(
            text: currentMessage,
            isUser: true,
            timestamp: Date()
        )
        chatMessages.append(userMessage)
        
        let message = currentMessage
        currentMessage = ""
        isProcessing = true
        
        Task {
            await processDreamMessage(message)
        }
    }
    
    @MainActor
    private func processDreamMessage(_ message: String) async {
        let dreamExtractionPrompt = """
        Analyze this message for dreams, aspirations, and recurring desires: "\(message)"
        
        Extract any goals, dreams, or aspirations mentioned and respond in this format:
        {
            "response": "Your encouraging response to the user",
            "extracted_concepts": [
                {
                    "title": "Concept title",
                    "description": "What this is about",
                    "keywords": ["keyword1", "keyword2"],
                    "priority": 3.5
                }
            ]
        }
        
        Be encouraging and help them explore their aspirations.
        """
        
        do {
            let context = DayContext(
                date: Date(),
                existingBlocks: [],
                currentEnergy: .daylight,
                preferredEmojis: ["🌊"],
                availableTime: 3600,
                mood: .crystal
            )
            
            let response = try await aiService.processMessage(dreamExtractionPrompt, context: context)
            
            // Parse JSON response to extract readable text
            let cleanedResponse = extractReadableTextFromResponse(response.text)
            
            // Add AI response with cleaned text
            let aiMessage = DreamChatMessage(
                text: cleanedResponse,
                isUser: false,
                timestamp: Date()
            )
            chatMessages.append(aiMessage)
            
            // Extract concepts (simplified for now)
            extractConceptsFromMessage(message)
            
        } catch {
            let errorMessage = DreamChatMessage(
                text: "I'm having trouble processing that right now, but I heard you mention some interesting aspirations!",
                isUser: false,
                timestamp: Date()
            )
            chatMessages.append(errorMessage)
            
            // Still try to extract concepts from the message
            extractConceptsFromMessage(message)
        }
        
        isProcessing = false
    }
    
    private func extractReadableTextFromResponse(_ response: String) -> String {
        // Clean up JSON responses from AI
        let cleanResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to parse as JSON and extract the "response" field
        if let data = cleanResponse.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responseText = jsonObject["response"] as? String {
            return responseText
        }
        
        // If not JSON format, return the original cleaned response
        return cleanResponse
    }
    
    private func extractConceptsFromMessage(_ message: String) {
        // Simple keyword-based extraction (in a real app, this would be more sophisticated)
        let dreamKeywords = ["want to", "hope to", "dream of", "goal", "aspiration", "would love to", "interested in"]
        let lowerMessage = message.lowercased()
        
        for keyword in dreamKeywords {
            if lowerMessage.contains(keyword) {
                // Extract potential concept
                let concept = DreamConcept(
                    title: "New aspiration from chat",
                    description: message.truncated(to: 100),
                    mentions: 1,
                    lastMentioned: Date(),
                    relatedKeywords: extractKeywords(from: message),
                    canMergeWith: [],
                    hasBeenPromotedToGoal: false
                )
                
                if !extractedConcepts.contains(where: { $0.title == concept.title }) {
                    extractedConcepts.append(concept)
                }
                break
            }
        }
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let words = text.lowercased().components(separatedBy: .whitespaces)
        let meaningfulWords = words.filter { word in
            word.count > 3 && !["want", "would", "could", "should", "that", "this", "with", "from"].contains(word)
        }
        return Array(meaningfulWords.prefix(5))
    }
    
    private func saveConcept(_ concept: DreamConcept) {
        if !dataManager.appState.dreamConcepts.contains(where: { $0.title == concept.title }) {
            dataManager.appState.dreamConcepts.append(concept)
            dataManager.save()
        }
        extractedConcepts.removeAll { $0.id == concept.id }
    }
    
    private func saveExtractedConcepts() {
        for concept in extractedConcepts {
            saveConcept(concept)
        }
    }
}

struct DreamChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}

struct DreamChatBubble: View {
    let message: DreamChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        message.isUser ? .blue.opacity(0.2) : .gray.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                
                Text(message.timestamp.timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct ConceptPill: View {
    let concept: DreamConcept
    let onSave: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(concept.title)
                .font(.caption)
                .fontWeight(.medium)
            
            Button("+") {
                onSave()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct DreamConceptView: View {
    let concept: DreamConcept
    let onConvertToGoal: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
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
            }
            
            Spacer()
            
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct IntakeSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var showingQuestionDetail: IntakeQuestion?
    @State private var showingAIInsights = false
    @State private var generateQuestionsCounter = 0
    @State private var coreMessage = ""
    @State private var isProcessingCore = false
    @State private var coreResponse = ""
    @State private var coreInsight = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Core Chat Bar - The brain of the mind tab
            VStack(alignment: .leading, spacing: 8) {
                Text("🧠 Core Chat")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)
                
                HStack(spacing: 8) {
                    TextField("Control chains, pillars, goals...", text: $coreMessage)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { processCoreMessage() }
                    
                    Button(isProcessingCore ? "..." : "⚡") {
                        processCoreMessage()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(coreMessage.isEmpty || isProcessingCore)
                    .frame(width: 32)
                }
                
                if !coreResponse.isEmpty {
                    Text(coreResponse)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .padding(8)
                        .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                
                if !coreInsight.isEmpty {
                    Text("💡 \(coreInsight)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            .padding(12)
            .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.purple.opacity(0.3), lineWidth: 1)
            )
            
            // Traditional Intake Questions
            HStack {
                Text("Intake Questions")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    Button("What AI knows about me") {
                        showingAIInsights = true
                    }
                    
                    Button("Generate new questions") {
                        generateNewQuestions()
                    }
                    
                    Button("Reset answered questions") {
                        resetAnsweredQuestions()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if dataManager.appState.intakeQuestions.isEmpty {
                VStack(spacing: 12) {
                    Text("🤔")
                        .font(.title)
                        .opacity(0.5)
                    
                    Text("No questions available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Generate Questions") {
                        generateNewQuestions()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(dataManager.appState.intakeQuestions) { question in
                        EnhancedIntakeQuestionView(
                            question: question,
                            onAnswerTap: {
                                showingQuestionDetail = question
                            },
                            onLongPress: {
                                showAIThoughts(for: question)
                            }
                        )
                    }
                }
                
                // Progress indicator
                let answeredCount = dataManager.appState.intakeQuestions.filter(\.isAnswered).count
                let totalCount = dataManager.appState.intakeQuestions.count
                
                if totalCount > 0 {
                    HStack {
                        Text("Progress: \(answeredCount)/\(totalCount) answered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        ProgressView(value: Double(answeredCount), total: Double(totalCount))
                            .frame(width: 100)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .sheet(item: $showingQuestionDetail) { question in
            IntakeQuestionDetailView(question: question) { updatedQuestion in
                if let index = dataManager.appState.intakeQuestions.firstIndex(where: { $0.id == question.id }) {
                    dataManager.appState.intakeQuestions[index] = updatedQuestion
                    dataManager.save()
                    
                    // Award XP for answering
                    dataManager.appState.addXP(10, reason: "Answered intake question")
                }
                showingQuestionDetail = nil
            }
        }
        .sheet(isPresented: $showingAIInsights) {
            AIKnowledgeView()
                .environmentObject(dataManager)
        }
    }
    
    private func generateNewQuestions() {
        generateQuestionsCounter += 1
        
        Task {
            let newQuestions = await generateContextualQuestions()
            await MainActor.run {
                dataManager.appState.intakeQuestions.append(contentsOf: newQuestions)
                dataManager.save()
            }
        }
    }
    
    private func generateContextualQuestions() async -> [IntakeQuestion] {
        // Generate questions based on current app state
        let existingCategories = Set(dataManager.appState.intakeQuestions.map(\.category))
        var newQuestions: [IntakeQuestion] = []
        
        // Add category-specific questions that haven't been covered
        if !existingCategories.contains(.routine) {
            newQuestions.append(IntakeQuestion(
                question: "What's your ideal morning routine?",
                category: .routine,
                importance: 4,
                aiInsight: "Morning routines set the tone for the entire day and affect energy levels"
            ))
        }
        
        if !existingCategories.contains(.energy) {
            newQuestions.append(IntakeQuestion(
                question: "When do you typically feel most creative?",
                category: .energy,
                importance: 4,
                aiInsight: "Creative time should be protected and scheduled when energy is optimal"
            ))
        }
        
        if !existingCategories.contains(.constraints) {
            newQuestions.append(IntakeQuestion(
                question: "What are your biggest time constraints during the week?",
                category: .constraints,
                importance: 5,
                aiInsight: "Understanding constraints helps the AI avoid suggesting impossible schedules"
            ))
        }
        
        return newQuestions
    }
    
    private func resetAnsweredQuestions() {
        for i in 0..<dataManager.appState.intakeQuestions.count {
            dataManager.appState.intakeQuestions[i].answer = nil
            dataManager.appState.intakeQuestions[i].answeredAt = nil
        }
        dataManager.save()
    }
    
    private func showAIThoughts(for question: IntakeQuestion) {
        // This would show a popover with AI insights
        // For now, just show the existing insight
        print("AI thinks: \(question.aiInsight ?? "No insights available")")
    }
    
    // MARK: - Core Chat Processing
    
    private func processCoreMessage() {
        guard !coreMessage.isEmpty else { return }
        
        let message = coreMessage
        coreMessage = ""
        isProcessingCore = true
        coreInsight = "Analyzing core request..."
        
        Task {
            do {
                let context = dataManager.createEnhancedContext()
                let corePrompt = buildCorePrompt(message: message, context: context)
                
                let response = try await aiService.processMessage(corePrompt, context: context)
                
                await MainActor.run {
                    coreResponse = response.text
                    isProcessingCore = false
                    coreInsight = "Core system updated"
                    
                    // Process any core actions
                    processCoreActions(message: message, response: response)
                }
                
                // Clear insight after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    coreInsight = ""
                }
                
            } catch {
                await MainActor.run {
                    coreResponse = "Core system temporarily unavailable"
                    isProcessingCore = false
                    coreInsight = "Error processing request"
                }
            }
        }
    }
    
    private func buildCorePrompt(message: String, context: DayContext) -> String {
        return """
        You are the CORE AI system that controls chains, pillars, and goals. You have elevated permissions to modify user data.
        
        Current system state:
        - Pillars: \(dataManager.appState.pillars.count) (\(dataManager.appState.pillars.filter(\.isActionable).count) actionable, \(dataManager.appState.pillars.filter(\.isPrinciple).count) principles)
        - Goals: \(dataManager.appState.goals.count) (\(dataManager.appState.goals.filter(\.isActive).count) active)
        - Chains: \(dataManager.appState.recentChains.count)
        - User XP: \(dataManager.appState.userXP) | XXP: \(dataManager.appState.userXXP)
        
        User core request: "\(message)"
        
        Available actions:
        - CREATE_PILLAR(name, type:actionable|principle, description, wisdom_text)
        - EDIT_PILLAR(name, changes)
        - CREATE_GOAL(title, description, importance)
        - BREAK_DOWN_GOAL(goal_name) -> chains/pillars/events
        - CREATE_CHAIN(name, activities[], flow_pattern)
        - EDIT_CHAIN(name, changes)
        - AI_ANALYZE(focus_area)
        
        Respond with advice and suggest specific actions. Keep responses under 100 words.
        """
    }
    
    private func processCoreActions(message: String, response: AIResponse) {
        // Smart core actions based on confidence thresholds and AI response
        guard let actionType = response.actionType else {
            analyzeMessageForCoreAction(message)
            return
        }
        
        // Handle smart AI responses with confidence-based decision making
        switch actionType {
        case .createPillar:
            if response.confidence >= 0.85 {
                createPillarFromAI(response)
            } else {
                coreInsight = "Need more details for pillar - specify type and frequency"
            }
            
        case .createGoal:
            if response.confidence >= 0.8 {
                createGoalFromAI(response)
            } else {
                coreInsight = "Need more details for goal - specify importance and timeline"
            }
            
        case .createChain:
            if response.confidence >= 0.75 {
                createChainFromAI(response)
            } else {
                coreInsight = "Need more details for chain - specify activities and flow"
            }
            
        case .createEvent:
            if response.confidence >= 0.7 {
                createEventFromAI(response, message: message)
            } else {
                coreInsight = "Need more details for event - specify time and duration"
            }
            
        case .suggestActivities:
            coreInsight = "Generated \(response.suggestions.count) activity suggestions"
            
        case .generalChat:
            if let createdItems = response.createdItems, !createdItems.isEmpty {
                handleCreatedItems(createdItems)
            } else {
                coreInsight = "Core system processed your request"
            }
        }
    }
    
    // MARK: - Smart Item Creation
    
    private func createPillarFromAI(_ response: AIResponse) {
        guard let createdItem = response.createdItems?.first(where: { $0.type == .pillar }),
              let pillarData = createdItem.data as? [String: Any] else {
            coreInsight = "Error creating pillar"
            return
        }
        
        let pillar = Pillar(
            name: pillarData["name"] as? String ?? "New Pillar",
            description: pillarData["description"] as? String ?? "AI-created pillar",
            type: PillarType(rawValue: pillarData["type"] as? String ?? "actionable") ?? .actionable,
            frequency: parseFrequency(pillarData["frequency"] as? String ?? "daily"),
            minDuration: TimeInterval((pillarData["minDuration"] as? Int ?? 30) * 60),
            maxDuration: TimeInterval((pillarData["maxDuration"] as? Int ?? 120) * 60),
            preferredTimeWindows: parseTimeWindows(pillarData["preferredTimeWindows"] as? [[String: Any]] ?? []),
            eventConsiderationEnabled: true,
            wisdomText: pillarData["wisdomText"] as? String,
            emoji: pillarData["emoji"] as? String ?? "🏛️"
        )
        
        dataManager.addPillar(pillar)
        coreInsight = "✅ Created pillar: \(pillar.name)"
    }
    
    private func createGoalFromAI(_ response: AIResponse) {
        guard let createdItem = response.createdItems?.first(where: { $0.type == .goal }),
              let goalData = createdItem.data as? [String: Any] else {
            coreInsight = "Error creating goal"
            return
        }
        
        let goal = Goal(
            title: goalData["title"] as? String ?? "New Goal",
            description: goalData["description"] as? String ?? "AI-created goal",
            state: .on,
            importance: goalData["importance"] as? Int ?? 3,
            groups: parseGoalGroups(goalData["groups"] as? [[String: Any]] ?? []),
            targetDate: parseTargetDate(goalData["targetDate"] as? String),
            emoji: goalData["emoji"] as? String ?? "🎯",
            relatedPillarIds: goalData["relatedPillarIds"] as? [UUID] ?? []
        )
        
        dataManager.addGoal(goal)
        coreInsight = "✅ Created goal: \(goal.title)"
    }
    
    private func createChainFromAI(_ response: AIResponse) {
        guard let createdItem = response.createdItems?.first(where: { $0.type == .chain }),
              let chainData = createdItem.data as? [String: Any] else {
            coreInsight = "Error creating chain"
            return
        }
        
        let blocks = parseChainBlocks(chainData["blocks"] as? [[String: Any]] ?? [])
        let chain = Chain(
            name: chainData["name"] as? String ?? "New Chain",
            blocks: blocks,
            flowPattern: FlowPattern(rawValue: chainData["flowPattern"] as? String ?? "waterfall") ?? .waterfall,
            emoji: chainData["emoji"] as? String ?? "🔗"
        )
        
        dataManager.addChain(chain)
        coreInsight = "✅ Created chain: \(chain.name) with \(chain.blocks.count) activities"
    }
    
    private func createEventFromAI(_ response: AIResponse, message: String) {
        guard let firstSuggestion = response.suggestions.first else {
            coreInsight = "Error creating event"
            return
        }
        
        // Extract time from message or use smart default
        let targetTime = extractTimeFromMessage(message) ?? findNextAvailableTime()
        
        var timeBlock = firstSuggestion.toTimeBlock()
        timeBlock.startTime = targetTime
        
        dataManager.addTimeBlock(timeBlock)
        coreInsight = "✅ Created event: \(timeBlock.title) at \(targetTime.timeString)"
    }
    
    private func handleCreatedItems(_ items: [CreatedItem]) {
        var createdCount = 0
        var lastItemTitle = ""
        
        for item in items {
            switch item.type {
            case .pillar:
                if let pillarData = item.data as? [String: Any] {
                    let pillar = Pillar(
                        name: pillarData["name"] as? String ?? "New Pillar",
                        description: pillarData["description"] as? String ?? "AI-created pillar",
                        frequency: .daily,
                        minDuration: 1800,
                        maxDuration: 7200,
                        preferredTimeWindows: [],
                        overlapRules: [],
                        quietHours: []
                    )
                    dataManager.addPillar(pillar)
                    createdCount += 1
                    lastItemTitle = pillar.name
                }
            case .goal:
                if let goalData = item.data as? [String: Any] {
                    let goal = Goal(
                        title: goalData["title"] as? String ?? "New Goal",
                        description: goalData["description"] as? String ?? "AI-created goal",
                        state: .on,
                        importance: goalData["importance"] as? Int ?? 3,
                        groups: []
                    )
                    dataManager.addGoal(goal)
                    createdCount += 1
                    lastItemTitle = goal.title
                }
            case .chain:
                if let chainData = item.data as? [String: Any] {
                    let chain = Chain(
                        name: chainData["name"] as? String ?? "New Chain",
                        blocks: [],
                        flowPattern: .waterfall
                    )
                    dataManager.addChain(chain)
                    createdCount += 1
                    lastItemTitle = chain.name
                }
            case .event:
                if let suggestion = item.data as? Suggestion {
                    let timeBlock = suggestion.toTimeBlock()
                    dataManager.addTimeBlock(timeBlock)
                    createdCount += 1
                    lastItemTitle = timeBlock.title
                }
            }
        }
        
        if createdCount > 0 {
            coreInsight = "✅ Created \(createdCount) item\(createdCount == 1 ? "" : "s"): \(lastItemTitle)"
        }
    }
    
    // MARK: - Smart Analysis Fallback
    
    private func analyzeMessageForCoreAction(_ message: String) {
        let lowerMessage = message.lowercased()
        
        if lowerMessage.contains("create pillar") || lowerMessage.contains("add pillar") {
            coreInsight = "💡 Ready to create pillar - specify name, type (actionable/principle), and frequency"
        } else if lowerMessage.contains("create goal") || lowerMessage.contains("add goal") {
            coreInsight = "💡 Ready to create goal - specify title, importance (1-5), and target date"
        } else if lowerMessage.contains("create chain") || lowerMessage.contains("add chain") {
            coreInsight = "💡 Ready to create chain - specify name and list of activities"
        } else if lowerMessage.contains("schedule") || lowerMessage.contains("create event") {
            coreInsight = "💡 Ready to schedule event - specify what, when, and duration"
        } else if lowerMessage.contains("break down") || lowerMessage.contains("breakdown") {
            coreInsight = "🎯 Analyzing goals for breakdown opportunities"
        } else {
            coreInsight = "Core system processed your request"
        }
    }
    
    // MARK: - Parsing Helpers
    
    private func parseFrequency(_ frequency: String) -> PillarFrequency {
        switch frequency.lowercased() {
        case "daily": return .daily
        case "weekly": return .weekly(1)
        case "as needed": return .asNeeded
        default: return .daily
        }
    }
    
    private func parseTimeWindows(_ windowsData: [[String: Any]]) -> [TimeWindow] {
        return windowsData.compactMap { window in
            guard let startHour = window["startHour"] as? Int,
                  let startMinute = window["startMinute"] as? Int,
                  let endHour = window["endHour"] as? Int,
                  let endMinute = window["endMinute"] as? Int else { return nil }
            
            return TimeWindow(startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute)
        }
    }
    
    private func parseGoalGroups(_ groupsData: [[String: Any]]) -> [GoalGroup] {
        return groupsData.compactMap { group in
            guard let name = group["name"] as? String,
                  let tasksData = group["tasks"] as? [[String: Any]] else { return nil }
            
            let tasks = tasksData.compactMap { taskData -> GoalTask? in
                guard let title = taskData["title"] as? String,
                      let description = taskData["description"] as? String else { return nil }
                
                return GoalTask(
                    title: title,
                    description: description,
                    estimatedDuration: TimeInterval((taskData["estimatedDuration"] as? Int ?? 3600)),
                    suggestedChains: [],
                    actionQuality: taskData["actionQuality"] as? Int ?? 3
                )
            }
            
            return GoalGroup(name: name, tasks: tasks)
        }
    }
    
    private func parseTargetDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func parseChainBlocks(_ blocksData: [[String: Any]]) -> [TimeBlock] {
        return blocksData.compactMap { blockData in
            guard let title = blockData["title"] as? String,
                  let duration = blockData["duration"] as? TimeInterval else { return nil }
            
            return TimeBlock(
                title: title,
                startTime: Date(),
                duration: duration,
                energy: EnergyType(rawValue: blockData["energy"] as? String ?? "daylight") ?? .daylight,
                emoji: blockData["emoji"] as? String ?? "🌊"
            )
        }
    }
    
    private func extractTimeFromMessage(_ message: String) -> Date? {
        // Enhanced time extraction with more patterns
        let lowerMessage = message.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        // Check for "at X:XX" patterns
        let timeRegex = try? NSRegularExpression(pattern: "at\\s+(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?", options: .caseInsensitive)
        if let regex = timeRegex {
            let range = NSRange(location: 0, length: message.count)
            if let match = regex.firstMatch(in: message, options: [], range: range) {
                let hourRange = match.range(at: 1)
                if let hourString = Range(hourRange, in: message).map({ String(message[$0]) }),
                   let hour = Int(hourString) {
                    return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)
                }
            }
        }
        
        // Check for relative time patterns
        if lowerMessage.contains("now") || lowerMessage.contains("immediately") {
            return now
        } else if lowerMessage.contains("in 1 hour") || lowerMessage.contains("in an hour") {
            return calendar.date(byAdding: .hour, value: 1, to: now)
        } else if lowerMessage.contains("in 30 minutes") || lowerMessage.contains("in half hour") {
            return calendar.date(byAdding: .minute, value: 30, to: now)
        } else if lowerMessage.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }
        
        return nil
    }
    
    private func findNextAvailableTime() -> Date {
        let now = Date()
        let calendar = Calendar.current
        let currentMinute = calendar.component(.minute, from: now)
        let roundedMinute = ((currentMinute / 15) + 1) * 15
        
        return calendar.date(byAdding: .minute, value: roundedMinute - currentMinute, to: now) ?? now
    }
    
    // MARK: - Smart Extraction Functions
    
    private func extractGoalTitle(from message: String) -> String {
        let lowerMessage = message.lowercased()
        
        // Try to extract goal from common patterns
        if let range = lowerMessage.range(of: "goal") {
            let afterGoal = String(lowerMessage[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let firstWord = afterGoal.split(separator: " ").first {
                return String(firstWord).capitalized
            }
        }
        
        // Look for "want to", "hope to", etc.
        let goalPatterns = ["want to", "hope to", "need to", "plan to", "goal is"]
        for pattern in goalPatterns {
            if let range = lowerMessage.range(of: pattern) {
                let afterPattern = String(lowerMessage[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !afterPattern.isEmpty {
                    return afterPattern.prefix(20).capitalized
                }
            }
        }
        
        return "New Goal"
    }
    
    private func extractPillarName(from message: String) -> String {
        let lowerMessage = message.lowercased()
        
        // Look for pillar indicators
        if let range = lowerMessage.range(of: "pillar") {
            let afterPillar = String(lowerMessage[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let firstWords = afterPillar.split(separator: " ").prefix(2).map(String.init).first {
                return firstWords.capitalized
            }
        }
        
        // Look for activity words
        let activityWords = ["exercise", "work", "reading", "meditation", "planning", "learning"]
        for word in activityWords {
            if lowerMessage.contains(word) {
                return word.capitalized
            }
        }
        
        return "New Pillar"
    }
    
    private func extractChainName(from message: String) -> String {
        let lowerMessage = message.lowercased()
        
        // Look for chain indicators
        if let range = lowerMessage.range(of: "chain") {
            let afterChain = String(lowerMessage[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !afterChain.isEmpty {
                return afterChain.prefix(15).capitalized
            }
        }
        
        // Look for routine/sequence words
        let routineWords = ["routine", "sequence", "flow", "series"]
        for word in routineWords {
            if lowerMessage.contains(word) {
                return "\(word.capitalized) Chain"
            }
        }
        
        return "New Chain"
    }
    
    private func determineImportanceFromMessage(_ message: String) -> Int {
        let lowerMessage = message.lowercased()
        
        if lowerMessage.contains("critical") || lowerMessage.contains("urgent") || lowerMessage.contains("essential") {
            return 5
        } else if lowerMessage.contains("important") || lowerMessage.contains("priority") {
            return 4
        } else if lowerMessage.contains("nice to") || lowerMessage.contains("would like") {
            return 2
        }
        
        return 3 // Default
    }
    
    private func determinePillarType(from message: String) -> PillarType {
        let lowerMessage = message.lowercased()
        
        if lowerMessage.contains("principle") || lowerMessage.contains("value") || lowerMessage.contains("belief") || lowerMessage.contains("guide") {
            return .principle
        } else if lowerMessage.contains("schedule") || lowerMessage.contains("activity") || lowerMessage.contains("time") || lowerMessage.contains("routine") {
            return .actionable
        }
        
        return .actionable // Default to actionable
    }
    
    private func inferFrequency(from message: String) -> String {
        let lowerMessage = message.lowercased()
        
        if lowerMessage.contains("daily") || lowerMessage.contains("every day") {
            return "daily"
        } else if lowerMessage.contains("weekly") || lowerMessage.contains("once a week") {
            return "weekly"
        } else if lowerMessage.contains("as needed") || lowerMessage.contains("when needed") {
            return "as needed"
        }
        
        return "daily" // Default
    }
    
    private func inferTargetDate(from message: String) -> Date? {
        let lowerMessage = message.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        if lowerMessage.contains("this week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        } else if lowerMessage.contains("this month") {
            return calendar.date(byAdding: .month, value: 1, to: now)
        } else if lowerMessage.contains("3 months") {
            return calendar.date(byAdding: .month, value: 3, to: now)
        } else if lowerMessage.contains("6 months") {
            return calendar.date(byAdding: .month, value: 6, to: now)
        } else if lowerMessage.contains("year") {
            return calendar.date(byAdding: .year, value: 1, to: now)
        }
        
        return calendar.date(byAdding: .month, value: 3, to: now) // Default 3 months
    }
    
    private func extractWisdom(from message: String) -> String? {
        let lowerMessage = message.lowercased()
        
        if lowerMessage.contains("believe") || lowerMessage.contains("value") || lowerMessage.contains("principle") {
            // Try to extract the wisdom part
            let wisdomIndicators = ["believe that", "value", "principle is", "important to"]
            for indicator in wisdomIndicators {
                if let range = lowerMessage.range(of: indicator) {
                    let wisdom = String(lowerMessage[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !wisdom.isEmpty {
                        return wisdom.capitalized
                    }
                }
            }
        }
        
        return nil
    }
    
    private func selectGoalEmoji(for title: String) -> String {
        let lowerTitle = title.lowercased()
        
        if lowerTitle.contains("health") || lowerTitle.contains("fitness") {
            return "💪"
        } else if lowerTitle.contains("learn") || lowerTitle.contains("study") {
            return "📚"
        } else if lowerTitle.contains("work") || lowerTitle.contains("career") {
            return "💼"
        } else if lowerTitle.contains("project") || lowerTitle.contains("build") {
            return "🚀"
        } else if lowerTitle.contains("money") || lowerTitle.contains("financial") {
            return "💰"
        } else if lowerTitle.contains("travel") {
            return "✈️"
        } else if lowerTitle.contains("relationship") || lowerTitle.contains("social") {
            return "👥"
        }
        
        return "🎯" // Default goal emoji
    }
    
    private func selectPillarEmoji(for name: String) -> String {
        let lowerName = name.lowercased()
        
        if lowerName.contains("exercise") || lowerName.contains("fitness") {
            return "💪"
        } else if lowerName.contains("work") || lowerName.contains("deep") {
            return "💼"
        } else if lowerName.contains("rest") || lowerName.contains("sleep") {
            return "🌙"
        } else if lowerName.contains("eat") || lowerName.contains("meal") {
            return "🍽️"
        } else if lowerName.contains("learn") || lowerName.contains("read") {
            return "📚"
        } else if lowerName.contains("meditate") || lowerName.contains("mindful") {
            return "🧘‍♀️"
        }
        
        return "🏛️" // Default pillar emoji
    }
    
    private func selectChainEmoji(for name: String) -> String {
        let lowerName = name.lowercased()
        
        if lowerName.contains("morning") {
            return "🌅"
        } else if lowerName.contains("evening") {
            return "🌙"
        } else if lowerName.contains("work") || lowerName.contains("focus") {
            return "🎯"
        } else if lowerName.contains("exercise") || lowerName.contains("workout") {
            return "💪"
        } else if lowerName.contains("creative") || lowerName.contains("art") {
            return "🎨"
        }
        
        return "🔗" // Default chain emoji
    }
    
    private func findRelatedPillars(for title: String) -> [Pillar] {
        let lowerTitle = title.lowercased()
        
        return dataManager.appState.pillars.filter { pillar in
            let pillarWords = pillar.name.lowercased().split(separator: " ")
            let titleWords = lowerTitle.split(separator: " ")
            
            let overlap = Set(pillarWords).intersection(Set(titleWords))
            return overlap.count >= 1
        }
    }
    
    private func createDefaultChainBlocks(from message: String) -> [TimeBlock] {
        // Create simple default blocks based on message content
        let lowerMessage = message.lowercased()
        
        if lowerMessage.contains("morning") {
            return [
                TimeBlock(title: "Preparation", startTime: Date(), duration: 900, energy: .sunrise, emoji: "🌅"),
                TimeBlock(title: "Main Activity", startTime: Date(), duration: 1800, energy: .sunrise, emoji: "💎"),
                TimeBlock(title: "Wrap-up", startTime: Date(), duration: 600, energy: .daylight, emoji: "☁️")
            ]
        } else if lowerMessage.contains("work") {
            return [
                TimeBlock(title: "Setup", startTime: Date(), duration: 600, energy: .daylight, emoji: "💎"),
                TimeBlock(title: "Focus Work", startTime: Date(), duration: 3600, energy: .daylight, emoji: "💎"),
                TimeBlock(title: "Review", startTime: Date(), duration: 900, energy: .daylight, emoji: "☁️")
            ]
        } else {
            return [
                TimeBlock(title: "Start", startTime: Date(), duration: 1200, energy: .daylight, emoji: "🌊"),
                TimeBlock(title: "Continue", startTime: Date(), duration: 1800, energy: .daylight, emoji: "🌊")
            ]
        }
    }
    
    // MARK: - Smart Suggestion Functions
    
    // Helper methods are already defined in the core chat section above
}

// MARK: - AI Outgo Section

struct AIOutgoSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var currentWisdom: String = ""
    @State private var patterns: [String] = []
    @State private var suggestions: [String] = []
    @State private var isGeneratingWisdom = false
    @State private var showingFullAnalysis = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🌟 AI Outgo")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                
                Spacer()
                
                Button("Full Analysis") {
                    showingFullAnalysis = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Current wisdom/insight
            if !currentWisdom.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Insight")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(currentWisdom)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(12)
                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            
            // Quick patterns identified
            if !patterns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Patterns Detected")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 4) {
                        ForEach(patterns.prefix(3), id: \.self) { pattern in
                            HStack {
                                Text("•")
                                    .foregroundStyle(.blue)
                                Text(pattern)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            
            // Action suggestions
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggestions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.green.opacity(0.1), in: Capsule())
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            
            // Wisdom generation button
            if currentWisdom.isEmpty && !isGeneratingWisdom {
                Button("Generate Wisdom") {
                    generateWisdom()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            } else if isGeneratingWisdom {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing your data...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if currentWisdom.isEmpty {
                generateWisdom()
            }
        }
        .sheet(isPresented: $showingFullAnalysis) {
            AIAnalysisView()
                .environmentObject(dataManager)
                .environmentObject(aiService)
        }
    }
    
    private func generateWisdom() {
        isGeneratingWisdom = true
        
        Task {
            do {
                let context = dataManager.createEnhancedContext()
                let wisdomPrompt = buildWisdomPrompt(context: context)
                
                let response = try await aiService.processMessage(wisdomPrompt, context: context)
                
                await MainActor.run {
                    parseWisdomResponse(response.text)
                    isGeneratingWisdom = false
                }
            } catch {
                await MainActor.run {
                    currentWisdom = "Your data shows consistent growth patterns. Keep building on your established routines."
                    isGeneratingWisdom = false
                }
            }
        }
    }
    
    private func buildWisdomPrompt(context: DayContext) -> String {
        let backfillDays = dataManager.appState.historicalDays.count
        let goalAlignment = calculateGoalAlignment()
        let pillarAdherence = calculatePillarAdherence()
        
        return """
        Analyze user's data and provide wise, actionable insights.
        
        Data summary:
        - Historical days recorded: \(backfillDays)
        - Goal alignment score: \(String(format: "%.1f", goalAlignment))/10
        - Pillar adherence: \(String(format: "%.1f", pillarAdherence))/10
        - Current patterns: \(dataManager.appState.userPatterns.suffix(5).joined(separator: ", "))
        
        Provide:
        1. One insightful observation (2-3 sentences)
        2. Top 3 patterns you notice
        3. 2-3 actionable suggestions
        
        Be wise, encouraging, and specific. Focus on gaps between goals/pillars and actual behavior.
        """
    }
    
    private func parseWisdomResponse(_ response: String) {
        // Simple parsing - in production would use structured JSON
        let lines = response.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        if let wisdomLine = lines.first {
            currentWisdom = wisdomLine
        }
        
        patterns = lines.filter { $0.contains("pattern") || $0.contains("•") }.prefix(3).map { $0 }
        suggestions = lines.filter { $0.contains("suggest") || $0.contains("try") || $0.contains("consider") }.prefix(3).map { $0 }
    }
    
    private func calculateGoalAlignment() -> Double {
        let activeGoals = dataManager.appState.goals.filter(\.isActive)
        guard !activeGoals.isEmpty else { return 5.0 }
        
        let avgProgress = activeGoals.map(\.progress).reduce(0, +) / Double(activeGoals.count)
        return avgProgress * 10
    }
    
    private func calculatePillarAdherence() -> Double {
        let actionablePillars = dataManager.appState.pillars.filter(\.isActionable)
        guard !actionablePillars.isEmpty else { return 7.0 }
        
        // Simple calculation based on how recently pillar events were created
        let now = Date()
        let adherenceScores = actionablePillars.map { pillar in
            guard let lastEvent = pillar.lastEventDate else { return 3.0 }
            let daysSince = now.timeIntervalSince(lastEvent) / 86400
            
            switch pillar.frequency {
            case .daily: return daysSince <= 1 ? 10.0 : max(0, 10 - daysSince)
            case .weekly: return daysSince <= 7 ? 10.0 : max(0, 10 - (daysSince / 7))
            default: return 7.0
            }
        }
        
        return adherenceScores.reduce(0, +) / Double(adherenceScores.count)
    }
}

struct AIAnalysisView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @State private var analysisText = ""
    @State private var isGenerating = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Comprehensive AI Analysis")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if isGenerating {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Analyzing your complete data profile...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        Text(analysisText)
                            .font(.body)
                            .lineSpacing(6)
                    }
                }
                .padding(24)
            }
            .navigationTitle("AI Analysis")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 700, height: 600)
        .task {
            await generateFullAnalysis()
        }
    }
    
    private func generateFullAnalysis() async {
        // Generate comprehensive analysis of user's data patterns, goal alignment, etc.
        await MainActor.run {
            analysisText = """
            Based on your data, I notice several important patterns:
            
            📊 Data Quality: You have \(dataManager.appState.historicalDays.count) days of backfill data, which helps me understand your true patterns versus your aspirational goals.
            
            🎯 Goal Alignment: Your active goals show varying levels of progress. Consider breaking down larger goals into specific chains or pillar activities.
            
            ⛰️ Pillar Strength: Your \(dataManager.appState.pillars.filter(\.isPrinciple).count) principle pillars provide good guidance, while your \(dataManager.appState.pillars.filter(\.isActionable).count) actionable pillars need consistent application.
            
            🔗 Chain Usage: You've created \(dataManager.appState.recentChains.count) chains, showing good understanding of activity sequences.
            
            💡 Recommendations:
            - Focus on consistent backfill to improve AI accuracy
            - Align daily activities with your principle pillars
            - Break down large goals into actionable chains
            - Use pillar day function to catch up on missed pillar activities
            """
            isGenerating = false
        }
    }
}

struct EnhancedIntakeQuestionView: View {
    let question: IntakeQuestion
    let onAnswerTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var showingAIThoughts = false
    
    var body: some View {
        Button(action: onAnswerTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(question.isAnswered ? .green : .orange)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(question.category.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.2), in: Capsule())
                            .foregroundColor(categoryColor)
                        
                        if question.isAnswered {
                            Text("Answered \(question.answeredAt?.timeString ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Importance indicator
                        HStack(spacing: 1) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < question.importance ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(index < question.importance ? .orange : .gray.opacity(0.3))
                            }
                        }
                    }
                }
                
                Spacer()
                
                if question.isAnswered {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            showingAIThoughts = true
        }
        .popover(isPresented: $showingAIThoughts) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Why AI asks this")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(question.aiInsight ?? "This question helps the AI understand your patterns and preferences better.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if question.isAnswered, let answer = question.answer {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your answer:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(answer)
                            .font(.body)
                            .padding(8)
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                Text("XP gained: +\(question.importance * 2)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding()
            .frame(width: 300, height: 200)
        }
    }
    
    private var categoryColor: Color {
        switch question.category {
        case .routine: return .blue
        case .preferences: return .green
        case .constraints: return .red
        case .goals: return .purple
        case .energy: return .orange
        case .context: return .gray
        }
    }
}

// MARK: - AI Knowledge View

struct AIKnowledgeView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // XP breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Knowledge About You (XP: \(dataManager.appState.userXP))")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("The AI learns about your preferences, patterns, and constraints to make better suggestions.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Answered questions
                    if !answeredQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What AI knows from your answers:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(answeredQuestions) { question in
                                KnowledgeItem(
                                    title: question.question,
                                    answer: question.answer ?? "",
                                    category: question.category.rawValue,
                                    xpValue: question.importance * 2
                                )
                            }
                        }
                    }
                    
                    // Detected patterns
                    if !dataManager.appState.userPatterns.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Detected patterns:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(dataManager.appState.userPatterns.prefix(10), id: \.self) { pattern in
                                Text("• \(pattern.capitalized)")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Goals and preferences
                    if !dataManager.appState.goals.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active goals influencing suggestions:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(dataManager.appState.goals.filter { $0.isActive }) { goal in
                                HStack {
                                    Text(goal.title)
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    Text("Importance: \(goal.importance)/5")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("What AI Knows")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private var answeredQuestions: [IntakeQuestion] {
        dataManager.appState.intakeQuestions.filter(\.isAnswered)
    }
}

struct KnowledgeItem: View {
    let title: String
    let answer: String
    let category: String
    let xpValue: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("+\(xpValue) XP")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.2), in: Capsule())
                    .foregroundColor(.blue)
            }
            
            Text(answer)
                .font(.body)
                .foregroundColor(.primary)
                .padding(8)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
            
            Text(category)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct IntakeQuestionView: View {
    let question: IntakeQuestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(question.isAnswered ? .green : .orange)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    Text(question.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if question.isAnswered {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct IntakeQuestionDetailView: View {
    let question: IntakeQuestion
    let onSave: (IntakeQuestion) -> Void
    
    @State private var answer: String
    @Environment(\.dismiss) private var dismiss
    
    init(question: IntakeQuestion, onSave: @escaping (IntakeQuestion) -> Void) {
        self.question = question
        self.onSave = onSave
        self._answer = State(initialValue: question.answer ?? "")
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Question")
                        .font(.headline)
                    
                    Text(question.question)
                        .font(.body)
                        .padding()
                        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Answer")
                        .font(.headline)
                    
                    TextField("Type your answer here...", text: $answer, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                if let insight = question.aiInsight {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why we ask this")
                            .font(.headline)
                        
                        Text(insight)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Intake Question")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updatedQuestion = question
                        updatedQuestion.answer = answer.isEmpty ? nil : answer
                        updatedQuestion.answeredAt = answer.isEmpty ? nil : Date()
                        onSave(updatedQuestion)
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

