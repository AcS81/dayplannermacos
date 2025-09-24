//
//  MonthViewComponents.swift
//  DayPlanner
//
//  Month View and Calendar Components
//

import SwiftUI

// MARK: - Month View Expanded

struct MonthViewExpanded: View {
    @Binding var selectedDate: Date
    @State private var displayedMonth: Date = Date()
    @State private var selectedDates: Set<Date> = []
    @State private var dragStartDate: Date?
    @State private var isDragging = false
    let dataManager: AppDataManager
    let onDayClick: (() -> Void)?
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left.circle")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(dateFormatter.string(from: displayedMonth))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right.circle")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                // Weekday headers
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(height: 20)
                }
                
                // Calendar days with multi-selection
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        MultiSelectCalendarDayCell(
                            date: date,
                            selectedDate: selectedDate,
                            selectedDates: selectedDates,
                            isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                            onTap: { handleDayTap(date) },
                            onDragStart: { handleDragStart(date) },
                            onDragEnter: { handleDragEnter(date) },
                            onDragEnd: { handleDragEnd() },
                            dataManager: dataManager
                        )
                    } else {
                        Rectangle()
                            .fill(.clear)
                            .frame(height: 28)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            displayedMonth = selectedDate
            selectedDates = [selectedDate]
        }
    }
    
    private var calendarDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let firstDayOfWeek = calendar.component(.weekday, from: firstOfMonth) - 1
        
        var days: [Date?] = Array(repeating: nil, count: firstDayOfWeek)
        
        let numberOfDays = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Fill remaining cells to complete the grid
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        }
    }
    
    // Multi-day selection handlers
    private func handleDayTap(_ date: Date) {
        // Always set the selected date first - this will trigger onChange and switchToDay
        selectedDate = date
        
        if selectedDates.contains(date) && selectedDates.count == 1 {
            // Single selection - navigate to that day and trigger day click
            onDayClick?()
        } else if selectedDates.contains(date) {
            // Remove from multi-selection
            selectedDates.remove(date)
            if !selectedDates.isEmpty {
                selectedDate = selectedDates.sorted().first ?? date
            }
        } else {
            // Add to selection or replace selection and trigger day click
            selectedDates = [date]
            onDayClick?()
        }
    }
    
    private func handleDragStart(_ date: Date) {
        dragStartDate = date
        isDragging = true
        selectedDates = [date]
        selectedDate = date
    }
    
    private func handleDragEnter(_ date: Date) {
        guard let startDate = dragStartDate, isDragging else { return }
        
        // Calculate continuous date range
        let start = min(startDate, date)
        let end = max(startDate, date)
        
        var newSelection: Set<Date> = []
        var current = start
        
        while current <= end {
            newSelection.insert(current)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
        }
        
        selectedDates = newSelection
        selectedDate = date
    }
    
    private func handleDragEnd() {
        dragStartDate = nil
        isDragging = false
    }
}

// MARK: - Calendar Day Cell

struct MultiSelectCalendarDayCell: View {
    let date: Date
    let selectedDate: Date
    let selectedDates: Set<Date>
    let isCurrentMonth: Bool
    let onTap: () -> Void
    let onDragStart: () -> Void
    let onDragEnter: () -> Void
    let onDragEnd: () -> Void
    let dataManager: AppDataManager
    
    @State private var isDragHovering = false
    
    private let calendar = Calendar.current
    
    private var isSelected: Bool {
        selectedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }
    
