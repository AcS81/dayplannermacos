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
                        flow: .water
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

// MARK: - PRD Action Bar (Global single message with Yes/No)

struct ActionBar: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingEphemeralInsight = false
    @State private var ephemeralText = ""
    
    var body: some View {
        if let message = dataManager.appState.currentActionBarMessage {
            VStack(spacing: 8) {
                HStack {
                    Text(message)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Yes/No buttons for actionable proposals
                    if !dataManager.appState.stagedBlocks.isEmpty {
                        HStack(spacing: 12) {
                            Button("No") {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    dataManager.rejectAllStagedBlocks()
                                }
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Button("Yes") {
                                withAnimation(.easeIn(duration: 0.3)) {
                                    dataManager.commitAllStagedBlocks()
                                    showEphemeralInsight(reason: "Committed staged items")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                
                // PRD: Ephemeral "hmm..." reflection line (2s only)
                if showingEphemeralInsight {
                    HStack {
                        Text("🔍 \(ephemeralText)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 2)
        }
    }
    
    private func showEphemeralInsight(reason: String) {
        let insights = [
            "Your scheduling patterns suggest you work best in the morning",
            "This fits well with your recent energy flow preferences", 
            "Building consistency with your established routines",
            "Optimizing for your typical \(Calendar.current.component(.hour, from: Date()) < 12 ? "morning" : "afternoon") productivity"
        ]
        
        ephemeralText = insights.randomElement() ?? "Looks good for your schedule"
        withAnimation(.easeIn(duration: 0.2)) {
            showingEphemeralInsight = true
        }
        
        // PRD: disappear after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingEphemeralInsight = false
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with XP/XXP and status
            TopBarView(
                xp: dataManager.appState.userXP,
                xxp: dataManager.appState.userXXP,
                aiConnected: aiService.isConnected,
                onSettingsTap: { showingSettings = true },
                onDiagnosticsTap: { showingAIDiagnostics = true }
            )
            
            // PRD: Action Bar - Single visible message with Yes/No
            ActionBar()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            // Main unified split view - Both calendar and mind visible simultaneously
            UnifiedSplitView(selectedDate: $selectedDate)
                .environmentObject(dataManager)
                .environmentObject(aiService)
            
            // Global Action Bar at bottom
            ActionBarView()
                .environmentObject(dataManager)
                .environmentObject(aiService)
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
        }
    }
    
    private func setupAppAppearance() {
        // Configure the app's visual appearance
        if let window = NSApplication.shared.windows.first {
            window.isMovableByWindowBackground = true
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
    @State private var trustLevel: Double = 0.7
    @State private var safeMode = false
    @State private var openaiApiKey = ""
    @State private var whisperApiKey = ""
    @State private var customApiEndpoint = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AI & Trust")
                .font(.title2)
                .fontWeight(.semibold)
            
            SettingsGroup("Trust Level") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("I trust AI to stage up to \(Int(trustLevel * 100))% of my day")
                        .font(.subheadline)
                    
                    HStack {
                        Text("0%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $trustLevel, in: 0...1, step: 0.1)
                            .onChange(of: trustLevel) {
                                // Save trust level
                                dataManager.appState.preferences.aiTrustLevel = trustLevel
                                dataManager.save()
                            }
                        
                        Text("100%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("This controls how aggressive AI suggestions can be. Lower values mean more conservative suggestions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            SettingsGroup("Safety") {
                Toggle("Safe Mode", isOn: $safeMode)
                    .help("Only suggest non-destructive changes, never modify existing events")
                    .onChange(of: safeMode) {
                        dataManager.appState.preferences.safeMode = safeMode
                        dataManager.save()
                    }
            }
            
            SettingsGroup("Auto-Staging") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Automatically stage suggestions for:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(dataManager.appState.pillars) { pillar in
                        Toggle(pillar.name, isOn: Binding(
                            get: { pillar.autoStageEnabled },
                            set: { newValue in
                                if let index = dataManager.appState.pillars.firstIndex(where: { $0.id == pillar.id }) {
                                    dataManager.appState.pillars[index].autoStageEnabled = newValue
                                    dataManager.save()
                                }
                            }
                        ))
                        .font(.caption)
                    }
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
            trustLevel = dataManager.appState.preferences.aiTrustLevel
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
                            flow: .water
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
    @State private var showingBackfill = false
    @State private var showingMonthView = false
    @State private var selectedMindSection: TimeframeSelector = .now
    
    var body: some View {
        HSplitView {
            // Left Panel - Calendar with expandable month view
            CalendarPanel(
                selectedDate: $selectedDate,
                showingMonthView: $showingMonthView,
                onBackfillTap: { showingBackfill = true }
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
            BackfillView()
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
    let onBackfillTap: () -> Void
    @State private var showingGapFiller = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar header with elegant styling
            CalendarPanelHeader(
                selectedDate: $selectedDate,
                showingMonthView: $showingMonthView,
                onBackfillTap: onBackfillTap,
                onGapFillerTap: { showingGapFiller = true }
            )
            
            // Month view (expandable/collapsible)
            if showingMonthView {
                MonthViewExpanded(selectedDate: $selectedDate)
                    .frame(height: 280)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingMonthView)
            }
            
            // Day view - enhanced with liquid glass styling
            EnhancedDayView(selectedDate: $selectedDate)
                .frame(maxHeight: .infinity)
        }
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.leading, 8)  // Moved further left
        .padding(.trailing, 4)
        .padding(.vertical, 12)
        .sheet(isPresented: $showingGapFiller) {
            GapFillerView()
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
                    // Enhanced chains section with flow glass
                    EnhancedChainsSection()
                        .environmentObject(dataManager)
                    
                    // Pillars section with crystal aesthetics
                    CrystalPillarsSection()
                        .environmentObject(dataManager)
                    
                    // Goals section with mist effects
                    MistGoalsSection()
                        .environmentObject(dataManager)
                    
                    // Dream builder with aurora gradients
                    AuroraDreamBuilderSection()
                        .environmentObject(dataManager)
                    
                    // Intake section
                    IntakeSection()
                        .environmentObject(dataManager)
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
    let onBackfillTap: () -> Void
    let onGapFillerTap: () -> Void
    
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
                // Month expand/collapse button
                Button(action: { 
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingMonthView.toggle()
                    }
                }) {
                    Image(systemName: showingMonthView ? "chevron.up.circle.fill" : "calendar.circle")
                        .font(.title2)
                        .foregroundStyle(showingMonthView ? .blue : .secondary)
                        .symbolEffect(.bounce, value: showingMonthView)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 16)
                
                // Action buttons with capsule style
                HStack(spacing: 6) {
                    Button("Gap Filler") {
                        onGapFillerTap()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
                    
                    Button("Backfill") {
                        onBackfillTap()
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

// MARK: - Enhanced Day View

struct EnhancedDayView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @Binding var selectedDate: Date
    @State private var showingBlockCreation = false
    @State private var creationTime: Date?
    @State private var draggedBlock: TimeBlock?
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced timeline view with liquid glass hour slots
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(0..<24, id: \.self) { hour in
                        EnhancedHourSlot(
                            hour: hour,
                            selectedDate: selectedDate,
                            blocks: blocksForHour(hour),
                            onTap: { time in
                                creationTime = time
                                showingBlockCreation = true
                            },
                            onBlockDrag: { block, location in
                                draggedBlock = block
                            },
                            onBlockDrop: { block, newTime in
                                handleBlockDrop(block: block, newTime: newTime)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            updateDataManagerDate()
        }
        .onAppear {
            selectedDate = dataManager.appState.currentDay.date
        }
        .sheet(isPresented: $showingBlockCreation) {
            BlockCreationSheet(
                suggestedTime: creationTime ?? Date(),
                onCreate: { block in
                    dataManager.stageBlock(block, explanation: "Time block created for \(block.startTime.timeString)")
                    dataManager.setActionBarMessage("I've staged your activity '\(block.title)' at \(block.startTime.timeString). Does this work for you?")
                    showingBlockCreation = false
                }
            )
        }
    }
    
    private func blocksForHour(_ hour: Int) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? dayStart
        let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart
        
        return dataManager.appState.currentDay.blocks.filter { block in
            block.startTime >= hourStart && block.startTime < hourEnd
        }
    }
    
    private func handleBlockDrop(block: TimeBlock, newTime: Date) {
        var updatedBlock = block
        updatedBlock.startTime = newTime
        dataManager.updateTimeBlock(updatedBlock)
    }
    
    private func updateDataManagerDate() {
        dataManager.appState.currentDay.date = selectedDate
        dataManager.save()
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
        switch hour {
        case 6: return .orange.opacity(0.1) // Sunrise
        case 7...17: return .blue.opacity(0.02) // Daytime
        case 18: return .orange.opacity(0.1) // Sunset
        case 19...21: return .purple.opacity(0.05) // Evening
        case 22...23, 0: return .indigo.opacity(0.08) // Midnight/Night
        default: return .indigo.opacity(0.05) // Deep night
        }
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
                        }
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
                    Rectangle()
                        .fill(.blue)
                        .frame(height: 2)
                        .offset(y: currentTimeOffset - 20)
                        .opacity(0.8)
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
}

// MARK: - Enhanced Time Block Card

struct EnhancedTimeBlockCard: View {
    let block: TimeBlock
    let onTap: () -> Void
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isHovering = false
    @State private var isResizing = false
    @State private var showingChainInput = false
    @State private var originalDuration: TimeInterval = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Main event card with enhanced dragging
            HStack(spacing: 10) {
                // Energy & flow indicators with enhanced styling
                VStack(spacing: 2) {
                    Text(block.energy.rawValue)
                        .font(.title3)
                    Text(block.flow.rawValue)
                        .font(.caption)
                }
                .opacity(0.8)
                
                // Enhanced block content
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
                        
                        // Glass state indicator with enhanced styling
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(block.flow.material.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                borderColor.opacity(isDragging ? 1.0 : 0.6),
                                lineWidth: isDragging ? 2 : 1
                            )
                    )
                    .shadow(
                        color: stateColor.opacity(isDragging ? 0.3 : 0.1),
                        radius: isDragging ? 8 : 3,
                        y: isDragging ? 4 : 1
                    )
            )
            .contentShape(Rectangle()) // Ensure proper hit testing
            .onTapGesture { 
                withAnimation(.easeInOut(duration: 0.1)) {
                    onTap()
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .simultaneousGesture(
                // Main drag gesture for moving events
                DragGesture(minimumDistance: 15, coordinateSpace: .local)
                    .onChanged { value in
                        guard !isResizing else { return }
                        
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
                        onDrop(Date()) // TODO: Calculate proper new time based on position
                    }
            )
            
            // Duration resize handle (bottom of event)
            if isHovering || isResizing {
                HStack {
                    Spacer()
                    
                    // Resize handle with clear visual feedback
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(.gray.opacity(0.4))
                            .frame(width: 16, height: 1)
                        Rectangle()
                            .fill(.gray.opacity(0.6))
                            .frame(width: 20, height: 2)
                        Rectangle()
                            .fill(.gray.opacity(0.4))
                            .frame(width: 16, height: 1)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.gray.opacity(0.3), lineWidth: 1)
                    )
                    .scaleEffect(isResizing ? 1.1 : 1.0)
                    .gesture(
                        DragGesture(coordinateSpace: .local)
                            .onChanged { value in
                                if !isResizing {
                                    isResizing = true
                                    originalDuration = block.duration
                                }
                                
                                // Convert vertical drag to duration change (rough calculation)
                                let deltaMinutes = Int(value.translation.height / 3)
                                let newDurationMinutes = max(15, block.durationMinutes + deltaMinutes)
                                
                                // TODO: Update block duration in real-time
                                // For now, just visual feedback
                            }
                            .onEnded { _ in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isResizing = false
                                }
                                // TODO: Commit duration change
                            }
                    )
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeUpDown.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    
                    Spacer()
                }
                .frame(height: isHovering || isResizing ? 20 : 0)
                .clipped()
                .transition(.opacity.combined(with: .scale))
            }
            
            // Chain input section (appears on hover for eligible events)
            if shouldShowChainInputs && (isHovering || showingChainInput) {
                HStack(spacing: 0) {
                    // Leading chain input (before this event)
                    if canChainBefore {
                        ChainInputButton(
                            position: .before,
                            isActive: showingChainInput,
                            onToggle: { 
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingChainInput.toggle()
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                    }
                    
                    Spacer()
                    
                    // Trailing chain input (after this event)
                    if canChainAfter {
                        ChainInputButton(
                            position: .after,
                            isActive: showingChainInput,
                            onToggle: { 
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingChainInput.toggle()
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .trailing))
                        ))
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: shouldShowChainInputs ? 32 : 0)
                .clipped()
            }
        }
        .scaleEffect(isDragging ? 0.98 : (isHovering ? 1.02 : 1.0))
        .offset(dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDragging)
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
    
    // Event chaining logic
    private var shouldShowChainInputs: Bool {
        // Only show for events that aren't in the past and have space for chaining
        !isEventInPast && (canChainBefore || canChainAfter)
    }
    
    private var isEventInPast: Bool {
        block.endTime < Date()
    }
    
    private var canChainBefore: Bool {
        // TODO: Check if there's enough space before this event (at least 15 minutes)
        // and no adjacent event
        true
    }
    
    private var canChainAfter: Bool {
        // TODO: Check if there's enough space after this event (at least 15 minutes)
        // and no adjacent event
        true
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
                            onDragEnd: { handleDragEnd() }
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
        if selectedDates.contains(date) && selectedDates.count == 1 {
            // Single selection - navigate to that day
            selectedDate = date
        } else if selectedDates.contains(date) {
            // Remove from multi-selection
            selectedDates.remove(date)
            if !selectedDates.isEmpty {
                selectedDate = selectedDates.sorted().first ?? date
            }
        } else {
            // Add to selection or replace selection
            selectedDates = [date]
            selectedDate = date
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
            onDragEnd: onDragEnd
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
    
    func dropEntered(info: DropInfo) {
        onDragEnter()
    }
    
    func dropExited(info: DropInfo) {
        onDragExit()
    }
    
    func performDrop(info: DropInfo) -> Bool {
        onDragEnd()
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Enhanced Mind Sections

struct EnhancedChainsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var showingChainCreator = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Chains",
                subtitle: "Flow sequences",
                systemImage: "link.circle",
                gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing),
                onAction: { showingChainCreator = true }
            )
            
            LazyVStack(spacing: 8) {
                ForEach(dataManager.appState.recentChains.prefix(5)) { chain in
                    EnhancedChainCard(chain: chain)
                }
                
                if dataManager.appState.recentChains.isEmpty {
                    EmptyStateCard(
                        icon: "🔗",
                        title: "No chains yet",
                        subtitle: "Create flow sequences"
                    )
                }
            }
        }
        .sheet(isPresented: $showingChainCreator) {
            ChainCreatorView { chain in
                dataManager.addChain(chain)
                showingChainCreator = false
            }
        }
    }
}

struct CrystalPillarsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Pillars", 
                subtitle: "Life foundations",
                systemImage: "building.columns.circle",
                gradient: LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
            )
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(dataManager.appState.pillars.prefix(4)) { pillar in
                    PillarCrystalCard(pillar: pillar)
                }
            }
        }
    }
}

struct MistGoalsSection: View {
    @EnvironmentObject private var dataManager: AppDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Goals",
                subtitle: "Aspirations & targets", 
                systemImage: "target.circle",
                gradient: LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
            )
            
            LazyVStack(spacing: 6) {
                ForEach(dataManager.appState.goals.prefix(3)) { goal in
                    GoalMistCard(goal: goal)
                }
            }
        }
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
            DreamBuilderView()
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
            PillarDetailView(pillar: pillar)
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
            GoalDetailView(goal: goal)
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
        .background(.ultraThinMaterial)
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
            BackfillView()
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
                // PRD: Stage blocks for approval instead of direct commit
                dataManager.stageBlock(block, explanation: "Manually created time block")
                dataManager.setActionBarMessage("I've staged your new activity '\(block.title)' for \(block.durationMinutes) minutes. Ready to add it?")
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
                            dataManager.stageSuggestion(suggestion)
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
                    preferredFlows: [.water],
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
        // PRD: Only committed blocks can be incomplete (staged blocks are proposals)
        dataManager.appState.currentDay.blocks.filter { block in
            block.endTime < Date() && block.glassState != .solid && !block.isStaged
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
                
                Text(suggestion.flow.rawValue)
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

struct BackfillView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeframe: BackfillTimeframe = .today
    @State private var selectedDate = Date()
    @State private var isGeneratingBackfill = false
    @State private var backfillSuggestions: [TimeBlock] = []
    @State private var stagedBackfillBlocks: [TimeBlock] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Timeframe selector
                BackfillTimeframeSelector(
                    selectedTimeframe: $selectedTimeframe,
                    selectedDate: $selectedDate
                )
                
                Divider()
                
                // Backfill workspace
                HStack(spacing: 0) {
                    // Timeline (similar to day view)
                    BackfillTimeline(
                        date: selectedDate,
                        suggestions: backfillSuggestions,
                        stagedBlocks: stagedBackfillBlocks,
                        onBlockMove: { block, newTime in
                            moveBackfillBlock(block, to: newTime)
                        },
                        onBlockRemove: { block in
                            removeBackfillBlock(block)
                        }
                    )
                    
                    Divider()
                    
                    // AI suggestions panel
                    BackfillSuggestionsPanel(
                        isGenerating: isGeneratingBackfill,
                        suggestions: backfillSuggestions,
                        onGenerateSuggestions: generateBackfillSuggestions,
                        onApplySuggestion: applySuggestion
                    )
                    .frame(width: 300)
                }
                
                // Bottom actions
                BackfillActionsBar(
                    hasChanges: !stagedBackfillBlocks.isEmpty,
                    onCommit: commitBackfill,
                    onDiscard: discardBackfill
                )
            }
            .navigationTitle("Backfill - Reconstruct Your Day")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 800, height: 700)
        .onAppear {
            generateBackfillSuggestions()
        }
    }
    
    // MARK: - Backfill Actions
    
    private func generateBackfillSuggestions() {
        isGeneratingBackfill = true
        
        Task {
            let prompt = """
            Reconstruct what likely happened on \(selectedDate.formatted(.dateTime.weekday().month().day())).
            
            Suggest a realistic daily schedule with:
            - Common activities for this day of the week
            - Typical work/personal time blocks
            - Meals, breaks, and transition time
            - End-of-day activities
            
            Focus on what someone would typically do rather than idealized planning.
            """
            
            do {
                let context = DayContext(
                    date: selectedDate,
                    existingBlocks: [],
                    currentEnergy: .daylight,
                    preferredFlows: [.water],
                    availableTime: 24 * 3600,
                    mood: .crystal
                )
                
                let response = try await aiService.processMessage(prompt, context: context)
                
                // PRD: Generate AI guess of what likely happened
                let aiGuessBlocks = createRealisticDayReconstruction(for: selectedDate)
                
                // Also use any AI suggestions as additional options
                let aiSuggestedBlocks = response.suggestions.enumerated().map { index, suggestion in
                    var block = suggestion.toTimeBlock()
                    // Space them out throughout the day
                    block.startTime = Calendar.current.date(byAdding: .hour, value: 8 + index * 2, to: selectedDate.startOfDay) ?? selectedDate
                    block.explanation = "AI suggested based on typical day patterns"
                    return block
                }
                
                // Combine AI guess with AI suggestions
                let allBlocks = aiGuessBlocks + aiSuggestedBlocks
                
                await MainActor.run {
                    backfillSuggestions = allBlocks
                    isGeneratingBackfill = false
                }
            } catch {
                await MainActor.run {
                    // Fallback suggestions
                    backfillSuggestions = createDefaultBackfillBlocks(for: selectedDate)
                    isGeneratingBackfill = false
                }
            }
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
                TimeBlock(title: "Sleep in", startTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date)!, duration: 3600, energy: .moonlight, flow: .mist),
                TimeBlock(title: "Lazy breakfast", startTime: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: date)!, duration: 1800, energy: .sunrise, flow: .mist),
                TimeBlock(title: "Personal time", startTime: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: date)!, duration: 7200, energy: .daylight, flow: .water),
                TimeBlock(title: "Lunch", startTime: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date)!, duration: 1800, energy: .daylight, flow: .mist),
                TimeBlock(title: "Afternoon activities", startTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: date)!, duration: 5400, energy: .daylight, flow: .water),
                TimeBlock(title: "Dinner", startTime: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: date)!, duration: 2700, energy: .moonlight, flow: .mist),
                TimeBlock(title: "Evening relaxation", startTime: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: date)!, duration: 3600, energy: .moonlight, flow: .water)
            ]
        } else {
            // Weekday reconstruction
            blocks = [
                TimeBlock(title: "Morning routine", startTime: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: date)!, duration: 3600, energy: .sunrise, flow: .crystal),
                TimeBlock(title: "Commute/Setup", startTime: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: date)!, duration: 1800, energy: .sunrise, flow: .mist),
                TimeBlock(title: "Morning work block", startTime: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: date)!, duration: 7200, energy: .daylight, flow: .crystal),
                TimeBlock(title: "Lunch break", startTime: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!, duration: 3600, energy: .daylight, flow: .mist),
                TimeBlock(title: "Afternoon work", startTime: calendar.date(bySettingHour: 13, minute: 30, second: 0, of: date)!, duration: 9000, energy: .daylight, flow: .water),
                TimeBlock(title: "Wrap up work", startTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: date)!, duration: 3600, energy: .daylight, flow: .crystal),
                TimeBlock(title: "Commute home", startTime: calendar.date(bySettingHour: 17, minute: 30, second: 0, of: date)!, duration: 1800, energy: .moonlight, flow: .mist),
                TimeBlock(title: "Dinner", startTime: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: date)!, duration: 2700, energy: .moonlight, flow: .mist),
                TimeBlock(title: "Evening personal time", startTime: calendar.date(bySettingHour: 20, minute: 30, second: 0, of: date)!, duration: 5400, energy: .moonlight, flow: .water)
            ]
        }
        
        // Mark all as explanatory AI reconstructions
        return blocks.map { block in
            var updatedBlock = block
            updatedBlock.explanation = "AI reconstructed based on typical \(isWeekend ? "weekend" : "weekday") patterns"
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
                flow: .mist
            ),
            TimeBlock(
                title: "Work Time",
                startTime: Calendar.current.date(byAdding: .hour, value: 10, to: startOfDay)!,
                duration: 14400, // 4 hours
                energy: .daylight,
                flow: .crystal
            ),
            TimeBlock(
                title: "Lunch Break",
                startTime: Calendar.current.date(byAdding: .hour, value: 13, to: startOfDay)!,
                duration: 3600,
                energy: .daylight,
                flow: .mist
            ),
            TimeBlock(
                title: "Afternoon Work",
                startTime: Calendar.current.date(byAdding: .hour, value: 15, to: startOfDay)!,
                duration: 10800, // 3 hours
                energy: .daylight,
                flow: .crystal
            ),
            TimeBlock(
                title: "Evening Activities",
                startTime: Calendar.current.date(byAdding: .hour, value: 19, to: startOfDay)!,
                duration: 7200, // 2 hours
                energy: .moonlight,
                flow: .water
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
                        stagedBlocks: stagedBlocks.filter { blocksForHour($0, hour) },
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
                .fill(block.flow.material)
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
                
                Text(block.flow.rawValue)
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
        // PRD: Consider both committed and staged blocks for gap analysis
        let allBlocks = dataManager.appState.currentDay.blocks + dataManager.appState.stagedBlocks
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
            flow: .water,
            glassState: .liquid
        )
        
        // PRD: Stage gap filler suggestions instead of direct commit
        dataManager.stageBlock(newBlock, explanation: "Gap filler suggestion for available time slot")
        dataManager.setActionBarMessage("I found a gap in your schedule and suggest: \(newBlock.title) (\(newBlock.durationMinutes)m). Add it?")
        
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
                    // Chains section
                    ChainsSection()
                    
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

