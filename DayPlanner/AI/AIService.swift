//
//  AIService.swift
//  DayPlanner
//
//  Simple local AI service for LM Studio integration
//

import Foundation
import AVFoundation

// MARK: - Audio Permission Types

enum AudioPermissionStatus: Codable {
    case undetermined
    case denied
    case granted
    
    var description: String {
        switch self {
        case .undetermined: return "Not Determined"
        case .denied: return "Denied"
        case .granted: return "Granted"
        }
    }
}

// MARK: - Whisper Service

/// Whisper-based speech recognition service
@MainActor
class WhisperService: ObservableObject {
    @Published var isProcessing = false
    @Published var lastError: String?
    
    private let session: URLSession
    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    /// Transcribe audio file using Whisper API
    func transcribe(audioFileURL: URL, apiKey: String) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        guard !apiKey.isEmpty else {
            throw WhisperError.missingAPIKey
        }
        
        // Prepare multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let audioData = try Data(contentsOf: audioFileURL)
        let httpBody = createMultipartBody(boundary: boundary, audioData: audioData, fileName: "audio.m4a")
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WhisperError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw WhisperError.apiError(message)
                }
                throw WhisperError.httpError(httpResponse.statusCode)
            }
            
            let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
            return result.text
            
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    /// Create multipart form data
    private func createMultipartBody(boundary: String, audioData: Data, fileName: String) -> Data {
        var body = Data()
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add language field (optional)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}

// MARK: - Whisper Models

struct WhisperResponse: Codable {
    let text: String
}

enum WhisperError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Whisper API key not configured"
        case .invalidResponse:
            return "Invalid response from Whisper API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        case .fileNotFound:
            return "Audio file not found"
        }
    }
}

// MARK: - AI Service

/// Local AI service that communicates with LM Studio
@MainActor
class AIService: ObservableObject {
    @Published var isConnected = false
    @Published var isProcessing = false
    @Published var lastResponseTime: TimeInterval = 0
    
    private let baseURL = "http://localhost:1234"
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false // Don't wait indefinitely
        config.allowsCellularAccess = false // Local network only
        self.session = URLSession(configuration: config)
        
