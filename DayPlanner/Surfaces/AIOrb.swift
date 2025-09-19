//
//  AIOrb.swift
//  DayPlanner
//
//  Floating AI orb with aurora effects and voice interaction
//

import SwiftUI
import AVFoundation

// MARK: - AI Orb Main View

/// Floating AI orb that responds to user interaction with liquid glass effects
struct AIOrb: View {
    @StateObject private var orbState = OrbState()
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var dataManager: AppDataManager
    @Environment(\.rippleManager) private var rippleManager
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingExpanded = false
    @State private var currentMessage = ""
    
    private let orbSize: CGFloat = 60
    private let expandedSize: CGFloat = 400
    
    var body: some View {
        ZStack {
            // Expanded AI interface
            if showingExpanded {
                ExpandedAIInterface(
                    message: $currentMessage,
                    aiService: aiService,
                    onDismiss: collapseOrb,
                    onSuggestion: handleAISuggestion
                )
                .frame(width: expandedSize, height: expandedSize * 0.8)
                .transition(.scale.combined(with: .opacity))
            } else {
                // Compact orb
                CompactOrb(
                    state: orbState,
                    size: orbSize,
                    onTap: expandOrb,
                    onVoiceStart: startVoiceInput,
                    onVoiceEnd: endVoiceInput
                )
                .offset(dragOffset)
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .gesture(orbDragGesture)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingExpanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: isDragging)
    }
    
    // MARK: - Gestures & Interactions
    
    private var orbDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    orbState.startDragging()
                }
                dragOffset = value.translation
            }
            .onEnded { value in
                isDragging = false
                orbState.stopDragging()
                
                // Snap to edges or return to center
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    dragOffset = snapPosition(for: value.translation)
                }
            }
    }
    
    private func expandOrb() {
        orbState.expand()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showingExpanded = true
        }
        
        // Create expansion ripple
        rippleManager?.createRipple(at: CGPoint(x: orbSize/2, y: orbSize/2), type: .aiThinking)
    }
    
    private func collapseOrb() {
        orbState.contract()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            showingExpanded = false
        }
    }
    
    private func startVoiceInput() {
        orbState.startListening()
        // Voice input implementation would go here
    }
    
    private func endVoiceInput() {
        orbState.stopListening()
        // End voice input and process
    }
    
    private func handleAISuggestion(_ suggestion: Suggestion) {
        dataManager.applySuggestion(suggestion)
        
        // Create success ripple
        rippleManager?.createRipple(at: CGPoint(x: orbSize/2, y: orbSize/2), type: .success)
        
        // Contract after successful action
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            collapseOrb()
        }
    }
    
    private func snapPosition(for translation: CGSize) -> CGSize {
        // For now, return to center. Could implement edge snapping
        return .zero
    }
}

// MARK: - Orb State Management

/// Manages the visual and behavioral state of the AI orb
@MainActor
class OrbState: ObservableObject {
    @Published var size: CGFloat = 60
    @Published var currentColors: [Color] = [.blue, .purple, .cyan]
    @Published var auroraPhase: Double = 0
    @Published var isThinking = false
    @Published var isListening = false
    @Published var isDragging = false
    @Published var pulseIntensity: Double = 1.0
    
    private var auroraTimer: Timer?
    
    init() {
        startAuroraAnimation()
    }
    
    deinit {
        auroraTimer?.invalidate()
    }
    
    // MARK: - State Changes
    
    func expand() {
        size = 200
        currentColors = [.white, .blue, .clear]
        pulseIntensity = 1.5
    }
    
    func contract() {
        size = 60
        currentColors = [.blue, .purple, .cyan]
        pulseIntensity = 1.0
        isThinking = false
        isListening = false
    }
    
    func startThinking() {
        isThinking = true
        currentColors = [.orange, .yellow, .red]
        pulseIntensity = 2.0
    }
    
    func stopThinking() {
        isThinking = false
        currentColors = [.blue, .purple, .cyan]
        pulseIntensity = 1.0
    }
    
    func startListening() {
        isListening = true
        currentColors = [.green, .mint, .cyan]
        pulseIntensity = 1.8
    }
    
    func stopListening() {
        isListening = false
        currentColors = [.blue, .purple, .cyan]
        pulseIntensity = 1.0
    }
    
    func startDragging() {
        isDragging = true
        pulseIntensity = 0.8
        currentColors = [.white, .gray, .blue]
    }
    
    func stopDragging() {
        isDragging = false
        pulseIntensity = 1.0
        currentColors = [.blue, .purple, .cyan]
    }
    
    // MARK: - Aurora Animation
    
