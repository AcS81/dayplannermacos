//
//  RippleEffects.swift
//  DayPlanner
//
//  Advanced ripple and water effects for the liquid glass system
//

import SwiftUI

// MARK: - Advanced Ripple System

/// Manager for complex ripple effects and animations
@MainActor
class RippleManager: ObservableObject {
    @Published var activeRipples: [AdvancedRipple] = []
    @Published var voiceRipples: [VoiceRipple] = []
    
    private var rippleTimer: Timer?
    
    init() {
        startCleanupTimer()
    }
    
    deinit {
        rippleTimer?.invalidate()
    }
    
    func createRipple(at point: CGPoint, type: RippleType = .tap) {
        let ripple = AdvancedRipple(center: point, type: type)
        activeRipples.append(ripple)
        
        // Remove after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + ripple.duration) {
            self.activeRipples.removeAll { $0.id == ripple.id }
        }
    }
    
    func createVoiceRipple(at point: CGPoint, intensity: Double) {
        let ripple = VoiceRipple(center: point, intensity: intensity)
        voiceRipples.append(ripple)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.voiceRipples.removeAll { $0.id == ripple.id }
        }
    }
    
    private func startCleanupTimer() {
        rippleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                let now = Date()
                self.activeRipples.removeAll { now.timeIntervalSince($0.startTime) > $0.duration }
                self.voiceRipples.removeAll { now.timeIntervalSince($0.startTime) > 0.5 }
            }
        }
    }
}

// MARK: - Advanced Ripple Types

enum RippleType {
    case tap           // Standard touch ripple
    case drag          // Dragging feedback
    case success       // Completion celebration
    case error         // Error indication
    case aiThinking    // AI processing indicator
    case voiceInput    // Voice input feedback
    
    var colors: [Color] {
        switch self {
        case .tap:
            return [.white.opacity(0.8), .green.opacity(0.4), .clear]
        case .drag:
            return [.green.opacity(0.6), .mint.opacity(0.3), .clear]
        case .success:
            return [.green.opacity(0.8), .mint.opacity(0.5), .clear]
        case .error:
            return [.red.opacity(0.8), .pink.opacity(0.4), .clear]
        case .aiThinking:
            return [.teal.opacity(0.6), .mint.opacity(0.4), .clear]
        case .voiceInput:
            return [.orange.opacity(0.7), .yellow.opacity(0.4), .clear]
        }
    }
    
    var duration: TimeInterval {
        switch self {
        case .tap, .drag: return 0.8
        case .success: return 1.2
        case .error: return 1.0
        case .aiThinking: return 2.0
        case .voiceInput: return 0.6
        }
    }
    
    var maxRadius: CGFloat {
        switch self {
        case .tap: return 80
        case .drag: return 60
        case .success: return 120
        case .error: return 100
        case .aiThinking: return 150
        case .voiceInput: return 90
        }
    }
}

/// Advanced ripple with multiple rings and effects
struct AdvancedRipple: Identifiable {
    let id = UUID()
    let center: CGPoint
    let type: RippleType
    let startTime = Date()
    let duration: TimeInterval
    let maxRadius: CGFloat
    
    init(center: CGPoint, type: RippleType) {
        self.center = center
        self.type = type
        self.duration = type.duration
        self.maxRadius = type.maxRadius
    }
    
    var progress: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        return min(elapsed / duration, 1.0)
    }
}

/// Voice-specific ripple for audio feedback
struct VoiceRipple: Identifiable {
    let id = UUID()
    let center: CGPoint
    let intensity: Double
    let startTime = Date()
    let baseRadius: CGFloat
    
    init(center: CGPoint, intensity: Double) {
        self.center = center
        self.intensity = intensity
        self.baseRadius = CGFloat(30 + intensity * 50)
    }
    
    var progress: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        return min(elapsed / 0.5, 1.0)
    }
    
    var currentRadius: CGFloat {
        baseRadius * (1.0 + CGFloat(progress) * 2.0)
    }
}

// MARK: - Ripple Views

/// Advanced multi-ring ripple view
struct AdvancedRippleView: View {
    let ripple: AdvancedRipple
    @State private var animationProgress: Double = 0
    