        Task {
            await checkConnection()
            
            // Set up periodic connection monitoring
            await startConnectionMonitoring()
        }
    }
    
    private func startConnectionMonitoring() async {
        // Check connection every 30 seconds
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                await checkConnection()
            }
        }
    }
    
    // MARK: - Connection Management
    
    func checkConnection() async {
        do {
            let url = URL(string: "\(baseURL)/v1/models")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0 // Shorter timeout for connection check
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await MainActor.run {
                    isConnected = true
                }
                print("✅ AI Service connected to LM Studio at \(baseURL)")
            } else {
                await MainActor.run {
                    isConnected = false
                }
                print("❌ AI Service: HTTP error \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            await MainActor.run {
                isConnected = false
            }
            print("❌ AI Service connection failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Message Processing
    
    func processMessage(_ message: String, context: DayContext) async throws -> AIResponse {
        guard isConnected else {
            throw AIError.notConnected
        }
        
        isProcessing = true
        let startTime = Date()
        
        defer {
            isProcessing = false
            lastResponseTime = Date().timeIntervalSince(startTime)
        }
        
        let prompt = buildPrompt(message: message, context: context)
        let response = try await generateCompletion(prompt: prompt)
        
        return try parseResponse(response)
    }
    
    func generateSuggestions(for context: DayContext) async throws -> [Suggestion] {
        let message = "Suggest some activities for my day"
        let response = try await processMessage(message, context: context)
        return response.suggestions
    }
    
    /// Get suggestions based on user message and context (for Action Bar)
    func getSuggestions(for message: String, context: DayContext) async throws -> [Suggestion] {
        isProcessing = true
        defer { isProcessing = false }
        
        // Use the existing processMessage method to get AI response
        let response = try await processMessage(message, context: context)
        return response.suggestions
    }
    
    // MARK: - Private Methods
    
    private func buildPrompt(message: String, context: DayContext) -> String {
        let pillarGuidanceText = context.pillarGuidance.isEmpty ? 
            "" : "\n\nUser's Core Principles (guide all suggestions):\n\(context.pillarGuidance.joined(separator: "\n"))"
        
        let actionablePillarsText = context.actionablePillars.isEmpty ? 
            "" : "\n\nActionable Pillars to consider:\n\(context.actionablePillars.map { "- \($0.name): \($0.description)" }.joined(separator: "\n"))"
        
        return """
        You are a helpful day planning assistant. The user is planning their day and needs suggestions.
        
        Current context:
        - Date & Time: \(context.date.formatted(.dateTime.weekday().month().day().year().hour().minute()))
        - Current energy: \(context.currentEnergy.description)
        - Existing activities: \(context.existingBlocks.count)
        - Available time: \(Int(context.availableTime/3600)) hours
        - Mood: \(context.mood.description)
        \(context.weatherContext != nil ? "- Weather: \(context.weatherContext!)" : "")\(pillarGuidanceText)\(actionablePillarsText)
        
        User message: "\(message)"
        
        IMPORTANT: Always align suggestions with the user's core principles listed above. Consider:
        - Weather conditions for indoor/outdoor activities
        - User's guiding principles when making any suggestion
        - How actionable pillars might need time slots
        - The user's current energy and mood state
        
        Please provide a helpful response and exactly 2 activity suggestions in this exact JSON format:
        {
            "response": "Your helpful response text that acknowledges their principles",
            "suggestions": [
                {
                    "title": "Activity name",
                    "explanation": "Brief reason why this aligns with their principles and current context",
                    "duration": 60,
                    "energy": "sunrise|daylight|moonlight",
                    "flow": "crystal|water|mist",
                    "confidence": 0.8
                }
            ]
        }
        
        Keep suggestions principle-aligned, realistic and personalized.
        """
    }
    
    private func generateCompletion(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        
        let requestBody: [String: Any] = [
            "model": "openai/gpt-oss-20b",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a helpful day planning assistant. Always respond with valid JSON."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 1000,
            "stream": false
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.requestFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ AI Service HTTP error \(httpResponse.statusCode)")
            if httpResponse.statusCode == 404 {
                throw AIError.notConnected
            } else {
                throw AIError.requestFailed
            }
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = jsonResponse?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        return content ?? ""
    }
    
    private func parseResponse(_ content: String) throws -> AIResponse {
        // Clean up the response - sometimes models add markdown formatting
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to extract JSON from the response
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let parsed = try JSONDecoder().decode(AIResponseJSON.self, from: jsonData)
            
            let suggestions = parsed.suggestions.prefix(2).map { suggestionJSON in
                Suggestion(
                    title: suggestionJSON.title,
                    duration: TimeInterval(suggestionJSON.duration * 60), // Convert minutes to seconds
                    suggestedTime: Date(), // Will be set when applied
                    energy: EnergyType(rawValue: suggestionJSON.energy) ?? .daylight,
                    flow: FlowState(rawValue: suggestionJSON.flow) ?? .water,
                    explanation: suggestionJSON.explanation,
                    confidence: suggestionJSON.confidence
                )
            }
            
            return AIResponse(
                text: parsed.response,
                suggestions: suggestions
            )
            
        } catch {
            // Fallback: create a simple response if JSON parsing fails
            return AIResponse(
                text: cleanContent,
                suggestions: []
            )
        }
    }
}

// MARK: - Data Models

struct AIResponse {
    let text: String
    let suggestions: [Suggestion]
}

private struct AIResponseJSON: Codable {
    let response: String
    let suggestions: [SuggestionJSON]
}

private struct SuggestionJSON: Codable {
    let title: String
    let explanation: String
    let duration: Int // in minutes
    let energy: String
    let flow: String
    let confidence: Double
}

// MARK: - Errors

enum AIError: LocalizedError {
    case notConnected
    case requestFailed
    case invalidResponse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "AI service is not connected. Please start LM Studio and load a model."
        case .requestFailed:
            return "Failed to process AI request"
        case .invalidResponse:
            return "Received invalid response from AI service"
        case .timeout:
            return "AI request timed out"
        }
    }
}

// MARK: - Testing & Development

