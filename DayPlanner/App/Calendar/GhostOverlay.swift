import SwiftUI

struct GhostOverlay: View {
    let selectedDate: Date
    let dayStartHour: Int
    let minuteHeight: CGFloat
    let suggestions: [Suggestion]
    @Binding var selectedGhosts: Set<UUID>
    let onToggle: (Suggestion) -> Void
    
    var body: some View {
        ForEach(suggestions) { suggestion in
            GhostEventCard(
                suggestion: suggestion,
                selectedDate: selectedDate,
                dayStartHour: dayStartHour,
                minuteHeight: minuteHeight,
                isSelected: selectedGhosts.contains(suggestion.id),
                onToggle: { onToggle(suggestion) }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }
}

private struct GhostEventCard: View {
    let suggestion: Suggestion
    let selectedDate: Date
    let dayStartHour: Int
    let minuteHeight: CGFloat
    let isSelected: Bool
    let onToggle: () -> Void
    
    @EnvironmentObject private var dataManager: AppDataManager
    @State private var isHovering = false
    
    private var calendar: Calendar { Calendar.current }
    
    private var startOfTimeline: Date {
        let dayStart = calendar.startOfDay(for: selectedDate)
        return calendar.date(byAdding: .hour, value: dayStartHour, to: dayStart) ?? dayStart
    }
    
    private var yPosition: CGFloat {
        let delta = suggestion.suggestedTime.timeIntervalSince(startOfTimeline)
        return CGFloat(delta / 60) * minuteHeight
    }
    
    private var eventHeight: CGFloat {
        let computed = CGFloat(suggestion.duration / 60) * minuteHeight
        return max(computed, 44)
    }
    
    private var checkboxSymbol: String {
        isSelected ? "checkmark.circle.fill" : "circle"
    }
    
    private var checkboxTint: Color {
        isSelected ? .white : .blue.opacity(0.75)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.35)
        }
        return Color.blue.opacity(0.18)
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.white.opacity(0.6)
        }
        return Color.blue.opacity(isHovering ? 0.55 : 0.35)
    }
    
    private var energyLabel: String {
        suggestion.energy.description.capitalized
    }
    
    private var linkedGoal: Goal? {
        guard let id = suggestion.relatedGoalId else { return nil }
        return dataManager.appState.goals.first { $0.id == id }
    }
    
    private var linkedPillar: Pillar? {
        guard let id = suggestion.relatedPillarId else { return nil }
        return dataManager.appState.pillars.first { $0.id == id }
    }
    
    private func connectionBadge(title: String, color: Color, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.18), in: Capsule())
        .foregroundStyle(color)
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: checkboxSymbol)
                    .font(.title3)
                    .foregroundStyle(checkboxTint)
                    .padding(.top, 2)
                    .symbolRenderingMode(.palette)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(suggestion.emoji) \(suggestion.title)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.white.opacity(0.9))
                            .lineLimit(2)
                        Spacer()
                        Text(suggestion.suggestedTime.timeString)
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    
                    HStack(spacing: 8) {
                        TagView(
                            text: "\(Int(suggestion.duration / 60))m",
                            systemImage: "clock" 
                        )
                        TagView(
                            text: energyLabel,
                            systemImage: "sparkles"
                        )
                        if suggestion.confidence > 0 {
                            TagView(
                                text: "\(Int(suggestion.confidence * 100))%",
                                systemImage: "bolt.fill"
                            )
                        }
                    }

                    if linkedGoal != nil || linkedPillar != nil {
                        HStack(spacing: 6) {
                            if let goal = linkedGoal {
                                connectionBadge(title: goal.title, color: .cyan, systemImage: "target")
                            }
                            if let pillar = linkedPillar {
                                connectionBadge(title: pillar.name, color: .purple, systemImage: "building.columns")
                            }
                            Spacer()
                        }
                    }
                    
                    if !suggestion.explanation.isEmpty {
                        Text(suggestion.explanation)
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.75))
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
                    .blur(radius: 0.2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [6, 6], dashPhase: 6))
                            .foregroundStyle(borderColor)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: eventHeight, alignment: .top)
        .offset(y: yPosition)
        .opacity(isHovering ? 0.95 : 0.85)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

private struct TagView: View {
    let text: String
    let systemImage: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(text)
                .font(.caption2.monospacedDigit())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.12), in: Capsule())
        .foregroundStyle(Color.white.opacity(0.8))
    }
}

struct GhostAcceptanceBar: View {
    let totalCount: Int
    let selectedCount: Int
    let onAcceptAll: () -> Void
    let onAcceptSelected: () -> Void
    
    private var buttonTitle: String {
        selectedCount > 0 ? "Accept selected" : "Accept all"
    }
    
    private var subtitle: String {
        if selectedCount > 0 {
            return "Ready to stage \(selectedCount) pick\(selectedCount == 1 ? "" : "s")"
        }
        return "\(totalCount) ghost recommendation\(totalCount == 1 ? "" : "s") queued"
    }
    
    private var buttonAction: () -> Void {
        selectedCount > 0 ? onAcceptSelected : onAcceptAll
    }
    
    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(Color.blue.opacity(0.9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommendations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(subtitle)
                        .font(.footnote)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            Button(buttonTitle, action: buttonAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .padding(.vertical, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)
    }
}
