// MARK: - Calendar Panel Header

import SwiftUI

struct CalendarPanelHeader: View {
    @Binding var selectedDate: Date
    @Binding var showingMonthView: Bool
    @Binding var showingRecommendations: Bool
    @Binding var showingTodoList: Bool
    let ghostCount: Int
    let isDefaultMonthView: Bool // Track if month view is shown by default
    let onBackToCalendar: (() -> Void)? // Callback to return to calendar view
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    // Elegant navigation arrows positioned next to date
                    Button(action: previousDay) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(.blue.opacity(0.08), in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Text(dateFormatter.string(from: selectedDate))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Button(action: nextDay) {
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(.blue.opacity(0.08), in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Text("Calendar")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Back to calendar button - show when in day view mode
                if !showingMonthView {
                    Button(action: { 
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            onBackToCalendar?()
                        }
                    }) {
                        Image(systemName: "calendar.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .symbolEffect(.bounce, value: !showingMonthView)
                    }
                    .buttonStyle(.plain)
                }
                
                // Month expand/collapse button - only show when not default view and in month view
                if !isDefaultMonthView && showingMonthView {
                    Button(action: { 
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingMonthView.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .symbolEffect(.bounce, value: showingMonthView)
                    }
                    .buttonStyle(.plain)
                }
                
                // To-Do expand/collapse button
                Button(action: { 
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingTodoList.toggle()
                    }
                }) {
                    Image(systemName: showingTodoList ? "chevron.down.circle.fill" : "checklist")
                        .font(.title2)
                        .foregroundStyle(showingTodoList ? .blue : .secondary)
                        .symbolEffect(.bounce, value: showingTodoList)
                }
                .buttonStyle(.plain)
                
                // Recommendations toggle with ghost count badge
                Button(action: toggleRecommendations) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.footnote)
                            .foregroundStyle(showingRecommendations ? Color.white : Color.blue.opacity(0.8))
                        Text("Recommendations")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(showingRecommendations ? Color.white : Color.primary.opacity(0.85))
                        if ghostCount > 0 {
                            Text("\(ghostCount)")
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(showingRecommendations ? Color.white.opacity(0.2) : Color.blue.opacity(0.12))
                                )
                                .foregroundStyle(showingRecommendations ? Color.white : Color.blue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(showingRecommendations ? .blue : .blue.opacity(0.25))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func previousDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func nextDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        }
    }
}

extension CalendarPanelHeader {
    private func toggleRecommendations() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            showingRecommendations.toggle()
        }
    }
}
