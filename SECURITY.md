# Security Implementation Guide

## Overview

This document outlines security implementation guidelines for the Day Planner app, focusing on local-first security, data protection, and privacy preservation as specified in the PRD.

## Security Architecture

### Core Security Principles

1. **Local-First Security**: All sensitive processing happens on-device
2. **Zero Trust Network**: No external dependencies for core functionality
3. **Data Minimization**: Collect and store only necessary data
4. **Encryption Everywhere**: Encrypt data at rest and in transit
5. **Principle of Least Privilege**: Minimal permissions required
6. **Transparent Security**: User visibility into all security mechanisms

## Data Protection

### 1. Encryption at Rest

#### Database Encryption
```swift
import SQLite3

class SecureDatabase {
    private var db: OpaquePointer?
    private let encryptionKey: Data
    
    init() throws {
        self.encryptionKey = try SecureKeyManager.getDatabaseKey()
        try openDatabase()
        try enableEncryption()
    }
    
    private func enableEncryption() throws {
        // Use SQLite encryption extension (SQLCipher)
        let keyString = encryptionKey.base64EncodedString()
        let result = sqlite3_exec(db, "PRAGMA key = '\(keyString)'", nil, nil, nil)
        
        guard result == SQLITE_OK else {
            throw DatabaseError.encryptionFailed
        }
    }
    
    // Verify encryption is working
    func verifyEncryption() throws {
        let result = sqlite3_exec(db, "PRAGMA cipher_version", nil, nil, nil)
        guard result == SQLITE_OK else {
            throw DatabaseError.encryptionVerificationFailed
        }
    }
}
```

#### Key Management
```swift
import CryptoKit
import LocalAuthentication

class SecureKeyManager {
    private static let keyIdentifier = "com.dayplanner.database.key"
    
    static func getDatabaseKey() throws -> Data {
        // Try to retrieve existing key from Keychain
        if let existingKey = try? retrieveKeyFromKeychain() {
            return existingKey
        }
        
        // Generate new key if none exists
        let newKey = SymmetricKey(size: .bits256)
        try storeKeyInKeychain(newKey.dataRepresentation)
        return newKey.dataRepresentation
    }
    
    private static func storeKeyInKeychain(_ key: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "DayPlanner",
            kSecAttrAccount as String: keyIdentifier,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false // Never sync to iCloud
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    private static func retrieveKeyFromKeychain() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "DayPlanner",
            kSecAttrAccount as String: keyIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let keyData = item as? Data else {
            throw KeychainError.retrieveFailed(status)
        }
        
        return keyData
    }
}
```

### 2. Secure Data Storage

#### User Preferences Encryption
```swift
class SecurePreferencesManager {
    private let encryptionKey: SymmetricKey
    
    init() throws {
        self.encryptionKey = try SecureKeyManager.getPreferencesKey()
    }
    
    func store<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        let encryptedData = try encrypt(data)
        
        UserDefaults.standard.set(encryptedData, forKey: key)
    }
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let encryptedData = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        let decryptedData = try decrypt(encryptedData)
        return try JSONDecoder().decode(type, from: decryptedData)
    }
    
    private func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!
    }
    
    private func decrypt(_ encryptedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }
}
```

### 3. AI Context Protection

#### Secure Context Management
```swift
class SecureContextManager {
    private let encryptionKey: SymmetricKey
    private let contextCache = NSCache<NSString, EncryptedContext>()
    
    func storeContext(_ context: PlanningContext, forKey key: String) throws {
        let contextData = try JSONEncoder().encode(context)
        let encryptedContext = try encryptContext(contextData)
        
        contextCache.setObject(encryptedContext, forKey: key as NSString)
    }
    
    func retrieveContext(forKey key: String) throws -> PlanningContext? {
        guard let encryptedContext = contextCache.object(forKey: key as NSString) else {
            return nil
        }
        
        let contextData = try decryptContext(encryptedContext)
        return try JSONDecoder().decode(PlanningContext.self, from: contextData)
    }
    
    // Clear sensitive context data after use
    func clearContext(forKey key: String) {
        contextCache.removeObject(forKey: key as NSString)
    }
    
    // Automatic cleanup of old contexts
    func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.contextCache.removeAllObjects()
        }
    }
}
```

## Network Security

### 1. Local AI Communication

