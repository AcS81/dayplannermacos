//
//  Extensions.swift
//  DayPlanner
//
//  Essential extensions for the liquid glass system
//

import SwiftUI
import Foundation

// MARK: - Shared DateFormatters

/// Shared DateFormatter instances to avoid recreation overhead
private struct DateFormatters {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()
    
    static let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Date Extensions

extension Date {
    /// Get hour component (0-23)
    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }
    
    /// Get minute component (0-59)
    var minute: Int {
        Calendar.current.component(.minute, from: self)
    }
    
    /// Set specific hour while preserving other components
    func setting(hour: Int) -> Date? {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: self)
    }
    
    /// Check if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Get start of day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// Add time interval and return new date
    func adding(minutes: Int) -> Date {
        addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    /// Format time as HH:mm
    var timeString: String {
        return DateFormatters.timeFormatter.string(from: self)
    }
    
    /// Precise time for timeline display (e.g., "6:45")
    var preciseTwoLineTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: self)
    }
    
    /// Format date as "Today", "Tomorrow", or "Wed, Dec 12"
    var dayString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInTomorrow(self) {
            return "Tomorrow"
        } else {
            return DateFormatters.dayFormatter.string(from: self)
        }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Create color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Liquid glass colors for different states
    static let liquidBlue = Color(hex: "007AFF").opacity(0.3)
    static let mistGray = Color(hex: "8E8E93").opacity(0.2)
    static let crystalCyan = Color(hex: "64D2FF").opacity(0.4)
    static let auroraGreen = Color(hex: "34C759").opacity(0.3)
    static let sunriseOrange = Color(hex: "FF9500").opacity(0.4)
    static let moonlightPurple = Color(hex: "AF52DE").opacity(0.3)
}

// MARK: - View Extensions

extension View {
    /// Apply liquid glass effect
    func liquidGlass() -> some View {
        LiquidGlassView {
            self
        }
    }
    
    /// Apply glow effect
    func glow(color: Color = .blue, radius: CGFloat = 8) -> some View {
        self
            .shadow(color: color.opacity(0.6), radius: radius)
            .shadow(color: color.opacity(0.3), radius: radius * 2)
    }
    
    /// Apply floating effect
    func floating(offset: CGFloat = 2, duration: Double = 2) -> some View {
        self
            .offset(y: offset)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: offset
            )
    }
    
    /// Apply pulsing effect
    func pulsing(scale: CGFloat = 1.05, duration: Double = 1.5) -> some View {
        self
            .scaleEffect(scale)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: scale
            )
    }
    
    /// Apply bounce effect on appear
    func bounceOnAppear() -> some View {
        BounceOnAppearView {
            self
        }
    }
}

// MARK: - Helper Views

struct BounceOnAppearView<Content: View>: View {
    let content: Content
    @State private var scale: CGFloat = 0.8
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    scale = 1.0
                }
            }
    }
}

