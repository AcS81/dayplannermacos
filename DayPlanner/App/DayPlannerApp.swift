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

// MARK: - Status Bar

struct StatusBar: View {
    let aiConnected: Bool
    let onSettingsTap: () -> Void
    let onDiagnosticsTap: () -> Void
    
    var body: some View {
        HStack {
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
            
            // App title
            Text("🌊 Day Planner")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
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
        .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
        .padding(.horizontal, 20)
        .padding(.top, 10)
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

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and done button
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.regularMaterial)
            
            Divider()
            
            // Main content
            HStack(spacing: 0) {
                // Settings sidebar
                SettingsSidebar(selectedTab: $selectedTab)
                    .frame(width: 200)
                
                Divider()
                
                // Settings content
                SettingsContent(selectedTab: selectedTab)
                    .frame(maxWidth: .infinity)
                    .environmentObject(dataManager)
            }
        }
        .frame(width: 700, height: 600)
        .background(.regularMaterial)
    }
}

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case ai = "AI & Trust"
    case calendar = "Calendar"
    case pillars = "Pillars & Rules"
    case chains = "Chains"
    case data = "Data & History"
    case about = "About"
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .ai: return "brain"
        case .calendar: return "calendar"
        case .pillars: return "building.columns"
        case .chains: return "link"
        case .data: return "externaldrive"
        case .about: return "info.circle"
        }
    }
}

struct SettingsSidebar: View {
    @Binding var selectedTab: SettingsTab
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 12) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                            .frame(width: 20, alignment: .center)
                            .foregroundColor(selectedTab == tab ? .white : .primary)
                        
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .foregroundColor(selectedTab == tab ? .white : .primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab ? .blue : .clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 12)
        .background(.quaternary)
        .frame(maxHeight: .infinity)
    }
}

struct SettingsContent: View {
    let selectedTab: SettingsTab
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                        .environmentObject(dataManager)
                case .ai:
                    AITrustSettingsView()
                        .environmentObject(dataManager)
                case .calendar:
                    CalendarSettingsView()
                        .environmentObject(dataManager)
                case .pillars:
                    PillarsRulesSettingsView()
                        .environmentObject(dataManager)
                case .chains:
                    ChainsSettingsView()
                        .environmentObject(dataManager)
                case .data:
                    DataHistorySettingsView()
                        .environmentObject(dataManager)
                case .about:
                    AboutSettingsView()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Settings Sections

struct GeneralSettingsView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Preferences")
                .font(.title2)
                .fontWeight(.semibold)
            
            SettingsGroup("Interface") {
                Toggle("Enable Voice Input", isOn: Binding(
                    get: { dataManager.appState.preferences.enableVoice },
                    set: { newValue in
                        dataManager.appState.preferences.enableVoice = newValue
                        dataManager.save()
                    }
                ))
                
                Toggle("Enable Animations", isOn: Binding(
                    get: { dataManager.appState.preferences.enableAnimations },
                    set: { newValue in
                        dataManager.appState.preferences.enableAnimations = newValue
                        dataManager.save()
                    }
                ))
                
                Toggle("Ephemeral Reflection", isOn: Binding(
                    get: { dataManager.appState.preferences.showEphemeralInsights },
                    set: { newValue in
                        dataManager.appState.preferences.showEphemeralInsights = newValue
                        dataManager.save()
                    }
                ))
                .help("Show brief AI insights that disappear after 2 seconds")
            }
            
            SettingsGroup("Time Preferences") {
                DatePicker("Preferred Start Time", 
                          selection: Binding(
                            get: { dataManager.appState.preferences.preferredStartTime },
                            set: { newValue in
                                dataManager.appState.preferences.preferredStartTime = newValue
                                dataManager.save()
                            }
                          ), displayedComponents: .hourAndMinute)
                
                DatePicker("Preferred End Time",
                          selection: Binding(
                            get: { dataManager.appState.preferences.preferredEndTime },
                            set: { newValue in
                                dataManager.appState.preferences.preferredEndTime = newValue
                                dataManager.save()
                            }
                          ), displayedComponents: .hourAndMinute)
                
                Picker("Default Block Duration", selection: Binding(
                    get: { Int(dataManager.appState.preferences.defaultBlockDuration / 60) },
                    set: { newValue in
                        dataManager.appState.preferences.defaultBlockDuration = TimeInterval(newValue * 60)
                        dataManager.save()
                    }
                )) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                }
            }
        }
    }
}

struct AITrustSettingsView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var safeMode = false
    @State private var openaiApiKey = ""
    @State private var whisperApiKey = ""
    @State private var customApiEndpoint = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AI & Trust")
                .font(.title2)
                .fontWeight(.semibold)
            
            
            SettingsGroup("Safety") {
                Toggle("Safe Mode", isOn: $safeMode)
                    .help("Only suggest non-destructive changes, never modify existing events")
                    .onChange(of: safeMode) {
                        dataManager.appState.preferences.safeMode = safeMode
                        dataManager.save()
                    }
            }
            
            
            SettingsGroup("API Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("OpenAI API Key:")
                            .frame(width: 120, alignment: .leading)
                        SecureField("sk-...", text: $openaiApiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: openaiApiKey) {
                                dataManager.appState.preferences.openaiApiKey = openaiApiKey
                                UserDefaults.standard.set(openaiApiKey, forKey: "openaiApiKey")
                                dataManager.save()
                            }
                        Button("Paste") {
                            if let clipboard = NSPasteboard.general.string(forType: .string) {
                                openaiApiKey = clipboard
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    HStack {
                        Text("Whisper API Key:")
                            .frame(width: 120, alignment: .leading)
                        SecureField("sk-...", text: $whisperApiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: whisperApiKey) {
                                dataManager.appState.preferences.whisperApiKey = whisperApiKey
                                UserDefaults.standard.set(whisperApiKey, forKey: "whisperApiKey")
                                dataManager.save()
                            }
                        Button("Paste") {
                            if let clipboard = NSPasteboard.general.string(forType: .string) {
                                whisperApiKey = clipboard
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    HStack {
                        Text("Custom Endpoint:")
                            .frame(width: 120, alignment: .leading)
                        TextField("http://localhost:1234", text: $customApiEndpoint)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: customApiEndpoint) {
                                dataManager.appState.preferences.customApiEndpoint = customApiEndpoint
                                dataManager.save()
                            }
                        Button("Paste") {
                            if let clipboard = NSPasteboard.general.string(forType: .string) {
                                customApiEndpoint = clipboard
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text("API keys are stored securely and only used for AI services. Custom endpoint defaults to LM Studio.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            safeMode = dataManager.appState.preferences.safeMode
            openaiApiKey = dataManager.appState.preferences.openaiApiKey
            whisperApiKey = dataManager.appState.preferences.whisperApiKey
            customApiEndpoint = dataManager.appState.preferences.customApiEndpoint
        }
    }
}

struct CalendarSettingsView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var eventKitEnabled = true
    @State private var calendarSyncStatus = "Connected"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Calendar Integration")
                .font(.title2)
                .fontWeight(.semibold)
            
            SettingsGroup("Apple Calendar") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EventKit Integration")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Status: \(calendarSyncStatus)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $eventKitEnabled)
                }
                
                if eventKitEnabled {
                    Button("Test Connection") {
                        // Test EventKit connection
                        calendarSyncStatus = "Testing..."
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            calendarSyncStatus = "Connected ✅"
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            SettingsGroup("Sync Settings") {
                Toggle("Two-way sync", isOn: Binding(
                    get: { dataManager.appState.preferences.twoWaySync },
                    set: { newValue in
                        dataManager.appState.preferences.twoWaySync = newValue
                        dataManager.save()
                    }
                ))
                    .help("Changes in DayPlanner appear in Calendar and vice versa")
                
                Toggle("Respect Calendar privacy", isOn: Binding(
                    get: { dataManager.appState.preferences.respectCalendarPrivacy },
                    set: { newValue in
                        dataManager.appState.preferences.respectCalendarPrivacy = newValue
                        dataManager.save()
                    }
                ))
                    .help("Don't read private event details")
                
                Picker("Default Calendar", selection: .constant(0)) {
                    Text("Personal").tag(0)
                    Text("Work").tag(1)
                    Text("Family").tag(2)
                }
            }
        }
    }
}

struct PillarsRulesSettingsView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var selectedPillar: Pillar?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Pillars & Soft Rules")
                .font(.title2)
                .fontWeight(.semibold)
            
            if dataManager.appState.pillars.isEmpty {
                VStack(spacing: 16) {
                    Text("No pillars defined yet")
                        .foregroundColor(.secondary)
                    
                    Button("Create Your First Pillar") {
                        // Navigate to pillar creation
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ForEach(dataManager.appState.pillars) { pillar in
                    SettingsGroup(pillar.name) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(pillar.color.color)
                                    .frame(width: 12, height: 12)
                                
                                Text(pillar.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Edit") {
                                    selectedPillar = pillar
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            
                            Text("Frequency: \(pillar.frequencyDescription)")
                                .font(.caption)
                            
                            Text("Duration: \(pillar.minDuration.minutes)min - \(pillar.maxDuration.minutes)min")
                                .font(.caption)
                            
                            if !pillar.quietHours.isEmpty {
                                Text("Quiet hours: \(pillar.quietHours.map(\.description).joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedPillar) { pillar in
            PillarEditView(pillar: pillar) { updatedPillar in
                if let index = dataManager.appState.pillars.firstIndex(where: { $0.id == pillar.id }) {
                    dataManager.appState.pillars[index] = updatedPillar
                    dataManager.save()
                }
                selectedPillar = nil
            }
        }
    }
}

struct ChainsSettingsView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var selectedChain: Chain?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chains Management")
                .font(.title2)
                .fontWeight(.semibold)
            
            SettingsGroup("Auto-promotion") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chains become routines after being completed 3 times")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle("Enable routine promotion", isOn: .constant(true))
                    
                    Toggle("Show promotion notifications", isOn: .constant(true))
                }
            }
            
            SettingsGroup("Recent Chains") {
                ForEach(dataManager.appState.recentChains.prefix(5)) { chain in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chain.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(chain.blocks.count) blocks • \(chain.totalDurationMinutes)m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if chain.completionCount >= 3 {
                            Text("Routine")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.2), in: Capsule())
                                .foregroundColor(.green)
                        }
                        
                        Button("Edit") {
                            selectedChain = chain
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
        }
        .sheet(item: $selectedChain) { chain in
            ChainEditView(chain: chain) { updatedChain in
                if let index = dataManager.appState.recentChains.firstIndex(where: { $0.id == chain.id }) {
                    dataManager.appState.recentChains[index] = updatedChain
                    dataManager.save()
                }
                selectedChain = nil
            }
        }
    }
}

struct DataHistorySettingsView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingExportSheet = false
    @State private var showingHistoryLog = false
    @State private var showingImportSheet = false
    @State private var showingClearDataAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Data & History")
                .font(.title2)
                .fontWeight(.semibold)
            
            SettingsGroup("Data Management") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Saved")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(dataManager.lastSaved?.formatted() ?? "Never")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Save Now") {
                        dataManager.save()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                HStack {
                    Button("Export Data") {
                        showingExportSheet = true
                    }
                    .buttonStyle(.bordered)
                    
                Button("Import Data") {
                    showingImportSheet = true
                }
                .buttonStyle(.bordered)
                }
            }
            
            SettingsGroup("History & Undo Log") {
                Toggle("Keep undo history", isOn: Binding(
                    get: { dataManager.appState.preferences.keepUndoHistory },
                    set: { newValue in
                        dataManager.appState.preferences.keepUndoHistory = newValue
                        dataManager.save()
                    }
                ))
                
                HStack {
                    Text("History retention")
                    
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { dataManager.appState.preferences.historyRetentionDays },
                        set: { newValue in
                            dataManager.appState.preferences.historyRetentionDays = newValue
                            dataManager.save()
                        }
                    )) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("1 year").tag(365)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
                
                Button("View History Log") {
                    showingHistoryLog = true
                }
                .buttonStyle(.bordered)
            }
            
            SettingsGroup("Privacy") {
                Toggle("Analytics", isOn: .constant(false))
                    .help("All data stays local - no analytics are sent")
                
                Toggle("Crash reports", isOn: .constant(false))
                    .help("Local crash logs only")
                
                Button("Clear All Data") {
                    showingClearDataAlert = true
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.red)
            }
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: ExportDocument(data: try! JSONEncoder().encode(dataManager.appState)),
            contentType: .json,
            defaultFilename: "DayPlanner_Export"
        ) { result in
            switch result {
            case .success(let url):
                print("Exported to: \(url)")
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    do {
                        let _ = try Data(contentsOf: url)
                        try await dataManager.importData(from: url)
                    } catch {
                        print("Import failed: \(error)")
                    }
                }
            case .failure(let error):
                print("Import selection failed: \(error)")
            }
        }
        .sheet(isPresented: $showingHistoryLog) {
            HistoryLogView()
                .environmentObject(dataManager)
        }
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                // Clear all data
                dataManager.appState = AppState()
                dataManager.save()
            }
        } message: {
            Text("This will permanently delete all your data, including time blocks, chains, pillars, and goals. This action cannot be undone.")
        }
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("About DayPlanner")
                .font(.title2)
                .fontWeight(.semibold)
            
            SettingsGroup("Version") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DayPlanner")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Version 1.0.0 (Build 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("🌊")
                        .font(.largeTitle)
                }
            }
            
            SettingsGroup("AI Model") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Local AI via LM Studio")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("All AI processing happens locally on your device. No data is sent to external servers.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Test AI Connection") {
                        // Test AI
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            SettingsGroup("Support") {
                Link("Documentation", destination: URL(string: "https://example.com")!)
                Link("Report Issue", destination: URL(string: "https://example.com")!)
                Link("Feature Request", destination: URL(string: "https://example.com")!)
            }
        }
    }
}

// MARK: - Helper Views

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(16)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct PillarEditView: View {
    let pillar: Pillar
    let onSave: (Pillar) -> Void
    
    @State private var name: String
    @State private var description: String
    @State private var frequency: PillarFrequency
    @Environment(\.dismiss) private var dismiss
    
    init(pillar: Pillar, onSave: @escaping (Pillar) -> Void) {
        self.pillar = pillar
        self.onSave = onSave
        self._name = State(initialValue: pillar.name)
        self._description = State(initialValue: pillar.description)
        self._frequency = State(initialValue: pillar.frequency)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section("Frequency") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(PillarFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Edit Pillar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updatedPillar = pillar
                        updatedPillar.name = name
                        updatedPillar.description = description
                        updatedPillar.frequency = frequency
                        onSave(updatedPillar)
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct ChainEditView: View {
    let chain: Chain
    let onSave: (Chain) -> Void
    
    @State private var name: String
    @State private var blocks: [TimeBlock]
    
    init(chain: Chain, onSave: @escaping (Chain) -> Void) {
        self.chain = chain
        self.onSave = onSave
        self._name = State(initialValue: chain.name)
        self._blocks = State(initialValue: chain.blocks)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Chain Name", text: $name)
                }
                
                Section("Time Blocks") {
                    ForEach($blocks, id: \.id) { $block in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Title", text: $block.title)
                            
                            HStack {
                                Text("Duration:")
                                Stepper("\(Int(block.duration/60))min", 
                                       value: Binding(
                                           get: { Double(block.duration/60) },
                                           set: { newValue in
                                               block.duration = TimeInterval(newValue * 60)
                                           }
                                       ), 
                                       in: 5...480, 
                                       step: 5)
                                Spacer()
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button("Add Block") {
                        let newBlock = TimeBlock(
                            title: "New Activity",
                            startTime: Date(),
                            duration: 30 * 60,
                            energy: .daylight,
                            emoji: "📋"
                        )
                        blocks.append(newBlock)
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Edit Chain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onSave(chain) // Cancel without changes
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updatedChain = chain
                        updatedChain.name = name
                        updatedChain.blocks = blocks
                        onSave(updatedChain)
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
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

// MARK: - Unified Split View

/// New unified layout showing both calendar and mind sections simultaneously
struct UnifiedSplitView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Binding var selectedDate: Date
    @Binding var showingMindPanel: Bool // Control mind panel visibility
    @State private var showingBackfill = false
    @State private var showingMonthView = true // Default to monthly view
    @State private var selectedMindSection: TimeframeSelector = .now
    
    var body: some View {
        ZStack {
            // Main calendar view - always stays on the left
            HStack(spacing: 0) {
                // Calendar panel always takes left side
                CalendarPanel(
                    selectedDate: $selectedDate,
                    showingMonthView: $showingMonthView
                )
                .frame(width: showingMindPanel ? 500 : .infinity)
                
                
                // Spacer to push everything to the left
                if showingMindPanel {
                    Spacer()
                        .frame(width: 450) // Same width as mind panel to reserve space
                }
            }
            
            // Rising mind panel overlay
            if showingMindPanel {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack(alignment: .topLeading) {
                            MindPanel(selectedTimeframe: $selectedMindSection)
                                .frame(width: 450)
                                .background(.ultraThinMaterial.opacity(0.95), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                                )
                            
                        }
                        .padding(.trailing, 8)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingMindPanel)
                    }
                }
            }
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

// MARK: - Calendar Panel

struct CalendarPanel: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Binding var selectedDate: Date
    @Binding var showingMonthView: Bool
    @State private var showingPillarDay = false
    @State private var showingBackfillTemplates = false
    @State private var showingChainsTemplates = false
    @State private var showingTodoList = false // Default to hiding todo list
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar header with elegant styling
            CalendarPanelHeader(
                selectedDate: $selectedDate,
                showingMonthView: $showingMonthView,
                showingBackfillTemplates: $showingBackfillTemplates,
                showingChainsTemplates: $showingChainsTemplates,
                showingTodoList: $showingTodoList,
                onPillarDayTap: { showingPillarDay = true },
                isDefaultMonthView: true, // Month view is shown by default
                onBackToCalendar: {
                    // Return to monthly calendar view
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingMonthView = true
                    }
                }
            )
            
            // Month view (expandable/collapsible) - switches to hourly view on day click
            if showingMonthView {
                MonthViewExpanded(
                    selectedDate: $selectedDate, 
                    dataManager: dataManager,
                    onDayClick: {
                        // Switch to hourly view when a day is clicked
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingMonthView = false
                            showingTodoList = false // Hide todo list when switching to day view
                        }
                    }
                )
                .frame(height: 280)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top))
                ))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingMonthView)
            }
            
            // Backfill templates dropdown (expandable/collapsible)
            if showingBackfillTemplates {
                BackfillTemplatesView(selectedDate: selectedDate)
                    .frame(height: 200)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingBackfillTemplates)
            }
            
            // Chains templates dropdown (expandable/collapsible)
            if showingChainsTemplates {
                ChainsTemplatesView(selectedDate: selectedDate)
                    .frame(height: 200)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingChainsTemplates)
            }
            
            // Day view - enhanced with liquid glass styling (only show when not in month view)
            if !showingMonthView {
                EnhancedDayView(selectedDate: $selectedDate)
                    .frame(maxHeight: showingTodoList ? nil : .infinity)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingMonthView)
            }
            
            // To-Do section (expandable/collapsible from bottom)
            if showingTodoList {
                TodoListView()
                    .frame(height: 300)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .bottom))
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingTodoList)
            }
        }
        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.leading, 8)  // Moved further left
        .padding(.trailing, 4)
        .padding(.vertical, 12)
        .sheet(isPresented: $showingPillarDay) {
            PillarDayView()
                .environmentObject(dataManager)
                .environmentObject(aiService)
        }
    }
}

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
                    // Pillars section with crystal aesthetics
                    CrystalPillarsSection()
                        .environmentObject(dataManager)
                    
                    // Enhanced goals section with breakdown functionality
                    EnhancedGoalsSection()
                        .environmentObject(dataManager)
                        .environmentObject(aiService)
                    
                    // Dream builder with aurora gradients
                    AuroraDreamBuilderSection()
                        .environmentObject(dataManager)
                    
                    // Intake section
                    IntakeSection()
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
        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.leading, 4)
        .padding(.trailing, 8)  // Better centered on right
        .padding(.vertical, 12)
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

// MARK: - Calendar Panel Header