#### Secure LM Studio Connection
```swift
class SecureLMStudioConnection {
    private let allowedHosts = ["localhost", "127.0.0.1"]
    private let allowedPort = 1234
    
    func validateConnection(url: URL) throws {
        guard let host = url.host,
              allowedHosts.contains(host),
              url.port == allowedPort || (url.port == nil && url.scheme == "http") else {
            throw NetworkError.unauthorizedHost
        }
        
        // Additional validation: ensure it's actually LM Studio
        try validateLMStudioSignature(url: url)
    }
    
    private func validateLMStudioSignature(url: URL) throws {
        // Check for LM Studio-specific endpoints
        let modelsURL = url.appendingPathComponent("/v1/models")
        let (data, _) = try await URLSession.shared.data(from: modelsURL)
        
        // Verify response structure matches LM Studio
        let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard response?["object"] as? String == "list" else {
            throw NetworkError.invalidServiceSignature
        }
    }
}
```

### 2. No External Network Access

#### Network Request Monitoring
```swift
class NetworkMonitor {
    static let shared = NetworkMonitor()
    private var isNetworkAccessEnabled = false
    
    // Only allow network access for optional features
    func enableNetworkAccess(for feature: NetworkFeature) {
        switch feature {
        case .weatherData:
            // Only if user explicitly enables weather integration
            isNetworkAccessEnabled = UserSettings.shared.enableWeatherIntegration
        case .backup:
            // Only for manual export/import
            isNetworkAccessEnabled = true
        default:
            isNetworkAccessEnabled = false
        }
    }
    
    func validateNetworkRequest(_ request: URLRequest) throws {
        guard isNetworkAccessEnabled else {
            throw NetworkError.unauthorizedNetworkAccess
        }
        
        // Additional validation for allowed domains
        guard let host = request.url?.host,
              isAllowedHost(host) else {
            throw NetworkError.unauthorizedHost
        }
    }
    
    private func isAllowedHost(_ host: String) -> Bool {
        let allowedHosts = [
            "localhost",
            "127.0.0.1",
            "api.weather.com", // Only if weather enabled
        ]
        return allowedHosts.contains(host)
    }
}
```

## Access Control

### 1. Calendar Permissions

#### Minimal Permission Request
```swift
class CalendarPermissionManager {
    private let eventStore = EKEventStore()
    
    func requestMinimalPermissions() async throws {
        // Request only event access, not reminders
        let granted = try await eventStore.requestAccess(to: .event)
        
        guard granted else {
            throw PermissionError.calendarAccessDenied
        }
        
        // Log permission grant for audit
        SecurityAuditLogger.log(
            event: .permissionGranted(type: .calendar),
            metadata: ["timestamp": Date().iso8601String]
        )
    }
    
    // Verify permissions before each use
    func verifyCalendarAccess() throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        guard status == .authorized else {
            throw PermissionError.calendarAccessRevoked
        }
    }
}
```

### 2. Speech Recognition Permissions

#### On-Device Speech Processing
```swift
class SecureSpeechManager {
    private let speechRecognizer: SFSpeechRecognizer?
    
    init() {
        // Force on-device recognition
        self.speechRecognizer = SFSpeechRecognizer()
        self.speechRecognizer?.supportsOnDeviceRecognition = true
    }
    
    func requestSpeechPermission() async throws {
        // Request speech recognition permission
        let authStatus = await SFSpeechRecognizer.requestAuthorization()
        
        guard authStatus == .authorized else {
            throw PermissionError.speechRecognitionDenied
        }
        
        // Verify on-device recognition is available
        guard speechRecognizer?.supportsOnDeviceRecognition == true else {
            throw SecurityError.offDeviceProcessingRequired
        }
    }
    
    func createSecureRecognitionRequest() throws -> SFSpeechURLRecognitionRequest {
        let request = SFSpeechURLRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        
        return request
    }
}
```

## Data Integrity

### 1. Commit Log Security

