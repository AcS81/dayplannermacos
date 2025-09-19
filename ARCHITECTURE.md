# 🌊 Liquid Glass Architecture
nw_socket_handle_socket_event [C1.1.1:2] Socket SO_ERROR [61: Connection refused]
nw_protocol_socket_set_no_wake_from_sleep [C1.1.1:2] setsockopt SO_NOWAKEFROMSLEEP failed [22: Invalid argument]
nw_protocol_socket_set_no_wake_from_sleep setsockopt SO_NOWAKEFROMSLEEP failed [22: Invalid argument]
nw_endpoint_flow_failed_with_error [C1.1.1 ::1.1234 in_progress socket-flow (satisfied (Path is satisfied), viable, interface: lo0)] already failing, returning
nw_protocol_socket_set_no_wake_from_sleep [C1.1.2:2] setsockopt SO_NOWAKEFROMSLEEP failed [22: Invalid argument]
nw_protocol_socket_set_no_wake_from_sleep setsockopt SO_NOWAKEFROMSLEEP failed [22: Invalid argument]
nw_protocol_socket_set_no_wake_from_sleep [C1.1.2:2] setsockopt SO_NOWAKEFROMSLEEP failed [22: Invalid argument]
nw_protocol_socket_set_no_wake_from_sleep setsockopt SO_NOWAKEFROMSLEEP failed [22: Invalid a

## Core Philosophy

Simple, beautiful, fluid. Three glass surfaces that respond like water to touch.

## System Overview

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Today Glass   │  │     AI Orb      │  │   Flow Glass    │
│  (Main Surface) │  │ (Floating AI)   │  │ (Side Panel)    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                       │                      │
┌─────────────────────────────────────────────────────────────┐
│              SwiftUI + Metal Glass Engine                   │
└─────────────────────────────────────────────────────────────┘
         │                       │                      │
┌─────────────────┐  ┌──────────────────┐  ┌─────────────────┐
│  Time Manager   │  │   AI Service     │  │  Pattern Store  │
│ (Local Storage) │  │  (LM Studio)     │  │ (Chain Memory)  │
└─────────────────┘  └──────────────────┘  └─────────────────┘
```

## 🎨 Glass Engine Components

### LiquidGlassView (Foundation)
```swift
struct LiquidGlassView<Content: View>: View {
    let content: Content
    @State private var ripplePhase: Double = 0
    @State private var glassOpacity: Double = 0.8
    @State private var hoverPoint: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // Dynamic blur background
            VisualEffectBlur(material: .hudWindow)
                .blendMode(.behindWindow)
            
            // Content with liquid distortion
            content
                .modifier(LiquidDistortion(
                    ripplePhase: ripplePhase,
                    epicenter: hoverPoint
                ))
            
            // Glass reflection overlay
            GlassReflection(opacity: glassOpacity)
                .animation(.spring(response: 0.6), value: glassOpacity)
        }
        .onTapGesture { location in
            createRipple(at: location)
        }
    }
}
```

### Time Block System
```swift
struct TimeBlock: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var startTime: Date
    var duration: TimeInterval
    var energy: EnergyType    // 🌅☀️🌙
    var flow: FlowState       // 💎🌊☁️
    var glassState: GlassState = .solid
}

enum GlassState {
    case solid      // Committed events
    case liquid     // Being dragged  
    case mist       // Staged suggestions
    case crystal    // AI generated
}
```

## 🌅 Today Glass (Main Surface)

### Three Panel System
```swift
struct TodayGlass: View {
    @StateObject private var timeManager = TimeManager()
    
    var body: some View {
        HStack(spacing: 20) {
            // Morning Mist (6am - 12pm)
            TimePanel(
                period: .morning,
                tint: .sunrise,
                blocks: timeManager.morningBlocks
            )
            
            // Afternoon Flow (12pm - 6pm)  
            TimePanel(
                period: .afternoon,
                tint: .daylight,
                blocks: timeManager.afternoonBlocks
            )
            
            // Evening Glow (6pm - 12am)
            TimePanel(
                period: .evening,
                tint: .sunset,
                blocks: timeManager.eveningBlocks
            )
        }
        .background(
            TimeGradient(currentHour: Date().hour)
                .ignoresSafeArea()
        )
    }
}
```

### Liquid Mercury Interactions
```swift
extension TimeBlock {
    func dragBehavior() -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                // Block becomes liquid mercury
                self.glassState = .liquid
                self.position = value.location
                
                // Create ripple trail
                RippleTrail.add(at: value.location)
            }
            .onEnded { value in
                // Settle into new position
                withAnimation(.spring(response: 0.8)) {
                    self.glassState = .solid
                    self.snapToNearestTimeSlot()
                }
            }
    }
}
```

## 🔮 AI Orb (Floating Intelligence)

### Orb Behavior System
```swift
struct AIOrb: View {
    @StateObject private var orbState = OrbState()
    @State private var phase: Double = 0
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: orbState.currentColors,
                    center: .center,
                    startRadius: 5,
                    endRadius: 50
                )
            )
            .frame(width: orbState.size, height: orbState.size)
            .modifier(AuroraEffect(phase: phase))
            .scaleEffect(orbState.isThinking ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 2).repeatForever(), value: phase)
            .onAppear {
                phase = 1.0
            }
    }
}

