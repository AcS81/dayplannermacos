# Privacy Implementation Guide

## Overview

This document details privacy-first implementation practices for the Day Planner app, ensuring complete user control over personal data and transparent data usage.

## Privacy Architecture

### Core Privacy Principles

1. **Local-First Processing**: All AI and data processing happens on-device
2. **Data Minimization**: Collect only necessary data for functionality
3. **User Control**: Complete transparency and control over all data usage
4. **Zero Cloud Dependency**: No data leaves the device without explicit user action
5. **Consent-Based Features**: All data access requires informed consent
6. **Data Portability**: Users can export all their data at any time

## Data Collection & Usage

### 1. Data Categories

#### Essential Data (Required for Core Functionality)
```swift
enum EssentialDataType {
    case calendarEvents        // From EventKit
    case userPreferences       // App settings
    case chains                // User-created activity sequences
    case goals                 // User-defined objectives
    case pillars              // User categories for activities
    case xpProgress           // Achievement tracking
    
    var privacyDescription: String {
        switch self {
        case .calendarEvents:
            return "Calendar events are accessed to provide scheduling suggestions"
        case .userPreferences:
            return "Settings are stored to personalize your experience"
        case .chains:
            return "Activity sequences you create are stored for reuse"
        case .goals:
            return "Your goals are stored to provide relevant suggestions"
        case .pillars:
            return "Activity categories help organize your time"
        case .xpProgress:
            return "Progress tracking motivates continued app usage"
        }
    }
}
```

#### Optional Data (Enhanced Features)
```swift
enum OptionalDataType {
    case voiceRecordings      // For speech-to-text (processed locally)
    case locationData         // For location-aware suggestions
    case weatherData          // For weather-aware planning
    case healthData           // For activity suggestions
    
    var privacyDescription: String {
        switch self {
        case .voiceRecordings:
            return "Voice input is processed on-device and never stored"
        case .locationData:
            return "Location enables travel time and location-aware suggestions"
        case .weatherData:
            return "Weather data helps suggest appropriate activities"
        case .healthData:
            return "Health data can inform activity suggestions"
        }
    }
    
    var isEnabled: Bool {
        switch self {
        case .voiceRecordings:
            return UserSettings.shared.enableVoiceInput
        case .locationData:
            return UserSettings.shared.enableLocationServices
        case .weatherData:
            return UserSettings.shared.enableWeatherIntegration
        case .healthData:
            return UserSettings.shared.enableHealthIntegration
        }
    }
}
```

### 2. Data Usage Transparency

#### Privacy Dashboard
```swift
struct PrivacyDashboardView: View {
    @StateObject private var privacyManager = PrivacyManager()
    
    var body: some View {
        NavigationView {
            List {
                Section("Data Usage") {
                    ForEach(privacyManager.dataUsageSummary, id: \.type) { usage in
                        DataUsageRowView(usage: usage)
                    }
                }
                
                Section("AI Knowledge") {
                    NavigationLink("What the AI Knows About You") {
                        AIKnowledgeView()
                    }
                }
                
                Section("Data Export") {
                    Button("Export All Data") {
                        privacyManager.exportAllData()
                    }
                    
                    Button("Delete All Data") {
                        privacyManager.showDeleteConfirmation = true
                    }
                }
                
                Section("Privacy Controls") {
                    ForEach(OptionalDataType.allCases, id: \.self) { dataType in
                        PrivacyToggleView(dataType: dataType)
                    }
                }
            }
            .navigationTitle("Privacy & Data")
        }
        .sheet(isPresented: $privacyManager.showDeleteConfirmation) {
            DataDeletionConfirmationView()
        }
    }
}
```