extension View {
    /// Apply shimmer effect
    func shimmer() -> some View {
        self
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.3), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .animation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false),
                    value: UUID()
                )
            )
    }
    
    /// Apply glass card style
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    /// Apply time-based tint
    func timeBasedTint(for hour: Int) -> some View {
        let tintColor: Color = {
            switch hour {
            case 6..<12: return .sunriseOrange
            case 12..<18: return .liquidBlue
            case 18..<22: return .moonlightPurple
            default: return .mistGray
            }
        }()
        
        return self.foregroundStyle(
            LinearGradient(
                colors: [tintColor, tintColor.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// Convert to minutes
    var minutes: Int {
        Int(self / 60)
    }
    
    /// Convert to hours
    var hours: Double {
        self / 3600
    }
    
    /// Format as readable duration (e.g., "1h 30m" or "45m")
    var durationString: String {
        let totalMinutes = Int(self / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == TimeBlock {
    /// Get total duration of all blocks
    var totalDuration: TimeInterval {
        reduce(0) { $0 + $1.duration }
    }
    
    /// Get blocks for a specific time period
    func blocks(for period: TimePeriod) -> [TimeBlock] {
        filter { $0.period == period }
    }
    
    /// Sort blocks by start time
    var sortedByTime: [TimeBlock] {
        sorted { $0.startTime < $1.startTime }
    }
    
    /// Check if there's overlap between blocks
    var hasOverlaps: Bool {
        let sorted = sortedByTime
        for i in 0..<sorted.count - 1 {
            if sorted[i].endTime > sorted[i + 1].startTime {
                return true
            }
        }
        return false
    }
    
    /// Find gaps between blocks
    var gaps: [(start: Date, duration: TimeInterval)] {
        let sorted = sortedByTime
        var gaps: [(start: Date, duration: TimeInterval)] = []
        
        for i in 0..<sorted.count - 1 {
            let endTime = sorted[i].endTime
            let nextStartTime = sorted[i + 1].startTime
            
            if nextStartTime > endTime {
                let gap = nextStartTime.timeIntervalSince(endTime)
                if gap > 300 { // Only gaps > 5 minutes
                    gaps.append((start: endTime, duration: gap))
                }
            }
        }
        
        return gaps
    }
}

// MARK: - String Extensions

extension String {
    /// Truncate string to specified length
    func truncated(to length: Int) -> String {
        if self.count <= length {
            return self
        } else {
            return String(self.prefix(length)) + "..."
        }
    }
    
    /// Check if string is not empty after trimming whitespace
    var isNotEmptyTrimmed: Bool {
        !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Return nil if string is empty after trimming, otherwise return self
    var nilIfEmpty: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - CGPoint Extensions

extension CGPoint {
    /// Distance to another point
    func distance(to point: CGPoint) -> CGFloat {
        sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
    
    /// Midpoint between two points
    func midpoint(to point: CGPoint) -> CGPoint {
        CGPoint(x: (x + point.x) / 2, y: (y + point.y) / 2)
    }
}

// MARK: - Haptic Feedback

#if os(iOS)
import UIKit

enum HapticStyle {
    case light, medium, heavy, selection, success, warning, error
    
    func trigger() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
#else
// macOS doesn't have haptic feedback, so we provide empty implementation
enum HapticStyle {
    case light, medium, heavy, selection, success, warning, error
    
    func trigger() {
        // No haptic feedback on macOS
    }
}
#endif

// MARK: - Performance Extensions

extension View {
    /// Optimize for better performance with many views
    func optimized() -> some View {
        self
            .drawingGroup() // Flatten view hierarchy for better performance
    }
    
    /// Add debug border in debug builds
    func debugBorder(_ color: Color = .red, width: CGFloat = 1) -> some View {
        #if DEBUG
        return self.border(color, width: width)
        #else
        return self
        #endif
    }
}

// MARK: - Environment Extensions

struct LiquidGlassEnvironment {
    static let defaultAnimationDuration: Double = 0.6
    static let defaultSpringResponse: Double = 0.6
    static let defaultSpringDamping: Double = 0.8
    
    static let rippleMaxRadius: CGFloat = 100
    static let glassOpacity: Double = 0.8
    static let tintIntensity: Double = 0.3
}

// MARK: - Astronomical Time Calculator

/// Provides accurate astronomical twilight colors based on real solar positions
class AstronomicalTimeCalculator {
    static let shared = AstronomicalTimeCalculator()
    
    private init() {}
    
    /// Get time-based color for hour considering astronomical twilight
    func getTimeColor(for hour: Int, date: Date) -> Color {
        let (sunrise, sunset) = calculateSolarTimes(for: date)
        let solarHour = Double(hour)
        
        // Calculate astronomical periods
        let astronomicalDawn = sunrise - 1.5      // 90 min before sunrise
        let nauticalDawn = sunrise - 1.0          // 60 min before sunrise
        let civilDawn = sunrise - 0.5             // 30 min before sunrise
        let goldenHourStart = sunset - 1.0        // 60 min before sunset
        let civilDusk = sunset + 0.5              // 30 min after sunset
        let nauticalDusk = sunset + 1.0           // 60 min after sunset
        let astronomicalDusk = sunset + 1.5       // 90 min after sunset
        
        switch solarHour {
        case ..<astronomicalDawn:
            return createNightColor(intensity: 0.08) // Deep night
        case astronomicalDawn..<nauticalDawn:
            return createDawnColor(progress: (solarHour - astronomicalDawn) / 0.5, intensity: 0.03) // Astronomical dawn
        case nauticalDawn..<civilDawn:
            return createDawnColor(progress: (solarHour - nauticalDawn) / 0.5, intensity: 0.05) // Nautical dawn
        case civilDawn..<sunrise:
            return createDawnColor(progress: (solarHour - civilDawn) / 0.5, intensity: 0.08) // Civil dawn
        case sunrise..<(sunrise + 1):
            return createSunriseColor(progress: (solarHour - sunrise) / 1.0) // Sunrise hour
        case (sunrise + 1)..<12:
            return createMorningColor(progress: (solarHour - sunrise - 1) / max(1, 12 - sunrise - 1)) // Morning
        case 12..<14:
            return createNoonColor() // High noon
        case 14..<goldenHourStart:
            return createAfternoonColor(progress: (solarHour - 14) / max(1, goldenHourStart - 14)) // Afternoon
        case goldenHourStart..<sunset:
            return createGoldenHourColor(progress: (solarHour - goldenHourStart) / max(1, sunset - goldenHourStart)) // Golden hour
        case sunset..<civilDusk:
            return createSunsetColor(progress: (solarHour - sunset) / 0.5) // Sunset
        case civilDusk..<nauticalDusk:
            return createDuskColor(progress: (solarHour - civilDusk) / 0.5, intensity: 0.08) // Civil dusk
        case nauticalDusk..<astronomicalDusk:
            return createDuskColor(progress: (solarHour - nauticalDusk) / 0.5, intensity: 0.05) // Nautical dusk
        case astronomicalDusk...:
            return createNightColor(intensity: (solarHour - astronomicalDusk) < 2 ? 0.06 : 0.08) // Night
        default:
            return .clear
        }
    }
    
    /// Calculate approximate sunrise/sunset times for date (simplified - could use real solar calculation)
    private func calculateSolarTimes(for date: Date) -> (sunrise: Double, sunset: Double) {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 180
        
        // Simplified solar calculation using sinusoidal approximation
        let solarDeclination = 23.45 * sin((Double(dayOfYear) - 81) * .pi / 182.5)
        let latitude = 40.0 // Default latitude (could be made location-aware)
        
        let hourAngle = acos(-tan(latitude * .pi / 180) * tan(solarDeclination * .pi / 180))
        let solarNoon = 12.0
        
        let sunrise = solarNoon - (hourAngle * 12 / .pi)
        let sunset = solarNoon + (hourAngle * 12 / .pi)
        
        // Clamp to reasonable bounds
        return (
            sunrise: max(5.0, min(8.0, sunrise)),
            sunset: max(16.0, min(20.0, sunset))
        )
    }
    
    // MARK: - Color Creation Functions
    
    private func createNightColor(intensity: Double) -> Color {
        Color(.sRGB, red: 0.05, green: 0.08, blue: 0.15, opacity: intensity)
    }
    
    private func createDawnColor(progress: Double, intensity: Double) -> Color {
        let red = 0.8 * progress
        let green = 0.4 * progress
        let blue = 0.6 * (1 - progress)
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: intensity)
    }
    
    private func createSunriseColor(progress: Double) -> Color {
        let red = 1.0 * (1 - progress * 0.3)
        let green = 0.6 + (0.4 * progress)
        let blue = 0.2 + (0.6 * progress)
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 0.08)
    }
    
    private func createMorningColor(progress: Double) -> Color {
        let red = 1.0 - (0.2 * progress)
        let green = 1.0
        let blue = 0.8 + (0.2 * progress)
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 0.03)
    }
    
    private func createNoonColor() -> Color {
        Color(.sRGB, red: 1.0, green: 1.0, blue: 0.9, opacity: 0.04)
    }
    
    private func createAfternoonColor(progress: Double) -> Color {
        let red = 1.0 - (0.1 * progress)
        let green = 0.9 - (0.1 * progress)
        let blue = 1.0
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 0.02)
    }
    
    private func createGoldenHourColor(progress: Double) -> Color {
        let red = 1.0
        let green = 0.8 - (0.2 * progress)
        let blue = 0.5 - (0.3 * progress)
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 0.06)
    }
    
    private func createSunsetColor(progress: Double) -> Color {
        let red = 1.0 - (0.3 * progress)
        let green = 0.5 - (0.3 * progress)
        let blue = 0.8 * progress
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 0.05)
    }
    
    private func createDuskColor(progress: Double, intensity: Double) -> Color {
        let red = 0.6 * (1 - progress)
        let green = 0.3 * (1 - progress)
        let blue = 0.8
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: intensity)
    }
}

// MARK: - Preview Extensions

#if DEBUG
extension TimeBlock {
    static func sample(title: String, hour: Int = 10) -> TimeBlock {
        TimeBlock(
            title: title,
            startTime: Date().setting(hour: hour) ?? Date(),
            duration: 3600, // 1 hour
            energy: .daylight,
            emoji: "📋"
        )
    }
}

extension Chain {
    static var sample: Chain {
        Chain(
            name: "Morning Routine",
            blocks: [
                .sample(title: "Coffee", hour: 8),
                .sample(title: "Exercise", hour: 9),
                .sample(title: "Shower", hour: 10)
            ],
            flowPattern: .waterfall,
            emoji: "🌅"
        )
    }
}

extension AppDataManager {
    static var preview: AppDataManager {
        let manager = AppDataManager()
        
        // Create enhanced sample blocks with varied properties and AI explanations
        let sampleBlocks = [
            TimeBlock(
                title: "Morning Routine",
                startTime: Date().setting(hour: 7) ?? Date(),
                duration: 30 * 60, // 30 minutes
                energy: .sunrise,
                emoji: "🌅",
                glassState: .solid,
            ),
            TimeBlock(
                title: "Deep Work Session",
                startTime: Date().setting(hour: 9) ?? Date(),
                duration: 90 * 60, // 1.5 hours
                energy: .sunrise,
                emoji: "💎",
                glassState: .solid,
            ),
            TimeBlock(
                title: "Team Standup",
                startTime: Date().setting(hour: 11) ?? Date(),
                duration: 30 * 60, // 30 minutes
                energy: .daylight,
                emoji: "👥",
                glassState: .solid,
            ),
            TimeBlock(
                title: "Lunch & Walk",
                startTime: Date().setting(hour: 12) ?? Date(),
                duration: 60 * 60, // 1 hour
                energy: .daylight,
                emoji: "🚶‍♀️",
                glassState: .solid,
            ),
            TimeBlock(
                title: "Client Presentation",
                startTime: Date().setting(hour: 14) ?? Date(),
                duration: 45 * 60, // 45 minutes
                energy: .daylight,
                emoji: "📊",
                glassState: .mist,
            ),
            TimeBlock(
                title: "Creative Brainstorming",
                startTime: Date().setting(hour: 16) ?? Date(),
                duration: 60 * 60, // 1 hour
                energy: .daylight,
                emoji: "💡",
                glassState: .crystal,
            ),
            TimeBlock(
                title: "Email & Admin",
                startTime: Date().setting(hour: 17) ?? Date(),
                duration: 45 * 60, // 45 minutes
                energy: .moonlight,
                emoji: "📧",
                glassState: .solid,
            ),
            TimeBlock(
                title: "Evening Exercise",
                startTime: Date().setting(hour: 19) ?? Date(),
                duration: 45 * 60, // 45 minutes
                energy: .moonlight,
                emoji: "🏃‍♀️",
                glassState: .mist,
            )
        ]
        
        manager.appState = AppState(
            currentDay: Day(
                date: Date(),
                blocks: sampleBlocks,
                mood: .prism
            ),
            recentChains: [
                .sample,
                Chain(
                    name: "Afternoon Focus",
                    blocks: [
                        TimeBlock(title: "Review Notes", startTime: Date().setting(hour: 13) ?? Date(), duration: 30 * 60, energy: .daylight, emoji: "📝"),
                        TimeBlock(title: "Deep Work", startTime: Date().setting(hour: 13, minute: 30) ?? Date(), duration: 90 * 60, energy: .daylight, emoji: "💼")
                    ],
                    flowPattern: .spiral,
                    emoji: "🎯"
                ),
                Chain(
                    name: "Morning Boost",
                    blocks: [
                        TimeBlock(title: "Meditation", startTime: Date().setting(hour: 6) ?? Date(), duration: 15 * 60, energy: .sunrise, emoji: "🧘‍♀️"),
                        TimeBlock(title: "Exercise", startTime: Date().setting(hour: 6, minute: 15) ?? Date(), duration: 30 * 60, energy: .sunrise, emoji: "💪"),
                        TimeBlock(title: "Breakfast", startTime: Date().setting(hour: 6, minute: 45) ?? Date(), duration: 15 * 60, energy: .sunrise, emoji: "🍳")
                    ],
                    flowPattern: .waterfall,
                    emoji: "⚡"
                )
            ],
            userXP: 450,
            userXXP: 680
        )
        return manager
    }
}
#endif
