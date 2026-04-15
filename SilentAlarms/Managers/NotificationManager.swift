import UserNotifications
import Foundation

final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private override init() { super.init() }

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    func setupCategories() {
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ALARM",
            title: "알람 끄기",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "ALARM",
            actions: [dismissAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func scheduleNotifications(for alarm: Alarm) {
        cancelNotifications(for: alarm)
        guard alarm.isEnabled else { return }

        let sound = AlarmSound.sound(for: alarm.soundName)
        let notifSound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound.fileName))

        let daysToSchedule: [Alarm.Weekday] = alarm.days.isEmpty
            ? []  // One-time: handled below
            : Array(alarm.days)

        if alarm.days.isEmpty {
            // One-time alarm
            guard let fireDate = alarm.nextFireDate() else { return }
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            scheduleNotification(
                id: "\(alarm.id.uuidString)-once",
                alarm: alarm,
                components: components,
                repeats: false,
                sound: notifSound
            )
        } else {
            for day in daysToSchedule {
                var components = DateComponents()
                components.weekday = day.calendarWeekdayIndex
                components.hour = alarm.hour
                components.minute = alarm.minute
                components.second = 0
                scheduleNotification(
                    id: "\(alarm.id.uuidString)-\(day.rawValue)",
                    alarm: alarm,
                    components: components,
                    repeats: true,
                    sound: notifSound
                )
            }
        }
    }

    private func scheduleNotification(id: String, alarm: Alarm, components: DateComponents,
                                       repeats: Bool, sound: UNNotificationSound) {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Silent Alarm" : alarm.label
        content.body = "알람이 울립니다 \(alarm.timeString) — 이어폰을 연결하세요"
        content.sound = sound
        content.categoryIdentifier = "ALARM"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationManager] Schedule error: \(error)")
            }
        }
    }

    func cancelNotifications(for alarm: Alarm) {
        var ids = Alarm.Weekday.allCases.map { "\(alarm.id.uuidString)-\($0.rawValue)" }
        ids.append("\(alarm.id.uuidString)-once")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground (alarm fires)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "DISMISS_ALARM" || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            AlarmManager.shared.dismissCurrentAlarm()
        }
        completionHandler()
    }
}
