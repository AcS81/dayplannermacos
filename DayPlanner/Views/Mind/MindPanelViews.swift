//
//  MindPanelViews.swift
//  DayPlanner
//
//  Mind Panel and Related Components
//

import SwiftUI

// MARK: - Mind Panel

struct MindPanel: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Binding var selectedTimeframe: TimeframeSelector
    
    var body: some View {
        VStack(spacing: 0) {
            // Mind header with timeframe selector
            MindPanelHeader(selectedTimeframe: $selectedTimeframe)
            
            // Scrollable mind content
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Core Chat section - the brain of the mind tab
                    CoreChatSection()
                        .environmentObject(dataManager)
                        .environmentObject(aiService)
                    
                    // Enhanced goals section with breakdown functionality
                    EnhancedGoalsSection()
                        .environmentObject(dataManager)
                        .environmentObject(aiService)
                    
                    // Pillars section with crystal aesthetics
                    CrystalPillarsSection()
                        .environmentObject(dataManager)
                    
                    // Intake section (without core chat)
                    IntakeQuestionsSection()
                        .environmentObject(dataManager)
                        .environmentObject(aiService)
                    
                    // Dream builder with aurora gradients
                    AuroraDreamBuilderSection()
                        .environmentObject(dataManager)
                    
                    // AI Outgo section - wisdom and feedback
                    AIOutgoSection()
                        .environmentObject(dataManager)
                        .environmentObject(aiService)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .background(.ultraThinMaterial.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.leading, 4)
        .padding(.trailing, 8)  // Better centered on right
        .padding(.vertical, 12)
    }
}

// MARK: - Mind Panel Header

struct MindPanelHeader: View {
    @Binding var selectedTimeframe: TimeframeSelector
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mind")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("Chains • Pillars • Goals")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Timeframe selector with liquid glass styling
            TimeframeSelectorCompact(selection: $selectedTimeframe)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Timeframe Selector Compact

struct TimeframeSelectorCompact: View {
    @Binding var selection: TimeframeSelector
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimeframeSelector.allCases, id: \.self) { timeframe in
                Button(action: { 
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selection = timeframe
                    }
                }) {
                    Text(timeframe.shortTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            selection == timeframe 
                                ? .blue.opacity(0.15) 
                                : .clear,
                            in: Capsule()
                        )
                        .foregroundStyle(selection == timeframe ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(.quaternary.opacity(0.5), in: Capsule())
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
                    // Core Chat section
                    CoreChatSection()
                        .environmentObject(dataManager)
                        .environmentObject(aiService)
                    
                    // Goals section
                    GoalsSection()
                    
                    // Pillars section
                    PillarsSection()
                    
                    // Intake Questions section
                    IntakeQuestionsSection()
                        .environmentObject(dataManager)
                        .environmentObject(aiService)
                    
                    // Dream Builder section
                    DreamBuilderSection()
                }
                .padding()
            }
        }
    }
}

struct TimeframeSelectorView: View {
    @Binding var selection: TimeframeSelector
    
    var body: some View {
        Picker("Timeframe", selection: $selection) {
            ForEach(TimeframeSelector.allCases, id: \.self) { timeframe in
                Text(timeframe.rawValue).tag(timeframe)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

// MARK: - Section Components

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
