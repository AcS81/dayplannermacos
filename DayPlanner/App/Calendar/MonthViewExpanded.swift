// MARK: - Month View Expanded

import SwiftUI

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
        .onChange(of: selectedDate) { oldValue, newValue in
            dataManager.switchToDay(newValue)
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
                                let _ = Double(parts[4]) ?? 0.8
                                
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
                                let _ = parts[2]
                                
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
                                
                                let newBlock = TimeBlock(
                                    title: title,
                                    startTime: self.targetTime,
                                    duration: 3600, // Default 1 hour for todo items
                                    energy: .daylight,
                                    emoji: "📝"
                                )
                                
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