#### AI Knowledge Transparency
```swift
struct AIKnowledgeView: View {
    @StateObject private var knowledgeManager = AIKnowledgeManager()
    
    var body: some View {
        List {
            Section("Personal Patterns") {
                ForEach(knowledgeManager.userPatterns) { pattern in
                    VStack(alignment: .leading) {
                        Text(pattern.description)
                            .font(.subheadline)
                        Text("Confidence: \(Int(pattern.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Spacer()
                            Button("Delete") {
                                knowledgeManager.deletePattern(pattern.id)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Section("Preferences") {
                ForEach(knowledgeManager.learnedPreferences) { preference in
                    HStack {
                        Text(preference.key)
                        Spacer()
                        Text(preference.value)
                            .foregroundColor(.secondary)
                        Button("Edit") {
                            knowledgeManager.editPreference(preference.id)
                        }
                        .font(.caption)
                    }
                }
            }
            
            Section("Recent Context") {
                Text("Last 24 hours of interactions:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(knowledgeManager.recentInteractions) { interaction in
                    VStack(alignment: .leading) {
                        Text(interaction.summary)
                            .font(.caption)
                        Text(interaction.timestamp.formatted(.dateTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Clear Recent Context") {
                    knowledgeManager.clearRecentContext()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .navigationTitle("AI Knowledge")
        .toolbar {
            Button("Clear All AI Knowledge") {
                knowledgeManager.clearAllKnowledge()
            }
        }
    }
}
```

## Privacy Controls

### 1. Granular Permissions

#### Permission Manager
```swift
class PrivacyPermissionManager {
    enum Permission {
        case calendarAccess
        case speechRecognition
        case locationServices
        case weatherData
        case healthKitAccess
        
        var systemPermission: Any.Type? {
            switch self {
            case .calendarAccess:
                return EKEventStore.self
            case .speechRecognition:
                return SFSpeechRecognizer.self
            case .locationServices:
                return CLLocationManager.self
            default:
                return nil
            }
        }
    }
    
    func requestPermission(_ permission: Permission) async -> Bool {
        // Show privacy explanation before requesting
        let userConsent = await showPrivacyExplanation(for: permission)
        guard userConsent else { return false }
        
        // Request system permission
        switch permission {
        case .calendarAccess:
            return await requestCalendarPermission()
        case .speechRecognition:
            return await requestSpeechPermission()
        case .locationServices:
            return await requestLocationPermission()
        case .weatherData:
            return await requestWeatherDataConsent()
        case .healthKitAccess:
            return await requestHealthKitPermission()
        }
    }
    
    private func showPrivacyExplanation(for permission: Permission) async -> Bool {
        let explanation = PrivacyExplanation(
            permission: permission,
            dataUsage: getDataUsageDescription(permission),
            retention: getDataRetentionPolicy(permission),
            sharing: "Data never leaves your device"
        )
        
        return await PrivacyConsentView.show(explanation)
    }
}
```

#### Dynamic Privacy Controls
```swift
struct PrivacyControlsView: View {
    @StateObject private var privacySettings = PrivacySettings.shared
    
    var body: some View {
        Form {
            Section("Data Processing") {
                Toggle("Local AI Processing Only", isOn: $privacySettings.localAIOnly)
                    .help("When enabled, all AI processing happens on-device only")
                
                Toggle("Minimize Data Collection", isOn: $privacySettings.minimizeDataCollection)
                    .help("Collect only essential data for core functionality")
            }
            
            Section("Optional Features") {
                Toggle("Voice Input", isOn: $privacySettings.enableVoiceInput)
                    .help("Process voice commands on-device using Speech framework")
                
                Toggle("Location Awareness", isOn: $privacySettings.enableLocationServices)
                    .help("Use location for travel time and location-aware suggestions")
                
                Toggle("Weather Integration", isOn: $privacySettings.enableWeatherIntegration)
                    .help("Fetch weather data to suggest appropriate activities")
            }
            
            Section("Data Retention") {
                Picker("AI Context Retention", selection: $privacySettings.contextRetention) {
                    Text("1 Hour").tag(ContextRetention.oneHour)
                    Text("24 Hours").tag(ContextRetention.oneDay)
                    Text("1 Week").tag(ContextRetention.oneWeek)
                    Text("Never Delete").tag(ContextRetention.permanent)
                }
                
                Picker("Conversation History", selection: $privacySettings.conversationRetention) {
                    Text("Current Session Only").tag(ConversationRetention.session)
                    Text("1 Day").tag(ConversationRetention.oneDay)
                    Text("1 Week").tag(ConversationRetention.oneWeek)
                    Text("1 Month").tag(ConversationRetention.oneMonth)
                }
            }
            
            Section("Advanced Privacy") {
                Toggle("Ephemeral Mode", isOn: $privacySettings.ephemeralMode)
                    .help("Clear all AI context and conversations on app restart")
                
                Toggle("Private Analytics", isOn: $privacySettings.enablePrivateAnalytics)
                    .help("Collect anonymous usage statistics locally for app improvement")
            }
        }
        .navigationTitle("Privacy Settings")
    }
}
```

