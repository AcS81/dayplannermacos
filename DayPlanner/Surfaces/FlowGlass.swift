//
//  FlowGlass.swift
//  DayPlanner
//
//  Side panel for chain management with cascade animations
//

import SwiftUI

// MARK: - Flow Glass Main View

/// Side panel that shows chains and patterns with waterfall animations
struct FlowGlass: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var selectedChain: Chain? = nil
    @State private var showingChainCreator = false
    @State private var cascadePhase: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            FlowHeader(
                onCreateChain: { showingChainCreator = true }
            )
            
            Divider()
            
            // Chain list with cascade animation
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(dataManager.appState.recentChains.enumerated()), id: \.element.id) { index, chain in
                        ChainFlowCard(
                            chain: chain,
                            animationDelay: Double(index) * 0.1,
                            phase: cascadePhase,
                            onSelect: { selectedChain = chain },
                            onApply: { applyChain(chain) }
                        )
                    }
                    
                    // Empty state
                    if dataManager.appState.recentChains.isEmpty {
                        EmptyChainState()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Spacer()
            
            // Quick actions
            QuickActionsView(
                onSuggestChain: suggestChain,
                onClearChains: clearChains
            )
        }
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showingChainCreator) {
            ChainCreatorView { newChain in
                dataManager.addChain(newChain)
                showingChainCreator = false
            }
        }
        .sheet(item: $selectedChain) { chain in
            ChainDetailView(chain: chain)
        }
        .onAppear {
            startCascadeAnimation()
        }
    }
    
    // MARK: - Actions
    
    private func startCascadeAnimation() {
        withAnimation(.easeInOut(duration: 1.5)) {
            cascadePhase = 1.0
        }
    }
    
    private func applyChain(_ chain: Chain) {
        // Find next available time slot
        let startTime = findNextAvailableSlot()
        dataManager.applyChain(chain, startingAt: startTime)
        
        // Visual feedback
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Could add ripple effect here
        }
    }
    
    private func suggestChain() {
        // Create a suggested chain based on current context
        let suggestedChain = createSuggestedChain()
        dataManager.addChain(suggestedChain)
    }
    
    private func clearChains() {
        withAnimation(.easeOut(duration: 0.5)) {
            dataManager.appState.recentChains.removeAll()
        }
        dataManager.save()
    }
    
    private func findNextAvailableSlot() -> Date {
        // Simple implementation - find next hour
        let now = Date()
        let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        return Calendar.current.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
    }
    
    private func createSuggestedChain() -> Chain {
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        switch currentHour {
        case 6..<9:
            return Chain(
                name: "Morning Energy",
                blocks: [
                    TimeBlock.sample(title: "Stretch", hour: 8),
                    TimeBlock.sample(title: "Coffee", hour: 8),
                    TimeBlock.sample(title: "Plan Day", hour: 9)
                ],
                flowPattern: .waterfall
            )
        case 12..<14:
            return Chain(
                name: "Lunch Break",
                blocks: [
                    TimeBlock.sample(title: "Lunch", hour: 12),
                    TimeBlock.sample(title: "Walk", hour: 13)
                ],
                flowPattern: .wave
            )
        case 18..<22:
            return Chain(
                name: "Evening Wind Down",
                blocks: [
                    TimeBlock.sample(title: "Dinner", hour: 18),
                    TimeBlock.sample(title: "Relax", hour: 19),
                    TimeBlock.sample(title: "Read", hour: 20)
                ],
                flowPattern: .ripple
            )
        default:
            return Chain(
                name: "Focus Session",
                blocks: [
                    TimeBlock.sample(title: "Deep Work", hour: currentHour),
                    TimeBlock.sample(title: "Break", hour: currentHour + 1)
                ],
                flowPattern: .spiral
            )
        }
    }
}

// MARK: - Flow Header

struct FlowHeader: View {
    let onCreateChain: () -> Void
    