class OrbState: ObservableObject {
    @Published var size: CGFloat = 60
    @Published var isThinking = false
    @Published var currentColors: [Color] = [.blue, .purple, .cyan]
    
    func expand() {
        withAnimation(.spring(response: 0.4)) {
            size = 200
            currentColors = [.white, .blue, .clear]
        }
    }
    
    func thinking() {
        isThinking = true
        currentColors = [.orange, .yellow, .red] // Aurora colors
    }
}
```

### Voice Interaction
```swift
struct VoiceInterface: View {
    @StateObject private var speechManager = SpeechManager()
    @State private var rippleRings: [RippleRing] = []
    
    var body: some View {
        ZStack {
            // Voice ripple rings
            ForEach(rippleRings, id: \.id) { ring in
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: ring.radius * 2, height: ring.radius * 2)
                    .animation(.easeOut(duration: 1), value: ring.radius)
            }
        }
        .onReceive(speechManager.audioLevelPublisher) { level in
            createVoiceRipple(intensity: level)
        }
    }
}
```

## 🌊 Flow Glass (Chain Management)

### Chain Visualization
```swift
struct ChainFlow: View {
    let chains: [Chain]
    @State private var cascadePhase: Double = 0
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(chains.indices, id: \.self) { index in
                    ChainView(chain: chains[index])
                        .modifier(CascadeEffect(
                            delay: Double(index) * 0.1,
                            phase: cascadePhase
                        ))
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2)) {
                cascadePhase = 1.0
            }
        }
    }
}

struct Chain: Identifiable {
    let id = UUID()
    let name: String
    let blocks: [TimeBlock]
    let flowPattern: FlowPattern
}

enum FlowPattern {
    case waterfall  // Sequential cascading
    case spiral     // Circular flow
    case ripple     // Radial expansion
    case wave       // Undulating motion
}
```

## 💾 Data Layer (Simplified)

### Core Data Models
```swift
// Just 3 simple structs - no complex database
struct AppState: Codable {
    var today: Day
    var chains: [Chain]
    var patterns: [Pattern]
}

struct Day: Codable, Identifiable {
    let id = UUID()
    let date: Date
    var blocks: [TimeBlock]
    var mood: GlassMood
}

enum GlassMood: Codable {
    case crystal    // Clear, focused day
    case mist       // Gentle, flowing day  
    case prism      // Creative, dynamic day
    case storm      // Intense, challenging day
}
```

### Local Storage
```swift
class AppDataManager: ObservableObject {
    @Published var appState = AppState()
    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DayPlannerState.json")
    
    func save() {
        // Simple JSON file storage
        try? JSONEncoder().encode(appState).write(to: fileURL)
    }
    
    func load() {
        // Load from JSON file
        if let data = try? Data(contentsOf: fileURL) {
            appState = (try? JSONDecoder().decode(AppState.self, from: data)) ?? AppState()
        }
    }
}
```

## 🤖 AI Integration (Streamlined)

### Single AI Service
```swift
class AIService: ObservableObject {
    private let baseURL = "http://localhost:1234"
    
    func suggest(for timeSlot: TimeSlot, context: DayContext) async throws -> [TimeBlock] {
        let prompt = """
        Time: \(timeSlot.description)
        Energy: \(context.currentEnergy)
        Recent: \(context.recentBlocks.map(\.title).joined(separator: ", "))
        
        Suggest 3 activities as JSON array with title, duration, energy, flow.
        """
        
        return try await streamingRequest(prompt: prompt)
    }
    
    private func streamingRequest(prompt: String) async throws -> [TimeBlock] {
        // Simple streaming implementation
        // Returns parsed TimeBlocks
    }
}
```

## 🎯 Performance Targets

### Glass Effects
- **60fps minimum** for all animations
- **120fps preferred** on ProMotion displays
- **<16ms frame time** for liquid interactions
- **<100ms touch response** for ripple effects

### AI Performance  
- **<2s response time** for suggestions
- **Real-time streaming** with <200ms first token
- **<200MB memory** usage for app (AI model separate)

### Battery Efficiency
- **Background idle**: Minimal CPU usage
- **Glass animations**: GPU-optimized shaders
- **AI requests**: Batched and cached

## 🔧 Development Setup

### Required Tools
- **Xcode 15+** with Swift 5.9
- **macOS 14+** for latest SwiftUI features  
- **LM Studio** with any 7B+ parameter model
- **Metal Performance Shaders** for glass effects

### Project Structure
```
DayPlanner/
├── Glass/           # Liquid glass UI system
│   ├── LiquidGlass.swift
│   ├── Ripples.swift
│   └── GlassEffects.swift
├── Surfaces/        # Three main surfaces  
│   ├── TodayGlass.swift
│   ├── AIOrb.swift
│   └── FlowGlass.swift
├── Data/            # Simple data layer
│   ├── Models.swift
│   └── Storage.swift
└── AI/              # Local AI integration
    └── AIService.swift
```

## 🚀 This is Simple

No complex databases. No endless configuration. No cloud dependencies.

**Three glass surfaces + local AI + beautiful animations = magical productivity.**

The architecture is intentionally minimal to focus on the core experience: making time planning feel like playing with liquid light.
