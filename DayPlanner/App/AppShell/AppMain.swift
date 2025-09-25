//
//  DayPlannerApp.swift
//  DayPlanner
//
//  Liquid Glass Day Planner - Main App
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - App Tab Enum

enum AppTab: String, CaseIterable {
    case calendar = "calendar"
    case mind = "mind"
    
    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .mind: return "Mind"
        }
    }
}

@main
struct DayPlannerApp: App {
    @StateObject private var dataManager = AppDataManager()
    @StateObject private var aiService = AIService()
    
    var body: some Scene {
        WindowGroup {
            RippleContainer {
                ContentView()
                    .environmentObject(dataManager)
                    .environmentObject(aiService)
            }
            .frame(minWidth: 1000, minHeight: 700)
            .background(.ultraThinMaterial)
            .clipped() // Prevent UI from moving outside bounds
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Time Block") {
                    // Create a new time block at the current time
                    let now = Date()
                    let _ = TimeBlock(
                        title: "New Task",
                        startTime: now,
                        duration: 3600, // 1 hour
                        energy: .daylight,
                        emoji: "📋"
                    )
                    // Note: Would need to access dataManager here in a real implementation
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Button("AI Assistant") {
                    // Focus on the AI action bar
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Divider()
                
                Button("Export Day") {
                    // Trigger export functionality
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.json]
                    panel.nameFieldStringValue = "DayPlanner_Export_\(Date().formatted(.iso8601.year().month().day()))"
                    panel.begin { result in
                        if result == .OK, let url = panel.url {
                            // Note: Would need to access dataManager here in a real implementation
                            print("Export to: \(url)")
                        }
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}


// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var showingSettings = false
    @State private var showingAIDiagnostics = false
    @State private var selectedTab: AppTab = .calendar
    @State private var selectedDate = Date() // Shared date state across tabs
    @State private var showingSettingsPanel = false
    @State private var showingXPDisplay = false
    @State private var showingMindPanel = false // Control mind panel visibility
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top bar with XP/XXP and status
                TopBarView(
                    xp: dataManager.appState.userXP,
                    xxp: dataManager.appState.userXXP,
                    aiConnected: aiService.isConnected,
                    showingMindPanel: $showingMindPanel,
                    hideSettingsButton: showingSettingsPanel,
                    onSettingsTap: { 
                        if showingSettingsPanel {
                            showingSettings = true
                        } else {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showingSettingsPanel = true
                            }
                            // Show XP display after panel slides in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    showingXPDisplay = true
                                }
                            }
                        }
                    },
                    onDiagnosticsTap: { showingAIDiagnostics = true }
                )
                
                
                // Main unified split view - Both calendar and mind visible simultaneously
                UnifiedSplitView(selectedDate: $selectedDate, showingMindPanel: $showingMindPanel)
                    .environmentObject(dataManager)
                    .environmentObject(aiService)
                
                // Floating Action Bar overlay
                Spacer()
            }
            
            // Animated Settings Strip - positioned at top to cover settings button
            if showingSettingsPanel {
                VStack {
                    AnimatedSettingsStrip(
                        xp: dataManager.appState.userXP,
                        xxp: dataManager.appState.userXXP,
                        isVisible: showingSettingsPanel,
                        showingXPDisplay: showingXPDisplay,
                        onClose: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showingSettingsPanel = false
                                showingXPDisplay = false
                            }
                        },
                        onSettingsTap: {
                            showingSettings = true
                        }
                    )
                    Spacer()
                }
            }
            
            // Floating Action Bar - positioned as overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionBarView()
                        .environmentObject(dataManager)
                        .environmentObject(aiService)
                        .frame(maxWidth: 600)
                    Spacer()
                }
                .padding(.bottom, 20)
                
                // Bottom Mind Button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingMindPanel.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Mind")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.bottom, 20)
            }
            
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingAIDiagnostics) {
            AIDiagnosticsView()
                .environmentObject(aiService)
        }
        .onTapGesture {
            if showingSettingsPanel {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showingSettingsPanel = false
                    showingXPDisplay = false
                }
            }
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