extension AIService {
    /// Create mock suggestions for testing when AI isn't available
    static func mockSuggestions() -> [Suggestion] {
        [
            Suggestion(
                title: "Morning Coffee & Planning",
                duration: 1800, // 30 minutes
                suggestedTime: Date().setting(hour: 8) ?? Date(),
                energy: .sunrise,
                flow: .mist,
                explanation: "Start your day mindfully",
                confidence: 0.9
            ),
            Suggestion(
                title: "Deep Work Session",
                duration: 5400, // 90 minutes  
                suggestedTime: Date().setting(hour: 9) ?? Date(),
                energy: .sunrise,
                flow: .crystal,
                explanation: "Take advantage of morning focus",
                confidence: 0.8
            )
        ]
    }
    
    /// Test the connection and basic functionality
    func runDiagnostics() async -> String {
        var diagnostics = "AI Service Diagnostics:\n"
        
        // Test connection
        await checkConnection()
        diagnostics += "Connection: \(isConnected ? "✅ Connected" : "❌ Not Connected")\n"
        
        if isConnected {
            // Test basic request
            do {
                let testContext = DayContext(
                    date: Date(),
                    existingBlocks: [],
                    currentEnergy: .daylight,
                    preferredFlows: [.water],
                    availableTime: 3600,
                    mood: .crystal
                )
                
                let _ = try await processMessage("Hello", context: testContext)
                diagnostics += "AI Response: ✅ Working\n"
                diagnostics += "Response Time: \(String(format: "%.2f", lastResponseTime))s\n"
            } catch {
                diagnostics += "AI Response: ❌ \(error.localizedDescription)\n"
            }
        }
        
        return diagnostics
    }
}

// MARK: - Preview Support

#if DEBUG
extension AIService {
    static var preview: AIService {
        let service = AIService()
        service.isConnected = true
        return service
    }
}
#endif

// MARK: - Speech Service

import Speech
import AVFoundation

