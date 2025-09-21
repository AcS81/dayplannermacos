//
//  AIOrb.swift
//  DayPlanner
//
//  Floating AI orb with aurora effects and voice interaction
//

import SwiftUI
import AVFoundation

// MARK: - AI Orb Main View

/// Floating AI orb that provides visual feedback and system status
struct AIOrb: View {
    @StateObject private var orbState = OrbState()
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var dataManager: AppDataManager
    @Environment(\.rippleManager) private var rippleManager
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingStatus = false
    
    private let orbSize: CGFloat = 60
    
    var body: some View {
        // Simplified orb - just visual indicator and status
        CompactOrb(
            state: orbState,
            size: orbSize,
            onTap: showSystemStatus,
            onVoiceStart: nil, // Removed voice - handled by Action Bar
            onVoiceEnd: nil
        )
        .offset(dragOffset)
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .gesture(orbDragGesture)
        .sheet(isPresented: $showingStatus) {
            AISystemStatusSheet()
                .environmentObject(aiService)
                .environmentObject(dataManager)
        }
        .onAppear {
            // Sync orb state with AI service
            syncWithAIService()
        }
        .onReceive(aiService.$isProcessing) { isProcessing in
            if isProcessing {
                orbState.startThinking()
            } else {
                orbState.stopThinking()
            }
        }
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
    
    private func showSystemStatus() {
        showingStatus = true
        
        // Create status ripple
        rippleManager?.createRipple(at: CGPoint(x: orbSize/2, y: orbSize/2), type: .aiThinking)
    }
    
    private func syncWithAIService() {
        // Update orb appearance based on AI service state
        if aiService.isConnected {
            orbState.currentColors = [.blue, .purple, .cyan]
        } else {
            orbState.currentColors = [.red, .orange, .yellow]
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
    let onVoiceStart: (() -> Void)?
    let onVoiceEnd: (() -> Void)?
    
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
            perform: { onVoiceStart?() },
            onPressingChanged: { pressing in
                if !pressing { onVoiceEnd?() }
            }
        )
    }
}

// MARK: - AI System Status Sheet

/// Simple status sheet showing AI service diagnostics and pattern insights
struct AISystemStatusSheet: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var diagnosticsText = ""
    @State private var patternSummary = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("AI System Status")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Connection status
                HStack {
                    Circle()
                        .fill(aiService.isConnected ? .green : .red)
                        .frame(width: 12, height: 12)
                    
                    Text(aiService.isConnected ? "AI Ready" : "AI Offline")
                        .font(.headline)
                        .foregroundStyle(aiService.isConnected ? .green : .red)
                    
                    Spacer()
                    
                    if !aiService.isConnected {
                        Button("Reconnect") {
                            Task { await aiService.checkConnection() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                
                // Pattern intelligence summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Intelligence Summary")
                        .font(.headline)
                    
                    Text(patternSummary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                
                // System diagnostics
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Diagnostics")
                        .font(.headline)
                    
                    ScrollView {
                        Text(diagnosticsText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("AI Status")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadDiagnostics()
        }
    }
    
    private func loadDiagnostics() {
        Task {
            let diagnostics = await aiService.runDiagnostics()
            let patterns = getPatternSummary()
            
            await MainActor.run {
                diagnosticsText = diagnostics
                patternSummary = patterns
            }
        }
    }
    
    private func getPatternSummary() -> String {
        let patterns = dataManager.patternEngine.detectedPatterns
        let confidence = dataManager.patternEngine.confidence
        
        if patterns.isEmpty {
            return "Building intelligence about your patterns. Keep using the app to improve AI suggestions."
        }
        
        let highConfidenceCount = patterns.filter { $0.confidence > 0.7 }.count
        
        return """
        Detected \(patterns.count) patterns with \(Int(confidence * 100))% average confidence.
        \(highConfidenceCount) high-confidence patterns are being used for smart suggestions.
        
        Recent insights: \(dataManager.patternEngine.actionableInsights.prefix(2).map(\.title).joined(separator: ", "))
        """
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
            
            // Enhanced confidence indicator
            VStack(spacing: 2) {
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 8, height: 8)
                
                Text(confidenceText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
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
    
    private var confidenceText: String {
        let percentage = Int(suggestion.confidence * 100)
        return "\(percentage)%"
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
