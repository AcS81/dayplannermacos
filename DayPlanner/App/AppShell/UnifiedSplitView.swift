// MARK: - Unified Split View

import SwiftUI

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

