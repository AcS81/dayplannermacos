//
//  Animations.swift
//  DayPlanner
//
//  Advanced liquid glass animations and celebration effects
//

import SwiftUI

// MARK: - Animation Constants

enum LiquidAnimations {
    static let shortDuration: Double = 0.3
    static let mediumDuration: Double = 0.6
    static let longDuration: Double = 1.2
    
    static let springResponse: Double = 0.6
    static let springDamping: Double = 0.8
    
    static let gentleSpring = Animation.spring(response: springResponse, dampingFraction: springDamping)
    static let quickSpring = Animation.spring(response: shortDuration, dampingFraction: springDamping)
    static let slowSpring = Animation.spring(response: longDuration, dampingFraction: springDamping)
}

// MARK: - Time-Based Background Gradient

/// Dynamic background that changes based on time of day
struct TimeGradient: View {
    let currentHour: Int
    @State private var animationPhase: Double = 0
    
    var body: some View {
        LinearGradient(
            colors: timeColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .hueRotation(.degrees(animationPhase * 10))
        .onAppear {
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                animationPhase = 1.0
            }
        }
    }
    
    private var timeColors: [Color] {
        switch currentHour {
        case 0..<3:   // Deep Night
            return [Color(hex: "0A0A0A").opacity(0.5), Color(hex: "1D1D1F").opacity(0.4), Color(hex: "2C2C2E").opacity(0.3)]
        case 3..<6:   // Pre-dawn
            return [Color(hex: "1D1D1F").opacity(0.4), Color(hex: "2C2C2E").opacity(0.3), Color(hex: "48484A").opacity(0.2)]
        case 6..<9:   // Sunrise
            return [Color(hex: "FF9500").opacity(0.3), Color(hex: "FF6B35").opacity(0.2), Color(hex: "F7931E").opacity(0.1)]
        case 9..<12:  // Morning
            return [Color(hex: "34C759").opacity(0.2), Color(hex: "64D2FF").opacity(0.2), Color(hex: "007AFF").opacity(0.1)]
        case 12..<17: // Afternoon
            return [Color(hex: "007AFF").opacity(0.3), Color(hex: "64D2FF").opacity(0.2), Color(hex: "34C759").opacity(0.1)]
        case 17..<20: // Evening
            return [Color(hex: "AF52DE").opacity(0.3), Color(hex: "FF9500").opacity(0.2), Color(hex: "FF6B35").opacity(0.1)]
        case 20..<24: // Night
            return [Color(hex: "1D1D1F").opacity(0.4), Color(hex: "2C2C2E").opacity(0.3), Color(hex: "48484A").opacity(0.2)]
        default:      // Fallback (shouldn't happen)
            return [Color(hex: "1D1D1F").opacity(0.4), Color(hex: "2C2C2E").opacity(0.3), Color(hex: "48484A").opacity(0.2)]
        }
    }
}

// MARK: - Celebration Animations

/// Burst of light particles for celebrations
struct CelebrationBurst: View {
    let center: CGPoint
    let isActive: Bool
    
    @State private var particles: [CelebrationParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(particles[index].color)
                    .frame(width: particles[index].size, height: particles[index].size)
                    .position(particles[index].position)
                    .opacity(particles[index].opacity)
                    .scaleEffect(particles[index].scale)
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                createBurst()
            }
        }
    }
    
    private func createBurst() {
        particles = []
        
        // Create 12 particles in a burst pattern
        for i in 0..<12 {
            let angle = Double(i) * .pi * 2 / 12
            let distance: CGFloat = 80
            
            let particle = CelebrationParticle(
                position: center,
                targetPosition: CGPoint(
                    x: center.x + CoreGraphics.cos(angle) * distance,
                    y: center.y + sin(angle) * distance
                ),
                color: celebrationColors.randomElement() ?? .blue,
                size: CGFloat.random(in: 4...8)
            )
            
            particles.append(particle)
        }
        
        // Animate particles
        withAnimation(.easeOut(duration: 1.0)) {
            for i in particles.indices {
                particles[i].position = particles[i].targetPosition
                particles[i].opacity = 0
                particles[i].scale = 0.5
            }
        }
        
        // Clear particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            particles.removeAll()
        }
    }
    
    private let celebrationColors: [Color] = [
        .green, .mint, .teal, .orange, .pink, .yellow, .green, .mint
    ]
}

struct CelebrationParticle {
    var position: CGPoint
    let targetPosition: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
}

// MARK: - Liquid Flow Animations

