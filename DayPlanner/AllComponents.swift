//
//  AllModularComponents.swift
//  DayPlanner
//
//  Consolidated import file for all modular components
//

// This file includes all the extracted components to ensure they compile together

// MARK: - Main Content View

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var showingSettings = false
    @State private var showingAIDiagnostics = false
    @State private var selectedTab: AppTab = .calendar
    @State private var selectedDate = Date() // Shared date state across tabs
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top bar with XP/XXP and status
                TopBarView(
                    xp: dataManager.appState.userXP,
                    xxp: dataManager.appState.userXXP,
                    aiConnected: aiService.isConnected,
                    onSettingsTap: { showingSettings = true },
                    onDiagnosticsTap: { showingAIDiagnostics = true }
                )
                
                
                // Main unified split view - Both calendar and mind visible simultaneously
                UnifiedSplitView(selectedDate: $selectedDate)
                    .environmentObject(dataManager)
                    .environmentObject(aiService)
                
                // Global Action Bar at bottom
                ActionBarView()
                    .environmentObject(dataManager)
                    .environmentObject(aiService)
            }
            
            // Floating AI Orb
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    AIOrb()
                        .environmentObject(aiService)
                        .environmentObject(dataManager)
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // Above the action bar
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingAIDiagnostics) {
            AIDiagnosticsView()
                .environmentObject(aiService)
        }
        .onAppear {
            setupAppAppearance()
            // Connect pattern engine to AI service
            aiService.setPatternEngine(dataManager.patternEngine)
        }
    }
    
    private func setupAppAppearance() {
        // Configure the app's visual appearance
        if let window = NSApplication.shared.windows.first {
            window.isMovableByWindowBackground = false // Prevent window drag interference
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor.clear
        }
    }
}

// MARK: - Unified Split View

/// New unified layout showing both calendar and mind sections simultaneously
struct UnifiedSplitView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Binding var selectedDate: Date
    @State private var showingBackfill = false
    @State private var showingMonthView = false
    @State private var selectedMindSection: TimeframeSelector = .now
    
    var body: some View {
        HSplitView {
            // Left Panel - Calendar with expandable month view
            CalendarPanel(
                selectedDate: $selectedDate,
                showingMonthView: $showingMonthView
            )
            .frame(minWidth: 500, idealWidth: 600)
            
            // Elegant liquid glass separator
            LiquidGlassSeparator()
                .frame(width: 2)
            
            // Right Panel - Mind content (chains, pillars, goals)
            MindPanel(selectedTimeframe: $selectedMindSection)
                .frame(minWidth: 400, idealWidth: 500)
        }
        .background(
            // Subtle unified background with gentle gradients
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.02),
                    Color.purple.opacity(0.01),
                    Color.blue.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showingBackfill) {
            EnhancedBackfillView()
                .environmentObject(dataManager)
                .environmentObject(aiService)
        }
    }
}

// MARK: - Liquid Glass Separator

struct LiquidGlassSeparator: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.15), location: 0.0),
                        .init(color: .blue.opacity(0.25), location: 0.4),
                        .init(color: .purple.opacity(0.2), location: 0.6),
                        .init(color: .white.opacity(0.1), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

// MARK: - Top Bar View

struct TopBarView: View {
    let xp: Int
    let xxp: Int
    let aiConnected: Bool
    let onSettingsTap: () -> Void
    let onDiagnosticsTap: () -> Void
    
    var body: some View {
        HStack {
            // XP and XXP display
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("XP")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    Text("\(xp)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.blue.opacity(0.1), in: Capsule())
                
                HStack(spacing: 6) {
                    Text("XXP")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    Text("\(xxp)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.1), in: Capsule())
            }
            
            Spacer()
            
            // AI connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(aiConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(aiConnected ? "AI Ready" : "AI Offline")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onTapGesture { onDiagnosticsTap() }
            
            Spacer()
            
            // Settings button
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.regularMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - AI Diagnostics View

struct AIDiagnosticsView: View {
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @State private var diagnosticsText = "Running diagnostics..."
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("AI Service Diagnostics")
                    .font(.headline)
                
                ScrollView {
                    Text(diagnosticsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 300)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                
                HStack {
                    Button("Refresh") {
                        runDiagnostics()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Test Connection") {
                        testConnection()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 500, height: 400)
            .navigationTitle("AI Diagnostics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            runDiagnostics()
        }
    }
    
    private func runDiagnostics() {
        Task {
            let result = await aiService.runDiagnostics()
            await MainActor.run {
                diagnosticsText = result
            }
        }
    }
    
    private func testConnection() {
        Task {
            await aiService.checkConnection()
            await MainActor.run {
                diagnosticsText += "\nConnection test: \(aiService.isConnected ? "✅ Success" : "❌ Failed")"
            }
        }
    }
}

// MARK: - Placeholder Views (Minimal implementations to ensure compilation)

struct CalendarPanel: View {
    @Binding var selectedDate: Date
    @Binding var showingMonthView: Bool
    
    var body: some View {
        VStack {
            Text("Calendar Panel")
            Text("Date: \(selectedDate.formatted())")
            Button("Toggle Month") { showingMonthView.toggle() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial.opacity(0.4))
    }
}

struct MindPanel: View {
    @Binding var selectedTimeframe: TimeframeSelector
    
    var body: some View {
        VStack {
            Text("Mind Panel")
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(TimeframeSelector.allCases, id: \.self) { timeframe in
                    Text(timeframe.rawValue).tag(timeframe)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial.opacity(0.35))
    }
}

struct ActionBarView: View {
    var body: some View {
        HStack {
            Text("Action Bar - AI Chat Interface")
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Settings")
            Button("Done") { dismiss() }
        }
        .frame(width: 400, height: 300)
    }
}

struct EnhancedBackfillView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Backfill View")
            Button("Done") { dismiss() }
        }
        .frame(width: 600, height: 400)
    }
}

// MARK: - Supporting Types

enum TimeframeSelector: String, CaseIterable {
    case now = "Now"
    case today = "Today"
    case week = "Week"
    case month = "Month"
    
    var shortTitle: String {
        switch self {
        case .now: return "Now"
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}