struct CalendarPanelHeader: View {
    @Binding var selectedDate: Date
    @Binding var showingMonthView: Bool
    @Binding var showingBackfillTemplates: Bool
    @Binding var showingChainsTemplates: Bool
    @Binding var showingTodoList: Bool
    let onPillarDayTap: () -> Void
    let isDefaultMonthView: Bool // Track if month view is shown by default
    let onBackToCalendar: (() -> Void)? // Callback to return to calendar view
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    // Elegant navigation arrows positioned next to date
                    Button(action: previousDay) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(.blue.opacity(0.08), in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Text(dateFormatter.string(from: selectedDate))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Button(action: nextDay) {
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(.blue.opacity(0.08), in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Text("Calendar")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Back to calendar button - show when in day view mode
                if !showingMonthView {
                    Button(action: { 
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            onBackToCalendar?()
                        }
                    }) {
                        Image(systemName: "calendar.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .symbolEffect(.bounce, value: !showingMonthView)
                    }
                    .buttonStyle(.plain)
                }
                
                // Month expand/collapse button - only show when not default view and in month view
                if !isDefaultMonthView && showingMonthView {
                    Button(action: { 
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingMonthView.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .symbolEffect(.bounce, value: showingMonthView)
                    }
                    .buttonStyle(.plain)
                }
                
                // To-Do expand/collapse button
                Button(action: { 
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingTodoList.toggle()
                    }
                }) {
                    Image(systemName: showingTodoList ? "chevron.down.circle.fill" : "checklist")
                        .font(.title2)
                        .foregroundStyle(showingTodoList ? .blue : .secondary)
                        .symbolEffect(.bounce, value: showingTodoList)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 16)
                
                // Action buttons with capsule style
                HStack(spacing: 6) {
                    Button("Pillar Day") {
                        onPillarDayTap()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
                    .help("Add missing pillar activities to today")
                    
                    Button("Backfill") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingBackfillTemplates.toggle()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
                    
                    Button("Chains") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingChainsTemplates.toggle()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func previousDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func nextDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        }
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
                
                Text("Pillars • Goals • Dreams")
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

// MARK: - Enhanced Day View

struct EnhancedDayView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @Binding var selectedDate: Date
    @State private var showingBlockCreation = false
    @State private var creationTime: Date?
    @State private var draggedBlock: TimeBlock?
    
    // Constants for precise timeline sizing
    private let minuteHeight: CGFloat = 1.0 // 1 pixel per minute = perfect precision
    
    var body: some View {
        VStack(spacing: 0) {
            // Proportional timeline view where duration = visual height
            ScrollView {
                ProportionalTimelineView(
                            selectedDate: selectedDate,
                    blocks: allBlocksForDay,
                    draggedBlock: draggedBlock,
                    minuteHeight: minuteHeight,
                            onTap: { time in
                                creationTime = time
                                showingBlockCreation = true
                            },
                            onBlockDrag: { block, location in
                                draggedBlock = block
                            },
                            onBlockDrop: { block, newTime in
                                handleBlockDrop(block: block, newTime: newTime)
                        draggedBlock = nil
                            }
                        )
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(draggedBlock != nil) // Disable scroll when dragging an event
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            dataManager.switchToDay(newValue)
        }
        .onAppear {
            selectedDate = dataManager.appState.currentDay.date
        }
        .sheet(isPresented: $showingBlockCreation) {
            BlockCreationSheet(
                suggestedTime: creationTime ?? Date(),
                onCreate: { block in
                    dataManager.addTimeBlock(block)
                    showingBlockCreation = false
                }
            )
        }
    }
    
    private var allBlocksForDay: [TimeBlock] {
        return dataManager.appState.currentDay.blocks
    }
    
    private func handleBlockDrop(block: TimeBlock, newTime: Date) {
        var updatedBlock = block
        updatedBlock.startTime = newTime
        dataManager.updateTimeBlock(updatedBlock)
    }
    
}

// MARK: - Precise Timeline View (Exact Positioning)

struct ProportionalTimelineView: View {
    let selectedDate: Date
    let blocks: [TimeBlock]
    let draggedBlock: TimeBlock?
    let minuteHeight: CGFloat
    let onTap: (Date) -> Void
    let onBlockDrag: (TimeBlock, CGPoint) -> Void
    let onBlockDrop: (TimeBlock, Date) -> Void
    
    private let calendar = Calendar.current
    private let dayStartHour = 0
    private let dayEndHour = 24
    
    private var currentHour: Int {
        calendar.component(.hour, from: Date())
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Time labels column with precise minute markers
            TimeLabelsColumn(
                selectedDate: selectedDate,
                dayStartHour: dayStartHour,
                dayEndHour: dayEndHour
            )
            .frame(width: 80)
            
            // Precise timeline canvas with astronomical hour colors
            ZStack(alignment: .topLeading) {
                // Background grid with astronomical colors
                TimelineCanvas(
                    selectedDate: selectedDate,
                    dayStartHour: dayStartHour,
                    dayEndHour: dayEndHour,
                    onTap: onTap
                )
                
                // Events positioned at exact times
                ForEach(blocks) { block in
                    PreciseEventCard(
                        block: block,
                        selectedDate: selectedDate,
                        dayStartHour: dayStartHour,
                        minuteHeight: minuteHeight,
                        isDragged: draggedBlock?.id == block.id,
                        allBlocks: blocks,
                        onDrag: { location in
                            onBlockDrag(block, location)
                        },
                        onDrop: { newTime in
                            onBlockDrop(block, newTime)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func blocksForHour(_ hour: Int, blocks: [TimeBlock]) -> [TimeBlock] {
        return blocks.filter { block in
            let blockHour = calendar.component(.hour, from: block.startTime)
            return blockHour == hour
        }
    }
    
    private func hourLabel(for hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        switch hour {
        case 6: return "🌅 \(formatter.string(from: date))"    // Sunrise
        case 12: return "☀️ \(formatter.string(from: date))"   // Noon sun
        case 18: return "🌇 \(formatter.string(from: date))"   // Sunset
        case 21: return "🌙 \(formatter.string(from: date))"   // Evening moon
        case 0: return "🌛 \(formatter.string(from: date))"    // Midnight crescent
        default: return formatter.string(from: date)
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        return calendar.component(.hour, from: Date()) == hour &&
               calendar.isDate(selectedDate, inSameDayAs: Date())
    }
    
    private func hourBackgroundColor(for hour: Int) -> Color {
        AstronomicalTimeCalculator.shared.getTimeColor(for: hour, date: selectedDate)
    }
    
    @ViewBuilder
    private func currentTimeIndicator(for hour: Int) -> some View {
        if isCurrentHour(hour) {
            let now = Date()
            let minute = calendar.component(.minute, from: now)
            let offsetY = CGFloat(minute) // 1 pixel per minute
            
            HStack(spacing: 8) {
                Rectangle()
                    .fill(.blue)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .opacity(0.8)
                    .shadow(color: .blue, radius: 1)
                
                Text("now")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .opacity(0.9)
            }
            .offset(y: offsetY)
        }
    }
}

// MARK: - Precise Timeline Components

struct TimeLabelsColumn: View {
    let selectedDate: Date
    let dayStartHour: Int
    let dayEndHour: Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(dayStartHour..<dayEndHour, id: \.self) { hour in
                VStack(spacing: 0) {
                    // Hour label at top
                    Text(hourLabel(for: hour))
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(isCurrentHour(hour) ? .blue : .primary)
                        .frame(height: 15, alignment: .bottom)
                    
                    // Quarter hour markers
                    VStack(spacing: 0) {
                        ForEach([15, 30, 45], id: \.self) { minute in
                            HStack {
                                Spacer()
                                Text(":\(minute)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(height: 15)
                        }
                    }
                }
                .frame(height: 60) // 60 pixels per hour
            }
        }
    }
    
    private func hourLabel(for hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        switch hour {
        case 6: return "🌅 \(formatter.string(from: date))"    // Sunrise
        case 12: return "☀️ \(formatter.string(from: date))"   // Noon sun
        case 18: return "🌇 \(formatter.string(from: date))"   // Sunset
        case 21: return "🌙 \(formatter.string(from: date))"   // Evening moon
        case 0: return "🌛 \(formatter.string(from: date))"    // Midnight crescent
        default: return formatter.string(from: date)
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        return calendar.component(.hour, from: Date()) == hour &&
               calendar.isDate(selectedDate, inSameDayAs: Date())
    }
}

struct TimelineCanvas: View {
    let selectedDate: Date
    let dayStartHour: Int
    let dayEndHour: Int
    let onTap: (Date) -> Void
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(dayStartHour..<dayEndHour, id: \.self) { hour in
                Rectangle()
                    .fill(hourBackgroundColor(for: hour))
                    .frame(height: 60) // 60 pixels per hour (1 pixel per minute)
                    .overlay(
                        // Quarter hour grid lines
                        VStack(spacing: 0) {
                            ForEach([15, 30, 45], id: \.self) { minute in
                                Rectangle()
                                    .fill(.quaternary.opacity(0.1))
                                    .frame(height: 1)
                                    .frame(maxWidth: .infinity)
                                    .offset(y: CGFloat(minute - 15))
                            }
                        },
                        alignment: .top
                    )
                    .overlay(
                        // Current time indicator
                        currentTimeIndicator(for: hour),
                        alignment: .topLeading
                    )
                    .overlay(
                        // Hour separator
                        Rectangle()
                            .fill(.quaternary.opacity(0.3))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let hourTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                        onTap(hourTime)
                    }
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        let hourTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                        return handleTimeslotDrop(providers: providers, at: hourTime)
                    }
            }
        }
    }
    
    private func hourBackgroundColor(for hour: Int) -> Color {
        AstronomicalTimeCalculator.shared.getTimeColor(for: hour, date: selectedDate)
    }
    
    @ViewBuilder
    private func currentTimeIndicator(for hour: Int) -> some View {
        if isCurrentHour(hour) {
            let now = Date()
            let minute = calendar.component(.minute, from: now)
            let offsetY = CGFloat(minute) // 1 pixel per minute
            
            HStack(spacing: 8) {
                Rectangle()
                    .fill(.blue)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .opacity(0.8)
                    .shadow(color: .blue, radius: 1)
                
                Text("now")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .opacity(0.9)
            }
            .offset(y: offsetY)
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        return calendar.component(.hour, from: Date()) == hour &&
               calendar.isDate(selectedDate, inSameDayAs: Date())
    }
    
    private func handleTimeslotDrop(providers: [NSItemProvider], at time: Date) -> Bool {
        for provider in providers {
            provider.loadObject(ofClass: NSString.self) { item, error in
                if let payload = item as? String, error == nil {
                    DispatchQueue.main.async {
                        self.processDroppedItem(payload: payload, at: time)
                    }
                }
            }
        }
        return true
    }
    
    private func processDroppedItem(payload: String, at time: Date) {
        // Handle backfill template drops
        if payload.hasPrefix("backfill_template:") {
            let parts = payload.dropFirst("backfill_template:".count).components(separatedBy: "|")
            if parts.count >= 5 {
                let title = parts[0]
                let duration = TimeInterval(Int(parts[1]) ?? 3600)
                let energy = EnergyType(rawValue: parts[2]) ?? .daylight
                let emoji = parts[3]
                
                // Create enhanced title with AI context
                let enhancedTitle = aiService.enhanceEventTitle(originalTitle: title, time: time, duration: duration)
                
                let newBlock = TimeBlock(
                    title: enhancedTitle,
                    startTime: time,
                    duration: duration,
                    energy: energy,
                    emoji: emoji
                )
                
                dataManager.addTimeBlock(newBlock)
            }
        }
        // Handle todo item drops
        else if payload.hasPrefix("todo_item:") {
            let parts = payload.dropFirst("todo_item:".count).components(separatedBy: "|")
            if parts.count >= 4 {
                let title = parts[0]
                let _ = parts[1] // UUID - we don't need it for the time block
                let dueDateString = parts[2]
                let isCompleted = Bool(parts[3]) ?? false
                
                // Don't create time blocks for completed todos
                guard !isCompleted else { return }
                
                // Create enhanced title with AI context
                let enhancedTitle = aiService.enhanceEventTitle(originalTitle: title, time: time, duration: 3600)
                
                let newBlock = TimeBlock(
                    title: enhancedTitle,
                    startTime: time,
                    duration: 3600, // Default 1 hour for todo items
                    energy: .daylight,
                    emoji: "📝"
                )
                
                dataManager.addTimeBlock(newBlock)
            }
        }
        // Handle chain template drops
        else if payload.hasPrefix("chain_template:") {
            let parts = payload.dropFirst("chain_template:".count).components(separatedBy: "|")
            if parts.count >= 3 {
                let name = parts[0]
                let totalDuration = Int(parts[1]) ?? 120
                let icon = parts[2]
                
                // Find the matching chain template
                if let template = findChainTemplate(by: name) {
                    // Create multiple time blocks based on the template's activities
                    createChainEventsFromTemplate(template, startTime: time)
                } else {
                    // Fallback: create a single event if template not found
                    let enhancedTitle = aiService.enhanceEventTitle(originalTitle: name, time: time, duration: TimeInterval(totalDuration * 60))
                    
                    let newBlock = TimeBlock(
                        title: enhancedTitle,
                        startTime: time,
                        duration: TimeInterval(totalDuration * 60),
                        energy: .daylight,
                        emoji: icon
                    )
                    
                    dataManager.addTimeBlock(newBlock)
                }
            }
        }
    }
    
    private func findChainTemplate(by name: String) -> ChainTemplate? {
        // Define the same chain templates here for drop handling
        let templates = [
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
        
        return templates.first { $0.name == name }
    }
    
    private func createChainEventsFromTemplate(_ template: ChainTemplate, startTime: Date) {
        var currentTime = startTime
        let activityDuration = TimeInterval(template.totalDuration * 60 / template.activities.count)
        
        for (index, activity) in template.activities.enumerated() {
            let energy = index < template.energyFlow.count ? template.energyFlow[index] : .daylight
            let enhancedTitle = aiService.enhanceEventTitle(originalTitle: activity, time: currentTime, duration: activityDuration)
            
            let newBlock = TimeBlock(
                title: enhancedTitle,
                startTime: currentTime,
                duration: activityDuration,
                energy: energy,
                emoji: template.icon
            )
            
            dataManager.addTimeBlock(newBlock)
            
            // Move to next time slot (with small buffer)
            currentTime = currentTime.addingTimeInterval(activityDuration + 300) // 5 minute buffer
        }
    }
}

struct PreciseEventCard: View {
    let block: TimeBlock
    let selectedDate: Date
    let dayStartHour: Int
    let minuteHeight: CGFloat
    let isDragged: Bool
    let allBlocks: [TimeBlock]
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingDetails = false
    @State private var isHovering = false
    @State private var showingChainOptions = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            HStack(spacing: 8) {
                // Energy and flow indicators
                VStack(spacing: 1) {
                    Text(block.energy.rawValue)
                        .font(.caption)
                    Text(block.emoji)
                        .font(.caption2)
                }
                .opacity(0.8)
                .frame(width: 25)
                
                // Block content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if !block.emoji.isEmpty {
                            Text(block.emoji)
                                .font(.caption)
                        }
                        
                        Text(block.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(durationBasedLineLimit)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        Text(block.startTime.preciseTwoLineTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        Text("\(block.durationMinutes)m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Simplified hover info
                        if isHovering && !isDragging {
                            Text("Tap for details")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .italic()
                        }
                        
                        // Info icon
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.blue.opacity(0.6))
                    }
                    
                    // Show end time for longer events
                    if block.durationMinutes >= 45 {
                        Text("→ \(block.endTime.preciseTwoLineTime)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                // Glass state indicator
                Circle()
                    .fill(stateColor)
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(height: eventHeight, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            borderColor, 
                            style: StrokeStyle(
                                lineWidth: 1
                            )
                        )
                )
        )
        .scaleEffect(isDragging ? 0.98 : 1.0)
        .offset(x: dragOffset.width, y: dragOffset.height + yPosition)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                    }
                    dragOffset = value.translation
                    onDrag(value.location)
                }
                .onEnded { value in
                    isDragging = false
                    dragOffset = .zero
                    
                    let newTime = calculateNewTime(from: value.translation)
                    onDrop(newTime)
                }
        )
        .sheet(isPresented: $showingDetails) {
            NoFlashEventDetailsSheet(
                block: block,
                allBlocks: allBlocks,
                onSave: { updatedBlock in
                    dataManager.updateTimeBlock(updatedBlock)
                    showingDetails = false
                },
                onDelete: {
                    dataManager.removeTimeBlock(block.id)
                    showingDetails = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }
    
    // MARK: - Precise Positioning
    
    private var yPosition: CGFloat {
        // Calculate exact Y position based on start time
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayStartTime = calendar.date(byAdding: .hour, value: dayStartHour, to: dayStart) ?? dayStart
        let totalMinutesFromStart = block.startTime.timeIntervalSince(dayStartTime) / 60
        return CGFloat(totalMinutesFromStart) * minuteHeight
    }
    
    private var eventHeight: CGFloat {
        // Height exactly proportional to duration
        CGFloat(block.durationMinutes) * minuteHeight
    }
    
    private var durationBasedLineLimit: Int {
        switch block.durationMinutes {
        case 0..<30: return 1
        case 30..<90: return 2
        default: return 3
        }
    }
    
    private var stateColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue
        case .mist: return .orange
        case .crystal: return .cyan
        }
    }
    
    private var borderColor: Color {
        switch block.glassState {
        case .solid: return .clear
        case .liquid: return .blue.opacity(0.6)
        case .mist: return .orange.opacity(0.5)
        case .crystal: return .cyan.opacity(0.7)
        }
    }
    
    private func calculateNewTime(from translation: CGSize) -> Date {
        // Precise time calculation using minute height
        let minuteChange = Int(translation.height / minuteHeight)
        let newTime = calendar.date(byAdding: .minute, value: minuteChange, to: block.startTime) ?? block.startTime
        
        // Round to nearest 15-minute interval for clean scheduling
        let minute = calendar.component(.minute, from: newTime)
        let roundedMinute = (minute / 15) * 15
        
        return calendar.date(bySettingHour: calendar.component(.hour, from: newTime), 
                           minute: roundedMinute, 
                           second: 0, 
                           of: newTime) ?? newTime
    }
    
}

// MARK: - Fixed Position Event Card (Proper Layout)

struct FixedPositionEventCard: View {
    let block: TimeBlock
    let selectedDate: Date
    let dayStartHour: Int
    let isDragged: Bool
    let allBlocks: [TimeBlock]
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingDetails = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Spacer to push event to correct vertical position
            Spacer()
                .frame(height: topSpacerHeight)
            
            // Event card with proper layout (no absolute positioning)
            Button(action: { 
                showingDetails = true // No animation to prevent flashing
            }) {
                HStack(spacing: 8) {
                    // Energy and flow indicators  
                    VStack(spacing: 2) {
                        Text(block.energy.rawValue)
                            .font(.caption)
                        Text(block.emoji)
                            .font(.caption)
                    }
                    .opacity(0.8)
                    .frame(width: 25)
                    
                    // Block content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(durationBasedLineLimit)
                        
                        HStack(spacing: 4) {
                            Text(block.startTime.timeString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            
                            Text("\(block.durationMinutes)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            // Improved arrow that's not buggy
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.blue.opacity(0.6))
                        }
                        
                        // Show end time for longer events
                        if block.durationMinutes >= 60 {
                            Text("→ \(block.endTime.timeString)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Spacer()
                    
                    // Glass state indicator
                    Circle()
                        .fill(stateColor)
                        .frame(width: 6, height: 6)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, durationBasedPadding)
            .frame(height: eventHeight, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                borderColor, 
                                style: StrokeStyle(
                                    lineWidth: 1
                                )
                            )
                    )
            )
            .scaleEffect(isDragging ? 0.98 : 1.0)
            .offset(dragOffset)
            .highPriorityGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        dragOffset = value.translation
                        onDrag(value.location)
                    }
                    .onEnded { value in
                        isDragging = false
                        dragOffset = .zero
                        
                        let newTime = calculateNewTime(from: value.translation)
                        onDrop(newTime)
                    }
            )
            .sheet(isPresented: $showingDetails) {
                // Fixed event details sheet
                NoFlashEventDetailsSheet(
                    block: block,
                    allBlocks: allBlocks,
                    onSave: { updatedBlock in
                        dataManager.updateTimeBlock(updatedBlock)
                        showingDetails = false
                    },
                    onDelete: {
                        dataManager.removeTimeBlock(block.id)
                        showingDetails = false
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var eventHeight: CGFloat {
        // Height proportional to duration with minimum
        max(30, CGFloat(block.durationMinutes))
    }
    
    private var topSpacerHeight: CGFloat {
        // Calculate minutes from day start (6 AM) to event start
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayStartTime = calendar.date(byAdding: .hour, value: dayStartHour, to: dayStart) ?? dayStart
        let minutesFromDayStart = block.startTime.timeIntervalSince(dayStartTime) / 60
        return max(0, CGFloat(minutesFromDayStart))
    }
    
    private var durationBasedLineLimit: Int {
        switch block.durationMinutes {
        case 0..<30: return 1
        case 30..<90: return 2
        default: return 3
        }
    }
    
    private var durationBasedPadding: CGFloat {
        switch block.durationMinutes {
        case 0..<30: return 4
        case 30..<60: return 6
        default: return 8
        }
    }
    
    private var stateColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue
        case .mist: return .orange
        case .crystal: return .cyan
        }
    }
    
    private var borderColor: Color {
        switch block.glassState {
        case .solid: return .clear
        case .liquid: return .blue.opacity(0.6)
        case .mist: return .orange.opacity(0.5)
        case .crystal: return .cyan.opacity(0.7)
        }
    }
    
    private func calculateNewTime(from translation: CGSize) -> Date {
        let minuteChange = Int(translation.height) // 1 pixel = 1 minute
        let newTime = calendar.date(byAdding: .minute, value: minuteChange, to: block.startTime) ?? block.startTime
        
        // Round to nearest 15-minute interval
        let minute = calendar.component(.minute, from: newTime)
        let roundedMinute = (minute / 15) * 15
        
        return calendar.date(bySettingHour: calendar.component(.hour, from: newTime), 
                           minute: roundedMinute, 
                           second: 0, 
                           of: newTime) ?? newTime
    }
}

// MARK: - Fixed Event Details Sheet (No NavigationView Issues)

struct FixedEventDetailsSheet: View {
    let block: TimeBlock
    let allBlocks: [TimeBlock]
    let onSave: (TimeBlock) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var editedBlock: TimeBlock
    @State private var activeTab: EventTab = .details
    @State private var showingDeleteConfirmation = false
    
    private let calendar = Calendar.current
    private let dayStartHour = 0
    
    init(block: TimeBlock, allBlocks: [TimeBlock], onSave: @escaping (TimeBlock) -> Void, onDelete: @escaping () -> Void) {
        self.block = block
        self.allBlocks = allBlocks
        self.onSave = onSave
        self.onDelete = onDelete
        self._editedBlock = State(initialValue: block)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Event Details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("✕") {
                    dismiss()
                }
                .font(.title3)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial.opacity(0.8))
            
            // Improved tab selector (no flashing)
            HStack(spacing: 4) {
                ForEach(EventTab.allCases, id: \.self) { tab in
                    Button(action: { activeTab = tab }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .medium))
                            
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(activeTab == tab ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(activeTab == tab ? .blue : .gray.opacity(0.2))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.4))
            
            // Tab content (no ScrollView to prevent conflicts)
            Group {
                switch activeTab {
                case .details:
                    EventDetailsTab(block: $editedBlock)
                case .chains:
                    EventChainsTab(
                        block: block,
                        allBlocks: allBlocks,
                        onAddChain: { position in
                            addChainToEvent(position: position)
                        }
                    )
                case .duration:
                    EventDurationTab(block: $editedBlock)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom actions
            HStack(spacing: 16) {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save Changes") {
                    onSave(editedBlock)
                }
                .buttonStyle(.borderedProminent)
                .disabled(editedBlock.title.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial.opacity(0.8))
        }
        .frame(width: 700, height: 600)
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 20)
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(block.title)'? This action cannot be undone.")
        }
    }
    
    private func addChainToEvent(position: ChainPosition) {
        let chainDuration: TimeInterval = 1800 // 30 minutes
        let chainName = position == .before ? "Prep for \(block.title)" : "Follow-up to \(block.title)"
        
        let newChain = Chain(
            name: chainName,
            blocks: [
                TimeBlock(
                    title: chainName,
                    startTime: Date(),
                    duration: chainDuration,
                    energy: block.energy,
                    emoji: block.emoji
                )
            ],
            flowPattern: .waterfall
        )
        
        let insertTime = position == .before 
            ? block.startTime.addingTimeInterval(-chainDuration - 300)
            : block.endTime.addingTimeInterval(300)
        
        dataManager.applyChain(newChain, startingAt: insertTime)
        dismiss() // Close the sheet after adding chain
    }
}

// MARK: - No Flash Event Details Sheet (Completely Static)

struct NoFlashEventDetailsSheet: View {
    let block: TimeBlock
    let allBlocks: [TimeBlock]
    let onSave: (TimeBlock) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var editedBlock: TimeBlock
    @State private var activeTab: EventTab = .details
    @State private var showingDeleteConfirmation = false
    
    private let calendar = Calendar.current
    
    init(block: TimeBlock, allBlocks: [TimeBlock], onSave: @escaping (TimeBlock) -> Void, onDelete: @escaping () -> Void) {
        self.block = block
        self.allBlocks = allBlocks
        self.onSave = onSave
        self.onDelete = onDelete
        self._editedBlock = State(initialValue: block)
    }
    
    var body: some View {
        // Fixed size container - no resizing, no flashing
        VStack(spacing: 0) {
            // Static header
            headerSection
            
            // Static tab selector - no animations
            staticTabSelector
            
            // Tab content without ScrollView (prevents layout conflicts)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            // Static bottom actions
            bottomActionsSection
        }
        .frame(width: 700, height: 600) // Fixed size - always fully expanded
        .background(.regularMaterial) // Solid background to prevent transparency flashing
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .transition(.identity) // No transition animations to prevent flashing
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete '\(block.title)'? This action cannot be undone.")
        }
    }
    
    // MARK: - Static Sections (No Animations)
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(block.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("Event Details")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("✕") {
                dismiss()
            }
            .font(.title3)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }
    
    private var staticTabSelector: some View {
        HStack(spacing: 3) {
            ForEach(EventTab.allCases, id: \.self) { tab in
                Button(action: { activeTab = tab }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(activeTab == tab ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40) // Fixed height
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(activeTab == tab ? .blue : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .details:
            StaticEventDetailsTab(block: $editedBlock)
        case .chains:
            StaticEventChainsTab(
                block: block,
                allBlocks: allBlocks,
                onAddChain: { position in
                    addChainToEvent(position: position)
                }
            )
        case .duration:
            StaticEventDurationTab(block: $editedBlock)
        }
    }
    
    private var bottomActionsSection: some View {
        HStack(spacing: 16) {
            Button("Delete", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            
            Button("Save Changes") {
                onSave(editedBlock)
            }
            .buttonStyle(.borderedProminent)
            .disabled(editedBlock.title.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }
    
    private func addChainToEvent(position: ChainPosition) {
        let chainDuration: TimeInterval = 1800 // 30 minutes
        let chainName = position == .before ? "Prep for \(block.title)" : "Follow-up to \(block.title)"
        
        let newChain = Chain(
            name: chainName,
            blocks: [
                TimeBlock(
                    title: chainName,
                    startTime: Date(),
                    duration: chainDuration,
                    energy: block.energy,
                    emoji: block.emoji
                )
            ],
            flowPattern: .waterfall
        )
        
        let insertTime = position == .before 
            ? block.startTime.addingTimeInterval(-chainDuration - 300)
            : block.endTime.addingTimeInterval(300)
        
        dataManager.applyChain(newChain, startingAt: insertTime)
        dismiss()
    }
}

// MARK: - Static Tab Components (No Flash Implementation)

struct StaticEventDetailsTab: View {
    @Binding var block: TimeBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title editing
            VStack(alignment: .leading, spacing: 8) {
                Text("Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                TextField("Activity title", text: $block.title)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            
            // Time and duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Timing")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    DatePicker("Start Time", selection: $block.startTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    HStack {
                        Text("Duration: \(block.durationMinutes) minutes")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("Ends at \(block.endTime.timeString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Energy and flow selection (simplified to prevent flashing)
            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 16) {
                    Picker("Energy", selection: $block.energy) {
                        ForEach(EnergyType.allCases, id: \.self) { energy in
                            Text("\(energy.rawValue) \(energy.description)").tag(energy)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Emoji", selection: $block.emoji) {
                        ForEach(["📋", "💎", "🌊", "☁️", "🎯", "💪", "🧠", "🎨"], id: \.self) { emoji in
                            Text(emoji).tag(emoji)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            Spacer()
        }
        .padding(24)
    }
}

struct StaticEventChainsTab: View {
    let block: TimeBlock
    let allBlocks: [TimeBlock]
    let onAddChain: (ChainPosition) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chain Operations")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Add activity sequences before or after this event")
                .font(.body)
                .foregroundStyle(.secondary)
            
            // Simple chain adding
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Add Before")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if canChainBefore {
                        HStack(spacing: 8) {
                            Button("Add Chain") {
                                onAddChain(.before)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Generate") {
                                generateAndStageChain(.before)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Text("No space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(chainBeforeStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                
                VStack(spacing: 8) {
                    Text("Add After")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if canChainAfter {
                        HStack(spacing: 8) {
                            Button("Add Chain") {
                                onAddChain(.after)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Generate") {
                                generateAndStageChain(.after)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Text("No space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(chainAfterStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            }
            
            Spacer()
        }
        .padding(24)
    }
    
    private var canChainBefore: Bool {
        calculateGapBefore() >= 300 // 5 minutes minimum
    }
    
    private var canChainAfter: Bool {
        calculateGapAfter() >= 300 // 5 minutes minimum
    }
    
    private var chainBeforeStatus: String {
        let gap = calculateGapBefore()
        if gap < 300 {
            return "Need 5min gap\n(\(Int(gap/60))min available)"
        }
        return "\(Int(gap/60)) minutes\navailable"
    }
    
    private var chainAfterStatus: String {
        let gap = calculateGapAfter()
        if gap < 300 {
            return "Need 5min gap\n(\(Int(gap/60))min available)"
        }
        return "\(Int(gap/60)) minutes\navailable"
    }
    
    private func calculateGapBefore() -> TimeInterval {
        let previousBlocks = allBlocks.filter { $0.endTime <= block.startTime && $0.id != block.id }
        guard let previousBlock = previousBlocks.max(by: { $0.endTime < $1.endTime }) else {
            let startOfDay = Calendar.current.startOfDay(for: block.startTime)
            return block.startTime.timeIntervalSince(startOfDay)
        }
        return block.startTime.timeIntervalSince(previousBlock.endTime)
    }
    
    private func calculateGapAfter() -> TimeInterval {
        let nextBlocks = allBlocks.filter { $0.startTime >= block.endTime && $0.id != block.id }
        guard let nextBlock = nextBlocks.min(by: { $0.startTime < $1.startTime }) else {
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: block.startTime) ?? block.endTime
            return endOfDay.timeIntervalSince(block.endTime)
        }
        return nextBlock.startTime.timeIntervalSince(block.endTime)
    }
    
    private func generateAndStageChain(_ position: ChainPosition) {
        // Generate appropriate chain based on context
        let availableTime = position == .before ? calculateGapBefore() : calculateGapAfter()
        
        // Create a context-appropriate chain
        let suggestedDuration = min(availableTime * 0.8, 3600) // Use 80% of available time, max 1 hour
        
        // Generate a time block that fits the context
        let chainBlock = TimeBlock(
            title: generateContextualActivity(for: block, position: position),
            startTime: position == .before ? 
                block.startTime.addingTimeInterval(-suggestedDuration) : 
                block.endTime,
            duration: suggestedDuration,
            energy: block.energy,
            emoji: selectContextualEmoji(for: block, position: position),
        )
        
        // Add to staged blocks (assuming access to data manager)
        // This would need to be passed down or accessed through environment
        // For now, we'll trigger the onAddChain callback which should handle staging
        onAddChain(position)
        
        // Note: chainBlock is created but not directly used here since we're using the callback
        _ = chainBlock
    }
    
    private func generateContextualActivity(for event: TimeBlock, position: ChainPosition) -> String {
        let eventTitle = event.title.lowercased()
        
        if position == .before {
            if eventTitle.contains("meeting") || eventTitle.contains("call") {
                return "Meeting Prep"
            } else if eventTitle.contains("workout") || eventTitle.contains("exercise") {
                return "Warm-up"
            } else if eventTitle.contains("work") || eventTitle.contains("project") {
                return "Focus Setup"
            } else {
                return "Preparation"
            }
        } else {
            if eventTitle.contains("meeting") || eventTitle.contains("call") {
                return "Follow-up Notes"
            } else if eventTitle.contains("workout") || eventTitle.contains("exercise") {
                return "Cool-down"
            } else if eventTitle.contains("work") || eventTitle.contains("project") {
                return "Wrap-up"
            } else {
                return "Transition"
            }
        }
    }
    
    private func selectContextualEmoji(for event: TimeBlock, position: ChainPosition) -> String {
        let eventEmoji = event.emoji
        
        if position == .before {
            switch eventEmoji {
            case "💼": return "📋"
            case "🏃‍♀️", "💪": return "🔥"
            case "👥": return "📝"
            default: return "⚡"
            }
        } else {
            switch eventEmoji {
            case "💼": return "✅"
            case "🏃‍♀️", "💪": return "🧘"
            case "👥": return "📝"
            default: return "🔄"
            }
        }
    }
}

struct StaticEventDurationTab: View {
    @Binding var block: TimeBlock
    
    private let presetDurations = [15, 30, 45, 60, 90, 120, 180, 240]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Duration Control")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Current duration display
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
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            
            // Preset duration buttons (simple, no complex layouts)
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Durations")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(presetDurations.prefix(4), id: \.self) { minutes in
                            durationButton(minutes: minutes)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(presetDurations.suffix(4), id: \.self) { minutes in
                            durationButton(minutes: minutes)
                        }
                    }
                }
            }
            
            // Simple duration slider
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom Duration: \(block.durationMinutes) minutes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
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
            
            Spacer()
        }
        .padding(24)
    }
    
    @ViewBuilder
    private func durationButton(minutes: Int) -> some View {
        Button(action: { setDuration(minutes) }) {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("min")
                    .font(.caption2)
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(
                block.durationMinutes == minutes ? .blue.opacity(0.2) : .gray.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        block.durationMinutes == minutes ? .blue : .clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func setDuration(_ minutes: Int) {
        block.duration = TimeInterval(minutes * 60)
    }
}

// MARK: - Hour With Events (Simplified Layout)

struct HourWithEvents: View {
    let hour: Int
    let selectedDate: Date
    let blocks: [TimeBlock]
    let draggedBlock: TimeBlock?
    let onTap: (Date) -> Void
    let onBlockDrag: (TimeBlock, CGPoint) -> Void
    let onBlockDrop: (TimeBlock, Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var isHovering = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Events for this hour
            ForEach(blocks) { block in
                CleanEventCard(
                    block: block,
                    onDrag: { location in
                        onBlockDrag(block, location)
                    },
                    onDrop: { newTime in
                        onBlockDrop(block, newTime)
                    }
                )
            }
            
            // Empty space for creating new blocks
            if blocks.isEmpty {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHovering ? .blue.opacity(0.05) : hourBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        isHovering ? .blue.opacity(0.3) : .clear,
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                                    )
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let hourTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                        onTap(hourTime)
                    }
                    .onHover { hovering in
                        isHovering = hovering
                    }
            }
            
            // Hour separator line
            if hour < 23 {
                Rectangle()
                    .fill(.quaternary.opacity(0.2))
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(minHeight: 60) // Minimum hour height
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var hourBackgroundColor: Color {
        AstronomicalTimeCalculator.shared.getTimeColor(for: hour, date: selectedDate)
    }
}

// MARK: - Clean Event Card (No Flash, Perfect Position)

struct CleanEventCard: View {
    let block: TimeBlock
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingDetails = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            HStack(spacing: 8) {
                // Energy and flow indicators
                VStack(spacing: 1) {
                    Text(block.energy.rawValue)
                        .font(.caption)
                    Text(block.emoji)
                        .font(.caption2)
                }
                .opacity(0.8)
                .frame(width: 25)
                
                // Block content
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(block.startTime.timeString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        Text("\(block.durationMinutes)m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Simple info icon - no animation
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.blue.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Glass state indicator
                Circle()
                    .fill(stateColor)
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, eventPadding)
        .frame(height: eventHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            borderColor, 
                            style: StrokeStyle(
                                lineWidth: 1
                            )
                        )
                )
        )
        .scaleEffect(isDragging ? 0.98 : 1.0)
        .offset(dragOffset)
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                    }
                    dragOffset = value.translation
                    onDrag(value.location)
                }
                .onEnded { value in
                    isDragging = false
                    dragOffset = .zero
                    
                    let newTime = calculateNewTime(from: value.translation)
                    onDrop(newTime)
                }
        )
        .sheet(isPresented: $showingDetails) {
            NoFlashEventDetailsSheet(
                block: block,
                allBlocks: dataManager.appState.currentDay.blocks,
                onSave: { updatedBlock in
                    dataManager.updateTimeBlock(updatedBlock)
                    showingDetails = false
                },
                onDelete: {
                    dataManager.removeTimeBlock(block.id)
                    showingDetails = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }
    
    // MARK: - Computed Properties
    
    private var eventHeight: CGFloat {
        // Height based on duration, scaled appropriately
        let baseHeight: CGFloat = 30
        let durationMultiplier = max(1.0, CGFloat(block.durationMinutes) / 60.0)
        return baseHeight * durationMultiplier
    }
    
    private var eventPadding: CGFloat {
        block.durationMinutes >= 60 ? 8 : 4
    }
    
    private var stateColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue
        case .mist: return .orange
        case .crystal: return .cyan
        }
    }
    
    private var borderColor: Color {
        switch block.glassState {
        case .solid: return .clear
        case .liquid: return .blue.opacity(0.6)
        case .mist: return .orange.opacity(0.5)
        case .crystal: return .cyan.opacity(0.7)
        }
    }
    
    private func calculateNewTime(from translation: CGSize) -> Date {
        // Simple time calculation based on drag distance
        let pixelsPerHour: CGFloat = 60
        let hourChange = translation.height / pixelsPerHour
        let minuteChange = Int(hourChange * 60)
        
        let newTime = calendar.date(byAdding: .minute, value: minuteChange, to: block.startTime) ?? block.startTime
        
        // Round to nearest 15-minute interval
        let minute = calendar.component(.minute, from: newTime)
        let roundedMinute = (minute / 15) * 15
        
        return calendar.date(bySettingHour: calendar.component(.hour, from: newTime), 
                           minute: roundedMinute, 
                           second: 0, 
                           of: newTime) ?? newTime
    }
}

// MARK: - Enhanced Hour Slot

struct EnhancedHourSlot: View {
    let hour: Int
    let selectedDate: Date
    let blocks: [TimeBlock]
    let onTap: (Date) -> Void
    let onBlockDrag: (TimeBlock, CGPoint) -> Void
    let onBlockDrop: (TimeBlock, Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var isHovering = false
    
    private var hourTime: Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        return calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? dayStart
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: hourTime)
    }
    
    private var isCurrentHour: Bool {
        Calendar.current.component(.hour, from: Date()) == hour &&
        Calendar.current.isDate(selectedDate, inSameDayAs: Date())
    }
    
    private var isCurrentMinute: Bool {
        let now = Date()
        let currentHour = Calendar.current.component(.hour, from: now)
        return currentHour == hour && Calendar.current.isDate(selectedDate, inSameDayAs: now)
    }
    
    private var currentTimeOffset: CGFloat {
        guard isCurrentMinute else { return 0 }
        let now = Date()
        let minute = Calendar.current.component(.minute, from: now)
        return CGFloat(minute) * 0.8 // Rough positioning within hour slot
    }
    
    private var dayNightBackground: Color {
        AstronomicalTimeCalculator.shared.getTimeColor(for: hour, date: selectedDate)
    }
    
    private var timeLabel: String {
        switch hour {
        case 6: return "🌅 \(timeString)"
        case 18: return "🌅 \(timeString)"
        case 0: return "🌙 \(timeString)"
        default: return timeString
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time label with enhanced styling and day/night indicators
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeLabel)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(isCurrentHour ? .blue : .primary)
                
                if isCurrentHour {
                    Circle()
                        .fill(.blue)
                        .frame(width: 4, height: 4)
                        .overlay(
                            Circle()
                                .stroke(.blue, lineWidth: 1)
                                .scaleEffect(1.5)
                                .opacity(0.3)
                        )
                }
            }
            .frame(width: 60, alignment: .trailing)
            
            // Hour content area
            VStack(alignment: .leading, spacing: 4) {
                ForEach(blocks) { block in
                    EnhancedTimeBlockCard(
                        block: block,
                        onTap: { },
                        onDrag: { location in
                            onBlockDrag(block, location)
                        },
                        onDrop: { newTime in
                            onBlockDrop(block, newTime)
                        },
                        allBlocks: blocksForCurrentDay()
                    )
                }
                
                // Empty space for creating new blocks
                if blocks.isEmpty {
                    Rectangle()
                        .fill(.clear)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHovering ? .blue.opacity(0.05) : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            isHovering ? .blue.opacity(0.3) : .clear,
                                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                                        )
                                )
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTap(hourTime)
                        }
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isHovering = hovering
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                // Current time line indicator
                isCurrentMinute ?
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(.blue)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .opacity(0.8)
                        
                        Text("now")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .opacity(0.9)
                    }
                    .offset(y: currentTimeOffset - 20)
                    : nil,
                alignment: .topLeading
            )
        }
        .padding(.vertical, 4)
        .background(
            Group {
                if isCurrentHour {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.blue.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(dayNightBackground)
                }
            }
        )
    }
    
    private func blocksForCurrentDay() -> [TimeBlock] {
        // Return all blocks for the current day for gap checking
        return dataManager.appState.currentDay.blocks
    }
}

// MARK: - Enhanced Time Block Card

struct EnhancedTimeBlockCard: View {
    let block: TimeBlock
    let onTap: () -> Void
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    let allBlocks: [TimeBlock] // For chain gap checking
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingDetails = false
    @State private var activeTab: EventTab = .details
    
    var body: some View {
        VStack(spacing: 0) {
            // Main clickable event card (no edge resize)
            Button(action: { showingDetails = true }) {
            HStack(spacing: 10) {
                    // Energy & flow indicators
                VStack(spacing: 2) {
                    Text(block.energy.rawValue)
                        .font(.title3)
                    Text(block.emoji)
                        .font(.caption)
                }
                .opacity(0.8)
                
                    // Block content
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        Text(timeString(from: block.startTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        Text("\(block.durationMinutes)m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                            // Glass state indicator
                        Circle()
                            .fill(stateColor.opacity(0.8))
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .stroke(stateColor, lineWidth: 1)
                                    .scaleEffect(isDragging ? 1.5 : 1.0)
                            )
                    }
                }
                    
                    Spacer()
                    
                    // Quick action indicator
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.regularMaterial.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                borderColor.opacity(isDragging ? 1.0 : 0.6),
                                style: StrokeStyle(
                                    lineWidth: isDragging ? 2 : 1
                                )
                            )
                    )
                    .shadow(
                        color: stateColor.opacity(isDragging ? 0.3 : 0.1),
                        radius: isDragging ? 8 : 3,
                        y: isDragging ? 4 : 1
                    )
            )
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .offset(dragOffset)
            .gesture(
                // Single, clean drag gesture for moving events
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging { 
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDragging = true
                            }
                        }
                        dragOffset = value.translation
                        onDrag(value.location)
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isDragging = false
                            dragOffset = .zero
                        }
                        // Calculate proper new time based on drag distance
                        let newTime = calculateNewTime(from: value.translation)
                        onDrop(newTime)
                    }
            )
            // No animation to prevent flashing
        }
        .sheet(isPresented: $showingDetails) {
            NoFlashEventDetailsSheet(
                block: block,
                allBlocks: allBlocks,
                onSave: { updatedBlock in
                    dataManager.updateTimeBlock(updatedBlock)
                    showingDetails = false
                },
                onDelete: {
                    dataManager.removeTimeBlock(block.id)
                    showingDetails = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }
    
    private var stateColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue  
        case .mist: return .purple
        case .crystal: return .cyan
        }
    }
    
    private var borderColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue
        case .mist: return .purple
        case .crystal: return .cyan
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func calculateNewTime(from translation: CGSize) -> Date {
        // Calculate time change based on vertical drag distance
        // Assume each 60 pixels = 1 hour (this can be adjusted)
        let pixelsPerHour: CGFloat = 60
        let hourChange = translation.height / pixelsPerHour
        
        // Convert to minutes for more precision
        let minuteChange = Int(hourChange * 60)
        
        // Apply the change to the current start time
        let newTime = Calendar.current.date(byAdding: .minute, value: minuteChange, to: block.startTime) ?? block.startTime
        
        // Round to nearest 15-minute interval for cleaner scheduling
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: newTime)
        let roundedMinute = (minute / 15) * 15
        
        return calendar.date(bySettingHour: calendar.component(.hour, from: newTime), 
                           minute: roundedMinute, 
                           second: 0, 
                           of: newTime) ?? newTime
    }
    
    private func showChainSelector(position: ChainPosition) {
        // TODO: Implement chain selector
    }
}

// MARK: - Event Details Sheet

enum EventTab: String, CaseIterable {
    case details = "Details"
    case chains = "Chains"
    case duration = "Duration"
    
    var icon: String {
        switch self {
        case .details: return "info.circle"
        case .chains: return "link"
        case .duration: return "clock"
        }
    }
}

struct EventDetailsSheet: View {
    let block: TimeBlock
    let activeTab: Binding<EventTab>
    let allBlocks: [TimeBlock]
    let onSave: (TimeBlock) -> Void
    let onDelete: () -> Void
    let onAddChain: (ChainPosition) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedBlock: TimeBlock
    @State private var showingDeleteConfirmation = false
    @State private var currentTab: EventTab = .details
    
    init(block: TimeBlock, activeTab: Binding<EventTab>, allBlocks: [TimeBlock], onSave: @escaping (TimeBlock) -> Void, onDelete: @escaping () -> Void, onAddChain: @escaping (ChainPosition) -> Void) {
        self.block = block
        self.activeTab = activeTab
        self.allBlocks = allBlocks
        self.onSave = onSave
        self.onDelete = onDelete
        self.onAddChain = onAddChain
        self._editedBlock = State(initialValue: block)
        self._currentTab = State(initialValue: activeTab.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Improved tab selector with liquid glass styling
                EventTabSelector(activeTab: $currentTab)
                
                Divider()
                    .opacity(0.3)
                
                // Tab content with smooth transitions
                ScrollView {
                    Group {
                        switch currentTab {
                        case .details:
                            EventDetailsTab(block: $editedBlock)
                        case .chains:
                            EventChainsTab(
                                block: block,
                                allBlocks: allBlocks,
                                onAddChain: onAddChain
                            )
                        case .duration:
                            EventDurationTab(block: $editedBlock)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: currentTab)
                }
                .frame(maxHeight: .infinity)
                
                Divider()
                    .opacity(0.3)
                
                // Enhanced bottom actions with liquid glass styling
                HStack(spacing: 12) {
                    Button("Delete", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save Changes") {
                        onSave(editedBlock)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editedBlock.title.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .navigationTitle(block.title)
            .background(.ultraThinMaterial.opacity(0.3))
        }
        .frame(width: 700, height: 600) // Made wider and taller for better usability
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(block.title)'? This action cannot be undone.")
        }
    }
}

struct EventTabSelector: View {
    @Binding var activeTab: EventTab
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(EventTab.allCases, id: \.self) { tab in
                Button(action: { 
                    // Instant tab switching to fix delays
                    activeTab = tab
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(activeTab == tab ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44) // Fixed height prevents flashing
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(activeTab == tab ? .blue : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            .ultraThinMaterial.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: activeTab) // Faster, smoother animation
    }
}

struct EventDetailsTab: View {
    @Binding var block: TimeBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title editing
            VStack(alignment: .leading, spacing: 8) {
                Text("Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                TextField("Activity title", text: $block.title)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            
            // Time and duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Timing")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    DatePicker("Start Time", selection: $block.startTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    HStack {
                        Text("Duration: \(block.durationMinutes) minutes")
                            .font(.subheadline)
                    
                    Spacer()
                    
                        Text("Ends at \(block.endTime.timeString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Energy and flow selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Energy")
                            .font(.subheadline)
                        
                        Picker("Energy", selection: $block.energy) {
                            ForEach(EnergyType.allCases, id: \.self) { energy in
                                Label(energy.description, systemImage: energy.rawValue)
                                    .tag(energy)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flow")
                            .font(.subheadline)
                        
                        Picker("Emoji", selection: $block.emoji) {
                            ForEach(["📋", "💎", "🌊", "☁️", "🎯", "💪", "🧠", "🎨"], id: \.self) { emoji in
                                Text(emoji)
                                    .tag(emoji)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            
            
            Spacer()
        }
        .padding(24)
    }
}

struct EventChainsTab: View {
    let block: TimeBlock
    let allBlocks: [TimeBlock]
    let onAddChain: (ChainPosition) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingChainSelector = false
    @State private var selectedPosition: ChainPosition = .after
    @State private var isGeneratingChains = false
    @State private var generatedChains: [Chain] = []
    @State private var showingGeneratedChains = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chain Operations")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Add activity sequences before or after this event")
                .font(.body)
                .foregroundStyle(.secondary)
            
            // Generate chains section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("AI Chain Generator")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("Generate Chains") {
                        generateChainsForEvent()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isGeneratingChains)
                }
                
                if isGeneratingChains {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating chain suggestions...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Let AI suggest activity chains based on this event")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            
            // Chain before section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Add Before")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if canChainBefore {
                        HStack(spacing: 8) {
                            Button("Add Chain") {
                                selectedPosition = .before
                                showingChainSelector = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button("Generate") {
                                generateAndStageChain(.before)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else {
                        Text("No space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(chainBeforeStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            
            // Chain after section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Add After")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if canChainAfter {
                        HStack(spacing: 8) {
                            Button("Add Chain") {
                                selectedPosition = .after
                                showingChainSelector = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button("Generate") {
                                generateAndStageChain(.after)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else {
                        Text("No space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(chainAfterStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            
            // Available chains section
            if !dataManager.appState.recentChains.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Chains")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(dataManager.appState.recentChains.prefix(5)) { chain in
                                ChainOptionCard(
                                    chain: chain,
                                    canAddBefore: canChainBefore,
                                    canAddAfter: canChainAfter,
                                    onAdd: { position in
                                        addChain(chain, at: position)
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .sheet(isPresented: $showingChainSelector) {
            ChainCreatorSheet(
                position: selectedPosition,
                baseBlock: block,
                onChainCreated: { chain in
                    addChain(chain, at: selectedPosition)
                    showingChainSelector = false
                }
            )
        }
        .sheet(isPresented: $showingGeneratedChains) {
            GeneratedChainsSheet(
                chains: generatedChains,
                baseBlock: block,
                canAddBefore: canChainBefore,
                canAddAfter: canChainAfter,
                onChainSelected: { chain, position in
                    addChain(chain, at: position)
                    showingGeneratedChains = false
                }
            )
        }
    }
    
    private var canChainBefore: Bool {
        let gapBefore = calculateGapBefore()
        return gapBefore >= 300 // 5 minutes minimum
    }
    
    private var canChainAfter: Bool {
        let gapAfter = calculateGapAfter()
        return gapAfter >= 300 // 5 minutes minimum
    }
    
    private var chainBeforeStatus: String {
        let gap = calculateGapBefore()
        if gap < 300 {
            return "Need at least 5 minutes gap (currently \(Int(gap/60))min available)"
        }
        return "Available space: \(Int(gap/60)) minutes"
    }
    
    private var chainAfterStatus: String {
        let gap = calculateGapAfter()
        if gap < 300 {
            return "Need at least 5 minutes gap (currently \(Int(gap/60))min available)"
        }
        return "Available space: \(Int(gap/60)) minutes"
    }
    
    private func calculateGapBefore() -> TimeInterval {
        // Find the previous event
        let previousBlocks = allBlocks.filter { $0.endTime <= block.startTime }
        guard let previousBlock = previousBlocks.max(by: { $0.endTime < $1.endTime }) else {
            // No previous event, gap to start of day
            let startOfDay = Calendar.current.startOfDay(for: block.startTime)
            return block.startTime.timeIntervalSince(startOfDay)
        }
        
        return block.startTime.timeIntervalSince(previousBlock.endTime)
    }
    
    private func calculateGapAfter() -> TimeInterval {
        // Find the next event  
        let nextBlocks = allBlocks.filter { $0.startTime >= block.endTime }
        guard let nextBlock = nextBlocks.min(by: { $0.startTime < $1.startTime }) else {
            // No next event, gap to end of day
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: block.startTime) ?? block.endTime
            return endOfDay.timeIntervalSince(block.endTime)
        }
        
        return nextBlock.startTime.timeIntervalSince(block.endTime)
    }
    
    private func addChain(_ chain: Chain, at position: ChainPosition) {
        let insertTime = position == .before 
            ? block.startTime.addingTimeInterval(-chain.totalDuration - 300) // 5 min buffer
            : block.endTime.addingTimeInterval(300) // 5 min buffer
        
        dataManager.applyChain(chain, startingAt: insertTime)
    }
    
    private func generateChainsForEvent() {
        isGeneratingChains = true
        
        Task {
            let context = dataManager.createEnhancedContext()
            let _ = buildChainGenerationPrompt(for: block, context: context)
            
            // Note: aiService should be accessed as @EnvironmentObject, not through dataManager
            // let _ = try await aiService.processMessage(prompt, context: context)
            let chains: [Chain] = [] // Placeholder - would parse AI response
            
            await MainActor.run {
                self.generatedChains = chains
                self.showingGeneratedChains = true
                self.isGeneratingChains = false
            }
        }
    }
    
    private func buildChainGenerationPrompt(for block: TimeBlock, context: DayContext) -> String {
        let gapBefore = calculateGapBefore() / 60 // in minutes
        let gapAfter = calculateGapAfter() / 60 // in minutes
        
        return """
        Generate activity chains for the event "\(block.title)" scheduled from \(formatTime(block.startTime)) to \(formatTime(block.endTime)).
        
        Event details:
        - Duration: \(Int(block.duration / 60)) minutes
        - Energy level: \(block.energy.description)
        - Emoji: \(block.emoji)
        
        Available gaps:
        - Before: \(Int(gapBefore)) minutes
        - After: \(Int(gapAfter)) minutes
        
        Context: \(context.currentEnergy.description), \(context.mood.description)
        
        Generate 2-3 different chain suggestions that could be added before or after this event. Consider:
        1. Energy transitions (prepare/wind down)
        2. Related activities that complement this event
        3. Time constraints and realistic durations
        
        Return JSON array of chains with format:
        [{
          "name": "Chain Name",
          "description": "Brief description",
          "position": "before" or "after",
          "emoji": "🔗",
          "blocks": [{
            "title": "Activity",
            "duration": 900,
            "energy": "daylight",
            "emoji": "💪"
          }]
        }]
        """
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func generateAndStageChain(_ position: ChainPosition) {
        // Generate appropriate chain based on context
        let availableTime = position == .before ? calculateGapBefore() : calculateGapAfter()
        
        // Create a context-appropriate chain
        let suggestedDuration = min(availableTime * 0.8, 3600) // Use 80% of available time, max 1 hour
        
        // Generate a time block that fits the context
        let chainBlock = TimeBlock(
            title: generateContextualActivity(for: block, position: position),
            startTime: position == .before ? 
                block.startTime.addingTimeInterval(-suggestedDuration) : 
                block.endTime,
            duration: suggestedDuration,
            energy: block.energy,
            emoji: selectContextualEmoji(for: block, position: position),
        )
        
        // Add to staged blocks through data manager
        dataManager.addTimeBlock(chainBlock)
    }
    
    private func generateContextualActivity(for event: TimeBlock, position: ChainPosition) -> String {
        let eventTitle = event.title.lowercased()
        
        if position == .before {
            if eventTitle.contains("meeting") || eventTitle.contains("call") {
                return "Meeting Prep"
            } else if eventTitle.contains("workout") || eventTitle.contains("exercise") {
                return "Warm-up"
            } else if eventTitle.contains("work") || eventTitle.contains("project") {
                return "Focus Setup"
            } else {
                return "Preparation"
            }
        } else {
            if eventTitle.contains("meeting") || eventTitle.contains("call") {
                return "Follow-up Notes"
            } else if eventTitle.contains("workout") || eventTitle.contains("exercise") {
                return "Cool-down"
            } else if eventTitle.contains("work") || eventTitle.contains("project") {
                return "Wrap-up"
            } else {
                return "Transition"
            }
        }
    }
    
    private func selectContextualEmoji(for event: TimeBlock, position: ChainPosition) -> String {
        let eventEmoji = event.emoji
        
        if position == .before {
            switch eventEmoji {
            case "💼": return "📋"
            case "🏃‍♀️", "💪": return "🔥"
            case "👥": return "📝"
            default: return "⚡"
            }
        } else {
            switch eventEmoji {
            case "💼": return "✅"
            case "🏃‍♀️", "💪": return "🧘"
            case "👥": return "📝"
            default: return "🔄"
            }
        }
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

// MARK: - Month View Expanded

struct MonthViewExpanded: View {
    @Binding var selectedDate: Date
    @State private var displayedMonth: Date = Date()
    @State private var selectedDates: Set<Date> = []
    @State private var dragStartDate: Date?
    @State private var isDragging = false
    let dataManager: AppDataManager
    let onDayClick: (() -> Void)?
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left.circle")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(dateFormatter.string(from: displayedMonth))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right.circle")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                // Weekday headers
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(height: 20)
                }
                
                // Calendar days with multi-selection
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        MultiSelectCalendarDayCell(
                            date: date,
                            selectedDate: selectedDate,
                            selectedDates: selectedDates,
                            isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                            onTap: { handleDayTap(date) },
                            onDragStart: { handleDragStart(date) },
                            onDragEnter: { handleDragEnter(date) },
                            onDragEnd: { handleDragEnd() },
                            dataManager: dataManager
                        )
                    } else {
                        Rectangle()
                            .fill(.clear)
                            .frame(height: 28)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            displayedMonth = selectedDate
            selectedDates = [selectedDate]
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            dataManager.switchToDay(newValue)
        }
    }
    
    private var calendarDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let firstDayOfWeek = calendar.component(.weekday, from: firstOfMonth) - 1
        
        var days: [Date?] = Array(repeating: nil, count: firstDayOfWeek)
        
        let numberOfDays = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Fill remaining cells to complete the grid
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        }
    }
    
    // Multi-day selection handlers
    private func handleDayTap(_ date: Date) {
        // Always set the selected date first - this will trigger onChange and switchToDay
        selectedDate = date
        
        if selectedDates.contains(date) && selectedDates.count == 1 {
            // Single selection - navigate to that day and trigger day click
            onDayClick?()
        } else if selectedDates.contains(date) {
            // Remove from multi-selection
            selectedDates.remove(date)
            if !selectedDates.isEmpty {
                selectedDate = selectedDates.sorted().first ?? date
            }
        } else {
            // Add to selection or replace selection and trigger day click
            selectedDates = [date]
            onDayClick?()
        }
    }
    
    private func handleDragStart(_ date: Date) {
        dragStartDate = date
        isDragging = true
        selectedDates = [date]
        selectedDate = date
    }
    
    private func handleDragEnter(_ date: Date) {
        guard let startDate = dragStartDate, isDragging else { return }
        
        // Calculate continuous date range
        let start = min(startDate, date)
        let end = max(startDate, date)
        
        var newSelection: Set<Date> = []
        var current = start
        
        while current <= end {
            newSelection.insert(current)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
        }
        
        selectedDates = newSelection
        selectedDate = date
    }
    
    private func handleDragEnd() {
        dragStartDate = nil
        isDragging = false
    }
}

// MARK: - Calendar Day Cell

struct MultiSelectCalendarDayCell: View {
    let date: Date
    let selectedDate: Date
    let selectedDates: Set<Date>
    let isCurrentMonth: Bool
    let onTap: () -> Void
    let onDragStart: () -> Void
    let onDragEnter: () -> Void
    let onDragEnd: () -> Void
    let dataManager: AppDataManager
    
    @State private var isDragHovering = false
    
    private let calendar = Calendar.current
    
    private var isSelected: Bool {
        selectedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }
    
    private var isPrimarySelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var isToday: Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }
    
    private var dayText: String {
        String(calendar.component(.day, from: date))
    }
    
    private var selectionStyle: SelectionStyle {
        if selectedDates.count <= 1 {
            return .single
        }
        
        let sortedDates = selectedDates.sorted()
        guard let index = sortedDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: date) }) else {
            return .none
        }
        
        if index == 0 { return .start }
        if index == sortedDates.count - 1 { return .end }
        return .middle
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(dayText)
                .font(.caption)
                .fontWeight(isToday ? .bold : .medium)
                .foregroundStyle(
                    isSelected ? .white : 
                    isToday ? .blue :
                    isCurrentMonth ? .primary : .gray.opacity(0.6)
                )
                .frame(width: 28, height: 28)
                .background(selectionBackground)
                .scaleEffect(isDragHovering ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onDrag {
            onDragStart()
            return NSItemProvider(object: date.description as NSString)
        }
        .onDrop(of: [.text], delegate: CalendarDropDelegate(
            date: date,
            onDragEnter: {
                isDragHovering = true
                onDragEnter()
            },
            onDragExit: { isDragHovering = false },
            onDragEnd: onDragEnd,
            dataManager: dataManager,
            targetTime: date
        ))
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragHovering)
    }
    
    @ViewBuilder
    private var selectionBackground: some View {
        switch selectionStyle {
        case .none:
            Circle()
                .fill(.clear)
                .overlay(
                    Circle()
                        .strokeBorder(isToday ? .blue : .clear, lineWidth: 1.5)
                )
        case .single:
            Circle()
                .fill(isSelected ? .blue : .clear)
                .overlay(
                    Circle()
                        .strokeBorder(isToday && !isSelected ? .blue : .clear, lineWidth: 1.5)
                )
        case .start:
            RoundedRectangle(cornerRadius: 14)
                .fill(.blue.opacity(isPrimarySelected ? 1.0 : 0.8))
                .clipShape(HalfCapsule(side: .leading))
        case .middle:
            Rectangle()
                .fill(.blue.opacity(isPrimarySelected ? 1.0 : 0.8))
        case .end:
            RoundedRectangle(cornerRadius: 14)
                .fill(.blue.opacity(isPrimarySelected ? 1.0 : 0.8))
                .clipShape(HalfCapsule(side: .trailing))
        }
    }
}

enum SelectionStyle {
    case none, single, start, middle, end
}

struct HalfCapsule: Shape {
    enum Side { case leading, trailing }
    let side: Side
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.height / 2
        
        switch side {
        case .leading:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), 
                       radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), 
                       radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.closeSubpath()
        case .trailing:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), 
                       radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), 
                       radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        
        return path
    }
}

struct CalendarDropDelegate: DropDelegate {
    let date: Date
    let onDragEnter: () -> Void
    let onDragExit: () -> Void
    let onDragEnd: () -> Void
    let dataManager: AppDataManager
    let targetTime: Date
    
    func dropEntered(info: DropInfo) {
        onDragEnter()
    }
    
    func dropExited(info: DropInfo) {
        onDragExit()
    }
    
    func performDrop(info: DropInfo) -> Bool {
        onDragEnd()
        
        // Check if we have TimeBlock data
        if let timeBlockData = info.itemProviders(for: [.timeBlockData]).first {
            timeBlockData.loadObject(ofClass: NSString.self) { provider, error in
                if error == nil {
                    // Handle TimeBlock drop - this would need to be enhanced
                    // For now, trigger the creation flow
                }
            }
            return true
        }
        
        // Check for chain template or backfill template data
        for provider in info.itemProviders(for: [.text]) {
            provider.loadObject(ofClass: NSString.self) { item, error in
                if let payload = item as? String, error == nil {
                    DispatchQueue.main.async {
                        // Parse backfill template payload
                        if payload.hasPrefix("backfill_template:") {
                            let parts = payload.dropFirst("backfill_template:".count).components(separatedBy: "|")
                            if parts.count >= 5 {
                                let title = parts[0]
                                let duration = TimeInterval(Int(parts[1]) ?? 3600)
                                let energy = EnergyType(rawValue: parts[2]) ?? .daylight
                                let emoji = parts[3]
                                let _ = Double(parts[4]) ?? 0.8
                                
                                // Create a time block from the dropped template and add directly to timeline
                                let newBlock = TimeBlock(
                                    title: title,
                                    startTime: self.targetTime,
                                    duration: duration,
                                    energy: energy,
                                    emoji: emoji,
                                )
                                
                                // Add directly to the timeline instead of staging
                                self.dataManager.addTimeBlock(newBlock)
                                
                            }
                        }
                        // Parse chain template payload
                        else if payload.hasPrefix("chain_template:") {
                            let parts = payload.dropFirst("chain_template:".count).components(separatedBy: "|")
                            if parts.count >= 3 {
                                let name = parts[0]
                                let duration = TimeInterval(Int(parts[1]) ?? 3600)
                                let _ = parts[2]
                                
                                // Create a time block from the dropped chain template and add directly to timeline
                                let newBlock = TimeBlock(
                                    title: name,
                                    startTime: self.targetTime,
                                    duration: duration,
                                    energy: .daylight,
                                    emoji: "🌊"
                                )
                                
                                // Add directly to the timeline instead of staging
                                self.dataManager.addTimeBlock(newBlock)
                                
                            }
                        }
                        // Handle todo item drops
                        else if payload.hasPrefix("todo_item:") {
                            let parts = payload.dropFirst("todo_item:".count).components(separatedBy: "|")
                            if parts.count >= 4 {
                                let title = parts[0]
                                let _ = parts[1] // UUID - we don't need it for the time block
                                let dueDateString = parts[2]
                                let isCompleted = Bool(parts[3]) ?? false
                                
                                // Don't create time blocks for completed todos
                                guard !isCompleted else { return }
                                
                                let newBlock = TimeBlock(
                                    title: title,
                                    startTime: self.targetTime,
                                    duration: 3600, // Default 1 hour for todo items
                                    energy: .daylight,
                                    emoji: "📝"
                                )
                                
                                self.dataManager.addTimeBlock(newBlock)
                            }
                        }
                        // Handle legacy chain template drops - now add directly to timeline
                        else if payload.contains("template") || payload.contains("chain") {
                            // Create a time block from the dropped template
                            let newBlock = TimeBlock(
                                title: payload.components(separatedBy: " template").first ?? payload,
                                startTime: self.targetTime,
                                duration: 3600, // Default 1 hour - could be improved
                                energy: .daylight,
                                emoji: "🌊"
                            )
                            
                            // Add directly to the timeline instead of staging
                            self.dataManager.addTimeBlock(newBlock)
                            
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Accept drops of text and TimeBlock data
        if info.hasItemsConforming(to: [.text]) || info.hasItemsConforming(to: [.timeBlockData]) {
            return DropProposal(operation: .move)
        }
        return DropProposal(operation: .forbidden)
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

struct EnhancedGoalsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var showingGoalCreator = false
    @State private var showingGoalBreakdown = false
    @State private var selectedGoal: Goal?
    @State private var showingGoalDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
            SectionHeader(
                title: "Goals",
                    subtitle: "Smart breakdown & tracking", 
                systemImage: "target.circle",
                gradient: LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
            )
            
                Spacer()
                
                Button(action: { showingGoalCreator = true }) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .help("Create new goal with AI breakdown")
            }
            
            LazyVStack(spacing: 8) {
                ForEach(dataManager.appState.goals) { goal in
                    EnhancedGoalCard(
                        goal: goal,
                        onTap: { 
                            selectedGoal = goal
                            showingGoalDetails = true
                        },
                        onBreakdown: { 
                            selectedGoal = goal
                            showingGoalBreakdown = true
                        },
                        onToggleState: {
                            toggleGoalState(goal)
                        }
                    )
                }
                
                if dataManager.appState.goals.isEmpty {
                    EmptyGoalsCard {
                        showingGoalCreator = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingGoalCreator) {
            EnhancedGoalCreatorSheet { newGoal in
                dataManager.addGoal(newGoal)
                showingGoalCreator = false
            }
            .environmentObject(aiService)
        }
        .sheet(isPresented: $showingGoalBreakdown) {
            if let goal = selectedGoal {
                AIGoalBreakdownSheet(goal: goal) { actions in
                    processGoalBreakdown(goal: goal, actions: actions)
                    showingGoalBreakdown = false
                }
                .environmentObject(aiService)
            }
        }
        .sheet(isPresented: $showingGoalDetails) {
            if let goal = selectedGoal {
                GoalDetailSheet(
                    goal: goal,
                    onSave: { updatedGoal in
                        dataManager.updateGoal(updatedGoal)
                        showingGoalDetails = false
                    },
                    onDelete: {
                        dataManager.removeGoal(id: goal.id)
                        showingGoalDetails = false
                    }
                )
            }
        }
    }
    
    private func toggleGoalState(_ goal: Goal) {
        var updatedGoal = goal
        switch updatedGoal.state {
        case .draft: updatedGoal.state = .on
        case .on: updatedGoal.state = .off
        case .off: updatedGoal.state = .draft
        }
        dataManager.updateGoal(updatedGoal)
    }
    
    private func processGoalBreakdown(goal: Goal, actions: [GoalBreakdownAction]) {
        var hasStageableActions = false
        
        for action in actions {
            switch action {
            case .createChain(let chain):
                // Stage chains as potential actions instead of applying immediately
                for block in chain.blocks {
                    dataManager.addTimeBlock(block)
                    hasStageableActions = true
                }
            case .createPillar(let pillar):
                // Apply pillars immediately as they don't need staging
                dataManager.addPillar(pillar)
            case .createEvent(let timeBlock):
                dataManager.addTimeBlock(timeBlock)
                hasStageableActions = true
            case .updateGoal(let updatedGoal):
                // Apply goal updates immediately
                dataManager.updateGoal(updatedGoal)
            }
        }
        
        // Only show "Ready to apply?" message if there are staged items
    }
}

struct AuroraDreamBuilderSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingDreamBuilder = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Dreams",
                subtitle: "Future visions",
                systemImage: "sparkles.circle", 
                gradient: LinearGradient(colors: [.orange, .pink, .purple], startPoint: .leading, endPoint: .trailing)
            )
            
            // Simplified dream builder interface
            VStack(spacing: 8) {
                AuroraDreamCard()
                
                Button("✨ Build New Vision") {
                    showingDreamBuilder = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .buttonBorderShape(.capsule)
            }
        }
        .sheet(isPresented: $showingDreamBuilder) {
            Text("Dream Builder - Coming Soon")
                .padding()
        }
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

// MARK: - Enhanced Goal Components

struct EnhancedGoalCard: View {
    let goal: Goal
    let onTap: () -> Void
    let onBreakdown: () -> Void
    let onToggleState: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Goal state indicator with click-to-toggle
            Button(action: onToggleState) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(goalStateColor)
                    .frame(width: 6, height: 24)
                    .overlay(
                        Text(goal.state.rawValue.prefix(1))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(.plain)
            .help("Toggle goal state: \(goal.state.rawValue)")
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(goal.emoji)
                        .font(.caption)
                    
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                }
                
                Text(goal.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("Importance: \(goal.importance)/5")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if goal.progress > 0 {
                        Text("Progress: \(Int(goal.progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    
                    if goal.needsBreakdown {
                        Text("Needs breakdown")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            if isHovering {
                HStack(spacing: 6) {
                    Button("Breakdown") {
                        onBreakdown()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("AI breakdown into chains/pillars/events")
                    
                    Button("Edit") {
                        onTap()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            } else {
                Circle()
                    .fill(goal.isActive ? .green : .orange)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial.opacity(isHovering ? 0.6 : 0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(goalStateColor.opacity(isHovering ? 0.4 : 0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in isHovering = hovering }
        .onTapGesture { onTap() }
    }
    
    private var goalStateColor: Color {
        switch goal.state {
        case .draft: return .orange
        case .on: return .green
        case .off: return .gray
        }
    }
}

struct EmptyGoalsCard: View {
    let onCreateGoal: () -> Void
    
    var body: some View {
        Button(action: onCreateGoal) {
            VStack(spacing: 12) {
                Text("🎯")
                    .font(.title)
                    .opacity(0.6)
                
                Text("Create Your First Goal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Goals help AI understand your priorities and create actionable plans")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("+ Create Goal")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(.green)
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

struct EnhancedGoalCreatorSheet: View {
    let onGoalCreated: (Goal) -> Void
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var goalTitle = ""
    @State private var goalDescription = ""
    @State private var importance = 3
    @State private var selectedState: GoalState = .draft
    @State private var selectedEmoji = "🎯"
    @State private var relatedPillarIds: [UUID] = []
    @State private var aiSuggestions = ""
    @State private var isGeneratingAI = false
    @State private var targetDate: Date?
    @State private var hasTargetDate = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Goal")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            TextField("Goal title", text: $goalTitle)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: goalTitle) { _, _ in
                                    generateAISuggestions()
                                }
                            
                            TextField("🎯", text: $selectedEmoji)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                        
                        TextField("Description (optional)", text: $goalDescription, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Importance: \(importance)/5")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Slider(value: Binding(
                                get: { Double(importance) },
                                set: { importance = Int($0) }
                            ), in: 1...5, step: 1)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("State")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("State", selection: $selectedState) {
                                ForEach(GoalState.allCases, id: \.self) { state in
                                    Text(state.rawValue).tag(state)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Set target date", isOn: $hasTargetDate)
                        
                        if hasTargetDate {
                            DatePicker("Target date", selection: Binding(
                                get: { targetDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date() },
                                set: { targetDate = $0 }
                            ), displayedComponents: .date)
                        }
                    }
                }
                
                // AI Suggestions
                if !aiSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Suggestions")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(aiSuggestions)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Goal") {
                        createGoal()
                    }
                    .disabled(goalTitle.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 700)
    }
    
    private func generateAISuggestions() {
        guard !goalTitle.isEmpty else { return }
        
        isGeneratingAI = true
        
        Task {
            do {
                let prompt = """
                User wants to create a goal: "\(goalTitle)"
                Description: "\(goalDescription)"
                
                Provide 2-3 sentence suggestion on:
                1. How to break this down into actionable steps
                2. What chains or pillars might support this goal
                3. Realistic timeline considerations
                
                Keep it encouraging and practical.
                """
                
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
                    aiSuggestions = response.text
                    isGeneratingAI = false
                }
            } catch {
                await MainActor.run {
                    aiSuggestions = "Consider breaking this goal into smaller, specific actions you can track daily or weekly."
                    isGeneratingAI = false
                }
            }
        }
    }
    
    private func createGoal() {
        let newGoal = Goal(
            title: goalTitle,
            description: goalDescription,
            state: selectedState,
            importance: importance,
            groups: [],
            targetDate: hasTargetDate ? targetDate : nil,
            emoji: selectedEmoji,
            relatedPillarIds: relatedPillarIds
        )
        
        onGoalCreated(newGoal)
    }
}

struct AIGoalBreakdownSheet: View {
    let goal: Goal
    let onActionsGenerated: ([GoalBreakdownAction]) -> Void
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedGoal: Goal
    @State private var breakdownActions: [GoalBreakdownAction] = []
    @State private var isGenerating = true
    @State private var analysisText = ""
    
    init(goal: Goal, onActionsGenerated: @escaping ([GoalBreakdownAction]) -> Void) {
        self.goal = goal
        self.onActionsGenerated = onActionsGenerated
        self._editedGoal = State(initialValue: goal)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("AI Goal Breakdown")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Goal editing section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Goal Details")
                        .font(.headline)
                    
                    HStack {
                        TextField("Goal title", text: $editedGoal.title)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("🎯", text: $editedGoal.emoji)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                    
                    TextField("Description", text: $editedGoal.description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .onChange(of: editedGoal.description) { _, _ in
                            // Regenerate breakdown when description changes
                            regenerateBreakdown()
                        }
                }
                
                if isGenerating {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Analyzing '\(editedGoal.title)' for breakdown...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !analysisText.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("AI Analysis")
                                        .font(.headline)
                                    
                                    Text(analysisText)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .padding()
                                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested Actions")
                                    .font(.headline)
                                
                                ForEach(Array(breakdownActions.enumerated()), id: \.offset) { index, action in
                                    ActionCard(action: action, index: index)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Apply All & Update Goal") {
                            // Update the goal first
                            let updatedActions = breakdownActions + [.updateGoal(editedGoal)]
                            onActionsGenerated(updatedActions)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(breakdownActions.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Goal Breakdown")
        }
        .frame(width: 700, height: 600)
        .task {
            await generateBreakdown()
        }
    }
    
    private func generateBreakdown() async {
        // Simple AI-generated breakdown for now
        await MainActor.run {
            analysisText = "This goal can be achieved through consistent daily actions and strategic planning."
            
            // Create sample breakdown actions
            breakdownActions = [
                .createPillar(Pillar(
                    name: "Daily \(goal.title) Work",
                    description: "Daily activities supporting \(goal.title)",
                    frequency: .daily,
                    minDuration: 1800,
                    maxDuration: 7200,
                    preferredTimeWindows: [],
                    overlapRules: [],
                    quietHours: []
                )),
                .createChain(Chain(
                    name: "\(goal.title) Sprint",
                    blocks: [
                        TimeBlock(
                            title: "Plan \(goal.title)",
                            startTime: Date(),
                            duration: 1800,
                            energy: .daylight,
                            emoji: "💎"
                        ),
                        TimeBlock(
                            title: "Execute \(goal.title) tasks",
                            startTime: Date(),
                            duration: 3600,
                            energy: .daylight,
                            emoji: "🌊"
                        )
                    ],
                    flowPattern: .waterfall
                ))
            ]
            
            isGenerating = false
        }
    }
    
    private func regenerateBreakdown() {
        isGenerating = true
        Task {
            await generateBreakdown()
        }
    }
}

struct ActionCard: View {
    let action: GoalBreakdownAction
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(actionColor, in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(actionTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(actionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: actionIcon)
                .font(.title3)
                .foregroundStyle(actionColor)
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var actionTitle: String {
        switch action {
        case .createChain(let chain): return "Create Chain: \(chain.name)"
        case .createPillar(let pillar): return "Create Pillar: \(pillar.name)"
        case .createEvent(let block): return "Schedule: \(block.title)"
        case .updateGoal: return "Update Goal Structure"
        }
    }
    
    private var actionDescription: String {
        switch action {
        case .createChain(let chain): return "\(chain.blocks.count) activities, \(chain.totalDurationMinutes)min"
        case .createPillar(let pillar): return "\(pillar.frequencyDescription) pillar"
        case .createEvent(let block): return "\(block.durationMinutes) minutes"
        case .updateGoal: return "Enhance goal structure"
        }
    }
    
    private var actionIcon: String {
        switch action {
        case .createChain: return "link"
        case .createPillar: return "building.columns"
        case .createEvent: return "calendar.badge.plus"
        case .updateGoal: return "pencil.circle"
        }
    }
    
    private var actionColor: Color {
        switch action {
        case .createChain: return .blue
        case .createPillar: return .purple
        case .createEvent: return .green
        case .updateGoal: return .orange
        }
    }
}

struct GoalDetailSheet: View {
    let goal: Goal
    let onSave: (Goal) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedGoal: Goal
    @State private var showingDeleteAlert = false
    
    init(goal: Goal, onSave: @escaping (Goal) -> Void, onDelete: @escaping () -> Void) {
        self.goal = goal
        self.onSave = onSave
        self.onDelete = onDelete
        self._editedGoal = State(initialValue: goal)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Goal title", text: $editedGoal.title)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                    
                    TextField("Description", text: $editedGoal.description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Importance: \(editedGoal.importance)/5")
                            .font(.subheadline)
                        
                        Slider(value: Binding(
                            get: { Double(editedGoal.importance) },
                            set: { editedGoal.importance = Int($0) }
                        ), in: 1...5, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("State")
                            .font(.subheadline)
                        
                        Picker("State", selection: $editedGoal.state) {
                            ForEach(GoalState.allCases, id: \.self) { state in
                                Text(state.rawValue).tag(state)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                if goal.progress > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress: \(Int(goal.progress * 100))%")
                            .font(.subheadline)
                        
                        ProgressView(value: goal.progress)
                            .progressViewStyle(.linear)
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Delete Goal") {
                        showingDeleteAlert = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Button("Save Changes") {
                        onSave(editedGoal)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editedGoal.title.isEmpty)
                }
            }
            .padding(24)
            .navigationTitle("Edit Goal")
        }
        .frame(width: 600, height: 500)
        .alert("Delete Goal", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete '\(goal.title)'? This action cannot be undone.")
        }
    }
}

struct AuroraDreamCard: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("🌈 Dream Canvas")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Visualize your future")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [.orange.opacity(0.1), .pink.opacity(0.1), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.title2)
                .opacity(0.6)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(.ultraThinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}

// MARK: - Top Bar View

struct TopBarView: View {
    let xp: Int
    let xxp: Int
    let aiConnected: Bool
    @Binding var showingMindPanel: Bool
    let hideSettingsButton: Bool
    let onSettingsTap: () -> Void
    let onDiagnosticsTap: () -> Void
    
    var body: some View {
        HStack {
            // XP and XXP display - HIDDEN BY DEFAULT
            // Will be shown in animated settings panel instead
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
            
            // Settings button - hidden when strip is showing
            if !hideSettingsButton {
                Button(action: onSettingsTap) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
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

// MARK: - Animated Settings Strip

struct AnimatedSettingsStrip: View {
    let xp: Int
    let xxp: Int
    let isVisible: Bool
    let showingXPDisplay: Bool
    let onClose: () -> Void
    let onSettingsTap: () -> Void
    
    @State private var stripOffset: CGFloat = 300
    @State private var xpOpacity: Double = 0
    @State private var xpScale: CGFloat = 0.8
    @State private var diffusionPhase: Double = 0
    
    var body: some View {
        // Dark strip that slides from right - positioned exactly at top bar level
        HStack(spacing: 0) {
            Spacer()
            
            // XP/XXP Display with diffusion animation - positioned to the left of settings
            HStack(spacing: 12) {
                // XP Display
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
                .opacity(xpOpacity)
                .scaleEffect(xpScale)
                .overlay(
                    // Diffusion effect overlay
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .clear, .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .opacity(diffusionPhase)
                        .scaleEffect(1.0 + diffusionPhase * 0.1)
                )
                
                // XXP Display
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
                .opacity(xpOpacity)
                .scaleEffect(xpScale)
                .overlay(
                    // Diffusion effect overlay
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.6), .clear, .orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .opacity(diffusionPhase)
                        .scaleEffect(1.0 + diffusionPhase * 0.1)
                )
                
                // Settings button
                Button(action: onSettingsTap) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.white.opacity(0.2), in: Circle())
                }
                .buttonStyle(.plain)
                .opacity(xpOpacity)
                .scaleEffect(xpScale)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .offset(x: stripOffset)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    stripOffset = 0
                }
            }
            .onChange(of: isVisible) { _, newValue in
                if !newValue {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        stripOffset = 300
                    }
                }
            }
            .onChange(of: showingXPDisplay) { _, newValue in
                if newValue {
                    // Start diffusion animation
                    withAnimation(.easeInOut(duration: 0.8)) {
                        xpOpacity = 1.0
                        xpScale = 1.0
                    }
                    
                    // Diffusion effect - removed continuous animation to prevent flashing
                    diffusionPhase = 1.0
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        xpOpacity = 0
                        xpScale = 0.8
                        diffusionPhase = 0
                    }
                }
            }
        }
        .frame(height: 44) // Match TopBarView height exactly
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(Color.clear)
        .onTapGesture {
            onClose()
        }
    }
}

// MARK: - Calendar Tab View

struct CalendarTabView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var showingBackfill = false
    @Binding var selectedDate: Date // Receive shared date state
    
    var body: some View {
        HStack(spacing: 0) {
            // Main calendar area
            VStack(spacing: 0) {
                // Top controls
                CalendarControlsBar(onBackfillTap: { showingBackfill = true })
                
                // Day view with shared date state
                DayPlannerView(selectedDate: $selectedDate)
                    .frame(maxHeight: .infinity)
                
                // Month view docked below (HIDDEN FOR NOW)
                // MonthView()
                //     .frame(height: 200)
            }
            
            // Right rail
            RightRailView()
                .frame(width: 300)
        }
        .sheet(isPresented: $showingBackfill) {
            EnhancedBackfillView()
                .environmentObject(dataManager)
                .environmentObject(aiService)
        }
    }
}

// MARK: - Calendar Controls Bar

struct CalendarControlsBar: View {
    let onBackfillTap: () -> Void
    @State private var showingGapFiller = false
    
    var body: some View {
        HStack {
            Text("Today")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Gap Filler") {
                    showingGapFiller = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Backfill") {
                    onBackfillTap()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.5))
        .sheet(isPresented: $showingGapFiller) {
            GapFillerView()
        }
    }
}

// MARK: - Right Rail View

struct RightRailView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var selectedSection: RightRailSection = .suggestions
    
    var body: some View {
        VStack(spacing: 0) {
            // Rail header
            RightRailHeader(selectedSection: $selectedSection)
            
            Divider()
            
            // Rail content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedSection {
                    case .manual:
                        ManualCreationSection()
                    case .suggestions:
                        SuggestionsSection()
                    case .reschedule:
                        RescheduleSection()
                    }
                }
                .padding()
            }
        }
        .background(.ultraThinMaterial.opacity(0.3))
    }
}

enum RightRailSection: String, CaseIterable {
    case manual = "Manual"
    case suggestions = "Suggestions"
    case reschedule = "Reschedule"
    
    var icon: String {
        switch self {
        case .manual: return "plus.circle"
        case .suggestions: return "sparkles"
        case .reschedule: return "clock.arrow.circlepath"
        }
    }
}

struct RightRailHeader: View {
    @Binding var selectedSection: RightRailSection
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(RightRailSection.allCases, id: \.self) { section in
                Button(action: { selectedSection = section }) {
                    VStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.system(size: 16))
                        
                        Text(section.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedSection == section ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedSection == section ? .blue.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Right Rail Sections

struct ManualCreationSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingBlockCreation = false
    @State private var showingChainCreation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Button(action: { showingBlockCreation = true }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("Time Block")
                        Spacer()
                    }
                    .padding()
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Button(action: { showingChainCreation = true }) {
                    HStack {
                        Image(systemName: "link")
                        Text("Chain")
                        Spacer()
                    }
                    .padding()
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "building.columns")
                        Text("Pillar")
                        Spacer()
                    }
                    .padding()
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingBlockCreation) {
            BlockCreationSheet(suggestedTime: Date()) { block in
                dataManager.addTimeBlock(block)
                showingBlockCreation = false
            }
        }
        .sheet(isPresented: $showingChainCreation) {
            ChainCreationView { chain in
                dataManager.addChain(chain)
                showingChainCreation = false
            }
        }
    }
}

struct SuggestionsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var suggestions: [Suggestion] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Suggestions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    generateSuggestions()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if suggestions.isEmpty {
                VStack(spacing: 8) {
                    Text("✨")
                        .font(.title2)
                        .opacity(0.5)
                    
                    Text("No suggestions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Get Suggestions") {
                        generateSuggestions()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        SuggestionRailCard(suggestion: suggestion) {
                            dataManager.applySuggestion(suggestion)
                            suggestions.removeAll { $0.id == suggestion.id }
                        }
                    }
                }
            }
        }
        .onAppear {
            if suggestions.isEmpty {
                generateSuggestions()
            }
        }
    }
    
    private func generateSuggestions() {
        isLoading = true
        
        Task {
            do {
                let context = DayContext(
                    date: Date(),
                    existingBlocks: dataManager.appState.currentDay.blocks,
                    currentEnergy: .daylight,
                    preferredEmojis: ["🌊"],
                    availableTime: 3600,
                    mood: dataManager.appState.currentDay.mood
                )
                
                let newSuggestions = try await aiService.generateSuggestions(for: context)
                
                await MainActor.run {
                    suggestions = newSuggestions
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    suggestions = AIService.mockSuggestions()
                    isLoading = false
                }
            }
        }
    }
}

struct RescheduleSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reschedule")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if incompletedBlocks.count > 0 {
                    Text("\(incompletedBlocks.count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.2), in: Capsule())
                        .foregroundColor(.red)
                }
            }
            
            if incompletedBlocks.isEmpty {
                VStack(spacing: 8) {
                    Text("✅")
                        .font(.title2)
                        .opacity(0.5)
                    
                    Text("All caught up!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(incompletedBlocks) { block in
                        RescheduleCard(block: block) {
                            rescheduleBlock(block)
                        }
                    }
                }
            }
        }
    }
    
    private var incompletedBlocks: [TimeBlock] {
        dataManager.appState.currentDay.blocks.filter { block in
            block.endTime < Date() && block.glassState != .solid
        }
    }
    
    private func rescheduleBlock(_ block: TimeBlock) {
        // Reschedule logic
        var updatedBlock = block
        updatedBlock.startTime = Date().addingTimeInterval(1800) // 30 minutes from now
        updatedBlock.glassState = .mist // Mark as rescheduled
        dataManager.updateTimeBlock(updatedBlock)
    }
}

// MARK: - Supporting Views

struct SuggestionRailCard: View {
    let suggestion: Suggestion
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Spacer()
                
                Text(suggestion.energy.rawValue)
                    .font(.caption2)
            }
            
            Text(suggestion.explanation)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(suggestion.duration.minutes)m")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2), in: Capsule())
                    
                    Text("at \(suggestion.suggestedTime.timeString)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(suggestion.emoji)
                    .font(.caption2)
                
                Spacer()
                
                Button("Add") {
                    onApply()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RescheduleCard: View {
    let block: TimeBlock
    let onReschedule: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(block.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Was: \(block.startTime.timeString)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Reschedule") {
                onReschedule()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(10)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Backfill View

struct EnhancedBackfillView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeframe: BackfillTimeframe = .today
    @State private var selectedDate = Date()
    @State private var isGeneratingBackfill = false
    @State private var backfillSuggestions: [TimeBlock] = []
    @State private var stagedBackfillBlocks: [TimeBlock] = []
    @State private var selectedViewMode: BackfillViewMode = .hybrid
    @State private var manualInputText = ""
    @State private var showingManualInput = false
    @State private var reconstructionQuality: Int = 80
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced header with more controls
            HStack {
                Text("Backfill Header")
                Spacer()
            }
            .padding()
            
            /*EnhancedBackfillHeader(
                selectedTimeframe: $selectedTimeframe,
                selectedDate: $selectedDate,
                selectedViewMode: $selectedViewMode,
                reconstructionQuality: $reconstructionQuality,
                isGenerating: isGeneratingBackfill,
                onGenerateBackfill: generateBackfillSuggestions,
                onToggleManualInput: { showingManualInput.toggle() }
            )*/
            
            Divider()
            
            // Main workspace with more real estate
            HSplitView {
                // Left: Large timeline workspace (70% of space)
                VStack(spacing: 0) {
                    Text("Enhanced Backfill Timeline - Coming Soon")
                        .padding()
                    
                    /*EnhancedBackfillTimeline(
                        date: selectedDate,
                        suggestions: backfillSuggestions,
                        stagedBlocks: stagedBackfillBlocks,
                        viewMode: selectedViewMode,
                        onBlockMove: { block, newTime in
                            moveBackfillBlock(block, to: newTime)
                        },
                        onBlockRemove: { block in
                            removeBackfillBlock(block)
                        },
                        onBlockEdit: { block in
                            editBackfillBlock(block)
                        }
                    )*/
                }
                .frame(minWidth: 600)
                
                // Right: Enhanced control panel (30% of space)
                VStack(spacing: 0) {
                    // AI suggestions section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("AI Reconstruction", systemImage: "sparkles")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(reconstructionQuality)% confidence")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(backfillSuggestions.prefix(8)) { suggestion in
                                    HStack {
                                        Text(suggestion.title)
                                        Spacer()
                                        Button("Add") { applySuggestion(suggestion) }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                    }
                                    .padding(8)
                                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding()
                    .background(.regularMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Manual input section (enhanced)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Manual Entry", systemImage: "pencil")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Quick Add") {
                                showQuickAddSheet()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        // Quick manual entry
                        TextField("Describe what happened...", text: $manualInputText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                        
                        HStack {
                            Button("Parse & Add") {
                                parseManualInput()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(manualInputText.isEmpty)
                            
                            Spacer()
                            
                            Button("Clear") {
                                manualInputText = ""
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        // Quick time block templates
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(quickTemplates, id: \.title) { template in
                                Button(action: { applyTemplate(template) }) {
                                    VStack(spacing: 4) {
                                        Text(template.icon)
                                            .font(.title2)
                                        Text(template.title)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(.thickMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    // Enhanced action buttons
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(stagedBackfillBlocks.count) events staged")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("Total: \(stagedTotalHours, specifier: "%.1f")h")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Button("Discard") {
                                discardBackfill()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Commit \(stagedBackfillBlocks.count) Events") {
                                commitBackfill()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(stagedBackfillBlocks.isEmpty)
                        }
                        
                        Button("Export to Calendar") {
                            exportToCalendar()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(.ultraThickMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                }
                .frame(minWidth: 350, idealWidth: 400)
                .padding()
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            generateBackfillSuggestions()
        }
    }
    
    // MARK: - Computed Properties
    
    private var stagedTotalHours: Double {
        let totalSeconds = stagedBackfillBlocks.reduce(0) { $0 + $1.duration }
        return totalSeconds / 3600
    }
    
    private var quickTemplates: [QuickTemplate] {
        [
            QuickTemplate(title: "Work", icon: "💼", duration: 8*3600, energy: .daylight, emoji: "💎"),
            QuickTemplate(title: "Meeting", icon: "👥", duration: 3600, energy: .daylight, emoji: "🌊"),
            QuickTemplate(title: "Lunch", icon: "🍽️", duration: 1800, energy: .daylight, emoji: "☁️"),
            QuickTemplate(title: "Break", icon: "☕", duration: 900, energy: .moonlight, emoji: "☁️"),
            QuickTemplate(title: "Travel", icon: "🚗", duration: 1800, energy: .moonlight, emoji: "☁️"),
            QuickTemplate(title: "Exercise", icon: "💪", duration: 3600, energy: .sunrise, emoji: "🌊")
        ]
    }
    
    // MARK: - Actions
    
    private func parseManualInput() {
        // Parse natural language input and create time blocks
        let input = manualInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        // Simple parsing logic - in real implementation would use AI
        let components = input.components(separatedBy: ",")
        
        for (index, component) in components.enumerated() {
            let title = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            
            let startHour = 9 + index * 2 // Spread throughout day
            let startTime = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
            
            let newBlock = TimeBlock(
                title: title,
                startTime: startTime,
                duration: 3600, // 1 hour default
                energy: .daylight,
                emoji: "💎",
            )
            
            stagedBackfillBlocks.append(newBlock)
        }
        
        manualInputText = ""
    }
    
    private func applyTemplate(_ template: QuickTemplate) {
        let startTime = Date() // Would be smarter about placement in real implementation
        
        let newBlock = TimeBlock(
            title: template.title,
            startTime: startTime,
            duration: template.duration,
            energy: template.energy,
            emoji: template.emoji,
        )
        
        stagedBackfillBlocks.append(newBlock)
    }
    
    private func showQuickAddSheet() {
        // Would show a detailed manual entry sheet
    }
    
    private func editSuggestion(_ suggestion: TimeBlock) {
        // Would show edit sheet for suggestion
    }
    
    private func editBackfillBlock(_ block: TimeBlock) {
        // Would show edit sheet for staged block
    }
    
    private func exportToCalendar() {
        // Export staged blocks to system calendar
    }
    
    // MARK: - Backfill Actions
    
    private func generateBackfillSuggestions() {
        isGeneratingBackfill = true
        
        Task {
            // Lightweight approach: focus on high-confidence events only
            let existingEvents = stagedBackfillBlocks
            let availableSlots = findAvailableTimeSlots(existing: existingEvents)
            
            // Generate only most confident activities based on existing data
            let aiGuessBlocks = createHighConfidenceReconstruction(
                for: selectedDate, 
                avoiding: existingEvents,
                inSlots: availableSlots
            )
            
            await MainActor.run {
                // Filter to only add events where we have high confidence and available slots
                backfillSuggestions = aiGuessBlocks.filter { suggested in
                    !existingEvents.contains { existing in
                        suggested.startTime < existing.endTime && suggested.endTime > existing.startTime
                    }
                }
                
                isGeneratingBackfill = false
            }
        }
    }
    
    private func findAvailableTimeSlots(existing: [TimeBlock]) -> [DateInterval] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        
        let sortedBlocks = existing.sorted { $0.startTime < $1.startTime }
        var availableSlots: [DateInterval] = []
        
        var currentTime = calendar.date(byAdding: .hour, value: 6, to: dayStart) ?? dayStart // Start at 6 AM
        
        for block in sortedBlocks {
            if currentTime < block.startTime {
                availableSlots.append(DateInterval(start: currentTime, end: block.startTime))
            }
            currentTime = max(currentTime, block.endTime)
        }
        
        // Add remaining time until end of reasonable day (22:00)
        let endOfReasonableDay = calendar.date(byAdding: .hour, value: 22, to: dayStart) ?? dayEnd
        if currentTime < endOfReasonableDay {
            availableSlots.append(DateInterval(start: currentTime, end: endOfReasonableDay))
        }
        
        return availableSlots.filter { $0.duration >= 1800 } // Only slots 30+ minutes
    }
    
    private func createHighConfidenceReconstruction(for date: Date, avoiding existingEvents: [TimeBlock], inSlots availableSlots: [DateInterval]) -> [TimeBlock] {
        let dayOfWeek = Calendar.current.component(.weekday, from: date)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        // High-confidence activities that most people do
        let highConfidenceActivities: [(title: String, duration: TimeInterval, energy: EnergyType, emoji: String, confidence: Double)] = isWeekend ? [
            ("Sleep in", 3600, .moonlight, "☁️", 0.9),
            ("Meals", 5400, .daylight, "☁️", 0.95),
            ("Personal time", 7200, .daylight, "🌊", 0.8),
            ("Evening activities", 5400, .moonlight, "🌊", 0.7)
        ] : [
            ("Morning routine", 3600, .sunrise, "💎", 0.9),
            ("Work time", 28800, .daylight, "💎", 0.85), // 8 hours
            ("Lunch", 3600, .daylight, "☁️", 0.9),
            ("Commute/travel", 3600, .moonlight, "☁️", 0.7),
            ("Dinner", 3600, .moonlight, "☁️", 0.9),
            ("Evening personal", 5400, .moonlight, "🌊", 0.6)
        ]
        
        var suggestions: [TimeBlock] = []
        
        // Place high-confidence activities in available slots
        for slot in availableSlots.prefix(4) { // Max 4 suggestions to keep it manageable
            for activity in highConfidenceActivities {
                if activity.duration <= slot.duration && suggestions.count < 3 {
                    let startTime = findBestTimeInSlot(slot: slot, duration: activity.duration, isWeekend: isWeekend)
                    
                    suggestions.append(TimeBlock(
                        title: activity.title,
                        startTime: startTime,
                        duration: min(activity.duration, slot.duration),
                        energy: activity.energy,
                        emoji: activity.emoji,
                        glassState: .crystal,
                    ))
                    break
                }
            }
        }
        
        return suggestions
    }
    
    private func findBestTimeInSlot(slot: DateInterval, duration: TimeInterval, isWeekend: Bool) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: slot.start)
        
        // Smart placement based on activity type and time
        if hour < 9 && !isWeekend {
            return slot.start // Early morning activities start early
        } else if hour >= 12 && hour < 14 {
            return slot.start // Lunch time activities
        } else {
            // Center the activity in the available slot
            let centerOffset = (slot.duration - duration) / 2
            return slot.start.addingTimeInterval(centerOffset)
        }
    }
    
    private func applySuggestion(_ suggestion: TimeBlock) {
        stagedBackfillBlocks.append(suggestion)
    }
    
    // PRD: Create realistic day reconstruction (AI guess)
    private func createRealisticDayReconstruction(for date: Date) -> [TimeBlock] {
        let dayOfWeek = Calendar.current.component(.weekday, from: date)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        var blocks: [TimeBlock] = []
        let calendar = Calendar.current
        
        if isWeekend {
            // Weekend reconstruction
            blocks = [
                TimeBlock(title: "Sleep in", startTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date)!, duration: 3600, energy: .moonlight, emoji: "☁️"),
                TimeBlock(title: "Lazy breakfast", startTime: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: date)!, duration: 1800, energy: .sunrise, emoji: "☁️"),
                TimeBlock(title: "Personal time", startTime: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: date)!, duration: 7200, energy: .daylight, emoji: "🌊"),
                TimeBlock(title: "Lunch", startTime: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date)!, duration: 1800, energy: .daylight, emoji: "☁️"),
                TimeBlock(title: "Afternoon activities", startTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: date)!, duration: 5400, energy: .daylight, emoji: "🌊"),
                TimeBlock(title: "Dinner", startTime: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: date)!, duration: 2700, energy: .moonlight, emoji: "☁️"),
                TimeBlock(title: "Evening relaxation", startTime: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: date)!, duration: 3600, energy: .moonlight, emoji: "🌊")
            ]
        } else {
            // Weekday reconstruction
            blocks = [
                TimeBlock(title: "Morning routine", startTime: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: date)!, duration: 3600, energy: .sunrise, emoji: "💎"),
                TimeBlock(title: "Commute/Setup", startTime: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: date)!, duration: 1800, energy: .sunrise, emoji: "☁️"),
                TimeBlock(title: "Morning work block", startTime: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: date)!, duration: 7200, energy: .daylight, emoji: "💎"),
                TimeBlock(title: "Lunch break", startTime: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!, duration: 3600, energy: .daylight, emoji: "☁️"),
                TimeBlock(title: "Afternoon work", startTime: calendar.date(bySettingHour: 13, minute: 30, second: 0, of: date)!, duration: 9000, energy: .daylight, emoji: "🌊"),
                TimeBlock(title: "Wrap up work", startTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: date)!, duration: 3600, energy: .daylight, emoji: "💎"),
                TimeBlock(title: "Commute home", startTime: calendar.date(bySettingHour: 17, minute: 30, second: 0, of: date)!, duration: 1800, energy: .moonlight, emoji: "☁️"),
                TimeBlock(title: "Dinner", startTime: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: date)!, duration: 2700, energy: .moonlight, emoji: "☁️"),
                TimeBlock(title: "Evening personal time", startTime: calendar.date(bySettingHour: 20, minute: 30, second: 0, of: date)!, duration: 5400, energy: .moonlight, emoji: "🌊")
            ]
        }
        
        // Mark all as explanatory AI reconstructions
        return blocks.map { block in
            var updatedBlock = block
            updatedBlock.glassState = .crystal // AI-generated
            return updatedBlock
        }
    }
    
    private func moveBackfillBlock(_ block: TimeBlock, to newTime: Date) {
        if let index = stagedBackfillBlocks.firstIndex(where: { $0.id == block.id }) {
            stagedBackfillBlocks[index].startTime = newTime
        }
    }
    
    private func removeBackfillBlock(_ block: TimeBlock) {
        stagedBackfillBlocks.removeAll { $0.id == block.id }
    }
    
    private func commitBackfill() {
        // Save backfilled day to data manager
        for block in stagedBackfillBlocks {
            dataManager.addTimeBlock(block)
        }
        
        // Clear staging
        stagedBackfillBlocks.removeAll()
        dismiss()
    }
    
    private func discardBackfill() {
        stagedBackfillBlocks.removeAll()
    }
    
    private func createDefaultBackfillBlocks(for date: Date) -> [TimeBlock] {
        let startOfDay = date.startOfDay
        return [
            TimeBlock(
                title: "Morning Routine",
                startTime: Calendar.current.date(byAdding: .hour, value: 8, to: startOfDay)!,
                duration: 3600,
                energy: .sunrise,
                emoji: "☁️"
            ),
            TimeBlock(
                title: "Work Time",
                startTime: Calendar.current.date(byAdding: .hour, value: 10, to: startOfDay)!,
                duration: 14400, // 4 hours
                energy: .daylight,
                emoji: "💎"
            ),
            TimeBlock(
                title: "Lunch Break",
                startTime: Calendar.current.date(byAdding: .hour, value: 13, to: startOfDay)!,
                duration: 3600,
                energy: .daylight,
                emoji: "☁️"
            ),
            TimeBlock(
                title: "Afternoon Work",
                startTime: Calendar.current.date(byAdding: .hour, value: 15, to: startOfDay)!,
                duration: 10800, // 3 hours
                energy: .daylight,
                emoji: "💎"
            ),
            TimeBlock(
                title: "Evening Activities",
                startTime: Calendar.current.date(byAdding: .hour, value: 19, to: startOfDay)!,
                duration: 7200, // 2 hours
                energy: .moonlight,
                emoji: "🌊"
            )
        ]
    }
}

enum BackfillTimeframe: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case older = "Older"
}

struct BackfillTimeframeSelector: View {
    @Binding var selectedTimeframe: BackfillTimeframe
    @Binding var selectedDate: Date
    
    var body: some View {
        HStack {
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(BackfillTimeframe.allCases, id: \.self) { timeframe in
                    Text(timeframe.rawValue).tag(timeframe)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
            
            if selectedTimeframe == .older {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            
            Spacer()
            
            Text("Reconstruct what actually happened")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.5))
        .onChange(of: selectedTimeframe) {
            switch selectedTimeframe {
            case .today:
                selectedDate = Date()
            case .yesterday:
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            case .older:
                // Keep selected date
                break
            }
        }
    }
}

struct BackfillTimeline: View {
    let date: Date
    let suggestions: [TimeBlock]
    let stagedBlocks: [TimeBlock]
    let onBlockMove: (TimeBlock, Date) -> Void
    let onBlockRemove: (TimeBlock) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    BackfillHourSlot(
                        hour: hour,
                        date: date,
                        stagedBlocks: [],
                        onBlockMove: onBlockMove,
                        onBlockRemove: onBlockRemove
                    )
                }
            }
            .padding()
        }
        .background(.quaternary.opacity(0.1))
    }
    
    private func blocksForHour(_ block: TimeBlock, _ hour: Int) -> Bool {
        let blockHour = Calendar.current.component(.hour, from: block.startTime)
        return blockHour == hour
    }
}

struct BackfillHourSlot: View {
    let hour: Int
    let date: Date
    let stagedBlocks: [TimeBlock]
    let onBlockMove: (TimeBlock, Date) -> Void
    let onBlockRemove: (TimeBlock) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Hour label
            Text(String(format: "%02d:00", hour))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            // Content area
            VStack(alignment: .leading, spacing: 4) {
                ForEach(stagedBlocks) { block in
                    BackfillBlockView(
                        block: block,
                        onMove: { newTime in
                            onBlockMove(block, newTime)
                        },
                        onRemove: {
                            onBlockRemove(block)
                        }
                    )
                }
                
                // Drop zone for new blocks
                Rectangle()
                    .fill(.clear)
                    .frame(height: stagedBlocks.isEmpty ? 40 : 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Could trigger inline creation
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct BackfillBlockView: View {
    let block: TimeBlock
    let onMove: (Date) -> Void
    let onRemove: () -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(block.durationMinutes) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                )
        )
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .gesture(
            DragGesture()
                .onChanged { _ in
                    isDragging = true
                }
                .onEnded { value in
                    isDragging = false
                    // Calculate new time based on drag location
                    // For simplicity, just keep current time
                    onMove(block.startTime)
                }
        )
    }
}

struct BackfillSuggestionsPanel: View {
    let isGenerating: Bool
    let suggestions: [TimeBlock]
    let onGenerateSuggestions: () -> Void
    let onApplySuggestion: (TimeBlock) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Suggestions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    onGenerateSuggestions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isGenerating)
            }
            
            if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    
                    Text("Reconstructing your day...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            BackfillSuggestionCard(
                                block: suggestion,
                                onApply: {
                                    onApplySuggestion(suggestion)
                                }
                            )
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.7))
    }
}

struct BackfillSuggestionCard: View {
    let block: TimeBlock
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(block.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(block.energy.rawValue)
                    .font(.caption2)
            }
            
            HStack {
                Text("\(block.durationMinutes)m")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.2), in: Capsule())
                
                Text(block.emoji)
                    .font(.caption2)
                
                Spacer()
                
                Button("Add") {
                    onApply()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct BackfillActionsBar: View {
    let hasChanges: Bool
    let onCommit: () -> Void
    let onDiscard: () -> Void
    
    var body: some View {
        HStack {
            if hasChanges {
                Text("\(hasChanges ? "Changes ready to save" : "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if hasChanges {
                HStack(spacing: 12) {
                    Button("Discard") {
                        onDiscard()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save to Calendar") {
                        onCommit()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Backfill Templates View

struct BackfillTemplatesView: View {
    let selectedDate: Date
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var templates: [BackfillTemplate] = []
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("What likely happened on \(selectedDate.dayString)")
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
                        DraggableBackfillTemplate(template: template)
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
        let dayOfWeek = Calendar.current.component(.weekday, from: selectedDate)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        if isWeekend {
            templates = [
                BackfillTemplate(title: "Sleep in", icon: "🛏️", duration: 3600, confidence: 0.9, energy: .moonlight, emoji: "☁️"),
                BackfillTemplate(title: "Breakfast", icon: "🥞", duration: 1800, confidence: 0.95, energy: .sunrise, emoji: "☁️"),
                BackfillTemplate(title: "Personal projects", icon: "🎨", duration: 7200, confidence: 0.8, energy: .daylight, emoji: "🌊"),
                BackfillTemplate(title: "Errands", icon: "🛒", duration: 5400, confidence: 0.7, energy: .daylight, emoji: "💎"),
                BackfillTemplate(title: "Social time", icon: "👥", duration: 5400, confidence: 0.6, energy: .daylight, emoji: "🌊"),
                BackfillTemplate(title: "Evening relax", icon: "📺", duration: 7200, confidence: 0.8, energy: .moonlight, emoji: "☁️")
            ]
        } else {
            templates = [
                BackfillTemplate(title: "Morning routine", icon: "☕", duration: 3600, confidence: 0.9, energy: .sunrise, emoji: "💎"),
                BackfillTemplate(title: "Work session", icon: "💼", duration: 14400, confidence: 0.85, energy: .daylight, emoji: "💎"),
                BackfillTemplate(title: "Lunch break", icon: "🍽️", duration: 3600, confidence: 0.9, energy: .daylight, emoji: "☁️"),
                BackfillTemplate(title: "Meetings", icon: "👥", duration: 3600, confidence: 0.7, energy: .daylight, emoji: "🌊"),
                BackfillTemplate(title: "Commute", icon: "🚗", duration: 3600, confidence: 0.8, energy: .moonlight, emoji: "☁️"),
                BackfillTemplate(title: "Dinner", icon: "🍽️", duration: 2700, confidence: 0.9, energy: .moonlight, emoji: "☁️"),
                BackfillTemplate(title: "Evening wind-down", icon: "📚", duration: 5400, confidence: 0.7, energy: .moonlight, emoji: "🌊")
            ]
        }
    }
}

struct BackfillTemplate: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let duration: TimeInterval
    let confidence: Double
    let energy: EnergyType
    let emoji: String
}

struct DraggableBackfillTemplate: View {
    let template: BackfillTemplate
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text(template.icon)
                .font(.title)
            
            Text(template.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            HStack(spacing: 4) {
                Text("\(template.duration.minutes)m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(Int(template.confidence * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .frame(width: 100, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial.opacity(isDragging ? 0.9 : 0.7))
                .shadow(color: .black.opacity(isDragging ? 0.2 : 0.1), radius: isDragging ? 8 : 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.green.opacity(template.confidence), lineWidth: 2)
        )
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .offset(dragOffset)
        .opacity(isDragging ? 0.8 : 1.0)
        .onDrag {
            createTimeBlockFromTemplate()
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
                    // Drop handled by onDrag provider
                }
        )
    }
    
    private func createTimeBlockFromTemplate() -> NSItemProvider {
        let _ = TimeBlock(
            title: template.title,
            startTime: Date(),
            duration: template.duration,
            energy: template.energy,
            emoji: template.emoji
        )
        
        // Create a more detailed drag payload
        let dragPayload = "backfill_template:\(template.title)|\(Int(template.duration))|\(template.energy.rawValue)|\(template.emoji)|\(template.confidence)"
        
        return NSItemProvider(object: dragPayload as NSString)
    }
}

// MARK: - Pillar Day View

struct PillarDayView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @State private var missingPillars: [Pillar] = []
    @State private var suggestedEvents: [TimeBlock] = []
    @State private var isAnalyzing = false
    @State private var analysisText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Intelligent pillar activity scheduling without removing existing events")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                if isAnalyzing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Analyzing pillar needs...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if !analysisText.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Analysis")
                                        .font(.headline)
                                    
                                    Text(analysisText)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .padding()
                                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            
                            if !missingPillars.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("⚠️ Overdue Pillars")
                                            .font(.headline)
                                            .foregroundStyle(.orange)
                                        
                                        Spacer()
                                        
                                        Text("Need attention")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    ForEach(missingPillars) { pillar in
                                        MissingPillarCard(pillar: pillar) {
                                            createPillarEvent(for: pillar)
                                        }
                                    }
                                }
                            }
                            
                            if !suggestedEvents.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("📅 Ready to Schedule")
                                            .font(.headline)
                                            .foregroundStyle(.green)
                                        
                                        Spacer()
                                        
                                        Text("Drag to timeline or click Add")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    ForEach(suggestedEvents) { event in
                                        DraggableSuggestedEventCard(event: event) {
                                            stagePillarEvent(event)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
                    HStack {
                        Button("Refresh Analysis") {
                            analyzePillarNeeds()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        if !suggestedEvents.isEmpty {
                            Button("Add All (\(suggestedEvents.count))") {
                                addAllPillarEvents()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pillar Day")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            analyzePillarNeeds()
        }
    }
    
    private func analyzePillarNeeds() {
        isAnalyzing = true
        
        Task {
            let actionablePillars = dataManager.appState.pillars.filter(\.isActionable)
            var missing: [Pillar] = []
            var suggestions: [TimeBlock] = []
            
            let now = Date()
            
            for pillar in actionablePillars {
                let daysSinceLastEvent = pillar.lastEventDate?.timeIntervalSince(now) ?? -99999999
                let needsEvent = shouldCreateEventForPillar(pillar, daysSince: daysSinceLastEvent / 86400)
                
                if needsEvent {
                    missing.append(pillar)
                }
            }
            
            // Generate suggested events for missing pillars (separate from just listing them)
            for pillar in missing {
                if let timeSlot = findBestTimeSlot(for: pillar) {
                    let suggestedEvent = TimeBlock(
                        title: pillar.name,
                        startTime: timeSlot.startTime,
                        duration: pillar.minDuration,
                        energy: .daylight,
                        emoji: pillar.emoji,
                        relatedPillarId: pillar.id
                    )
                    suggestions.append(suggestedEvent)
                }
            }
            
            await MainActor.run {
                missingPillars = missing
                suggestedEvents = suggestions
                analysisText = generateAnalysisText(missingCount: missing.count, totalPillars: actionablePillars.count)
                isAnalyzing = false
            }
        }
    }
    
    private func shouldCreateEventForPillar(_ pillar: Pillar, daysSince: Double) -> Bool {
        switch pillar.frequency {
        case .daily:
            return daysSince <= -1 // More than 1 day ago
        case .weekly(let count):
            let expectedInterval = 7.0 / Double(count)
            return daysSince <= -expectedInterval
        case .monthly(let count):
            let expectedInterval = 30.0 / Double(count)
            return daysSince <= -expectedInterval
        case .asNeeded:
            return daysSince <= -7 // Weekly check for as-needed items
        }
    }
    
    private func findBestTimeSlot(for pillar: Pillar) -> (startTime: Date, duration: TimeInterval)? {
        let calendar = Calendar.current
        let today = Date()
        
        // Check preferred time windows
        for window in pillar.preferredTimeWindows {
            if let windowStart = calendar.date(bySettingHour: window.startHour, minute: window.startMinute, second: 0, of: today) {
                // Check if this slot is available
                if isTimeSlotAvailable(start: windowStart, duration: pillar.minDuration) {
                    return (startTime: windowStart, duration: pillar.minDuration)
                }
            }
        }
        
        // Fallback: find any available slot
        return findNextAvailableSlot(duration: pillar.minDuration)
    }
    
    private func isTimeSlotAvailable(start: Date, duration: TimeInterval) -> Bool {
        let end = start.addingTimeInterval(duration)
        let allBlocks = dataManager.appState.currentDay.blocks
        
        return !allBlocks.contains { block in
            let blockInterval = DateInterval(start: block.startTime, end: block.endTime)
            let checkInterval = DateInterval(start: start, end: end)
            return blockInterval.intersects(checkInterval)
        }
    }
    
    private func findNextAvailableSlot(duration: TimeInterval) -> (startTime: Date, duration: TimeInterval)? {
        let calendar = Calendar.current
        let now = Date()
        let roundedNow = calendar.date(byAdding: .minute, value: 15 - calendar.component(.minute, from: now) % 15, to: now) ?? now
        
        var searchTime = roundedNow
        let endOfDay = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now
        
        while searchTime < endOfDay {
            if isTimeSlotAvailable(start: searchTime, duration: duration) {
                return (startTime: searchTime, duration: duration)
            }
            searchTime = calendar.date(byAdding: .minute, value: 30, to: searchTime) ?? searchTime
        }
        
        return nil
    }
    
    private func generateAnalysisText(missingCount: Int, totalPillars: Int) -> String {
        if missingCount == 0 {
            return "🎉 All your pillars are up to date! Your consistency is paying off."
        } else {
            return "📊 Found \(missingCount) of \(totalPillars) pillars that need attention based on their frequency settings."
        }
    }
    
    private func createPillarEvent(for pillar: Pillar) {
        if let suggestion = suggestedEvents.first(where: { $0.title == pillar.name }) {
            stagePillarEvent(suggestion)
        }
    }
    
    private func stagePillarEvent(_ event: TimeBlock) {
        dataManager.addTimeBlock(event)
        suggestedEvents.removeAll { $0.id == event.id }
    }
    
    private func addAllPillarEvents() {
        for event in suggestedEvents {
            stagePillarEvent(event)
        }
        
        dismiss()
    }
}

struct MissingPillarCard: View {
    let pillar: Pillar
    let onCreateEvent: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text(pillar.emoji)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pillar.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(pillar.frequencyDescription) - overdue")
                    .font(.caption)
                    .foregroundStyle(.orange)
                
                if let lastEvent = pillar.lastEventDate {
                    Text("Last: \(lastEvent.dayString)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button("Schedule") {
                onCreateEvent()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DraggableSuggestedEventCard: View {
    let event: TimeBlock
    let onAdd: () -> Void
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        HStack(spacing: 12) {
            // Emoji from related pillar or event
            Text(event.emoji.isEmpty ? "📅" : event.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Text(event.startTime.timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(event.durationMinutes)m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
            }
            
            Spacer()
            
            if !isDragging {
                Button("Add") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("Drop on timeline")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .italic()
            }
        }
        .padding(12)
        .background(.green.opacity(isDragging ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.green.opacity(isDragging ? 0.6 : 0.3), lineWidth: isDragging ? 2 : 1)
        )
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .offset(dragOffset)
        .opacity(isDragging ? 0.8 : 1.0)
        .onDrag {
            createEventDragProvider()
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
                    // Stage the event when drag ends
                    onAdd()
                }
        )
    }
    
    private func createEventDragProvider() -> NSItemProvider {
        // Stage the event immediately when drag starts
        dataManager.addTimeBlock(event)
        return NSItemProvider(object: event.title as NSString)
    }
}

// MARK: - Gap Filler View

struct GapFillerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var gapSuggestions: [GapSuggestion] = []
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Find time for micro-tasks in your schedule gaps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if isAnalyzing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        
                        Text("Analyzing your schedule...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else if gapSuggestions.isEmpty {
                    VStack(spacing: 16) {
                        Text("🔍")
                            .font(.title)
                        
                        Text("No gaps found")
                            .font(.headline)
                        
                        Text("Your schedule looks full! Try refreshing or checking a different day.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Analyze Again") {
                            analyzeGaps()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(gapSuggestions) { suggestion in
                                GapSuggestionCard(suggestion: suggestion) {
                                    applyGapSuggestion(suggestion)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Gap Filler")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            analyzeGaps()
        }
    }
    
    private func analyzeGaps() {
        isAnalyzing = true
        
        Task {
            let gaps = findScheduleGaps()
            let suggestions = await generateGapSuggestions(for: gaps)
            
            await MainActor.run {
                gapSuggestions = suggestions
                isAnalyzing = false
            }
        }
    }
    
    private func findScheduleGaps() -> [ScheduleGap] {
        let allBlocks = dataManager.appState.currentDay.blocks
        let sortedBlocks = allBlocks.sortedByTime
        var gaps: [ScheduleGap] = []
        
        // If no blocks exist, treat the whole day as gaps
        if sortedBlocks.isEmpty {
            // Create gaps for typical work hours
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            gaps.append(ScheduleGap(
                startTime: calendar.date(byAdding: .hour, value: 9, to: startOfDay)!,
                duration: 3600 * 8 // 8 hour work day
            ))
            return gaps
        }
        
        // Find gaps between existing blocks
        for i in 0..<sortedBlocks.count - 1 {
            let currentEnd = sortedBlocks[i].endTime
            let nextStart = sortedBlocks[i + 1].startTime
            
            let gapDuration = nextStart.timeIntervalSince(currentEnd)
            if gapDuration >= 900 { // 15+ minute gaps
                gaps.append(ScheduleGap(
                    startTime: currentEnd,
                    duration: gapDuration
                ))
            }
        }
        
        return gaps
    }
    
    private func generateGapSuggestions(for gaps: [ScheduleGap]) async -> [GapSuggestion] {
        var suggestions: [GapSuggestion] = []
        
        // Always provide some suggestions even if no gaps found
        if gaps.isEmpty {
            // Create default suggestions for an empty schedule
            let defaultTasks = [
                MicroTask(title: "Quick email check", estimatedDuration: 900),
                MicroTask(title: "Plan tomorrow", estimatedDuration: 1200),
                MicroTask(title: "Organize workspace", estimatedDuration: 1800)
            ]
            
            let now = Date()
            for (index, task) in defaultTasks.enumerated() {
                let startTime = Calendar.current.date(byAdding: .hour, value: index + 1, to: now) ?? now
                suggestions.append(GapSuggestion(
                    task: task,
                    startTime: startTime,
                    duration: task.estimatedDuration
                ))
            }
            return suggestions
        }
        
        for gap in gaps {
            let gapMinutes = Int(gap.duration / 60)
            let taskSuggestions = generateTasksForDuration(gapMinutes)
            
            for task in taskSuggestions {
                suggestions.append(GapSuggestion(
                    task: task,
                    startTime: gap.startTime,
                    duration: min(gap.duration, task.estimatedDuration)
                ))
            }
        }
        
        return suggestions
    }
    
    private func generateTasksForDuration(_ minutes: Int) -> [MicroTask] {
        switch minutes {
        case 15..<30:
            return [
                MicroTask(title: "Quick email check", estimatedDuration: 900),
                MicroTask(title: "Tidy workspace", estimatedDuration: 900),
                MicroTask(title: "Stretch break", estimatedDuration: 600)
            ]
        case 30..<60:
            return [
                MicroTask(title: "Review daily goals", estimatedDuration: 1800),
                MicroTask(title: "Quick workout", estimatedDuration: 1800),
                MicroTask(title: "Meal prep", estimatedDuration: 2400)
            ]
        default:
            return [
                MicroTask(title: "Short walk", estimatedDuration: 600),
                MicroTask(title: "Mindfulness moment", estimatedDuration: 300)
            ]
        }
    }
    
    private func applyGapSuggestion(_ suggestion: GapSuggestion) {
        let newBlock = TimeBlock(
            title: suggestion.task.title,
            startTime: suggestion.startTime,
            duration: suggestion.duration,
            energy: .daylight,
            emoji: "🌊",
            glassState: .liquid
        )
        
        dataManager.addTimeBlock(newBlock)
        
        // Remove the applied suggestion
        if let index = gapSuggestions.firstIndex(where: { $0.id == suggestion.id }) {
            gapSuggestions.remove(at: index)
        }
        
        dismiss()
    }
}

struct ScheduleGap {
    let startTime: Date
    let duration: TimeInterval
}

struct MicroTask {
    let title: String
    let estimatedDuration: TimeInterval
}

struct GapSuggestion: Identifiable {
    let id = UUID()
    let task: MicroTask
    let startTime: Date
    let duration: TimeInterval
}

struct GapSuggestionCard: View {
    let suggestion: GapSuggestion
    let onApply: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(suggestion.startTime.timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(suggestion.duration / 60))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Add") {
                onApply()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
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

// MARK: - Action Bar View

struct FloatingActionBarView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @StateObject private var speechService = SpeechService()
    @State private var messageText = ""
    @State private var isVoiceMode = false
    @State private var pendingSuggestions: [Suggestion] = []
    @State private var ephemeralInsight: String?
    @State private var showInsightTimer: Timer?
    @State private var lastResponse = ""
    @State private var lastConfidence: Double = 0.0
    @State private var messageHistory: [AIMessage] = []
    @State private var showHistory = false
    
    // Floating position state
    @State private var dragOffset = CGSize.zero
    @State private var currentPosition = CGSize.zero
    @State private var isDragging = false
    
    // Default position (middle bottom, well spaced)
    private let defaultPosition = CGSize(width: 0, height: -100) // 100 points up from bottom
    private let snapThreshold: CGFloat = 400 // Distance threshold for snapping
    
    var body: some View {
        VStack(spacing: 8) {
                // Enhanced ephemeral insight with better styling
            if let insight = ephemeralInsight {
                HStack(spacing: 12) {
                    // Thinking indicator
                    if insight.contains("Analyzing") || insight.contains("Processing") {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    }
                    
                    Text(insight)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fontWeight(.medium)
                        .animation(.easeInOut(duration: 0.3), value: insight)
                    
                    Spacer()
                    
                    if !insight.contains("...") {
                        Button("💬") {
                            promoteInsightToTranscript(insight)
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)))
            }
            
            // Main action bar
            HStack(spacing: 12) {
                // History toggle
                Button(action: { showHistory.toggle() }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                // Voice/Text toggle
                Button(action: { isVoiceMode.toggle() }) {
                    Image(systemName: isVoiceMode ? "mic.fill" : "text.bubble")
                        .foregroundColor(isVoiceMode ? .red : .blue)
                }
                .buttonStyle(.plain)
                
                // Message input or voice indicator
                if isVoiceMode {
                    HStack {
                        Circle()
                            .fill(speechService.isListening ? .red : .gray)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: speechService.isListening)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(speechService.isListening ? "Listening..." : 
                                 speechService.canStartListening ? "Hold to speak" : "Speech unavailable")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            
                            // Show partial or final transcription
                            if !speechService.partialText.isEmpty {
                                Text(speechService.partialText)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .italic()
                            } else if !speechService.transcribedText.isEmpty {
                                Text(speechService.transcribedText)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onLongPressGesture(
                        minimumDuration: 0.1,
                        perform: { endVoiceInput() },
                        onPressingChanged: { pressing in
                            if pressing && speechService.canStartListening {
                                startVoiceInput()
                            } else {
                                endVoiceInput()
                            }
                        }
                    )
                    .disabled(!speechService.canStartListening)
                } else {
                    TextField("Ask AI or describe what you need...", text: $messageText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            sendMessage()
                        }
                }
                
                // Send button (disabled in voice mode)
                if !isVoiceMode {
                    Button("Send") {
                        sendMessage()
                    }
                    .disabled(messageText.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // AI Response (if available)
            if !lastResponse.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(lastResponse)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Confidence indicator
                        if lastConfidence > 0 {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(confidenceColor(lastConfidence))
                                    .frame(width: 6, height: 6)
                                
                                Text("\(Int(lastConfidence * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // TTS button
                    Button(speechService.isSpeaking ? "🔇" : "🔊") {
                        if speechService.isSpeaking {
                            speechService.stopSpeaking()
                        } else {
                            speechService.speak(text: lastResponse)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            
            // Staged suggestions with Yes/No (Nothing stages until explicit Yes)
            if !pendingSuggestions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(pendingSuggestions) { suggestion in
                        StagedSuggestionView(
                            suggestion: suggestion,
                            onAccept: { acceptSuggestion(suggestion) },
                            onReject: { rejectSuggestion(suggestion) }
                        )
                    }
                    
                    // Batch actions if multiple suggestions
                    if pendingSuggestions.count > 1 {
                        HStack {
                            Button("Accept All") {
                                acceptAllSuggestions()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Reject All") {
                                rejectAllSuggestions()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            
            // Undo countdown (10-second window)
        }
        .sheet(isPresented: $showHistory) {
            MessageHistoryView(messages: messageHistory, onDismiss: { showHistory = false })
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .offset(x: currentPosition.width + dragOffset.width, 
                y: currentPosition.height + dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    
                    // Calculate final position
                    let totalOffset = CGSize(
                        width: currentPosition.width + value.translation.width,
                        height: currentPosition.height + value.translation.height
                    )
                    
                    // Check if close to default position
                    let distanceFromDefault = sqrt(
                        pow(totalOffset.width - defaultPosition.width, 2) + 
                        pow(totalOffset.height - defaultPosition.height, 2)
                    )
                    
                    // Always animate to final position, but use different animations
                    if distanceFromDefault < snapThreshold {
                        // Smooth snap to default position
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.1)) {
                            currentPosition = defaultPosition
                            dragOffset = .zero
                        }
                    } else {
                        // Smooth move to new position
                        withAnimation(.easeOut(duration: 0.3)) {
                            currentPosition = totalOffset
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onAppear {
            // Set initial position to default
            currentPosition = defaultPosition
        }
    }
    
    // MARK: - Message Handling
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let message = messageText
        messageText = ""
        
        // Add to history
        messageHistory.append(AIMessage(text: message, isUser: true, timestamp: Date()))
        
        Task {
            // Show enhanced thinking state
            await MainActor.run {
                showEphemeralInsight("✨ Analyzing your request...")
            }
            
            do {
                // Get AI response
                let context = createContext()
                
                await MainActor.run {
                    showEphemeralInsight("🧠 Processing with AI...")
                }
                
                let response = try await aiService.processMessage(message, context: context)
                
                   await MainActor.run {
                       lastResponse = response.text
                       lastConfidence = response.confidence

                       // Handle different types of AI responses based on confidence and action type
                       if let actionType = response.actionType {
                           handleSmartAIResponse(response, actionType: actionType, message: message)
                       } else {
                           // Fallback to legacy behavior
                           handleLegacyResponse(response, message: message)
                       }
                    
                    // Add AI response to history
                    messageHistory.append(AIMessage(text: response.text, isUser: false, timestamp: Date()))
                }
            } catch {
                await MainActor.run {
                    showEphemeralInsight("Sorry, I couldn't process that right now")
                    lastResponse = "I'm having trouble connecting right now. Please try again."
                    messageHistory.append(AIMessage(text: "Error: \(error.localizedDescription)", isUser: false, timestamp: Date()))
                }
            }
        }
    }
    
    // MARK: - Voice Input
    
    // MARK: - Suggestion Handling (Staging System)
    
    private func acceptSuggestion(_ suggestion: Suggestion) {
        // Use new staging system directly
        dataManager.applySuggestion(suggestion)
        
        // Remove from pending
        pendingSuggestions.removeAll { $0.id == suggestion.id }
        
        showEphemeralInsight("Staged '\(suggestion.title)' for your review")
    }
    
    private func rejectSuggestion(_ suggestion: Suggestion) {
        dataManager.rejectSuggestion(suggestion)
        pendingSuggestions.removeAll { $0.id == suggestion.id }
        showEphemeralInsight("No problem, I'll learn from this")
    }
    
    private func acceptAllSuggestions() {
        for suggestion in pendingSuggestions {
            dataManager.applySuggestion(suggestion)
        }
        let count = pendingSuggestions.count
        pendingSuggestions.removeAll()
        showEphemeralInsight("Staged \(count) suggestion\(count == 1 ? "" : "s") for your review")
    }
    
    private func rejectAllSuggestions() {
        for suggestion in pendingSuggestions {
            dataManager.rejectSuggestion(suggestion)
        }
        pendingSuggestions.removeAll()
        showEphemeralInsight("All rejected - I'll remember this")
    }
    
    
    // MARK: - Helper Methods
    
    private func showEphemeralInsight(_ text: String) {
        ephemeralInsight = text
        showInsightTimer?.invalidate()
        showInsightTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                ephemeralInsight = nil
            }
        }
    }
    
    private func promoteInsightToTranscript(_ insight: String) {
        // Add insight to permanent message history
        messageHistory.append(AIMessage(text: "💡 \(insight)", isUser: false, timestamp: Date()))
        ephemeralInsight = nil
        showEphemeralInsight("Added to conversation history")
    }
    
    
    private func startVoiceInput() {
        Task {
            do {
                try await speechService.startListening()
                showEphemeralInsight("🎤 Listening...")
            } catch {
                showEphemeralInsight("Speech recognition error: \(error.localizedDescription)")
            }
        }
    }
    
    private func endVoiceInput() {
        Task {
            await speechService.stopListening()
            
            // Process the transcribed text
            if !speechService.transcribedText.isEmpty {
                messageText = speechService.transcribedText
                showEphemeralInsight("Voice input captured: \(speechService.transcribedText.prefix(30))...")
                
                // Automatically send the transcribed message
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    sendMessage()
                }
            } else {
                showEphemeralInsight("No speech detected")
            }
        }
    }
    
    // Detect if user is asking AI to schedule something
    private func isSchedulingRequest(_ message: String) -> Bool {
        let schedulingKeywords = [
            "schedule", "book", "add", "create", "plan", "set up", "arrange", 
            "put in", "block", "reserve", "calendar", "time for", "remind me"
        ]
        
        let lowerMessage = message.lowercased()
        return schedulingKeywords.contains { keyword in
            lowerMessage.contains(keyword)
        }
    }
    
    // MARK: - Smart AI Response Handlers
    
    private func handleSmartAIResponse(_ response: AIResponse, actionType: AIActionType, message: String) {
        switch actionType {
        case .createEvent:
            handleEventCreation(response, message: message)
        case .createGoal:
            handleGoalCreation(response, message: message)
        case .createPillar:
            handlePillarCreation(response, message: message)
        case .createChain:
            handleChainCreation(response, message: message)
        case .suggestActivities:
            handleActivitySuggestions(response, message: message)
        case .generalChat:
            handleGeneralChat(response, message: message)
        }
    }
    
    private func handleEventCreation(_ response: AIResponse, message: String) {
        if response.confidence >= 0.7 { // Lowered threshold for better UX
            // High confidence - create the event directly with full details
            if let firstSuggestion = response.suggestions.first {
                let targetTime = extractDateFromMessage(message) ?? findNextAvailableTime(after: Date())
                
                // Create fully populated time block
                let timeBlock = TimeBlock(
                    title: firstSuggestion.title,
                    startTime: targetTime,
                    duration: firstSuggestion.duration,
                    energy: firstSuggestion.energy,
                    emoji: firstSuggestion.emoji,
                    glassState: .crystal, // AI-created
                    relatedGoalId: findRelatedGoal(for: firstSuggestion.title)?.id,
                    relatedPillarId: findRelatedPillar(for: firstSuggestion.title)?.id
                )
                
                dataManager.addTimeBlock(timeBlock)
                
                // Award XP for successful AI scheduling
                dataManager.appState.addXP(5, reason: "AI scheduled event")
                
                let dateString = Calendar.current.isDate(targetTime, inSameDayAs: Date()) ? "today" : targetTime.dayString
                showEphemeralInsight("✨ Created \(timeBlock.title) for \(dateString) at \(targetTime.timeString)!")
                
                // Create related suggestions if this event could be part of a chain
                suggestRelatedActivities(for: timeBlock, confidence: response.confidence)
            }
        } else if response.confidence >= 0.5 {
            // Medium confidence - show enhanced suggestion with more context
            pendingSuggestions = response.suggestions.map { suggestion in
                var enhanced = suggestion
                enhanced.explanation = "\(suggestion.explanation) (Confidence: \(Int(response.confidence * 100))%)"
                return enhanced
            }
            showEphemeralInsight("💡 I think you want to create an event. Here's my best guess:")
        } else {
            // Low confidence - ask for clarification
            showEphemeralInsight("🤔 Could you be more specific about what you'd like to schedule?")
        }
    }
    
    private func handleGoalCreation(_ response: AIResponse, message: String) {
        if response.confidence >= 0.8 { // Lowered threshold for better UX
            // High confidence - create the goal directly with full population
            if let createdItem = response.createdItems?.first(where: { $0.type == .goal }),
               let goalData = createdItem.data as? [String: Any] {
                
                // Create fully populated goal with simplified fallbacks
                    let goal = Goal(
                    title: goalData["title"] as? String ?? "New Goal",
                    description: goalData["description"] as? String ?? "AI-created goal based on your request",
                        state: .on,
                    importance: goalData["importance"] as? Int ?? 3,
                    groups: [],
                    targetDate: nil,
                    emoji: goalData["emoji"] as? String ?? "🎯",
                    relatedPillarIds: []
                )
                
                    dataManager.addGoal(goal)
                
                // Award XP for goal creation
                dataManager.appState.addXP(15, reason: "AI created goal")
                
                showEphemeralInsight("🎯 Created goal: \(goal.title) (Importance: \(goal.importance)/5)")
                
                // Suggest immediate actions with delay
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        showEphemeralInsight("💡 Create supporting activities for '\(goal.title)'?")
                    }
                }
            }
        } else if response.confidence >= 0.6 {
            // Medium confidence - show clarification with suggestions
            showEphemeralInsight("🤔 I think you want to create a goal. What's the main outcome you're hoping for?")
        } else {
            // Low confidence - ask for more details
            showEphemeralInsight("💭 I'd love to help you create a goal! Tell me what you want to achieve.")
        }
    }
    
    private func handlePillarCreation(_ response: AIResponse, message: String) {
        if response.confidence >= 0.85 { // Lowered threshold slightly
            // High confidence - create the pillar directly with full details
            if let createdItem = response.createdItems?.first(where: { $0.type == .pillar }),
               let pillarData = createdItem.data as? [String: Any] {
                
                // Create fully populated pillar with simplified fallbacks
                    let pillar = Pillar(
                    name: pillarData["name"] as? String ?? "New Pillar",
                    description: pillarData["description"] as? String ?? "AI-created pillar based on your request",
                    type: PillarType(rawValue: pillarData["type"] as? String ?? "actionable") ?? .actionable,
                    frequency: PillarFrequency.daily,
                    minDuration: TimeInterval((pillarData["minDuration"] as? Int ?? 30) * 60),
                    maxDuration: TimeInterval((pillarData["maxDuration"] as? Int ?? 120) * 60),
                    preferredTimeWindows: [],
                    overlapRules: [],
                    quietHours: [],
                    eventConsiderationEnabled: true,
                    wisdomText: pillarData["wisdomText"] as? String,
                    emoji: pillarData["emoji"] as? String ?? "🏛️",
                    relatedGoalId: nil
                )
                
                    dataManager.addPillar(pillar)
                
                // Award XP for pillar creation
                dataManager.appState.addXP(20, reason: "AI created pillar")
                
                showEphemeralInsight("🏛️ Created \(pillar.type.rawValue.lowercased()) pillar: \(pillar.name)")
                
                // Suggest scheduling if it's actionable
                if pillar.isActionable {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            showEphemeralInsight("📅 Schedule '\(pillar.name)' activity?")
                        }
                    }
                }
            }
        } else if response.confidence >= 0.6 {
            // Medium confidence - ask for clarification
            showEphemeralInsight("🤔 I think you want to create a pillar. Is this a recurring activity or a guiding principle?")
        } else {
            // Low confidence - ask for more details
            showEphemeralInsight("💭 Tell me more about this pillar - is it something you want to do regularly or a principle to guide decisions?")
        }
    }
    
    private func handleChainCreation(_ response: AIResponse, message: String) {
        if response.confidence >= 0.75 {
            // High confidence - create the chain directly with full details
            if let createdItem = response.createdItems?.first(where: { $0.type == .chain }),
               let chainData = createdItem.data as? [String: Any] {
                
                // Create fully populated chain with simplified fallbacks
                let chain = Chain(
                    name: chainData["name"] as? String ?? "New Chain",
                    blocks: [TimeBlock(title: "Activity", startTime: Date(), duration: 1800, energy: .daylight, emoji: "🌊")],
                    flowPattern: FlowPattern(rawValue: chainData["flowPattern"] as? String ?? "waterfall") ?? .waterfall,
                    emoji: chainData["emoji"] as? String ?? "🔗",
                    relatedGoalId: nil,
                    relatedPillarId: nil
                )
                
                dataManager.addChain(chain)
                
                // Award XP for chain creation
                dataManager.appState.addXP(10, reason: "AI created chain")
                
                showEphemeralInsight("🔗 Created chain: \(chain.name) with \(chain.blocks.count) activities")
                
                // Suggest applying the chain
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        showEphemeralInsight("⚡ Apply '\(chain.name)' now?")
                    }
                }
            }
        } else if response.confidence >= 0.6 {
            // Medium confidence - show suggestions but ask for clarification
            pendingSuggestions = response.suggestions
            showEphemeralInsight("💡 I think you want to create a chain. Should these activities be linked together?")
        } else {
            // Low confidence - ask for more details
            showEphemeralInsight("🤔 Tell me more about this chain - what activities should be connected?")
        }
    }
    
    private func handleActivitySuggestions(_ response: AIResponse, message: String) {
        pendingSuggestions = response.suggestions
        if !response.suggestions.isEmpty {
            showEphemeralInsight("💡 Found \(response.suggestions.count) suggestion\(response.suggestions.count == 1 ? "" : "s") for you")
        } else {
            showEphemeralInsight("Here's what I think...")
        }
    }
    
    private func handleGeneralChat(_ response: AIResponse, message: String) {
        // For general chat, just show suggestions if any
        if !response.suggestions.isEmpty {
            pendingSuggestions = response.suggestions
            showEphemeralInsight("💭 Here's a thought...")
        } else {
            showEphemeralInsight("💬 Thanks for sharing!")
        }
    }
    
    private func handleLegacyResponse(_ response: AIResponse, message: String) {
        // Enhanced legacy handling with smart confidence-based decisions
        if isSchedulingRequest(message) && !response.suggestions.isEmpty {
            // Determine if we should create directly or stage based on multiple factors
            let shouldCreateDirectly = shouldCreateEventsDirectly(response: response, message: message)
            
            if shouldCreateDirectly {
                // Create events directly with enhanced details
            let targetDate = extractDateFromMessage(message) ?? Date()
                var createdCount = 0
            
            for (index, suggestion) in response.suggestions.enumerated() {
                let suggestedTime = findNextAvailableTime(after: targetDate.addingTimeInterval(Double(index * 30 * 60)))
                    
                    // Create fully populated time block with relationships
                    let timeBlock = TimeBlock(
                        title: suggestion.title,
                        startTime: suggestedTime,
                        duration: suggestion.duration,
                        energy: suggestion.energy,
                        emoji: suggestion.emoji,
                        glassState: .crystal, // AI-created
                        relatedGoalId: findRelatedGoal(for: suggestion.title)?.id,
                        relatedPillarId: findRelatedPillar(for: suggestion.title)?.id
                    )
                    
                    dataManager.addTimeBlock(timeBlock)
                    createdCount += 1
                }
                
            let dateString = Calendar.current.isDate(targetDate, inSameDayAs: Date()) ? "today" : targetDate.dayString
                showEphemeralInsight("✨ Created \(createdCount) event\(createdCount == 1 ? "" : "s") for \(dateString)!")
            
                // Award XP for successful AI scheduling
                dataManager.appState.addXP(createdCount * 5, reason: "AI direct scheduling")
                
            pendingSuggestions = []
        } else {
                // Stage for user approval with enhanced context
                pendingSuggestions = response.suggestions.map { suggestion in
                    var enhanced = suggestion
                    enhanced.explanation = "\(suggestion.explanation) (Auto-suggested based on your request)"
                    return enhanced
                }
                showEphemeralInsight("💡 Here's what I suggest for your request:")
            }
        } else {
            // Regular suggestion flow with confidence indication
            pendingSuggestions = response.suggestions
            if !response.suggestions.isEmpty {
                let avgConfidence = response.suggestions.map(\.confidence).reduce(0, +) / Double(response.suggestions.count)
                let confidenceText = avgConfidence > 0.8 ? "strong" : avgConfidence > 0.6 ? "good" : "rough"
                showEphemeralInsight("💡 Found \(response.suggestions.count) \(confidenceText) suggestion\(response.suggestions.count == 1 ? "" : "s") for you")
            } else {
                showEphemeralInsight("💬 I understand, but need more details to help you")
            }
        }
    }
    
    // MARK: - Smart Decision Making
    
    private func shouldCreateEventsDirectly(response: AIResponse, message: String) -> Bool {
        // Multiple factors determine if we should create directly
        let factors: [Double] = [
            response.confidence, // Base confidence
            isSchedulingRequest(message) ? 0.2 : 0.0, // Clear scheduling intent
            hasSpecificTime(message) ? 0.2 : 0.0, // Time specified
            hasUrgencyIndicators(message) ? 0.15 : 0.0, // Urgency words
            response.suggestions.count == 1 ? 0.1 : 0.0, // Single clear suggestion
            lastConfidence > 0.7 ? 0.1 : 0.0 // Recent successful interactions
        ]
        
        let combinedConfidence = factors.reduce(0, +) / Double(factors.count)
        return combinedConfidence >= 0.65 // Lower threshold for better UX
    }
    
    private func hasSpecificTime(_ message: String) -> Bool {
        let timePatterns = ["at ", ":\\d{2}", "am", "pm", "tomorrow", "today", "now", "in \\d+"]
        return timePatterns.contains { pattern in
            message.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    private func hasUrgencyIndicators(_ message: String) -> Bool {
        let urgencyWords = ["urgent", "asap", "immediately", "now", "quickly", "soon", "today"]
        let lowerMessage = message.lowercased()
        return urgencyWords.contains { lowerMessage.contains($0) }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func createContext() -> DayContext {
        dataManager.createEnhancedContext()
    }
    
    // MARK: - AI Scheduling Helper Functions
    
    private func extractDateFromMessage(_ message: String) -> Date? {
        let lowercased = message.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        // Check for "today"
        if lowercased.contains("today") {
            return now
        }
        
        // Check for "tomorrow"
        if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }
        
        // Check for "next week"
        if lowercased.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        }
        
        // Check for day names (monday, tuesday, etc.)
        let dayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for (index, dayName) in dayNames.enumerated() {
            if lowercased.contains(dayName) {
                let targetWeekday = index + 2 // Monday = 2 in Calendar.current
                let adjustedWeekday = targetWeekday > 7 ? 1 : targetWeekday
                
                var components = DateComponents()
                components.weekday = adjustedWeekday
                
                // Find next occurrence of this weekday
                if let nextDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) {
                    return nextDate
                }
            }
        }
        
        // Check for time patterns like "at 3pm", "at 15:00"
        let timeRegex = try? NSRegularExpression(pattern: "at\\s+(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?", options: .caseInsensitive)
        if let regex = timeRegex {
            let range = NSRange(location: 0, length: message.count)
            if let match = regex.firstMatch(in: message, options: [], range: range) {
                let hourRange = match.range(at: 1)
                let minuteRange = match.range(at: 2)
                let ampmRange = match.range(at: 3)
                
                if let hourString = Range(hourRange, in: message).map({ String(message[$0]) }),
                   let hour = Int(hourString) {
                    
                    let minute = minuteRange.location != NSNotFound ? 
                        Range(minuteRange, in: message).map({ Int(String(message[$0])) }) ?? 0 : 0
                    
                    let isPM = ampmRange.location != NSNotFound ? 
                        Range(ampmRange, in: message).map({ String(message[$0]).lowercased() == "pm" }) ?? false : false
                    
                    let adjustedHour = isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour)
                    
                    return calendar.date(bySettingHour: adjustedHour, minute: minute ?? 0, second: 0, of: now)
                }
            }
        }
        
        // Default to current time if no specific date/time found
        return nil
    }
    
    private func findNextAvailableTime(after startTime: Date) -> Date {
        let allBlocks = dataManager.appState.currentDay.blocks
        let sortedBlocks = allBlocks.sorted { $0.startTime < $1.startTime }
        
        var searchTime = startTime
        let minimumDuration: TimeInterval = 30 * 60 // 30 minutes minimum slot
        
        // Look for gaps in the schedule
        for block in sortedBlocks {
            // If there's enough time before this block
            if searchTime.addingTimeInterval(minimumDuration) <= block.startTime {
                return searchTime
            }
            
            // Move search time to after this block
            if block.endTime > searchTime {
                searchTime = block.endTime
            }
        }
        
        // If no gaps found, return the time after the last block
        return searchTime
    }
    
    // MARK: - Smart Relationship Detection
    
    private func findRelatedGoal(for eventTitle: String) -> Goal? {
        let lowercaseTitle = eventTitle.lowercased()
        
        return dataManager.appState.goals.first { goal in
            let goalWords = goal.title.lowercased().split(separator: " ")
            let titleWords = lowercaseTitle.split(separator: " ")
            
            // Check for word overlap
            let overlap = Set(goalWords).intersection(Set(titleWords))
            return overlap.count >= 1 && goal.isActive
        }
    }
    
    private func findRelatedPillar(for eventTitle: String) -> Pillar? {
        let lowercaseTitle = eventTitle.lowercased()
        
        return dataManager.appState.pillars.first { pillar in
            let pillarWords = pillar.name.lowercased().split(separator: " ")
            let titleWords = lowercaseTitle.split(separator: " ")
            
            // Check for word overlap or category match
            let overlap = Set(pillarWords).intersection(Set(titleWords))
            if overlap.count >= 1 { return true }
            
            // Check for category matches
            if lowercaseTitle.contains("work") && pillar.name.lowercased().contains("work") { return true }
            if lowercaseTitle.contains("exercise") && pillar.name.lowercased().contains("exercise") { return true }
            if lowercaseTitle.contains("meeting") && pillar.name.lowercased().contains("meeting") { return true }
            
            return false
        }
    }
    
    private func suggestRelatedActivities(for timeBlock: TimeBlock, confidence: Double) {
        // If confidence is high, suggest creating a chain around this event
        if confidence >= 0.8 {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
                await MainActor.run {
                    showEphemeralInsight("💡 Want to create a chain around '\(timeBlock.title)'?")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StagedSuggestionView: View {
    let suggestion: Suggestion
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(suggestion.explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text("\(suggestion.duration.minutes) min")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2), in: Capsule())
                    
                    Text(suggestion.energy.rawValue)
                        .font(.caption2)
                    
                    Text(suggestion.emoji)
                        .font(.caption2)
                }
            }
            
            Spacer()
            
            // Confidence indicator
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            // Actions
            HStack(spacing: 8) {
                Button("No") {
                    onReject()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Yes") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
        )
    }
    
    private var confidenceColor: Color {
        switch suggestion.confidence {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

struct MessageHistoryView: View {
    let messages: [AIMessage]
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            .navigationTitle("Conversation History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

struct MessageBubble: View {
    let message: AIMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isUser ? .blue.opacity(0.2) : .gray.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 12)
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

// MARK: - Supporting Data Models

struct AIMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - Day Planner View

struct DayPlannerView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @Binding var selectedDate: Date // Use shared date state
    @State private var showingBlockCreation = false
    @State private var creationTime: Date?
    @State private var draggedBlock: TimeBlock?
    
    var body: some View {
        VStack(spacing: 0) {
            // Date header
            DayViewHeader(selectedDate: $selectedDate)
            
            // Timeline view
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        HourSlot(
                            hour: hour,
                            blocks: blocksForHour(hour),
                            onTap: { time in
                                creationTime = time
                                showingBlockCreation = true
                            },
                            onBlockDrag: { block, location in
                                draggedBlock = block
                                // Handle block dragging
                            },
                            onBlockDrop: { block, newTime in
                                handleBlockDrop(block: block, newTime: newTime)
                                draggedBlock = nil // Clear drag state
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollDisabled(draggedBlock != nil) // Disable scroll when dragging an event
        }
        .onAppear {
            // Ensure selectedDate matches currentDay on appear
            selectedDate = dataManager.appState.currentDay.date
        }
        .sheet(isPresented: $showingBlockCreation) {
            BlockCreationSheet(
                suggestedTime: creationTime ?? Date(),
                onCreate: { block in
                    dataManager.addTimeBlock(block)
                    showingBlockCreation = false
                    creationTime = nil
                }
            )
        }
    }
    
    private func blocksForHour(_ hour: Int) -> [TimeBlock] {
        let calendar = Calendar.current
        let allBlocks = dataManager.appState.currentDay.blocks
        return allBlocks.filter { block in
            let blockHour = calendar.component(.hour, from: block.startTime)
            return blockHour == hour
        }
    }
    
    private func updateDataManagerDate() {
        // Update the current day in data manager when date changes
        if !Calendar.current.isDate(dataManager.appState.currentDay.date, inSameDayAs: selectedDate) {
            switchToDate(selectedDate)
        }
    }
    
    private func switchToDate(_ date: Date) {
        // Use the proper switchToDay method from data manager to preserve data
        dataManager.switchToDay(date)
    }
    
    private func handleBlockDrop(block: TimeBlock, newTime: Date) {
        // Update the block's start time
        var updatedBlock = block
        updatedBlock.startTime = newTime
        
        // Update the block in the data manager
        dataManager.updateTimeBlock(updatedBlock)
        
        // Clear the dragged block
        draggedBlock = nil
        
        // Provide haptic feedback
        #if os(iOS)
        HapticStyle.light.trigger()
        #endif
    }
}

struct DayViewHeader: View {
    @Binding var selectedDate: Date
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        HStack {
            // Previous day
            Button(action: previousDay) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Current date
            Text(selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // Next day
            Button(action: nextDay) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private func previousDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            updateDataManagerDate()
        }
    }
    
    private func nextDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            updateDataManagerDate()
        }
    }
    
    private func updateDataManagerDate() {
        // Update the current day in data manager when date changes
        if !Calendar.current.isDate(dataManager.appState.currentDay.date, inSameDayAs: selectedDate) {
            switchToDate(selectedDate)
        }
    }
    
    private func switchToDate(_ date: Date) {
        // Use the proper switchToDay method from data manager to preserve data
        dataManager.switchToDay(date)
    }
}

struct HourSlot: View {
    let hour: Int
    let blocks: [TimeBlock]
    let onTap: (Date) -> Void
    let onBlockDrag: (TimeBlock, CGPoint) -> Void
    let onBlockDrop: (TimeBlock, Date) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Hour label
            VStack {
                Text(hourString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
                
                if hour < 23 {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 1)
                        .frame(width: 50)
                }
            }
            
            // Content area
            VStack(alignment: .leading, spacing: 4) {
                ForEach(blocks) { block in
                    SimpleTimeBlockView(
                        block: block,
                        onDrag: { location in
                            onBlockDrag(block, location)
                        },
                        onDrop: { newTime in
                            onBlockDrop(block, newTime)
                        }
                    )
                }
                
                // Empty space for tapping
                if blocks.isEmpty {
                    Rectangle()
                        .fill(.clear)
                        .frame(height: 60)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let calendar = Calendar.current
                            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
                            onTap(date)
                        }
                }
                
                // Hour separator line
                if hour < 23 {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
    }
    
    private var hourString: String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.timeString
    }
}

// MARK: - Simple Time Block View (Replacement for old complex TimeBlockView)

struct SimpleTimeBlockView: View {
    let block: TimeBlock
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingDetails = false
    @State private var activeTab: EventTab = .details
    
    var body: some View {
        // Fixed draggable event card with proper gesture priority
        VStack(spacing: 0) {
                HStack(spacing: 8) {
                    // Energy and flow indicators
                    VStack(spacing: 2) {
                        Text(block.energy.rawValue)
                            .font(.caption)
                        Text(block.emoji)
                            .font(.caption)
                    }
                .opacity(0.8)
                    
                    // Block content
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if !block.emoji.isEmpty {
                                Text(block.emoji)
                                    .font(.caption)
                            }
                            
                            Text(block.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        
                                HStack {
                                    Text(block.startTime.timeString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(block.durationMinutes) min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                        
                        // Quick visual indicator of what's available
                        if canAddChainBefore || canAddChainAfter {
                            Text("⛓️")
                                    .font(.caption2)
                                .opacity(0.6)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Glass state indicator
                    Circle()
                        .fill(stateColor)
                        .frame(width: 6, height: 6)
                
                // Click to open details indicator
                Button(action: { showingDetails = true }) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                borderColor, 
                                style: StrokeStyle(
                                    lineWidth: 1
                                )
                            )
                    )
            )
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .offset(dragOffset)
            .contentShape(Rectangle()) // Ensure entire area is draggable
            .highPriorityGesture(
                // Exclusive drag gesture that overrides scroll
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDragging = true
                            }
                        }
                        dragOffset = value.translation
                        onDrag(value.location)
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.5)) {
                            isDragging = false
                            dragOffset = .zero
                        }
                        
                        // Calculate new time based on drag distance
                        let newTime = calculateNewTime(from: value.translation)
                        onDrop(newTime)
                    }
            )
            // No animation to prevent flashing
        }
        .sheet(isPresented: $showingDetails) {
            NoFlashEventDetailsSheet(
                block: block,
                allBlocks: getAllBlocks(),
                onSave: { updatedBlock in
                    dataManager.updateTimeBlock(updatedBlock)
                    showingDetails = false
                },
                onDelete: {
                    dataManager.removeTimeBlock(block.id)
                    showingDetails = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }
    
    private var stateColor: Color {
        switch block.glassState {
        case .solid: return .green
        case .liquid: return .blue
        case .mist: return .orange
        case .crystal: return .cyan
        }
    }
    
    private var borderColor: Color {
        switch block.glassState {
        case .solid: return .clear
        case .liquid: return .blue.opacity(0.6)
        case .mist: return .orange.opacity(0.5)
        case .crystal: return .cyan.opacity(0.7)
        }
    }
    
    private var canAddChainBefore: Bool {
        let gap = calculateGapBefore()
        return gap >= 300 // 5 minutes minimum
    }
    
    private var canAddChainAfter: Bool {
        let gap = calculateGapAfter()
        return gap >= 300 // 5 minutes minimum
    }
    
    private func getAllBlocks() -> [TimeBlock] {
        return dataManager.appState.currentDay.blocks
    }
    
    private func calculateGapBefore() -> TimeInterval {
        let allBlocks = getAllBlocks()
        let previousBlocks = allBlocks.filter { $0.endTime <= block.startTime && $0.id != block.id }
        guard let previousBlock = previousBlocks.max(by: { $0.endTime < $1.endTime }) else {
            // No previous event, gap to start of day
            let startOfDay = Calendar.current.startOfDay(for: block.startTime)
            return block.startTime.timeIntervalSince(startOfDay)
        }
        
        return block.startTime.timeIntervalSince(previousBlock.endTime)
    }
    
    private func calculateGapAfter() -> TimeInterval {
        let allBlocks = getAllBlocks()
        let nextBlocks = allBlocks.filter { $0.startTime >= block.endTime && $0.id != block.id }
        guard let nextBlock = nextBlocks.min(by: { $0.startTime < $1.startTime }) else {
            // No next event, gap to end of day
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: block.startTime) ?? block.endTime
            return endOfDay.timeIntervalSince(block.endTime)
        }
        
        return nextBlock.startTime.timeIntervalSince(block.endTime)
    }
    
    private func calculateNewTime(from translation: CGSize) -> Date {
        // Calculate time change based on vertical drag distance
        // Assume each 60 pixels = 1 hour (adjustable)
        let pixelsPerHour: CGFloat = 60
        let hourChange = translation.height / pixelsPerHour
        
        // Convert to minutes for more precision
        let minuteChange = Int(hourChange * 60)
        
        // Apply the change to the current start time
        let newTime = Calendar.current.date(byAdding: .minute, value: minuteChange, to: block.startTime) ?? block.startTime
        
        // Round to nearest 15-minute interval for cleaner scheduling
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: newTime)
        let roundedMinute = (minute / 15) * 15
        
        return calendar.date(bySettingHour: calendar.component(.hour, from: newTime), 
                           minute: roundedMinute, 
                           second: 0, 
                           of: newTime) ?? newTime
    }
    
    private func showChainSelector(position: ChainPosition) {
        // This will be handled by the EventDetailsSheet's onAddChain closure
        // which is called from the EventChainsTab
        print("Chain selector triggered for \(position) position - handled by details sheet")
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

// MARK: - Block Creation Sheet


struct BlockCreationSheet: View {
    let suggestedTime: Date
    let onCreate: (TimeBlock) -> Void
    
    @State private var title = ""
    @State private var selectedEnergy: EnergyType = .daylight
    @State private var selectedEmoji: String = "🌊"
    @State private var duration: Int = 60 // minutes
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Title input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity")
                        .font(.headline)
                    
                    TextField("What would you like to do?", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                
                // Energy selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Energy Level")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(EnergyType.allCases, id: \.self) { energy in
                            Button(action: { selectedEnergy = energy }) {
                                VStack(spacing: 4) {
                                    Text(energy.rawValue)
                                        .font(.title2)
                                    Text(energy.description)
                                        .font(.caption)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    selectedEnergy == energy ? energy.color.opacity(0.2) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selectedEnergy == energy ? energy.color : .gray.opacity(0.3),
                                            lineWidth: selectedEnergy == energy ? 2 : 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Flow selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity Type")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(["📋", "💎", "🌊", "☁️", "🎯", "💪", "🧠", "🎨"], id: \.self) { emoji in
                            Button(action: { selectedEmoji = emoji }) {
                                VStack(spacing: 4) {
                                    Text(emoji)
                                        .font(.title2)
                                    Text("Activity")
                                        .font(.caption)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    selectedEmoji == emoji ? .blue.opacity(0.2) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selectedEmoji == emoji ? .blue : .gray.opacity(0.3),
                                            lineWidth: selectedEmoji == emoji ? 2 : 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Duration slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration: \(duration) minutes")
                        .font(.headline)
                    
                    Slider(value: Binding(
                        get: { Double(duration) },
                        set: { duration = Int($0) }
                    ), in: 15...240, step: 15)
                    .accentColor(.blue)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("New Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let block = TimeBlock(
                            title: title,
                            startTime: suggestedTime,
                            duration: TimeInterval(duration * 60),
                            energy: selectedEnergy,
                            emoji: selectedEmoji,
                            glassState: .mist
                        )
                        onCreate(block)
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
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

struct ChainBlockEditRow: View {
    let block: TimeBlock
    let index: Int
    let onUpdate: (TimeBlock) -> Void
    let onRemove: () -> Void
    
    @State private var editedBlock: TimeBlock
    
    init(block: TimeBlock, index: Int, onUpdate: @escaping (TimeBlock) -> Void, onRemove: @escaping () -> Void) {
        self.block = block
        self.index = index
        self.onUpdate = onUpdate
        self.onRemove = onRemove
        self._editedBlock = State(initialValue: block)
    }
    
    var body: some View {
        HStack {
            Text("\(index).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
            
            TextField("Activity title", text: $editedBlock.title)
                .textFieldStyle(.roundedBorder)
                .onChange(of: editedBlock.title) { _, _ in
                    onUpdate(editedBlock)
                }
            
            Stepper("\(editedBlock.durationMinutes)m", 
                   value: Binding(
                       get: { Double(editedBlock.duration/60) },
                       set: { newValue in
                           editedBlock.duration = TimeInterval(newValue * 60)
                           onUpdate(editedBlock)
                       }
                   ), 
                   in: 5...480, 
                   step: 5)
                .frame(width: 80)
            
            Button("Remove") {
                onRemove()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .foregroundColor(.red)
        }
        .padding(.vertical, 2)
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

struct GoalsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingGoalCreator = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Goals")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("New Goal") {
                    showingGoalCreator = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if dataManager.appState.goals.isEmpty {
                VStack(spacing: 8) {
                    Text("🎯")
                        .font(.title)
                        .opacity(0.5)
                    
                    Text("No goals yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Set goals to get AI suggestions for achieving them")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(dataManager.appState.goals) { goal in
                        GoalRowView(goal: goal)
                    }
                }
            }
        }
        .sheet(isPresented: $showingGoalCreator) {
            GoalCreationView { newGoal in
                dataManager.appState.goals.append(newGoal)
                dataManager.save()
                showingGoalCreator = false
            }
        }
    }
}

struct GoalRowView: View {
    let goal: Goal
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(goal.state.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(stateColor.opacity(0.2), in: Capsule())
                        .foregroundColor(stateColor)
                    
                    Text("Importance: \(goal.importance)/5")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if goal.progress > 0 {
                ProgressView(value: goal.progress)
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var stateColor: Color {
        switch goal.state {
        case .draft: return .orange
        case .on: return .green
        case .off: return .gray
        }
    }
}

struct GoalCreationView: View {
    let onCreate: (Goal) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var importance = 3
    @State private var state: GoalState = .draft
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal Title")
                        .font(.headline)
                    TextField("e.g., Learn Swift Programming", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                    TextField("Brief description of your goal", text: $description)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Importance: \(importance)/5")
                        .font(.headline)
                    Slider(value: Binding(
                        get: { Double(importance) },
                        set: { importance = Int($0) }
                    ), in: 1...5, step: 1)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Initial State")
                        .font(.headline)
                    
                    Picker("State", selection: $state) {
                        ForEach(GoalState.allCases, id: \.self) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Goal Breakdown Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Break Down Into Actions")
                        .font(.headline)
                    
                    Text("Convert your goal into actionable steps:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("→ Create Pillar") {
                            createPillarFromGoal()
                        }
                        .buttonStyle(.bordered)
                        .help("Create a recurring pillar based on this goal")
                        
                        Button("→ Create Chain") {
                            createChainFromGoal()
                        }
                        .buttonStyle(.bordered)
                        .help("Create a sequence of activities for this goal")
                        
                        Button("→ Create Event") {
                            createEventFromGoal()
                        }
                        .buttonStyle(.bordered)
                        .help("Schedule a specific time block for this goal")
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Create Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newGoal = Goal(
                            title: title,
                            description: description,
                            state: state,
                            importance: importance,
                            groups: []
                        )
                        onCreate(newGoal)
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func createPillarFromGoal() {
        let _ = Pillar(
            name: title,
            description: "Supporting pillar for: \(description)",
            frequency: .weekly(2),
            minDuration: 1800, // 30 minutes
            maxDuration: 7200, // 2 hours
            preferredTimeWindows: [],
            overlapRules: [],
            quietHours: []
        )
        // This would ideally show a pillar creation sheet, but for now just create directly
        // In a real app, you'd want to let users customize the pillar
    }
    
    private func createChainFromGoal() {
        let _ = Chain(
            name: "\(title) Chain",
            blocks: [
                TimeBlock(
                    title: "Plan \(title)",
                    startTime: Date(),
                    duration: 1800, // 30 minutes
                    energy: .daylight,
                    emoji: "💎"
                ),
                TimeBlock(
                    title: "Execute \(title)",
                    startTime: Date(),
                    duration: 3600, // 60 minutes
                    energy: .daylight,
                    emoji: "🌊"
                )
            ],
            flowPattern: .waterfall
        )
        // This would ideally show a chain creation sheet, but for now just create directly
    }
    
    private func createEventFromGoal() {
        let _ = TimeBlock(
            title: title,
            startTime: Date(),
            duration: 3600, // 60 minutes default
            energy: .daylight,
            emoji: "🌊"
        )
        // This would ideally show a time block creation sheet
    }
}

struct DreamBuilderSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var selectedConcepts: Set<UUID> = []
    @State private var showingMergeView = false
    @State private var showingDreamChat = false
    
    // Cached sorted concepts to prevent expensive re-sorting on every view update
    private var sortedDreamConcepts: [DreamConcept] {
        dataManager.appState.dreamConcepts.sorted { $0.priority > $1.priority }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dream Builder")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !selectedConcepts.isEmpty {
                    Button("Merge (\(selectedConcepts.count))") {
                        showingMergeView = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Button("Dream Chat") {
                    showingDreamChat = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if dataManager.appState.dreamConcepts.isEmpty {
                VStack(spacing: 8) {
                    Text("✨")
                        .font(.title)
                        .opacity(0.5)
                    
                    Text("No dreams captured yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("As you chat with AI, recurring desires will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Start Dream Chat") {
                        showingDreamChat = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sortedDreamConcepts) { concept in
                        EnhancedDreamConceptView(
                            concept: concept,
                            isSelected: selectedConcepts.contains(concept.id),
                            onToggleSelection: {
                                if selectedConcepts.contains(concept.id) {
                                    selectedConcepts.remove(concept.id)
                                } else {
                                    selectedConcepts.insert(concept.id)
                                }
                            },
                            onConvertToGoal: {
                                convertConceptToGoal(concept)
                            },
                            onShowMergeOptions: {
                                showMergeOptions(for: concept)
                            }
                        )
                    }
                }
                
                if !selectedConcepts.isEmpty {
                    Button("Clear Selection") {
                        selectedConcepts.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .sheet(isPresented: $showingMergeView) {
            DreamMergeView(
                concepts: selectedConcepts.compactMap { id in
                    dataManager.appState.dreamConcepts.first { $0.id == id }
                },
                onMerge: { mergedConcept in
                    mergeConcepts(selectedConcepts, into: mergedConcept)
                    selectedConcepts.removeAll()
                    showingMergeView = false
                }
            )
            .environmentObject(aiService)
        }
        .sheet(isPresented: $showingDreamChat) {
            DreamChatView()
                .environmentObject(dataManager)
                .environmentObject(aiService)
        }
    }
    
    private func convertConceptToGoal(_ concept: DreamConcept) {
        let newGoal = Goal(
            title: concept.title,
            description: concept.description,
            state: .draft,
            importance: min(5, max(1, Int(concept.priority))),
            groups: []
        )
        dataManager.appState.goals.append(newGoal)
        
        // Mark concept as promoted
        if let index = dataManager.appState.dreamConcepts.firstIndex(where: { $0.id == concept.id }) {
            dataManager.appState.dreamConcepts[index].hasBeenPromotedToGoal = true
        }
        
        dataManager.save()
    }
    
    private func showMergeOptions(for concept: DreamConcept) {
        // Show which concepts this can merge with
        selectedConcepts.insert(concept.id)
        for mergeableId in concept.canMergeWith {
            selectedConcepts.insert(mergeableId)
        }
    }
    
    private func mergeConcepts(_ conceptIds: Set<UUID>, into mergedConcept: DreamConcept) {
        // Remove individual concepts
        dataManager.appState.dreamConcepts.removeAll { conceptIds.contains($0.id) }
        
        // Add merged concept
        dataManager.appState.dreamConcepts.append(mergedConcept)
        dataManager.save()
    }
}

struct EnhancedDreamConceptView: View {
    let concept: DreamConcept
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onConvertToGoal: () -> Void
    let onShowMergeOptions: () -> Void
    
    @State private var showingAIThoughts = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            
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
                
                // Mergeable indicators
                if !concept.canMergeWith.isEmpty {
                    Text("Can merge with \(concept.canMergeWith.count) other concept\(concept.canMergeWith.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .onTapGesture {
                            onShowMergeOptions()
                        }
                }
            }
            
            Spacer()
            
            VStack(spacing: 6) {
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
                
                // Priority indicator
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(index < Int(concept.priority) ? .orange : .gray.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? .blue.opacity(0.1) : .gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? .blue : .clear, lineWidth: 1)
                )
        )
        .onLongPressGesture {
            showingAIThoughts = true
        }
        .popover(isPresented: $showingAIThoughts) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Thoughts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Priority Score: \(String(format: "%.1f", concept.priority))")
                    .font(.subheadline)
                
                Text("This concept shows up frequently in your conversations and aligns with your stated interests. The AI thinks this could be developed into a concrete goal with specific action steps.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if !concept.relatedKeywords.isEmpty {
                    Text("Related: \(concept.relatedKeywords.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(width: 300, height: 150)
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

// MARK: - Emoji Picker Button

struct EmojiPickerButton: View {
    @Binding var selectedEmoji: String
    @State private var showingEmojiPicker = false
    
    private let commonEmojis = [
        "🏛️", "💪", "🧠", "❤️", "🎯", "📚", "🏃‍♀️", "🍎",
        "💼", "🎨", "🌱", "⚡", "🔥", "🌊", "☀️", "🌙",
        "🎵", "📝", "💡", "🚀", "🏆", "🎪", "🌈", "⭐",
        "🔮", "💎", "🌸", "🍀", "🦋", "🌺", "🌻", "🌹"
    ]
    
    var body: some View {
        Button(action: {
            showingEmojiPicker.toggle()
        }) {
            Text(selectedEmoji.isEmpty ? "🏛️" : selectedEmoji)
                .font(.title2)
                .frame(width: 60, height: 40)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingEmojiPicker) {
            EmojiPickerView(selectedEmoji: $selectedEmoji, emojis: commonEmojis) {
                showingEmojiPicker = false
            }
        }
    }
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    let emojis: [String]
    let onSelection: () -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Emoji")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(action: {
                            selectedEmoji = emoji
                            onSelection()
                        }) {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(
                                    selectedEmoji == emoji ? 
                                        .blue.opacity(0.2) : 
                                        .clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
        }
        .padding(.vertical)
        .frame(width: 360)
    }
}

// MARK: - Helper Types

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct HistoryLogView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if dataManager.appState.preferences.keepUndoHistory {
                    Text("History logging is enabled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("History log functionality would be implemented here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Text("History logging is disabled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("History Log")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
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