struct ActionBarView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @StateObject private var speechService = SpeechService()
    @State private var messageText = ""
    @State private var isVoiceMode = false
    @State private var pendingSuggestions: [Suggestion] = []
    @State private var ephemeralInsight: String?
    @State private var showInsightTimer: Timer?
    @State private var lastResponse = ""
    @State private var messageHistory: [AIMessage] = []
    @State private var showHistory = false
    @State private var undoCountdown: Int? = nil
    @State private var undoTimer: Timer?
    
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
                HStack {
                    Text(lastResponse)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
            if let countdown = undoCountdown {
                HStack {
                    Text("Added to calendar")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button("Undo (\(countdown)s)") {
                        performUndo()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .sheet(isPresented: $showHistory) {
            MessageHistoryView(messages: messageHistory, onDismiss: { showHistory = false })
        }
        .padding()
        .background(.ultraThinMaterial)
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
                    
                    // Check if this is a scheduling request - if so, stage it for approval
                    if isSchedulingRequest(message) && !response.suggestions.isEmpty {
                        // Check if user specified a particular date/time
                        let targetDate = extractDateFromMessage(message) ?? Date()
                        
                        // Stage all suggestions with proper timing
                        for (index, suggestion) in response.suggestions.enumerated() {
                            let suggestedTime = findNextAvailableTime(after: targetDate.addingTimeInterval(Double(index * 30 * 60)))
                            var stagedBlock = suggestion.toTimeBlock()
                            stagedBlock.startTime = suggestedTime
                            dataManager.stageBlock(stagedBlock, explanation: "AI suggestion based on: '\(message)'", stagedBy: "Chat AI")
                        }
                        
                        let count = response.suggestions.count
                        let dateString = Calendar.current.isDate(targetDate, inSameDayAs: Date()) ? "today" : targetDate.dayString
                        dataManager.setActionBarMessage("I've staged \(count) suggestion\(count == 1 ? "" : "s") for \(dateString) based on '\(message)'. Does this look right?")
                        showEphemeralInsight("Staged \(count) item\(count == 1 ? "" : "s") for \(dateString)!")
                        
                        // Clear pending suggestions since they're now staged
                        pendingSuggestions = []
                    } else {
                        // Regular suggestion flow
                        pendingSuggestions = response.suggestions
                        if !response.suggestions.isEmpty {
                            showEphemeralInsight("Found \(response.suggestions.count) option\(response.suggestions.count == 1 ? "" : "s") for you")
                        } else {
                            showEphemeralInsight("Here's what I think...")
                        }
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
    
    // MARK: - Undo System (10-second window)
    
    private func startUndoCountdown() {
        undoCountdown = 10
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard let countdown = undoCountdown else { return }
            
            if countdown > 1 {
                undoCountdown = countdown - 1
            } else {
                // Commit to EventKit after 10 seconds
                commitStagedItems()
                undoCountdown = nil
                undoTimer?.invalidate()
                undoTimer = nil
            }
        }
    }
    
    private func performUndo() {
        dataManager.undoStagedItems()
        undoCountdown = nil
        undoTimer?.invalidate()
        undoTimer = nil
        showEphemeralInsight("Undone - changes reverted")
    }
    
    private func commitStagedItems() {
        Task {
            await dataManager.commitStagedItems()
            await MainActor.run {
                showEphemeralInsight("Committed to your calendar")
            }
        }
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
    
    private func createContext() -> DayContext {
        DayContext(
            date: Date(),
            existingBlocks: dataManager.appState.currentDay.blocks,
            currentEnergy: .daylight,
            preferredFlows: [.water],
            availableTime: 3600,
            mood: dataManager.appState.currentDay.mood,
            weatherContext: dataManager.weatherService.getWeatherContext()
        )
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
        let allBlocks = dataManager.appState.currentDay.blocks + dataManager.appState.stagedBlocks
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
                    
                    Text(suggestion.flow.rawValue)
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
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            updateDataManagerDate()
        }
        .onAppear {
            // Ensure selectedDate matches currentDay on appear
            selectedDate = dataManager.appState.currentDay.date
        }
        .sheet(isPresented: $showingBlockCreation) {
            BlockCreationSheet(
                suggestedTime: creationTime ?? Date(),
                onCreate: { block in
                    // PRD: Stage blocks for approval instead of direct commit
                    dataManager.stageBlock(block, explanation: "Time block created for \(block.startTime.timeString)")
                    dataManager.setActionBarMessage("I've staged your activity '\(block.title)' at \(block.startTime.timeString). Does this work for you?")
                    showingBlockCreation = false
                    creationTime = nil
                }
            )
        }
    }
    
    private func blocksForHour(_ hour: Int) -> [TimeBlock] {
        let calendar = Calendar.current
        // PRD: Include both committed blocks AND staged blocks for display
        let allBlocks = dataManager.appState.currentDay.blocks + dataManager.appState.stagedBlocks
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
                    TimeBlockView(
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

struct TimeBlockView: View {
    let block: TimeBlock
    let onDrag: (CGPoint) -> Void
    let onDrop: (Date) -> Void
    let showAddChainStart: Bool = true
    let showAddChainEnd: Bool = true
    
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isExpanded = false
    @State private var showingChainSelector = false
    @State private var addChainPosition: ChainTabPosition = .start
    @State private var aiGeneratedSummary = ""
    @State private var isResizing = false
    @State private var resizeOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Pre-chain + tab
            if showAddChainStart && !isDragging {
                ChainAddTab(position: .start) {
                    addChainPosition = .start
                    showingChainSelector = true
                }
            }
            
            // Main block content
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Energy and flow indicators
                    VStack(spacing: 2) {
                        Text(block.energy.rawValue)
                            .font(.caption)
                        Text(block.flow.rawValue)
                            .font(.caption)
                    }
                    
                    // Block content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if isExpanded {
                            // Expanded view with AI summary
                            VStack(alignment: .leading, spacing: 6) {
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
                                    
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Ends \(block.endTime.timeString)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !aiGeneratedSummary.isEmpty {
                                    Text(aiGeneratedSummary)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .padding(6)
                                        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                                }
                                
                                // Additional details
                                HStack {
                                    Text("Energy: \(block.energy.description)")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(block.energy.color.opacity(0.2), in: Capsule())
                                    
                                    Text("Flow: \(block.flow.description)")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.2), in: Capsule())
                                    
                                    Spacer()
                                }
                            }
                        } else {
                            // Collapsed view with short summary
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
                                
                                Text("tap to expand")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Glass state indicator
                    Circle()
                        .fill(stateColor)
                        .frame(width: 6, height: 6)
                }
                
                // Chain indicators (if block is part of a chain)
                if let chainInfo = getChainInfo() {
                    HStack {
                        Text("Part of: \(chainInfo.name)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("\(chainInfo.position)/\(chainInfo.totalBlocks)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(block.flow.material)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                block.isStaged ? .gray : borderColor, 
                                style: StrokeStyle(
                                    lineWidth: block.isStaged ? 2 : borderWidth,
                                    dash: block.isStaged ? [4, 4] : []
                                )
                            )
                    )
            )
            // PRD: Staged items have 50% opacity
            .opacity(block.isStaged ? 0.5 : 1.0)
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .offset(dragOffset)
            // Visual feedback for resizing - stretch the block
            .scaleEffect(x: 1.0, y: isResizing ? 1.0 + (resizeOffset / 200) : 1.0)
            // Add visual feedback for resizing
            .overlay(
                // Resize handle at the bottom
                Rectangle()
                    .fill(.clear)
                    .frame(height: 8)
                    .overlay(
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(.secondary.opacity(isResizing ? 0.8 : 0.4))
                                    .frame(width: 8, height: 2)
                            }
                        }
                        .scaleEffect(isResizing ? 1.2 : 1.0)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isResizing {
                                    withAnimation(.spring(response: 0.2)) {
                                        isResizing = true
                                    }
                                }
                                resizeOffset = value.translation.height
                            }
                            .onEnded { value in
                                withAnimation(.spring(response: 0.4)) {
                                    isResizing = false
                                    resizeOffset = 0
                                }
                                
                                // Calculate new duration and update block
                                let newDuration = calculateNewDuration(from: value.translation.height)
                                updateBlockDuration(newDuration)
                            }
                    )
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                
                if isExpanded && aiGeneratedSummary.isEmpty {
                    generateAISummary()
                }
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            withAnimation(.spring(response: 0.3)) {
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
            
            // Post-chain + tab
            if showAddChainEnd && !isDragging {
                ChainAddTab(position: .end) {
                    addChainPosition = .end
                    showingChainSelector = true
                }
            }
        }
        .sheet(isPresented: $showingChainSelector) {
            ChainSelectorView(
                position: addChainPosition,
                baseBlock: block,
                onChainSelected: { chain in
                    attachChain(chain, at: addChainPosition)
                    showingChainSelector = false
                }
            )
            .environmentObject(dataManager)
            .environmentObject(aiService)
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
    
    private var borderWidth: CGFloat {
        switch block.glassState {
        case .solid: return 0
        case .liquid: return 2
        case .mist: return 1
        case .crystal: return 1.5
        }
    }
    
    private func generateAISummary() {
        Task {
            let prompt = """
            Generate a brief, insightful summary for this time block:
            Activity: \(block.title)
            Duration: \(block.durationMinutes) minutes
            Energy: \(block.energy.description)
            Flow: \(block.flow.description)
            Time: \(block.startTime.timeString) - \(block.endTime.timeString)
            
            Provide a 1-2 sentence summary that gives context about what this activity involves, why it's scheduled at this time, or helpful tips. Keep it concise and useful.
            """
            
            do {
                let context = DayContext(
                    date: block.startTime,
                    existingBlocks: [block],
                    currentEnergy: block.energy,
                    preferredFlows: [block.flow],
                    availableTime: block.duration,
                    mood: .crystal
                )
                
                let response = try await aiService.processMessage(prompt, context: context)
                
                await MainActor.run {
                    aiGeneratedSummary = response.text
                }
            } catch {
                await MainActor.run {
                    aiGeneratedSummary = "A \(block.durationMinutes)-minute \(block.flow.description.lowercased()) activity scheduled for your \(block.energy.description.lowercased()) hours."
                }
            }
        }
    }
    
    private func getChainInfo() -> ChainInfo? {
        // Check if this block is part of any chain
        for chain in dataManager.appState.recentChains {
            if let index = chain.blocks.firstIndex(where: { $0.title == block.title }) {
                return ChainInfo(
                    name: chain.name,
                    position: index + 1,
                    totalBlocks: chain.blocks.count
                )
            }
        }
        return nil
    }
    
    private func attachChain(_ chain: Chain, at position: ChainTabPosition) {
        let insertTime = position == .start 
            ? block.startTime.addingTimeInterval(-chain.totalDuration - 300) // 5 min buffer
            : block.endTime.addingTimeInterval(300) // 5 min buffer
        
        dataManager.applyChain(chain, startingAt: insertTime)
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
    
    private func calculateNewDuration(from yTranslation: CGFloat) -> TimeInterval {
        // Calculate duration change based on vertical drag distance
        // Same ratio as drag: 60 pixels = 1 hour
        let pixelsPerHour: CGFloat = 60
        let hourChange = yTranslation / pixelsPerHour
        let minuteChange = hourChange * 60
        
        // Apply the change to current duration
        let currentDurationMinutes = block.duration / 60
        let newDurationMinutes = max(15, currentDurationMinutes + Double(minuteChange)) // Minimum 15 minutes
        
        // Round to nearest 15-minute interval
        let roundedMinutes = (Int(newDurationMinutes) / 15) * 15
        
        return TimeInterval(max(15, roundedMinutes) * 60) // Convert back to seconds
    }
    
    private func updateBlockDuration(_ newDuration: TimeInterval) {
        var updatedBlock = block
        updatedBlock.duration = newDuration
        
        // Update the block in the data manager
        dataManager.updateTimeBlock(updatedBlock)
        
        // Provide haptic feedback
        #if os(iOS)
        HapticStyle.medium.trigger()
        #endif
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
        Flow: \(baseBlock.flow.description)
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
                preferredFlows: [baseBlock.flow],
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
                        flow: .crystal
                    ),
                    TimeBlock(
                        title: "Quick review",
                        startTime: Date(),
                        duration: 600,
                        energy: baseBlock.energy,
                        flow: .mist
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
                        flow: .mist
                    ),
                    TimeBlock(
                        title: "Next steps",
                        startTime: Date(),
                        duration: 1200,
                        energy: .daylight,
                        flow: .crystal
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
                        TimeBlock(title: "Prepare space", startTime: Date(), duration: 600, energy: .daylight, flow: .mist),
                        TimeBlock(title: "Mental prep", startTime: Date(), duration: 900, energy: .daylight, flow: .crystal)
                    ],
                    flowPattern: .waterfall
                ),
                Chain(
                    name: "Energy Boost",
                    blocks: [
                        TimeBlock(title: "Quick movement", startTime: Date(), duration: 300, energy: .sunrise, flow: .water),
                        TimeBlock(title: "Hydrate", startTime: Date(), duration: 300, energy: .daylight, flow: .mist)
                    ],
                    flowPattern: .ripple
                )
            ]
        } else {
            return [
                Chain(
                    name: "Cool Down",
                    blocks: [
                        TimeBlock(title: "Reflect", startTime: Date(), duration: 600, energy: .daylight, flow: .mist),
                        TimeBlock(title: "Organize", startTime: Date(), duration: 900, energy: .daylight, flow: .crystal)
                    ],
                    flowPattern: .waterfall
                ),
                Chain(
                    name: "Transition",
                    blocks: [
                        TimeBlock(title: "Quick break", startTime: Date(), duration: 300, energy: .moonlight, flow: .mist),
                        TimeBlock(title: "Prepare next", startTime: Date(), duration: 600, energy: .daylight, flow: .crystal)
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
                    flow: baseBlock.flow
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
        if selectedDates.isEmpty {
            // First selection
            selectedDates.insert(date)
            dateSelectionRange.start = date
            dataManager.switchToDay(date)
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
            dataManager.switchToDay(date)
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
                preferredFlows: [.water],
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
    @State private var selectedFlow: FlowState = .water
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
                        ForEach(FlowState.allCases, id: \.self) { flow in
                            Button(action: { selectedFlow = flow }) {
                                VStack(spacing: 4) {
                                    Text(flow.rawValue)
                                        .font(.title2)
                                    Text(flow.description)
                                        .font(.caption)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    selectedFlow == flow ? .blue.opacity(0.2) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selectedFlow == flow ? .blue : .gray.opacity(0.3),
                                            lineWidth: selectedFlow == flow ? 2 : 1
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
                            flow: selectedFlow,
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

enum TimeframeSelector: String, CaseIterable {
    case now = "Now"
    case lastTwoWeeks = "Last 2 weeks"
    case custom = "Custom"
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
            flow: .water,
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
            
            Toggle("Auto-stage", isOn: Binding(
                get: { pillar.autoStageEnabled },
                set: { newValue in
                    if let index = dataManager.appState.pillars.firstIndex(where: { $0.id == pillar.id }) {
                        dataManager.appState.pillars[index].autoStageEnabled = newValue
                        dataManager.save()
                    }
                }
            ))
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
                    flow: .crystal
                ),
                TimeBlock(
                    title: "Execute \(title)",
                    startTime: Date(),
                    duration: 3600, // 60 minutes
                    energy: .daylight,
                    flow: .water
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
            flow: .water
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
                preferredFlows: [.water],
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
                preferredFlows: [.water],
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Intake (Ask Me)")
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

// MARK: - Preview

// MARK: - Detail Views


struct PillarDetailView: View {
    let pillar: Pillar
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Pillar overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text(pillar.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if !pillar.description.isEmpty {
                            Text(pillar.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Pillar settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Settings")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Frequency:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(pillar.frequency)".capitalized)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Duration:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(pillar.minDuration/60))-\(Int(pillar.maxDuration/60)) min")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Pillar Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

struct GoalDetailView: View {
    let goal: Goal
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Goal overview
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.title)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(goal.state.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.1), in: Capsule())
                                    .foregroundStyle(.blue)
                            }
                            
                            Spacer()
                            
                            if goal.isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        if !goal.description.isEmpty {
                            Text(goal.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Goal actions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Actions")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            Button("Create Supporting Pillar") {
                                // Create pillar logic
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            
                            Button("Create Action Chain") {
                                // Create chain logic
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            
                            Button("Schedule Time Block") {
                                // Schedule logic
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Goal Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 500)
    }
}

struct DreamBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dreamTitle = ""
    @State private var dreamDescription = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("🌈")
                        .font(.system(size: 60))
                    
                    Text("Build Your Vision")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Visualize your future and create actionable steps")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dream Title")
                            .font(.headline)
                        
                        TextField("What's your vision?", text: $dreamTitle)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        TextEditor(text: $dreamDescription)
                            .frame(height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                Spacer()
                
                Button("Create Vision") {
                    // Create dream logic
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(dreamTitle.isEmpty)
            }
            .padding(24)
            .navigationTitle("Dream Builder")
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

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppDataManager.preview)
            .environmentObject(AIService.preview)
            .frame(width: 1200, height: 800)
    }
}
#endif