### 2. Data Export & Portability

#### Comprehensive Data Export
```swift
class DataExportManager {
    func exportAllUserData() async throws -> URL {
        let exportData = UserDataExport()
        
        // Collect all user data
        exportData.events = try await EventRepository().fetchAllEvents()
        exportData.chains = try await ChainRepository().fetchAllChains()
        exportData.goals = try await GoalRepository().fetchAllGoals()
        exportData.pillars = try await PillarRepository().fetchAllPillars()
        exportData.preferences = try await PreferencesRepository().fetchAllPreferences()
        exportData.xpHistory = try await XPRepository().fetchAllEntries()
        exportData.conversationHistory = try await ConversationRepository().fetchAllConversations()
        
        // Include metadata
        exportData.metadata = ExportMetadata(
            exportDate: Date(),
            appVersion: Bundle.main.appVersion,
            dataVersion: "1.0",
            totalRecords: exportData.totalRecordCount
        )
        
        // Encrypt export file with user-provided password
        let exportURL = try await createEncryptedExport(exportData)
        
        // Log export for audit trail
        PrivacyAuditLogger.log(.dataExported(recordCount: exportData.totalRecordCount))
        
        return exportURL
    }
    
    private func createEncryptedExport(_ data: UserDataExport) async throws -> URL {
        let jsonData = try JSONEncoder().encode(data)
        
        // Get export password from user
        let password = try await getExportPassword()
        
        // Encrypt with user password
        let encryptedData = try CryptoManager.encrypt(jsonData, withPassword: password)
        
        // Save to user-selected location
        let saveURL = try await presentSaveDialog(suggestedName: "DayPlannerExport-\(Date().iso8601String).encrypted")
        try encryptedData.write(to: saveURL)
        
        return saveURL
    }
}

struct UserDataExport: Codable {
    var events: [Event] = []
    var chains: [Chain] = []
    var goals: [Goal] = []
    var pillars: [Pillar] = []
    var preferences: [UserPreference] = []
    var xpHistory: [XPEntry] = []
    var conversationHistory: [AIConversation] = []
    var metadata: ExportMetadata!
    
    var totalRecordCount: Int {
        events.count + chains.count + goals.count + pillars.count + 
        preferences.count + xpHistory.count + conversationHistory.count
    }
}
```

### 3. Data Deletion