    private func startAuroraAnimation() {
        auroraTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.linear(duration: 0.1)) {
                    self.auroraPhase += 0.05
                    if self.auroraPhase >= 1.0 {
                        self.auroraPhase = 0
                    }
                }
            }
        }
    }
}

// MARK: - Compact Orb View

/// The small floating orb in its default state
struct CompactOrb: View {
    @ObservedObject var state: OrbState
    let size: CGFloat
    let onTap: () -> Void
    let onVoiceStart: () -> Void
    let onVoiceEnd: () -> Void
    
    var body: some View {
        ZStack {
            // Base orb with aurora gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: state.currentColors,
                        center: .center,
                        startRadius: 5,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(state.pulseIntensity)
                .modifier(AuroraEffect(phase: state.auroraPhase))
            
            // Thinking animation overlay
            if state.isThinking {
                ThinkingAnimation()
                    .frame(width: size * 1.2, height: size * 1.2)
            }
            
            // Listening animation overlay
            if state.isListening {
                ListeningAnimation()
                    .frame(width: size * 1.3, height: size * 1.3)
            }
            
            // Drag indicator
            if state.isDragging {
                Circle()
                    .strokeBorder(.white.opacity(0.5), lineWidth: 2)
                    .frame(width: size * 1.1, height: size * 1.1)
            }
        }
        .onTapGesture { onTap() }
        .onLongPressGesture(
            minimumDuration: 0.5,
            perform: { onVoiceStart() },
            onPressingChanged: { pressing in
                if !pressing { onVoiceEnd() }
            }
        )
    }
}

// MARK: - Expanded AI Interface

/// Full AI interaction interface when orb is expanded
struct ExpandedAIInterface: View {
    @Binding var message: String
    let aiService: AIService
    let onDismiss: () -> Void
    let onSuggestion: (Suggestion) -> Void
    
    @State private var suggestions: [Suggestion] = []
    @State private var isProcessing = false
    @State private var responseText = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with close button
            HStack {
                Text("AI Assistant")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Message input area
            VStack(spacing: 12) {
                TextField("Ask me anything about your day...", text: $message)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        processMessage()
                    }
                
                HStack {
                    Button("Send") {
                        processMessage()
                    }
                    .disabled(message.isEmpty || isProcessing)
                    
                    Spacer()
                    
                    if isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Response area
            if !responseText.isEmpty {
                ScrollView {
                    Text(responseText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxHeight: 100)
            }
            
            // Suggestions
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(suggestions) { suggestion in
                        SuggestionCard(
                            suggestion: suggestion,
                            onAccept: { onSuggestion(suggestion) }
                        )
                    }
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func processMessage() {
        guard !message.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            do {
                let context = DayContext(
                    date: Date(),
                    existingBlocks: [],
                    currentEnergy: .daylight,
                    preferredFlows: [.water],
                    availableTime: 3600,
                    mood: .crystal
                )
                
                let response = try await aiService.processMessage(message, context: context)
                
                await MainActor.run {
                    responseText = response.text
                    suggestions = response.suggestions
                    isProcessing = false
                    message = ""
                }
            } catch {
                await MainActor.run {
                    responseText = "Sorry, I couldn't process your request right now."
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Animation Effects

/// Aurora-like color shifting effect
struct AuroraEffect: ViewModifier {
    let phase: Double
    
    func body(content: Content) -> some View {
        content
            .hueRotation(.degrees(phase * 30))
            .scaleEffect(1.0 + sin(phase * .pi * 2) * 0.05)
            .opacity(0.9 + sin(phase * .pi * 2) * 0.1)
    }
}

/// Thinking animation with swirling particles
struct ThinkingAnimation: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<6) { index in
                Circle()
                    .fill(.orange.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .offset(x: 25)
                    .rotationEffect(.degrees(rotation + Double(index * 60)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

/// Listening animation with pulsing rings
struct ListeningAnimation: View {
    @State private var scale: Double = 1.0
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .strokeBorder(.green.opacity(0.4), lineWidth: 2)
                    .scaleEffect(scale)
                    .opacity(1.0 - scale * 0.5)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.5),
                        value: scale
                    )
            }
        }
        .onAppear {
            scale = 2.0
        }
    }
}

// MARK: - Suggestion Card

/// Individual suggestion card with accept/reject actions
struct SuggestionCard: View {
    let suggestion: Suggestion
    let onAccept: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(suggestion.explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Confidence indicator
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Button("Add") {
                onAccept()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
    
    private var confidenceColor: Color {
        switch suggestion.confidence {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AIOrb_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.1)
                .ignoresSafeArea()
            
            AIOrb()
        }
        .frame(width: 600, height: 400)
        .environmentObject(AppDataManager.preview)
    }
}
#endif
