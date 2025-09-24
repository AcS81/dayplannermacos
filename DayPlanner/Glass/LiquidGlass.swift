//
//  LiquidGlass.swift
//  DayPlanner
//
//  The foundation of our liquid glass visual system
//

import SwiftUI
import Metal

// MARK: - Liquid Glass Foundation

/// The core liquid glass view that wraps any content with magical glass effects
struct LiquidGlassView<Content: View>: View {
    let content: Content
    
    @State private var ripplePhase: Double = 0
    @State private var glassOpacity: Double = 0.8
    @State private var hoverPoint: CGPoint = .zero
    @State private var isHovering = false
    @State private var lastTapLocation: CGPoint = .zero
    @State private var ripples: [Ripple] = []
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Background blur layer with green tint
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
                .overlay(
                    Color.green.opacity(0.15) // Green tint overlay
                        .blendMode(.multiply)
                )
            
            // Content layer with liquid distortion
            content
                .modifier(LiquidDistortionEffect(
                    ripples: ripples,
                    hoverPoint: hoverPoint,
                    phase: ripplePhase
                ))
            
            // Active ripples overlay
            ForEach(ripples, id: \.id) { ripple in
                RippleView(ripple: ripple)
            }
            
            // Glass reflection and highlight overlay
            GlassReflectionOverlay(
                opacity: glassOpacity,
                hoverPoint: hoverPoint,
                isHovering: isHovering
            )
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isHovering = hovering
                glassOpacity = 0.8  // Fixed opacity to prevent flashing
            }
        }
        .onTapGesture { location in
            createRipple(at: location)
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    hoverPoint = value.location
                }
                .onEnded { _ in
                    // Complete the gesture properly
                }
        )
    }
    
    private func createRipple(at location: CGPoint) {
        let newRipple = Ripple(
            center: location,
            startTime: Date(),
            maxRadius: 100,
            duration: 1.0
        )
        
        withAnimation(.easeOut(duration: 1.0)) {
            ripples.append(newRipple)
        }
        
        // Remove ripple after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ripples.removeAll { $0.id == newRipple.id }
        }
        
        // Disabled ripple phase animation to prevent continuous flashing
        // ripplePhase = ripplePhase == 0 ? 1 : 0
    }
}

// MARK: - Ripple System

/// Represents a single ripple effect
struct Ripple: Identifiable {
    let id = UUID()
    let center: CGPoint
    let startTime: Date
    let maxRadius: CGFloat
    let duration: TimeInterval
    
    var currentRadius: CGFloat {
        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(elapsed / duration, 1.0)
        return maxRadius * CGFloat(progress)
    }
    
    var opacity: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(elapsed / duration, 1.0)
        return 1.0 - progress
    }
}

/// Visual representation of a ripple
struct RippleView: View {
    let ripple: Ripple
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.8), .blue.opacity(0.4), .clear],
                    startPoint: .center,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .frame(width: animationProgress * 2, height: animationProgress * 2)
            .position(ripple.center)
            .opacity(1.0 - Double(animationProgress / ripple.maxRadius))
            .onAppear {
                withAnimation(.easeOut(duration: ripple.duration)) {
                    animationProgress = ripple.maxRadius
                }
            }
    }
}

// MARK: - Visual Effects

/// Custom visual effect blur for better glass appearance
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = material
        effectView.blendingMode = blendingMode
        effectView.state = .active
        return effectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Glass reflection overlay that follows cursor
struct GlassReflectionOverlay: View {
    let opacity: Double
    let hoverPoint: CGPoint
    let isHovering: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Subtle reflection gradient
                RadialGradient(
                    colors: [
                        .white.opacity(0.1),
                        .blue.opacity(0.05),
                        .clear
                    ],
                    center: UnitPoint(
                        x: hoverPoint.x / geometry.size.width,
                        y: hoverPoint.y / geometry.size.height
                    ),
                    startRadius: 20,
                    endRadius: 100
                )
                .opacity(isHovering ? 1.0 : 0.0)
                
                // Edge highlights
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.3),
                                .clear,
                                .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .opacity(opacity)
            }
        }
    }
}

// MARK: - Liquid Distortion Effect

/// ViewModifier that applies liquid distortion to content
struct LiquidDistortionEffect: ViewModifier {
    let ripples: [Ripple]
    let hoverPoint: CGPoint
    let phase: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(1.0 + sin(phase * .pi) * 0.002) // Subtle breathing
            .opacity(1.0)  // Fixed opacity - no more flashing
    }
}

// MARK: - Time-Based Glass Tinting

/// Provides time-of-day based glass tinting
// TimeGradient is defined in Animations.swift

// MARK: - Glass Material Helpers

extension Material {
    /// Custom glass materials for different contexts
    static let crystalGlass = Material.ultraThinMaterial
    static let mistGlass = Material.thinMaterial  
    static let waterGlass = Material.regularMaterial
    static let cloudGlass = Material.thickMaterial
}

// MARK: - Liquid Glass Modifiers

// View extensions are defined in Extensions.swift
extension View {
    /// Apply subtle glass background with green tint
    func glassBackground(_ material: Material = .regularMaterial) -> some View {
        self
            .background(material, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                Color.green.opacity(0.1)
                    .blendMode(.multiply)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    /// Apply liquid glass with specific mood and green tint
    func glassEffect(_ mood: GlassMood) -> some View {
        self
            .background(mood.backgroundGradient)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                Color.green.opacity(0.12)
                    .blendMode(.multiply)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct LiquidGlassView_Previews: PreviewProvider {
    static var previews: some View {
        LiquidGlassView {
            VStack(spacing: 20) {
                Text("🌊 Liquid Glass")
                    .font(.title)
                    .fontWeight(.medium)
                
                Text("Touch anywhere to create ripples")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue.opacity(0.3))
                        .frame(width: 60, height: 40)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.green.opacity(0.3))
                        .frame(width: 60, height: 40)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.purple.opacity(0.3))
                        .frame(width: 60, height: 40)
                }
            }
            .padding(40)
        }
        .frame(width: 400, height: 300)
    }
}
#endif