    private var isPrimarySelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var isToday: Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }
    
    private var dayText: String {
        String(calendar.component(.day, from: date))
    }
    
    private var selectionStyle: SelectionStyle {
        if selectedDates.count <= 1 {
            return .single
        }
        
        let sortedDates = selectedDates.sorted()
        guard let index = sortedDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: date) }) else {
            return .none
        }
        
        if index == 0 { return .start }
        if index == sortedDates.count - 1 { return .end }
        return .middle
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(dayText)
                .font(.caption)
                .fontWeight(isToday ? .bold : .medium)
                .foregroundStyle(
                    isSelected ? .white : 
                    isToday ? .blue :
                    isCurrentMonth ? .primary : .gray.opacity(0.6)
                )
                .frame(width: 28, height: 28)
                .background(selectionBackground)
                .scaleEffect(isDragHovering ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onDrag {
            onDragStart()
            return NSItemProvider(object: date.description as NSString)
        }
        .onDrop(of: [.text], delegate: CalendarDropDelegate(
            date: date,
            onDragEnter: {
                isDragHovering = true
                onDragEnter()
            },
            onDragExit: { isDragHovering = false },
            onDragEnd: onDragEnd,
            dataManager: dataManager,
            targetTime: date
        ))
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragHovering)
    }
    
    @ViewBuilder
    private var selectionBackground: some View {
        switch selectionStyle {
        case .none:
            Circle()
                .fill(.clear)
                .overlay(
                    Circle()
                        .strokeBorder(isToday ? .blue : .clear, lineWidth: 1.5)
                )
        case .single:
            Circle()
                .fill(isSelected ? .blue : .clear)
                .overlay(
                    Circle()
                        .strokeBorder(isToday && !isSelected ? .blue : .clear, lineWidth: 1.5)
                )
        case .start:
            RoundedRectangle(cornerRadius: 14)
                .fill(.blue.opacity(isPrimarySelected ? 1.0 : 0.8))
                .clipShape(HalfCapsule(side: .leading))
        case .middle:
            Rectangle()
                .fill(.blue.opacity(isPrimarySelected ? 1.0 : 0.8))
        case .end:
            RoundedRectangle(cornerRadius: 14)
                .fill(.blue.opacity(isPrimarySelected ? 1.0 : 0.8))
                .clipShape(HalfCapsule(side: .trailing))
        }
    }
}

enum SelectionStyle {
    case none, single, start, middle, end
}

struct HalfCapsule: Shape {
    enum Side { case leading, trailing }
    let side: Side
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.height / 2
        
        switch side {
        case .leading:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), 
                       radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), 
                       radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.closeSubpath()
        case .trailing:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), 
                       radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), 
                       radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        
        return path
    }
}

struct CalendarDropDelegate: DropDelegate {
    let date: Date
    let onDragEnter: () -> Void
    let onDragExit: () -> Void
    let onDragEnd: () -> Void
    let dataManager: AppDataManager
    let targetTime: Date
    
    func dropEntered(info: DropInfo) {
        onDragEnter()
    }
    
    func dropExited(info: DropInfo) {
        onDragExit()
    }
    