#### Tamper-Proof Audit Trail
```swift
class SecureCommitLogger {
    private let signingKey: Curve25519.Signing.PrivateKey
    private let database: SecureDatabase
    
    init() throws {
        self.signingKey = try SecureKeyManager.getSigningKey()
        self.database = try SecureDatabase()
    }
    
    func logCommit(_ operation: DatabaseOperation) throws {
        let logEntry = CommitLogEntry(
            id: UUID(),
            operation: operation,
            timestamp: Date(),
            checksum: calculateChecksum(operation)
        )
        
        // Sign the log entry
        let signature = try signLogEntry(logEntry)
        let signedEntry = SignedCommitLogEntry(
            entry: logEntry,
            signature: signature
        )
        
        try database.store(signedEntry)
    }
    
    func verifyCommitLog() throws -> Bool {
        let entries = try database.fetchAll(SignedCommitLogEntry.self)
        
        for entry in entries {
            guard try verifySignature(entry) else {
                throw SecurityError.commitLogTampered
            }
        }
        
        return true
    }
    
    private func signLogEntry(_ entry: CommitLogEntry) throws -> Data {
        let entryData = try JSONEncoder().encode(entry)
        return try signingKey.signature(for: entryData)
    }
}
```

### 2. Data Validation

#### Input Sanitization
```swift
class DataValidator {
    static func validateEventInput(_ event: EventInput) throws -> Event {
        // Sanitize title
        let sanitizedTitle = sanitizeString(event.title, maxLength: 200)
        
        // Validate time boundaries
        guard event.startTime < event.endTime else {
            throw ValidationError.invalidTimeRange
        }
        
        guard event.startTime > Date().addingTimeInterval(-365 * 24 * 3600) else {
            throw ValidationError.dateOutOfRange
        }
        
        // Sanitize location
        let sanitizedLocation = event.location.map { 
            sanitizeString($0, maxLength: 100) 
        }
        
        return Event(
            id: UUID().uuidString,
            title: sanitizedTitle,
            startTime: event.startTime,
            endTime: event.endTime,
            location: sanitizedLocation,
            notes: event.notes.map { sanitizeString($0, maxLength: 1000) }
        )
    }
    
    private static func sanitizeString(_ input: String, maxLength: Int) -> String {
        // Remove potentially dangerous characters
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)
        
        let sanitized = input.components(separatedBy: allowedCharacters.inverted)
            .joined()
        
        return String(sanitized.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

## Security Monitoring

### 1. Audit Logging

#### Comprehensive Security Events
```swift
class SecurityAuditLogger {
    private static let logger = Logger(
        subsystem: "com.dayplanner.security",
        category: "audit"
    )
    
    enum SecurityEvent {
        case permissionGranted(type: PermissionType)
        case permissionDenied(type: PermissionType)
        case dataAccess(type: DataAccessType)
        case encryptionEvent(type: EncryptionEventType)
        case suspiciousActivity(type: SuspiciousActivityType)
    }
    
    static func log(
        event: SecurityEvent,
        metadata: [String: Any] = [:],
        level: OSLogType = .info
    ) {
        var logMessage = "Security Event: \(event)"
        
        if !metadata.isEmpty {
            let metadataString = metadata.map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            logMessage += " | \(metadataString)"
        }
        
        logger.log(level: level, "\(logMessage, privacy: .private)")
        
        // Store critical security events in secure database
        if isCriticalSecurityEvent(event) {
            storeCriticalSecurityEvent(event, metadata: metadata)
        }
    }
    
    private static func isCriticalSecurityEvent(_ event: SecurityEvent) -> Bool {
        switch event {
        case .suspiciousActivity, .permissionDenied:
            return true
        default:
            return false
        }
    }
}
```

### 2. Anomaly Detection

#### Behavioral Analysis
```swift
class SecurityAnalyzer {
    private var behaviorBaseline: BehaviorBaseline?
    
    func analyzeBehavior(_ activity: UserActivity) -> SecurityThreat? {
        guard let baseline = behaviorBaseline else {
            // Establish baseline
            establishBaseline(from: activity)
            return nil
        }
        
        // Check for anomalies
        if isAnomalousActivity(activity, against: baseline) {
            let threat = SecurityThreat(
                type: .anomalousUserBehavior,
                severity: calculateSeverity(activity, baseline: baseline),
                activity: activity,
                timestamp: Date()
            )
            
            SecurityAuditLogger.log(
                event: .suspiciousActivity(type: .behaviorAnomaly),
                metadata: ["threat": threat.description],
                level: .fault
            )
            
            return threat
        }
        
        return nil
    }
    
    private func isAnomalousActivity(
        _ activity: UserActivity,
        against baseline: BehaviorBaseline
    ) -> Bool {
        // Check unusual access patterns
        if activity.accessFrequency > baseline.averageAccessFrequency * 3 {
            return true
        }
        
        // Check unusual time patterns
        if !baseline.normalOperatingHours.contains(activity.timestamp.hour) {
            return true
        }
        
        // Check unusual data access volumes
        if activity.dataAccessVolume > baseline.averageDataAccess * 5 {
            return true
        }
        
        return false
    }
}
```

## Incident Response

### 1. Threat Detection

#### Automated Response System
```swift
class SecurityIncidentHandler {
    private let alertThreshold: SecuritySeverity = .medium
    