#### Comprehensive Data Deletion
```swift
class DataDeletionManager {
    enum DeletionScope {
        case specificDataType(EssentialDataType)
        case conversationHistory
        case aiKnowledge
        case allUserData
    }
    
    func deleteData(scope: DeletionScope) async throws {
        switch scope {
        case .specificDataType(let dataType):
            try await deleteSpecificDataType(dataType)
        case .conversationHistory:
            try await deleteConversationHistory()
        case .aiKnowledge:
            try await deleteAIKnowledge()
        case .allUserData:
            try await deleteAllUserData()
        }
        
        // Secure memory cleanup
        try secureMemoryCleanup()
        
        // Log deletion for audit
        PrivacyAuditLogger.log(.dataDeleted(scope: scope))
    }
    
    private func deleteAllUserData() async throws {
        // Delete from database
        try await EventRepository().deleteAll()
        try await ChainRepository().deleteAll()
        try await GoalRepository().deleteAll()
        try await PillarRepository().deleteAll()
        try await PreferencesRepository().deleteAll()
        try await XPRepository().deleteAll()
        try await ConversationRepository().deleteAll()
        
        // Clear keychain entries
        try SecureKeyManager.deleteAllKeys()
        
        // Clear UserDefaults
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        // Clear all caches
        AIContextManager.shared.clearAllContexts()
        
        // Reset privacy settings to defaults
        PrivacySettings.shared.resetToDefaults()
    }
    
    private func secureMemoryCleanup() throws {
        // Overwrite sensitive memory regions
        // This is a simplified example - actual implementation would be more thorough
        let sensitiveDataCleared = SecureMemoryManager.clearSensitiveMemory()
        
        guard sensitiveDataCleared else {
            throw PrivacyError.memoryCleanupFailed
        }
    }
}
```

## Privacy-Preserving AI

### 1. Local Context Management

#### Context Minimization
```swift
class PrivacyAwareContextManager {
    private let maxContextAge: TimeInterval
    private let maxContextSize: Int
    
    init() {
        let settings = PrivacySettings.shared
        self.maxContextAge = settings.contextRetention.timeInterval
        self.maxContextSize = settings.minimizeDataCollection ? 1000 : 5000
    }
    
    func buildMinimalContext(for request: AIRequest) -> PlanningContext {
        var context = PlanningContext()
        
        // Only include essential information
        context.currentDay = request.targetDate
        context.existingEvents = getRelevantEvents(for: request.targetDate)
        
        // Minimize user preferences to essential ones only
        if PrivacySettings.shared.minimizeDataCollection {
            context.userPreferences = getEssentialPreferences()
        } else {
            context.userPreferences = getAllPreferences()
        }
        
        // Limit historical data based on privacy settings
        let historyLimit = PrivacySettings.shared.contextRetention.historyLimit
        context.recentActivity = getRecentActivity(limit: historyLimit)
        
        // Remove sensitive fields if requested
        if PrivacySettings.shared.removeSensitiveContext {
            context = removeSensitiveInformation(from: context)
        }
        
        return context
    }
    
    private func removeSensitiveInformation(from context: PlanningContext) -> PlanningContext {
        var sanitizedContext = context
        
        // Remove location information
        sanitizedContext.existingEvents = sanitizedContext.existingEvents.map { event in
            var sanitizedEvent = event
            sanitizedEvent.location = nil
            return sanitizedEvent
        }
        
        // Remove personal notes
        sanitizedContext.existingEvents = sanitizedContext.existingEvents.map { event in
            var sanitizedEvent = event
            sanitizedEvent.notes = nil
            return sanitizedEvent
        }
        
        return sanitizedContext
    }
}
```

### 2. Conversation Privacy

#### Automatic Conversation Cleanup
```swift
class ConversationPrivacyManager {
    private let cleanupTimer: Timer
    
    init() {
        // Set up automatic cleanup based on user preferences
        let interval = PrivacySettings.shared.conversationRetention.cleanupInterval
        self.cleanupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.performAutomaticCleanup()
            }
        }
    }
    
    func performAutomaticCleanup() async {
        let retentionPolicy = PrivacySettings.shared.conversationRetention
        
        do {
            // Delete conversations older than retention policy
            let cutoffDate = Date().addingTimeInterval(-retentionPolicy.timeInterval)
            try await ConversationRepository().deleteConversationsBefore(cutoffDate)
            
            // Clear sensitive AI context
            AIContextManager.shared.clearExpiredContexts()
            
            // Clear ephemeral data if in ephemeral mode
            if PrivacySettings.shared.ephemeralMode {
                try await clearEphemeralData()
            }
            
            PrivacyAuditLogger.log(.automaticCleanupPerformed(policy: retentionPolicy))
            
        } catch {
            PrivacyAuditLogger.log(.cleanupFailed(error: error))
        }
    }
    
    private func clearEphemeralData() async throws {
        // Clear all AI-generated content
        try await AIResponseCache.shared.clearAll()
        
        // Clear all staging areas
        StagingManager.shared.clearAllStaged()
        
        // Clear suggestion cache
        SuggestionCache.shared.clearAll()
    }
}
```