/// Smooth flowing animation between states
struct LiquidTransition<Content: View>: View {
    let content: Content
    let isActive: Bool
    let direction: FlowDirection
    
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    init(isActive: Bool, direction: FlowDirection = .up, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.isActive = isActive
        self.direction = direction
    }
    
    var body: some View {
        content
            .offset(offset)
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(LiquidAnimations.gentleSpring, value: isActive)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    // Enter animation
                    withAnimation(LiquidAnimations.gentleSpring) {
                        offset = .zero
                        scale = 1.0
                        opacity = 1.0
                    }
                } else {
                    // Exit animation
                    withAnimation(LiquidAnimations.quickSpring) {
                        offset = direction.offsetValue
                        scale = 0.8
                        opacity = 0
                    }
                }
            }
            .onAppear {
                if !isActive {
                    offset = direction.offsetValue
                    scale = 0.8
                    opacity = 0
                }
            }
    }
}

enum FlowDirection {
    case up, down, left, right, center
    
    var offsetValue: CGSize {
        switch self {
        case .up: return CGSize(width: 0, height: -50)
        case .down: return CGSize(width: 0, height: 50)
        case .left: return CGSize(width: -50, height: 0)
        case .right: return CGSize(width: 50, height: 0)
        case .center: return .zero
        }
    }
}

// MARK: - Glass State Transitions

/// Visual representation of different glass states with transitions
struct GlassStateIndicator: View {
    let state: GlassState
    let size: CGFloat = 12
    
    var body: some View {
        Circle()
            .fill(stateGradient)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(stateColor.opacity(0.6), lineWidth: 1)
            )
            .scaleEffect(state == .liquid ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: state == .liquid)
    }
    
    private var stateColor: Color {
        switch state {
        case .solid: return .green
        case .liquid: return .mint
        case .mist: return .gray
        case .crystal: return .teal
        }
    }
    
    private var stateGradient: RadialGradient {
        RadialGradient(
            colors: [stateColor.opacity(0.8), stateColor.opacity(0.4), .clear],
            center: .center,
            startRadius: 0,
            endRadius: size / 2
        )
    }
}

// MARK: - Morphing Shapes

/// Shape that morphs between different forms
struct MorphingShape: View {
    let targetShape: ShapeType
    @State private var currentProgress: Double = 0
    
    var body: some View {
        morphedPath
            .fill(.green.opacity(0.3))
            .stroke(.green.opacity(0.6), lineWidth: 2)
            .animation(.easeInOut(duration: 2.0), value: targetShape)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    currentProgress = 1.0
                }
            }
    }
    
    private var morphedPath: Path {
        Path { path in
            switch targetShape {
            case .circle:
                path.addEllipse(in: CGRect(x: 0, y: 0, width: 100, height: 100))
            case .square:
                path.addRect(CGRect(x: 0, y: 0, width: 100, height: 100))
            case .wave:
                addWavePath(to: &path)
            case .drop:
                addDropPath(to: &path)
            }
        }
    }
    
    private func addWavePath(to path: inout Path) {
        let width: CGFloat = 100
        let height: CGFloat = 100
        
        path.move(to: CGPoint(x: 0, y: height/2))
        
        for x in stride(from: 0, to: width, by: 2) {
            let y = height/2 + sin(x/10 + currentProgress * .pi * 2) * 20
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    
    private func addDropPath(to path: inout Path) {
        // Simple drop shape
        path.move(to: CGPoint(x: 50, y: 0))
        path.addCurve(
            to: CGPoint(x: 100, y: 50),
            control1: CGPoint(x: 80, y: 20),
            control2: CGPoint(x: 90, y: 35)
        )
        path.addCurve(
            to: CGPoint(x: 50, y: 100),
            control1: CGPoint(x: 100, y: 70),
            control2: CGPoint(x: 80, y: 90)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: 50),
            control1: CGPoint(x: 20, y: 90),
            control2: CGPoint(x: 0, y: 70)
        )
        path.addCurve(
            to: CGPoint(x: 50, y: 0),
            control1: CGPoint(x: 10, y: 35),
            control2: CGPoint(x: 20, y: 20)
        )
    }
}

enum ShapeType: CaseIterable {
    case circle, square, wave, drop
}

// MARK: - Energy Flow Visualization

/// Animated energy flow lines
struct EnergyFlow: View {
    let energy: EnergyType
    @State private var flowPhase: Double = 0
    
