import Foundation

struct Alarm: Codable, Identifiable {
    let id: UUID
    var isEnabled: Bool
    var hour: Int
    var minute: Int
    var days: Set<Weekday>
    var soundName: String
    var label: String

    init(id: UUID = UUID(), isEnabled: Bool = true, hour: Int, minute: Int,
         days: Set<Weekday> = [], soundName: String = "alarm_gentle", label: String = "") {
        self.id = id
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
        self.days = days
        self.soundName = soundName
        self.label = label
    }

    enum Weekday: Int, Codable, CaseIterable, Comparable {
        case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

        var shortName: String {
            switch self {
            case .sunday: return "일"
            case .monday: return "월"
            case .tuesday: return "화"
            case .wednesday: return "수"
            case .thursday: return "목"
            case .friday: return "금"
            case .saturday: return "토"
            }
        }

        var calendarWeekdayIndex: Int { rawValue }

        static func < (lhs: Weekday, rhs: Weekday) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var daysString: String {
        if days.isEmpty { return "한 번" }
        if days.count == 7 { return "매일" }
        let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekends: Set<Weekday> = [.saturday, .sunday]
        if days == weekdays { return "평일" }
        if days == weekends { return "주말" }
        return days.sorted().map { $0.shortName }.joined(separator: " ")
    }

    func nextFireDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day, .weekday], from: now)

        if days.isEmpty {
            // One-time alarm: next occurrence today or tomorrow
            var candidate = DateComponents()
            candidate.hour = hour
            candidate.minute = minute
            candidate.second = 0
            if let date = calendar.nextDate(after: now, matching: candidate, matchingPolicy: .nextTime) {
                return date
            }
        }

        // Find the next weekday match
        let sortedDays = days.sorted()
        let todayWeekday = components.weekday ?? 1
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        for offset in 0...7 {
            let checkWeekday = ((todayWeekday - 1 + offset) % 7) + 1
            if let day = sortedDays.first(where: { $0.rawValue == checkWeekday }) {
                if offset == 0 {
                    // Today: check if time has passed
                    if hour > currentHour || (hour == currentHour && minute > currentMinute) {
                        var dc = DateComponents()
                        dc.hour = hour
                        dc.minute = minute
                        dc.second = 0
                        return calendar.nextDate(after: now.addingTimeInterval(-1), matching: dc, matchingPolicy: .nextTime)
                    }
                } else {
                    var dc = DateComponents()
                    dc.weekday = day.rawValue
                    dc.hour = hour
                    dc.minute = minute
                    dc.second = 0
                    return calendar.nextDate(after: now, matching: dc, matchingPolicy: .nextTime)
                }
            }
        }
        return nil
    }
}