## Privacy Audit & Compliance

### 1. Privacy Audit Logging

#### Comprehensive Privacy Events
```swift
class PrivacyAuditLogger {
    enum PrivacyEvent {
        case dataAccessed(type: DataAccessType, purpose: String)
        case dataExported(recordCount: Int)
        case dataDeleted(scope: DeletionScope)
        case permissionRequested(permission: Permission)
        case permissionGranted(permission: Permission)
        case permissionDenied(permission: Permission)
        case aiContextUsed(contextSize: Int, purpose: String)
        case sensitiveDataProcessed(type: SensitiveDataType)
        case automaticCleanupPerformed(policy: ConversationRetention)
        case cleanupFailed(error: Error)
        case privacySettingChanged(setting: String, newValue: String)
    }
    
    static func log(_ event: PrivacyEvent) {
        let logEntry = PrivacyLogEntry(
            event: event,
            timestamp: Date(),
            appVersion: Bundle.main.appVersion
        )
        
        // Log to privacy-specific audit trail
        do {
            try PrivacyAuditStore.shared.store(logEntry)
        } catch {
            // Fallback to system log
            Logger(subsystem: "DayPlanner", category: "Privacy")
                .error("Privacy audit logging failed: \(error)")
        }
    }
    
    static func generatePrivacyReport() -> PrivacyReport {
        let entries = PrivacyAuditStore.shared.getAllEntries()
        
        return PrivacyReport(
            reportDate: Date(),
            totalEvents: entries.count,
            dataAccessEvents: entries.filter { $0.isDataAccess }.count,
            permissionEvents: entries.filter { $0.isPermissionEvent }.count,
            deletionEvents: entries.filter { $0.isDeletionEvent }.count,
            summary: generatePrivacySummary(from: entries)
        )
    }
}
```

### 2. Privacy Compliance

#### Data Processing Compliance
```swift
class PrivacyComplianceManager {
    func validateDataProcessing(_ operation: DataOperation) throws {
        // Ensure operation complies with privacy settings
        guard hasValidConsent(for: operation) else {
            throw PrivacyError.noValidConsent
        }
        
        // Verify data minimization
        guard isDataMinimized(operation) else {
            throw PrivacyError.dataNotMinimized
        }
        
        // Check retention limits
        guard respectsRetentionLimits(operation) else {
            throw PrivacyError.retentionLimitExceeded
        }
        
        // Verify local processing requirement
        guard isLocalProcessingOnly(operation) else {
            throw PrivacyError.externalProcessingNotAllowed
        }
    }
    
    private func hasValidConsent(for operation: DataOperation) -> Bool {
        switch operation.dataType {
        case .essential:
            return true // Essential data processing is always allowed
        case .optional(let optionalType):
            return optionalType.isEnabled && optionalType.hasValidConsent
        case .sensitive:
            return operation.hasExplicitConsent && operation.consentDate > Date().addingTimeInterval(-30 * 24 * 3600) // 30 days
        }
    }
    
    func generateComplianceReport() -> ComplianceReport {
        return ComplianceReport(
            reportDate: Date(),
            dataProcessingCompliant: validateAllDataProcessing(),
            retentionCompliant: validateRetentionPolicies(),
            consentCompliant: validateConsentManagement(),
            securityCompliant: validateSecurityMeasures(),
            recommendations: generateComplianceRecommendations()
        )
    }
}
```

This comprehensive privacy implementation ensures the Day Planner app maintains the highest privacy standards, giving users complete control over their personal data while enabling the full functionality described in the PRD.