    var body: some View {
        Canvas { context, size in
            drawEnergyFlow(context: context, size: size)
        }
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                flowPhase = 1.0
            }
        }
    }
    
    private func drawEnergyFlow(context: GraphicsContext, size: CGSize) {
        let path = createFlowPath(size: size)
        
        // Create gradient for energy flow
        let gradient = Gradient(colors: energy.flowColors)
        
        // Draw flowing line
        context.stroke(
            path,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: 0, y: size.height/2),
                endPoint: CGPoint(x: size.width, y: size.height/2)
            ),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        
        // Draw flow particles
        drawFlowParticles(context: context, path: path)
    }
    
    private func createFlowPath(size: CGSize) -> Path {
        Path { path in
            let amplitude: CGFloat = 20
            let frequency: CGFloat = 0.02
            
            path.move(to: CGPoint(x: 0, y: size.height/2))
            
            for x in stride(from: 0, to: size.width, by: 2) {
                let y = size.height/2 + sin(x * frequency + flowPhase * .pi * 2) * amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
    
    private func drawFlowParticles(context: GraphicsContext, path: Path) {
        // Draw small particles along the path
        for i in 0..<5 {
            // Calculate progress position for particle animation
            _ = (Double(i) / 5.0 + flowPhase).truncatingRemainder(dividingBy: 1.0)
            let point = path.currentPoint ?? .zero
            
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
                with: .color(energy.color.opacity(0.8))
            )
        }
    }
}

extension EnergyType {
    var flowColors: [Color] {
        switch self {
        case .sunrise: return [.orange, .yellow, .orange]
        case .daylight: return [.green, .mint, .green]  
        case .moonlight: return [.teal, .mint, .teal]
        }
    }
}

// MARK: - Haptic Feedback Integration

#if os(macOS)
// macOS-specific subtle feedback
struct HapticFeedback {
    static func light() {
        NSSound.beep()
    }
    
    static func success() {
        // Could play a subtle system sound
    }
    
    static func error() {
        NSSound.beep()
    }
}
#endif

// MARK: - View Modifiers

extension View {
    /// Apply liquid transition effect
    func liquidTransition(isActive: Bool, direction: FlowDirection = .up) -> some View {
        LiquidTransition(isActive: isActive, direction: direction) {
            self
        }
    }
    
    /// Apply celebration burst effect
    func celebrationBurst(at center: CGPoint, isActive: Bool) -> some View {
        overlay(
            CelebrationBurst(center: center, isActive: isActive)
        )
    }
    
    /// Apply morphing shape overlay
    func morphingShape(_ shape: ShapeType) -> some View {
        overlay(
            MorphingShape(targetShape: shape)
                .allowsHitTesting(false)
        )
    }
    
    /// Apply energy flow effect
    func energyFlow(_ energy: EnergyType) -> some View {
        overlay(
            EnergyFlow(energy: energy)
                .allowsHitTesting(false)
        )
    }
    
    /// Apply glass state indicator
    func glassStateIndicator(_ state: GlassState, position: UnitPoint = .topTrailing) -> some View {
        overlay(
            GlassStateIndicator(state: state),
            alignment: Alignment(horizontal: position.x < 0.5 ? .leading : .trailing,
                               vertical: position.y < 0.5 ? .top : .bottom)
        )
    }
}

// MARK: - Success Animations

/// Complete success animation sequence
struct SuccessSequence: View {
    let isActive: Bool
    @State private var phase: Int = 0
    
    var body: some View {
        ZStack {
            // Expanding ring
            if phase >= 1 {
                Circle()
                    .strokeBorder(.green.opacity(0.6), lineWidth: 3)
                    .scaleEffect(phase >= 1 ? 2.0 : 0.5)
                    .opacity(phase >= 1 ? 0 : 1)
                    .animation(.easeOut(duration: 0.8), value: phase)
            }
            
            // Center checkmark
            if phase >= 2 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
                    .scaleEffect(phase >= 2 ? 1.2 : 0.8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: phase)
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startSuccessSequence()
            } else {
                phase = 0
            }
        }
    }
    
    private func startSuccessSequence() {
        phase = 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            phase = 2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            phase = 0
        }
    }
}

// MARK: - Preview

#if DEBUG
struct Animations_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            TimeGradient(currentHour: 14)
                .frame(height: 100)
            
            HStack(spacing: 20) {
                ForEach(GlassState.allCases, id: \.self) { state in
                    GlassStateIndicator(state: state)
                }
            }
            
            EnergyFlow(energy: .sunrise)
                .frame(height: 60)
            
            SuccessSequence(isActive: true)
                .frame(width: 60, height: 60)
        }
        .frame(width: 400, height: 400)
        .padding()
    }
}
#endif
