//
//  TimelineViews.swift
//  DayPlanner
//
//  Timeline-related views extracted from DayPlannerApp.swift
//

import SwiftUI

// MARK: - Precise Timeline View (Exact Positioning)

struct ProportionalTimelineView: View {
    let selectedDate: Date
    let blocks: [TimeBlock]
    let draggedBlock: TimeBlock?
    let minuteHeight: CGFloat
    let onTap: (Date) -> Void
    let onBlockDrag: (TimeBlock, CGPoint) -> Void
    let onBlockDrop: (TimeBlock, Date) -> Void
    
    private let calendar = Calendar.current
    private let dayStartHour = 6
    private let dayEndHour = 24
    
    private var currentHour: Int {
        calendar.component(.hour, from: Date())
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Time labels column with precise minute markers
            TimeLabelsColumn(
                selectedDate: selectedDate,
                dayStartHour: dayStartHour,
                dayEndHour: dayEndHour
            )
            .frame(width: 80)
            
            // Precise timeline canvas with beautiful day/night gradients
            ZStack(alignment: .topLeading) {
                // Beautiful day/night gradient background
                TimeGradient(currentHour: currentHour)
                    .opacity(0.4)
                    .cornerRadius(8)
                
                // Background grid
                TimelineCanvas(
                    selectedDate: selectedDate,
                    dayStartHour: dayStartHour,
                    dayEndHour: dayEndHour,
                    onTap: onTap
                )
                
                // Events positioned at exact times
                ForEach(blocks) { block in
                    PreciseEventCard(
                        block: block,
                        selectedDate: selectedDate,
                        dayStartHour: dayStartHour,
                        minuteHeight: minuteHeight,
                        isDragged: draggedBlock?.id == block.id,
                        allBlocks: blocks,
                        onDrag: { location in
                            onBlockDrag(block, location)
                        },
                        onDrop: { newTime in
                            onBlockDrop(block, newTime)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func blocksForHour(_ hour: Int, blocks: [TimeBlock]) -> [TimeBlock] {
        return blocks.filter { block in
            let blockHour = calendar.component(.hour, from: block.startTime)
            return blockHour == hour
        }
    }
    
    private func hourLabel(for hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        switch hour {
        case 6: return "🌅 \(formatter.string(from: date))"    // Sunrise
        case 12: return "☀️ \(formatter.string(from: date))"   // Noon sun
        case 18: return "🌇 \(formatter.string(from: date))"   // Sunset
        case 21: return "🌙 \(formatter.string(from: date))"   // Evening moon
        case 0: return "🌛 \(formatter.string(from: date))"    // Midnight crescent
        default: return formatter.string(from: date)
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        return calendar.component(.hour, from: Date()) == hour &&
               calendar.isDate(selectedDate, inSameDayAs: Date())
    }
    
    private func hourBackgroundColor(for hour: Int) -> Color {
        AstronomicalTimeCalculator.shared.getTimeColor(for: hour, date: selectedDate)
    }
    
    @ViewBuilder
    private func currentTimeIndicator(for hour: Int) -> some View {
        if isCurrentHour(hour) {
            let now = Date()
            let minute = calendar.component(.minute, from: now)
            let offsetY = CGFloat(minute) // 1 pixel per minute
            
            HStack(spacing: 8) {
                Rectangle()
                    .fill(.blue)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .opacity(0.8)
                    .shadow(color: .blue, radius: 1)
                
                Text("now")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .opacity(0.9)
            }
            .offset(y: offsetY)
        }
    }
}

// MARK: - Precise Timeline Components

struct TimeLabelsColumn: View {
    let selectedDate: Date
    let dayStartHour: Int
    let dayEndHour: Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(dayStartHour..<dayEndHour, id: \.self) { hour in
                VStack(spacing: 0) {
                    // Hour label at top
                    Text(hourLabel(for: hour))
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(isCurrentHour(hour) ? .blue : .primary)
                        .frame(height: 15, alignment: .bottom)
                    
                    // Quarter hour markers
                    VStack(spacing: 0) {
                        ForEach([15, 30, 45], id: \.self) { minute in
                            HStack {
                                Spacer()
                                Text(":\(minute)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(height: 15)
                        }
                    }
                }
                .frame(height: 60) // 60 pixels per hour
            }
        }
    }
    
    private func hourLabel(for hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        switch hour {
        case 6: return "🌅 \(formatter.string(from: date))"    // Sunrise
        case 12: return "☀️ \(formatter.string(from: date))"   // Noon sun
        case 18: return "🌇 \(formatter.string(from: date))"   // Sunset
        case 21: return "🌙 \(formatter.string(from: date))"   // Evening moon
        case 0: return "🌛 \(formatter.string(from: date))"    // Midnight crescent
        default: return formatter.string(from: date)
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        return calendar.component(.hour, from: Date()) == hour &&
               calendar.isDate(selectedDate, inSameDayAs: Date())
    }
}

struct TimelineCanvas: View {
    let selectedDate: Date
    let dayStartHour: Int
    let dayEndHour: Int
    let onTap: (Date) -> Void
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(dayStartHour..<dayEndHour, id: \.self) { hour in
                Rectangle()
                    .fill(hourBackgroundColor(for: hour))
                    .frame(height: 60) // 60 pixels per hour (1 pixel per minute)
                    .overlay(
                        // Quarter hour grid lines
                        VStack(spacing: 0) {
                            ForEach([15, 30, 45], id: \.self) { minute in
                                Rectangle()
                                    .fill(.quaternary.opacity(0.1))
                                    .frame(height: 1)
                                    .frame(maxWidth: .infinity)
                                    .offset(y: CGFloat(minute - 15))
                            }
                        },
                        alignment: .top
                    )
                    .overlay(
                        // Current time indicator
                        currentTimeIndicator(for: hour),
                        alignment: .topLeading
                    )
                    .overlay(
                        // Hour separator
                        Rectangle()
                            .fill(.quaternary.opacity(0.3))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let hourTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                        onTap(hourTime)
                    }
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        let hourTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                        return handleTimeslotDrop(providers: providers, at: hourTime)
                    }
            }
        }
    }
    
    private func hourBackgroundColor(for hour: Int) -> Color {
        AstronomicalTimeCalculator.shared.getTimeColor(for: hour, date: selectedDate)
    }
    
    @ViewBuilder
    private func currentTimeIndicator(for hour: Int) -> some View {
        if isCurrentHour(hour) {
            let now = Date()
            let minute = calendar.component(.minute, from: now)
            let offsetY = CGFloat(minute) // 1 pixel per minute
            
            HStack(spacing: 8) {
                Rectangle()
                    .fill(.blue)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .opacity(0.8)
                    .shadow(color: .blue, radius: 1)
                
                Text("now")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .opacity(0.9)
            }
            .offset(y: offsetY)
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        return calendar.component(.hour, from: Date()) == hour &&
               calendar.isDate(selectedDate, inSameDayAs: Date())
    }
    
    private func handleTimeslotDrop(providers: [NSItemProvider], at time: Date) -> Bool {
        for provider in providers {
            provider.loadObject(ofClass: NSString.self) { item, error in
                if let payload = item as? String, error == nil {
                    DispatchQueue.main.async {
                        self.processDroppedItem(payload: payload, at: time)
                    }
                }
            }
        }
        return true
    }
    
    private func processDroppedItem(payload: String, at time: Date) {
        // Handle backfill template drops
        if payload.hasPrefix("backfill_template:") {
            let parts = payload.dropFirst("backfill_template:".count).components(separatedBy: "|")
            if parts.count >= 5 {
                let title = parts[0]
                let duration = TimeInterval(Int(parts[1]) ?? 3600)
                let energy = EnergyType(rawValue: parts[2]) ?? .daylight
                let emoji = parts[3]
                
                // Create enhanced title with AI context
                let enhancedTitle = aiService.enhanceEventTitle(originalTitle: title, time: time, duration: duration)
                
                let newBlock = TimeBlock(
                    title: enhancedTitle,
                    startTime: time,
                    duration: duration,
                    energy: energy,
                    emoji: emoji
                )
                
                dataManager.addTimeBlock(newBlock)
            }
        }
        // Handle todo item drops
        else if payload.hasPrefix("todo_item:") {
            let parts = payload.dropFirst("todo_item:".count).components(separatedBy: "|")
            if parts.count >= 4 {
                let title = parts[0]
                let _ = parts[1] // UUID - we don't need it for the time block
                let dueDateString = parts[2]
                let isCompleted = Bool(parts[3]) ?? false
                
                // Don't create time blocks for completed todos
                guard !isCompleted else { return }
                
                // Create enhanced title with AI context
                let enhancedTitle = aiService.enhanceEventTitle(originalTitle: title, time: time, duration: 3600)
                
                let newBlock = TimeBlock(
                    title: enhancedTitle,
                    startTime: time,
                    duration: 3600, // Default 1 hour for todo items
                    energy: .daylight,
                    emoji: "📝"
                )
                
                dataManager.addTimeBlock(newBlock)
            }
        }
        // Handle chain template drops
        else if payload.hasPrefix("chain_template:") {
            let parts = payload.dropFirst("chain_template:".count).components(separatedBy: "|")
            if parts.count >= 3 {
                let name = parts[0]
                let totalDuration = Int(parts[1]) ?? 120
                let icon = parts[2]
                
                // Find the matching chain template
                if let template = findChainTemplate(by: name) {
                    // Create multiple time blocks based on the template's activities
                    createChainEventsFromTemplate(template, startTime: time)
                } else {
                    // Fallback: create a single event if template not found
                    let enhancedTitle = aiService.enhanceEventTitle(originalTitle: name, time: time, duration: TimeInterval(totalDuration * 60))
                    
                    let newBlock = TimeBlock(
                        title: enhancedTitle,
                        startTime: time,
                        duration: TimeInterval(totalDuration * 60),
                        energy: .daylight,
                        emoji: icon
                    )
                    
                    dataManager.addTimeBlock(newBlock)
                }
            }
        }
    }
    
    private func findChainTemplate(by name: String) -> ChainTemplate? {
        // Define the same chain templates here for drop handling
        let templates = [
            ChainTemplate(
                name: "Morning Routine",
                icon: "🌅",
                activities: ["Wake up routine", "Exercise", "Breakfast", "Plan day"],
                totalDuration: 120, // 2 hours
                energyFlow: [.sunrise, .sunrise, .daylight, .daylight]
            ),
            ChainTemplate(
                name: "Deep Work",
                icon: "🎯", 
                activities: ["Setup workspace", "Focus session", "Break", "Review"],
                totalDuration: 90, // 1.5 hours
                energyFlow: [.daylight, .daylight, .moonlight, .daylight]
            ),
            ChainTemplate(
                name: "Evening Wind-down",
                icon: "🌙",
                activities: ["Dinner", "Reflection", "Reading", "Sleep prep"],
                totalDuration: 150, // 2.5 hours  
                energyFlow: [.daylight, .moonlight, .moonlight, .moonlight]
            ),
            ChainTemplate(
                name: "Creative Flow",
                icon: "🎨",
                activities: ["Inspiration gathering", "Brainstorm", "Create", "Refine"],
                totalDuration: 180, // 3 hours
                energyFlow: [.daylight, .sunrise, .sunrise, .daylight]
            )
        ]
        
        return templates.first { $0.name == name }
    }
    
    private func createChainEventsFromTemplate(_ template: ChainTemplate, startTime: Date) {
        var currentTime = startTime
        let activityDuration = TimeInterval(template.totalDuration * 60 / template.activities.count)
        
        for (index, activity) in template.activities.enumerated() {
            let energy = index < template.energyFlow.count ? template.energyFlow[index] : .daylight
            let enhancedTitle = aiService.enhanceEventTitle(originalTitle: activity, time: currentTime, duration: activityDuration)
            
            let newBlock = TimeBlock(
                title: enhancedTitle,
                startTime: currentTime,
                duration: activityDuration,
                energy: energy,
                emoji: template.icon
            )
            
            dataManager.addTimeBlock(newBlock)
            
            // Move to next time slot (with small buffer)
            currentTime = currentTime.addingTimeInterval(activityDuration + 300) // 5 minute buffer
        }
    }
}