/// Complete speech recognition and text-to-speech service using Whisper
@MainActor
class SpeechService: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    @Published var partialText = ""
    @Published var authorizationStatus: AudioPermissionStatus = .undetermined
    @Published var lastError: String?
    
    private var audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingTask: Task<Void, Never>?
    private var whisperService: WhisperService?
    private var speechRecognizer: SFSpeechRecognizer?
    
    // TTS
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
        speechRecognizer = SFSpeechRecognizer()
        speechRecognizer?.delegate = self
        whisperService = WhisperService()
        
        // Setup audio session
        setupAudioSession()
        
        Task {
            await requestPermissions()
        }
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async {
        // Request microphone permission on macOS
        #if os(macOS)
        let micStatus = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run {
            authorizationStatus = micStatus ? .granted : .denied
        }
        #else
        let micStatus = await AVAudioApplication.requestRecordPermission()
        await MainActor.run {
            authorizationStatus = AVAudioApplication.shared.recordPermission == .granted ? .granted : .denied
        }
        #endif
        
        print("🎤 Microphone permissions: \(micStatus)")
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastError = "Failed to setup audio session: \(error.localizedDescription)"
            print("❌ Audio session error: \(error)")
        }
        #else
        // macOS doesn't use AVAudioSession
        print("🎤 Audio session setup (macOS - no configuration needed)")
        #endif
    }
    
    // MARK: - Speech Recognition with Whisper
    
    func startListening() async throws {
        guard authorizationStatus == .granted else {
            throw SpeechError.notAuthorized
        }
        
        // Stop any existing recording
        await stopListening()
        
        // Create temporary file for recording
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(UUID().uuidString).m4a")
        
        // Setup audio file
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        do {
            audioFile = try AVAudioFile(forWriting: tempURL, settings: settings)
        } catch {
            throw SpeechError.cannotCreateRequest
        }
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self, let audioFile = self.audioFile else { return }
            try? audioFile.write(from: buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        await MainActor.run {
            isListening = true
            partialText = ""
            transcribedText = ""
            lastError = nil
        }
        
        print("🎤 Started recording for Whisper transcription")
    }
    
    func stopListening() async {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        await MainActor.run {
            isListening = false
        }
        
        // Process recorded audio with Whisper
        if let audioFile = audioFile {
            recordingTask = Task {
                await processWithWhisper(audioFileURL: audioFile.url)
            }
        }
        
        audioFile = nil
        print("🎤 Stopped recording, processing with Whisper...")
    }
    
    private func processWithWhisper(audioFileURL: URL) async {
        // Get API keys from UserDefaults (since we can't access dataManager from here)
        let whisperKey = UserDefaults.standard.string(forKey: "whisperApiKey") ?? ""
        let openaiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
        
        let keyToUse = !whisperKey.isEmpty ? whisperKey : openaiKey
        
        if keyToUse.isEmpty {
            await MainActor.run {
                lastError = "No API key configured for Whisper"
            }
            return
        }
        
        guard let whisperService = whisperService else {
            await MainActor.run {
                lastError = "Whisper service not available"
            }
            return
        }
        
        do {
            let transcription = try await whisperService.transcribe(audioFileURL: audioFileURL, apiKey: keyToUse)
            
            await MainActor.run {
                transcribedText = transcription
                lastError = nil
            }
            
            print("🎤 Whisper transcription: \(transcription)")
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: audioFileURL)
            
        } catch {
            await MainActor.run {
                lastError = "Whisper transcription error: \(error.localizedDescription)"
            }
            print("❌ Whisper error: \(error)")
        }
    }
    
    // MARK: - Text to Speech
    
    func speak(text: String, rate: Float = 0.5, pitch: Float = 1.0, volume: Float = 1.0) {
        // Stop any current speech
        stopSpeaking()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        
        currentUtterance = utterance
        speechSynthesizer.speak(utterance)
        
        isSpeaking = true
        
        print("🔊 Speaking: \(text.prefix(50))...")
    }
    
    func stopSpeaking() {
        // Use nonisolated to avoid QoS priority inversion
        Task.detached(priority: .userInitiated) {
            let wasSpeaking = await MainActor.run {
                return self.speechSynthesizer.isSpeaking
            }
            
            if wasSpeaking {
                await MainActor.run {
                    _ = self.speechSynthesizer.stopSpeaking(at: .immediate)
                }
            }
            
            await MainActor.run {
                self.currentUtterance = nil
                self.isSpeaking = false
            }
        }
    }
    
    func pauseSpeaking() {
        Task.detached(priority: .userInitiated) {
            let wasSpeaking = await MainActor.run {
                return self.speechSynthesizer.isSpeaking
            }
            
            if wasSpeaking {
                await MainActor.run {
                    _ = self.speechSynthesizer.pauseSpeaking(at: .immediate)
                }
            }
        }
    }
    
    func continueSpeaking() {
        Task.detached(priority: .userInitiated) {
            let wasPaused = await MainActor.run {
                return self.speechSynthesizer.isPaused
            }
            
            if wasPaused {
                await MainActor.run {
                    _ = self.speechSynthesizer.continueSpeaking()
                }
            }
        }
    }
    
    // MARK: - Utility
    
    var canStartListening: Bool {
        return authorizationStatus == .granted && !isListening && speechRecognizer?.isAvailable == true
    }
    
    var canSpeak: Bool {
        return !isSpeaking
    }
    
    func getDiagnostics() -> String {
        var diagnostics = "Speech Service Diagnostics:\n"
        diagnostics += "Speech Authorization: \(authorizationStatus)\n"
        diagnostics += "Recognizer Available: \(speechRecognizer?.isAvailable ?? false)\n"
        diagnostics += "On-device Support: \(speechRecognizer?.supportsOnDeviceRecognition ?? false)\n"
        diagnostics += "Currently Listening: \(isListening)\n"
        diagnostics += "Currently Speaking: \(isSpeaking)\n"
        diagnostics += "Audio Engine Running: \(audioEngine.isRunning)\n"
        
        if let error = lastError {
            diagnostics += "Last Error: \(error)\n"
        }
        
        return diagnostics
    }
}

// MARK: - Speech Recognizer Delegate

@MainActor
extension SpeechService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available && isListening {
                lastError = "Speech recognizer became unavailable"
                await stopListening()
            }
        }
    }
}

// MARK: - Speech Synthesizer Delegate

@MainActor
extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentUtterance = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        // Keep isSpeaking true when paused
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentUtterance = nil
        }
    }
}

// MARK: - Speech Errors

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case cannotCreateRequest
    case audioEngineFailure
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please grant permission in System Preferences."
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .cannotCreateRequest:
            return "Cannot create speech recognition request"
        case .audioEngineFailure:
            return "Audio engine failed to start"
        }
    }
}

// MARK: - Extensions

#if DEBUG
extension SpeechService {
    static var preview: SpeechService {
        let service = SpeechService()
        service.authorizationStatus = .granted
        return service
    }
}
#endif
