// MARK: - Gap Filler View

import SwiftUI

struct GapFillerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var gapSuggestions: [GapSuggestion] = []
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Find time for micro-tasks in your schedule gaps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if isAnalyzing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        
                        Text("Analyzing your schedule...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else if gapSuggestions.isEmpty {
                    VStack(spacing: 16) {
                        Text("🔍")
                            .font(.title)
                        
                        Text("No gaps found")
                            .font(.headline)
                        
                        Text("Your schedule looks full! Try refreshing or checking a different day.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Analyze Again") {
                            analyzeGaps()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(gapSuggestions) { suggestion in
                                GapSuggestionCard(suggestion: suggestion) {
                                    applyGapSuggestion(suggestion)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Gap Filler")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            analyzeGaps()
        }
    }
    
    private func analyzeGaps() {
        isAnalyzing = true
        
        Task {
            let gaps = findScheduleGaps()
            let suggestions = await generateGapSuggestions(for: gaps)
            
            await MainActor.run {
                gapSuggestions = suggestions
                isAnalyzing = false
            }
        }
    }
    
    private func findScheduleGaps() -> [ScheduleGap] {
        let allBlocks = dataManager.appState.currentDay.blocks
        let sortedBlocks = allBlocks.sortedByTime
        var gaps: [ScheduleGap] = []
        
        // If no blocks exist, treat the whole day as gaps
        if sortedBlocks.isEmpty {
            // Create gaps for typical work hours
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            gaps.append(ScheduleGap(
                startTime: calendar.date(byAdding: .hour, value: 9, to: startOfDay)!,
                duration: 3600 * 8 // 8 hour work day
            ))
            return gaps
        }
        
        // Find gaps between existing blocks
        for i in 0..<sortedBlocks.count - 1 {
            let currentEnd = sortedBlocks[i].endTime
            let nextStart = sortedBlocks[i + 1].startTime
            
            let gapDuration = nextStart.timeIntervalSince(currentEnd)
            if gapDuration >= 900 { // 15+ minute gaps
                gaps.append(ScheduleGap(
                    startTime: currentEnd,
                    duration: gapDuration
                ))
            }
        }
        
        return gaps
    }
    
    private func generateGapSuggestions(for gaps: [ScheduleGap]) async -> [GapSuggestion] {
        var suggestions: [GapSuggestion] = []
        
        // Always provide some suggestions even if no gaps found
        if gaps.isEmpty {
            // Create default suggestions for an empty schedule
            let defaultTasks = [
                MicroTask(title: "Quick email check", estimatedDuration: 900),
                MicroTask(title: "Plan tomorrow", estimatedDuration: 1200),
                MicroTask(title: "Organize workspace", estimatedDuration: 1800)
            ]
            
            let now = Date()
            for (index, task) in defaultTasks.enumerated() {
                let startTime = Calendar.current.date(byAdding: .hour, value: index + 1, to: now) ?? now
                suggestions.append(GapSuggestion(
                    task: task,
                    startTime: startTime,
                    duration: task.estimatedDuration
                ))
            }
            return suggestions
        }
        
        for gap in gaps {
            let gapMinutes = Int(gap.duration / 60)
            let taskSuggestions = generateTasksForDuration(gapMinutes)
            
            for task in taskSuggestions {
                suggestions.append(GapSuggestion(
                    task: task,
                    startTime: gap.startTime,
                    duration: min(gap.duration, task.estimatedDuration)
                ))
            }
        }
        
        return suggestions
    }
    
    private func generateTasksForDuration(_ minutes: Int) -> [MicroTask] {
        switch minutes {
        case 15..<30:
            return [
                MicroTask(title: "Quick email check", estimatedDuration: 900),
                MicroTask(title: "Tidy workspace", estimatedDuration: 900),
                MicroTask(title: "Stretch break", estimatedDuration: 600)
            ]
        case 30..<60:
            return [
                MicroTask(title: "Review daily goals", estimatedDuration: 1800),
                MicroTask(title: "Quick workout", estimatedDuration: 1800),
                MicroTask(title: "Meal prep", estimatedDuration: 2400)
            ]
        default:
            return [
                MicroTask(title: "Short walk", estimatedDuration: 600),
                MicroTask(title: "Mindfulness moment", estimatedDuration: 300)
            ]
        }
    }
    
    private func applyGapSuggestion(_ suggestion: GapSuggestion) {
        let newBlock = TimeBlock(
            title: suggestion.task.title,
            startTime: suggestion.startTime,
            duration: suggestion.duration,
            energy: .daylight,
            emoji: "🌊",
            glassState: .liquid
        )
        
        dataManager.addTimeBlock(newBlock)
        
        // Remove the applied suggestion
        if let index = gapSuggestions.firstIndex(where: { $0.id == suggestion.id }) {
            gapSuggestions.remove(at: index)
        }
        
        dismiss()
    }
}

struct ScheduleGap {
    let startTime: Date
    let duration: TimeInterval
}

struct MicroTask {
    let title: String
    let estimatedDuration: TimeInterval
}

struct GapSuggestion: Identifiable {
    let id = UUID()
    let task: MicroTask
    let startTime: Date
    let duration: TimeInterval
}

struct GapSuggestionCard: View {
    let suggestion: GapSuggestion
    let onApply: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(suggestion.startTime.timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(suggestion.duration / 60))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Add") {
                onApply()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}