    func handleThreat(_ threat: SecurityThreat) {
        SecurityAuditLogger.log(
            event: .suspiciousActivity(type: threat.type.toSuspiciousActivityType()),
            metadata: threat.metadata,
            level: threat.severity.logLevel
        )
        
        switch threat.severity {
        case .low:
            monitorAndLog(threat)
        case .medium:
            restrictAccess(threat)
        case .high:
            lockdownAndAlert(threat)
        case .critical:
            emergencyShutdown(threat)
        }
    }
    
    private func restrictAccess(_ threat: SecurityThreat) {
        // Temporarily disable certain features
        SecuritySettings.shared.enableSafeMode()
        
        // Clear sensitive caches
        ContextManager.shared.clearAllContexts()
        
        // Require re-authentication for sensitive operations
        AuthenticationManager.shared.requireReauth()
    }
    
    private func emergencyShutdown(_ threat: SecurityThreat) {
        // Immediately clear all sensitive data from memory
        clearSensitiveMemory()
        
        // Disable network access
        NetworkMonitor.shared.disableAllNetworkAccess()
        
        // Log detailed incident report
        createIncidentReport(threat)
        
        // Notify user of security incident
        presentSecurityAlert(threat)
    }
}
```

### 2. Recovery Procedures

#### Data Recovery and Cleanup
```swift
class SecurityRecoveryManager {
    func initiateRecovery(from incident: SecurityIncident) async throws {
        // 1. Verify system integrity
        try await verifySystemIntegrity()
        
        // 2. Clean potentially compromised data
        try await cleanCompromisedData(incident.affectedDataTypes)
        
        // 3. Regenerate encryption keys if necessary
        if incident.severity >= .high {
            try await regenerateEncryptionKeys()
        }
        
        // 4. Restore from secure backup if needed
        if incident.requiresDataRestore {
            try await restoreFromSecureBackup()
        }
        
        // 5. Re-establish secure baseline
        await establishNewSecurityBaseline()
        
        // 6. Document recovery process
        try await documentRecovery(incident)
    }
    
    private func regenerateEncryptionKeys() async throws {
        // Generate new database encryption key
        let newDatabaseKey = try SecureKeyManager.generateNewDatabaseKey()
        
        // Re-encrypt all stored data with new key
        try await reencryptDatabase(with: newDatabaseKey)
        
        // Update keychain with new key
        try SecureKeyManager.updateDatabaseKey(newDatabaseKey)
        
        SecurityAuditLogger.log(
            event: .encryptionEvent(type: .keyRegeneration),
            metadata: ["reason": "security_incident_recovery"]
        )
    }
}
```

## Security Testing

### 1. Penetration Testing

#### Automated Security Tests
```swift
class SecurityTestSuite: XCTestCase {
    func testDatabaseEncryption() async throws {
        let database = try SecureDatabase()
        
        // Verify encryption is enabled
        try database.verifyEncryption()
        
        // Test key rotation
        try await database.rotateEncryptionKey()
        
        // Verify data is still accessible after rotation
        let testData = TestDataFactory.createTestEvent()
        try await database.store(testData)
        let retrieved = try await database.fetch(Event.self, id: testData.id)
        
        XCTAssertEqual(retrieved?.title, testData.title)
    }
    
    func testUnauthorizedAccess() {
        let secureManager = SecurePreferencesManager()
        
        // Attempt to access without proper authentication
        XCTAssertThrowsError(try secureManager.retrieve(String.self, forKey: "sensitive_data")) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }
    
    func testNetworkRequestBlocking() {
        let monitor = NetworkMonitor.shared
        
        // Test unauthorized external request
        let unauthorizedURL = URL(string: "https://external-service.com")!
        let request = URLRequest(url: unauthorizedURL)
        
        XCTAssertThrowsError(try monitor.validateNetworkRequest(request)) { error in
            XCTAssertEqual(error as? NetworkError, .unauthorizedHost)
        }
    }
}
```

This comprehensive security implementation ensures the Day Planner app maintains the highest security standards while preserving user privacy and data integrity as specified in the PRD.
