// MARK: - Status Bar

import SwiftUI

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