    var body: some View {
        HStack {
            Text("Chains")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onCreateChain) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Chain Flow Card

struct ChainFlowCard: View {
    let chain: Chain
    let animationDelay: Double
    let phase: Double
    let onSelect: () -> Void
    let onApply: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chain header
            HStack {
                Text(chain.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Flow pattern indicator
                Text(flowPatternEmoji)
                    .font(.caption)
            }
            
            // Chain info
            HStack {
                Label("\(chain.blocks.count) steps", systemImage: "link")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(chain.totalDurationMinutes)min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Action buttons (shown on hover)
            if isHovering {
                HStack {
                    Button("View") {
                        onSelect()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Button("Apply") {
                        onApply()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(12)
        .background(
            cardBackground
        )
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .offset(y: cardOffset)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isHovering)
    }
    
    private var flowPatternEmoji: String {
        switch chain.flowPattern {
        case .waterfall: return "⬇️"
        case .spiral: return "🌀"
        case .ripple: return "〰️"
        case .wave: return "🌊"
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary.opacity(isHovering ? 0.6 : 0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(isHovering ? 0.2 : 0.1), lineWidth: 1)
            )
    }
    
    private var cardScale: Double {
        let adjustedPhase = max(0, phase - animationDelay)
        return 0.8 + adjustedPhase * 0.2
    }
    
    private var cardOpacity: Double {
        let adjustedPhase = max(0, phase - animationDelay)
        return min(adjustedPhase * 2, 1.0)
    }
    
    private var cardOffset: CGFloat {
        let adjustedPhase = max(0, phase - animationDelay)
        return CGFloat((1.0 - adjustedPhase) * 30)
    }
}

// MARK: - Empty Chain State

struct EmptyChainState: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("🔗")
                .font(.system(size: 40))
                .opacity(0.6)
            
            Text("No chains yet")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Create chains by linking related activities together")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create First Chain") {
                // This would trigger chain creation
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
        )
    }
}

// MARK: - Quick Actions

struct QuickActionsView: View {
    let onSuggestChain: () -> Void
    let onClearChains: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Button("Suggest Chain") {
                onSuggestChain()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("Clear All") {
                onClearChains()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(16)
    }
}

// MARK: - Chain Creator View

struct ChainCreatorView: View {
    let onCreate: (Chain) -> Void
    
    @State private var chainName = ""
    @State private var blocks: [TimeBlock] = []
    @State private var selectedPattern: FlowPattern = .waterfall
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Chain name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chain Name")
                        .font(.headline)
                    
                    TextField("Enter chain name", text: $chainName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Flow pattern selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flow Pattern")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(FlowPattern.allCases, id: \.self) { pattern in
                            PatternCard(
                                pattern: pattern,
                                isSelected: selectedPattern == pattern,
                                onSelect: { selectedPattern = pattern }
                            )
                        }
                    }
                }
                
                // Blocks (simplified for MVP)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activities")
                        .font(.headline)
                    
                    Text("Add activities by linking them from your day view")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Create Chain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createChain()
                    }
                    .disabled(chainName.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private func createChain() {
        let newChain = Chain(
            name: chainName,
            blocks: blocks.isEmpty ? [TimeBlock.sample(title: "New Activity")] : blocks,
            flowPattern: selectedPattern
        )
        onCreate(newChain)
    }
}

// MARK: - Pattern Card

struct PatternCard: View {
    let pattern: FlowPattern
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Text(patternEmoji)
                    .font(.title2)
                
                Text(pattern.description)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? .blue.opacity(0.2) : .clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? .blue : .gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var patternEmoji: String {
        switch pattern {
        case .waterfall: return "⬇️"
        case .spiral: return "🌀"
        case .ripple: return "〰️"
        case .wave: return "🌊"
        }
    }
}

// MARK: - Chain Detail View

struct ChainDetailView: View {
    let chain: Chain
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    chainInfoSection
                    Divider()
                    activitiesSection
                }
                .padding(24)
            }
            .navigationTitle(chain.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private var chainInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chain Details")
                .font(.headline)
            
            HStack {
                Label("Duration", systemImage: "clock")
                Spacer()
                Text("\(chain.totalDurationMinutes) minutes")
            }
            
            HStack {
                Label("Activities", systemImage: "link")
                Spacer()
                Text("\(chain.blocks.count)")
            }
            
            HStack {
                Label("Pattern", systemImage: "waveform")
                Spacer()
                Text(chain.flowPattern.description)
            }
        }
    }
    
    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activities")
                .font(.headline)
            
            ForEach(Array(chain.blocks.enumerated()), id: \.element.id) { index, block in
                activityRow(index: index, block: block)
            }
        }
    }
    
    private func activityRow(index: Int, block: TimeBlock) -> some View {
        HStack {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline)
                Text("\(block.durationMinutes) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(block.energy.rawValue)
                Text(block.emoji)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct FlowGlass_Previews: PreviewProvider {
    static var previews: some View {
        FlowGlass()
            .frame(width: 300, height: 600)
            .environmentObject(AppDataManager.preview)
    }
}
#endif