    var body: some View {
        ZStack {
            // Multiple concentric rings
            ForEach(0..<3, id: \.self) { ringIndex in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: ripple.type.colors,
                            startPoint: .center,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: max(1, 3 - CGFloat(ringIndex)),
                            lineCap: .round
                        )
                    )
                    .frame(
                        width: currentRadius(for: ringIndex),
                        height: currentRadius(for: ringIndex)
                    )
                    .opacity(ringOpacity(for: ringIndex))
            }
        }
        .position(ripple.center)
        .onAppear {
            withAnimation(.easeOut(duration: ripple.duration)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func currentRadius(for ringIndex: Int) -> CGFloat {
        let delay = Double(ringIndex) * 0.1
        let adjustedProgress = max(0, animationProgress - delay)
        return ripple.maxRadius * CGFloat(adjustedProgress)
    }
    
    private func ringOpacity(for ringIndex: Int) -> Double {
        let delay = Double(ringIndex) * 0.1
        let adjustedProgress = max(0, animationProgress - delay)
        return (1.0 - adjustedProgress) * 0.8
    }
}

/// Voice ripple with pulsing effect
struct VoiceRippleView: View {
    let ripple: VoiceRipple
    @State private var pulsePhase: Double = 0
    
    var body: some View {
        Circle()
            .stroke(
                RadialGradient(
                    colors: [
                        .orange.opacity(0.8),
                        .yellow.opacity(0.4),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: ripple.currentRadius / 2
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: ripple.currentRadius, height: ripple.currentRadius)
            .scaleEffect(1.0 + sin(pulsePhase) * 0.1)
            .opacity(1.0 - ripple.progress)
            .position(ripple.center)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    pulsePhase = .pi
                }
            }
    }
}

// MARK: - Water Effect Components

/// Liquid mercury effect for dragging elements
struct LiquidMercuryEffect: ViewModifier {
    let isDragging: Bool
    let dragPosition: CGPoint
    
    @State private var mercuryPhase: Double = 0
    @State private var trailPoints: [CGPoint] = []
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .opacity(isDragging ? 0.8 : 1.0)
            .blur(radius: isDragging ? 0.5 : 0)
            .overlay(
                // Mercury trail effect
                Canvas { context, size in
                    if isDragging && trailPoints.count > 1 {
                        var path = Path()
                        path.move(to: trailPoints[0])
                        
                        for point in trailPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                        
                        context.stroke(
                            path,
                            with: .color(.green.opacity(0.3)),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                    }
                }
            )
            .onChange(of: dragPosition) {
                if isDragging {
                    updateMercuryTrail(dragPosition)
                }
            }
            .animation(.easeOut(duration: 0.3), value: isDragging)
    }
    
    private func updateMercuryTrail(_ newPoint: CGPoint) {
        trailPoints.append(newPoint)
        
        // Keep trail length manageable
        if trailPoints.count > 10 {
            trailPoints.removeFirst()
        }
        
        // Clear trail when not dragging
        if !isDragging {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                trailPoints.removeAll()
            }
        }
    }
}

// MARK: - Cascade Water Effect

/// Waterfall cascade effect for chain animations
struct WaterfallCascade: View {
    let items: [AnyView]
    let isAnimating: Bool
    
    @State private var cascadeProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(items.indices, id: \.self) { index in
                items[index]
                    .opacity(itemOpacity(for: index))
                    .offset(y: itemOffset(for: index))
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.8)
                        .delay(Double(index) * 0.1),
                        value: cascadeProgress
                    )
            }
        }
        .onAppear {
            if isAnimating {
                withAnimation {
                    cascadeProgress = 1.0
                }
            }
        }
        .onChange(of: isAnimating) {
            withAnimation {
                cascadeProgress = isAnimating ? 1.0 : 0.0
            }
        }
    }
    
    private func itemOpacity(for index: Int) -> Double {
        let delay = Double(index) * 0.1
        let adjustedProgress = max(0, cascadeProgress - delay)
        return min(adjustedProgress * 2, 1.0)
    }
    
    private func itemOffset(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.1
        let adjustedProgress = max(0, cascadeProgress - delay)
        return CGFloat((1.0 - adjustedProgress) * 50)
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply liquid mercury effect when dragging
    func liquidMercury(isDragging: Bool, position: CGPoint) -> some View {
        modifier(LiquidMercuryEffect(isDragging: isDragging, dragPosition: position))
    }
    
    /// Create ripple effect at specified location
    func rippleEffect(at location: CGPoint, type: RippleType = .tap) -> some View {
        overlay(
            AdvancedRippleView(ripple: AdvancedRipple(center: location, type: type))
        )
    }
}

// MARK: - Ripple Container

/// Container view that manages multiple ripple effects
struct RippleContainer: View {
    @StateObject private var rippleManager = RippleManager()
    let content: AnyView
    
    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }
    
    var body: some View {
        ZStack {
            content
            
            // Active ripples layer
            ForEach(rippleManager.activeRipples) { ripple in
                AdvancedRippleView(ripple: ripple)
            }
            
            // Voice ripples layer
            ForEach(rippleManager.voiceRipples) { ripple in
                VoiceRippleView(ripple: ripple)
            }
        }
        .environmentObject(rippleManager)
    }
}

// MARK: - Environment Values

struct RippleManagerKey: EnvironmentKey {
    static let defaultValue: RippleManager? = nil
}

extension EnvironmentValues {
    var rippleManager: RippleManager? {
        get { self[RippleManagerKey.self] }
        set { self[RippleManagerKey.self] = newValue }
    }
}

// MARK: - Preview

#if DEBUG
struct RippleEffects_Previews: PreviewProvider {
    static var previews: some View {
        RippleContainer {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(width: 300, height: 200)
                .overlay(
                    Text("Tap for Ripples")
                        .font(.title2)
                )
        }
        .frame(width: 400, height: 300)
    }
}
#endif