    func performDrop(info: DropInfo) -> Bool {
        onDragEnd()
        
        // Check if we have TimeBlock data
        if let timeBlockData = info.itemProviders(for: [.timeBlockData]).first {
            timeBlockData.loadObject(ofClass: NSString.self) { provider, error in
                if error == nil {
                    // Handle TimeBlock drop - this would need to be enhanced
                    // For now, trigger the creation flow
                }
            }
            return true
        }
        
        // Check for chain template or backfill template data
        for provider in info.itemProviders(for: [.text]) {
            provider.loadObject(ofClass: NSString.self) { item, error in
                if let payload = item as? String, error == nil {
                    DispatchQueue.main.async {
                        // Parse backfill template payload
                        if payload.hasPrefix("backfill_template:") {
                            let parts = payload.dropFirst("backfill_template:".count).components(separatedBy: "|")
                            if parts.count >= 5 {
                                let title = parts[0]
                                let duration = TimeInterval(Int(parts[1]) ?? 3600)
                                let energy = EnergyType(rawValue: parts[2]) ?? .daylight
                                let emoji = parts[3]
                                let confidence = Double(parts[4]) ?? 0.8
                                
                                // Create a time block from the dropped template and add directly to timeline
                                let newBlock = TimeBlock(
                                    title: title,
                                    startTime: self.targetTime,
                                    duration: duration,
                                    energy: energy,
                                    emoji: emoji,
                                )
                                
                                // Add directly to the timeline instead of staging
                                self.dataManager.addTimeBlock(newBlock)
                                
                            }
                        }
                        // Parse chain template payload
                        else if payload.hasPrefix("chain_template:") {
                            let parts = payload.dropFirst("chain_template:".count).components(separatedBy: "|")
                            if parts.count >= 3 {
                                let name = parts[0]
                                let duration = TimeInterval(Int(parts[1]) ?? 3600)
                                let icon = parts[2]
                                
                                // Create a time block from the dropped chain template and add directly to timeline
                                let newBlock = TimeBlock(
                                    title: name,
                                    startTime: self.targetTime,
                                    duration: duration,
                                    energy: .daylight,
                                    emoji: "🌊"
                                )
                                
                                // Add directly to the timeline instead of staging
                                self.dataManager.addTimeBlock(newBlock)
                                
                            }
                        }
                        // Handle legacy chain template drops - now add directly to timeline
                        else if payload.contains("template") || payload.contains("chain") {
                            // Create a time block from the dropped template
                            let newBlock = TimeBlock(
                                title: payload.components(separatedBy: " template").first ?? payload,
                                startTime: self.targetTime,
                                duration: 3600, // Default 1 hour - could be improved
                                energy: .daylight,
                                emoji: "🌊"
                            )
                            
                            // Add directly to the timeline instead of staging
                            self.dataManager.addTimeBlock(newBlock)
                            
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Accept drops of text and TimeBlock data
        if info.hasItemsConforming(to: [.text]) || info.hasItemsConforming(to: [.timeBlockData]) {
            return DropProposal(operation: .move)
        }
        return DropProposal(operation: .forbidden)
    }
}

struct MonthView: View {
    @EnvironmentObject private var dataManager: AppDataManager
    @EnvironmentObject private var aiService: AIService
    @State private var selectedDates: Set<Date> = []
    @State private var currentMonth = Date()
    @State private var dateSelectionRange: (start: Date?, end: Date?) = (nil, nil)
    @State private var showingMultiDayInsight = false
    @State private var multiDayInsight = ""
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 12) {
            // Month header
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(dateFormatter.string(from: currentMonth))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            // Selection info
            if selectedDates.count > 1 {
                HStack {
                    Text("\(selectedDates.count) days selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Clear") {
                        clearSelection()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 16)
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Weekday headers
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(height: 20)
                }
                
                // Calendar days
                ForEach(monthDays, id: \.self) { date in
                    if let date = date {
                        EnhancedDayCell(
                            date: date,
                            isSelected: selectedDates.contains(date),
                            isInRange: isDateInSelectionRange(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                            onTap: {
                                handleDayTap(date)
                            }
                        )
                    } else {
                        Rectangle()
                            .fill(.clear)
                            .frame(height: 32)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Multi-day insight view
            if showingMultiDayInsight && !multiDayInsight.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AI Insight")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("✕") {
                            showingMultiDayInsight = false
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                    }
                    
                    ScrollView {
                        Text(multiDayInsight)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.5))
        .onChange(of: selectedDates) {
            updateMultiDayInsight()
        }
    }
    
    private var monthDays: [Date?] {
        guard let monthStart = calendar.dateInterval(of: .month, for: currentMonth)?.start else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        
        var days: [Date?] = []
        
        // Add empty cells for days before month start
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add days of the month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // MARK: - Day Selection Logic
    
    private func handleDayTap(_ date: Date) {
        // Always switch to the clicked day first
        dataManager.switchToDay(date)
        
        if selectedDates.isEmpty {
            // First selection
            selectedDates.insert(date)
            dateSelectionRange.start = date
        } else if selectedDates.count == 1 {
            // Second selection - create range
            let existingDate = selectedDates.first!
            let startDate = min(date, existingDate)
            let endDate = max(date, existingDate)
            
            selectedDates.removeAll()
            
            // Add all dates in range
            var currentDate = startDate
            while currentDate <= endDate {
                selectedDates.insert(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            dateSelectionRange = (startDate, endDate)
        } else {
            // Reset selection
            selectedDates.removeAll()
            selectedDates.insert(date)
            dateSelectionRange = (date, nil)
        }
    }
    
    private func clearSelection() {
        selectedDates.removeAll()
        dateSelectionRange = (nil, nil)
        showingMultiDayInsight = false
        multiDayInsight = ""
    }
    
    private func isDateInSelectionRange(_ date: Date) -> Bool {
        guard let start = dateSelectionRange.start,
              let end = dateSelectionRange.end else { return false }
        return date >= start && date <= end
    }
    
    // MARK: - AI Multi-Day Insights
    
    private func updateMultiDayInsight() {
        guard selectedDates.count > 1 else {
            showingMultiDayInsight = false
            return
        }
        
        let sortedDates = selectedDates.sorted()
        guard let startDate = sortedDates.first,
              let endDate = sortedDates.last else { return }
        
        Task {
            await generateMultiDayInsight(start: startDate, end: endDate)
        }
    }
    
    @MainActor
    private func generateMultiDayInsight(start: Date, end: Date) async {
        let now = Date()
        let isPastPeriod = end < now
        let dayCount = selectedDates.count
        let daysFromNow = Calendar.current.dateComponents([.day], from: now, to: start).day ?? 0
        
        let prompt: String
        if isPastPeriod {
            // PRD: Past period - reflection text on wins/blockers
            prompt = """
            Reflect on the \(dayCount)-day period from \(start.formatted(.dateTime.month().day())) to \(end.formatted(.dateTime.month().day())).
            
            Analyze this time period and provide:
            1. Key wins and accomplishments during this period
            2. Main blockers or challenges that came up  
            3. Patterns or insights about productivity/energy
            4. Brief assessment of how the time was used
            
            Keep it concise - 2-3 sentences focusing on wins and blockers.
            """
        } else {
            // PRD: Future period - possible goals to be in-progress by that time
            prompt = """
            Looking at a future \(dayCount)-day period starting \(daysFromNow) days from now (\(start.formatted(.dateTime.month().day())) to \(end.formatted(.dateTime.month().day()))).
            
            Given this time delta, suggest what goals could be achieved or in-progress by that time:
            - Realistic goals for a \(dayCount)-day period
            - Projects that could be started or completed
            - Skills or habits that could be developed
            - Meaningful milestones to work towards
            
            Keep it motivating and actionable (2-3 sentences max).
            """
        }
        
        do {
            let context = DayContext(
                date: start,
                existingBlocks: dataManager.appState.currentDay.blocks,
                currentEnergy: .daylight,
                preferredEmojis: ["🌊"],
                availableTime: TimeInterval(dayCount * 24 * 3600),
                mood: dataManager.appState.currentDay.mood
            )
            
            let response = try await aiService.processMessage(prompt, context: context)
            
            multiDayInsight = response.text
            withAnimation(.easeInOut(duration: 0.3)) {
                showingMultiDayInsight = true
            }
        } catch {
            multiDayInsight = isPastPeriod
                ? "This was a \(dayCount)-day period. Reflect on what you accomplished and learned."
                : "In \(daysFromNow) days, you could make significant progress on your goals. Consider what you'd like to achieve by then."
            
            withAnimation(.easeInOut(duration: 0.3)) {
                showingMultiDayInsight = true
            }
        }
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

struct EnhancedDayCell: View {
    let date: Date
    let isSelected: Bool
    let isInRange: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isCurrentMonth ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(backgroundView)
                .overlay(overlayView)
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundView: some View {
        Group {
            if isSelected {
                Circle()
                    .fill(.blue.opacity(0.3))
            } else if isInRange {
                Rectangle()
                    .fill(.blue.opacity(0.1))
            } else {
                Circle()
                    .fill(.clear)
            }
        }
    }
    
    private var overlayView: some View {
        Group {
            if isSelected {
                Circle()
                    .strokeBorder(.blue, lineWidth: 2)
            } else if isInRange {
                Rectangle()
                    .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
            } else {
                Circle()
                    .strokeBorder(.clear, lineWidth: 0)
            }
        }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isCurrentMonth ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? .blue : .clear)
                        .opacity(isSelected ? 0.2 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? .blue : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
