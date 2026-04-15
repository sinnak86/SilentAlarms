import Foundation
import UserNotifications

final class AlarmManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var alarms: [Alarm] = []
    @Published var currentlyRingingAlarm: Alarm?

    // MARK: - Dependencies

    weak var audioManager: AudioManager?

    // MARK: - Private

    private var checkTimer: Timer?
    private let storageKey = "savedAlarms_v1"
    private var firedAlarmIDs: Set<UUID> = []  // prevents double-fire within same minute

    // MARK: - Init

    init() {
        loadAlarms()
        requestNotificationPermission()
        startAlarmChecking()
    }

    // MARK: - Persistence

    func loadAlarms() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Alarm].self, from: data) else { return }
        alarms = decoded
    }

    func saveAlarms() {
        guard let data = try? JSONEncoder().encode(alarms) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - CRUD

    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        saveAlarms()
        scheduleLocalNotifications(for: alarm)
    }

    func updateAlarm(_ alarm: Alarm) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        cancelLocalNotifications(for: alarms[idx])
        alarms[idx] = alarm
        saveAlarms()
        if alarm.isEnabled {
            scheduleLocalNotifications(for: alarm)
        }
    }

    func deleteAlarm(at offsets: IndexSet) {
        for index in offsets {
            cancelLocalNotifications(for: alarms[index])
        }
        alarms.remove(atOffsets: offsets)
        saveAlarms()
    }

    func toggleAlarm(_ alarm: Alarm) {
        var updated = alarm
        updated.isEnabled.toggle()
        updateAlarm(updated)
    }

    // MARK: - Alarm checking (background timer)

    func startAlarmChecking() {
        checkTimer?.invalidate()
        // Check every 15 seconds — reliable within any minute, works with firedAlarmIDs dedup.
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkAlarms()
        }
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
        // Check immediately on start
        checkAlarms()
    }

    private func checkAlarms() {
        let cal = Calendar.current
        let now = Date()
        let currentHour    = cal.component(.hour,    from: now)
        let currentMinute  = cal.component(.minute,  from: now)
        let currentWeekday = cal.component(.weekday, from: now) // 1=Sun…7=Sat

        for alarm in alarms where alarm.isEnabled {
            guard alarm.hour == currentHour,
                  alarm.minute == currentMinute,
                  let wd = Weekday(rawValue: currentWeekday),
                  alarm.days.contains(wd) else { continue }

            // Prevent re-firing if already fired in this minute
            guard !firedAlarmIDs.contains(alarm.id) else { continue }

            firedAlarmIDs.insert(alarm.id)
            fireAlarm(alarm)

            // Clear the fired flag after 90 s so next day it can fire again
            let alarmID = alarm.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self] in
                self?.firedAlarmIDs.remove(alarmID)
            }
        }
    }

    private func fireAlarm(_ alarm: Alarm) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentlyRingingAlarm = alarm
            self.audioManager?.playAlarm(alarm.soundID)
        }
    }

    func stopCurrentAlarm() {
        audioManager?.stopAlarm()
        currentlyRingingAlarm = nil
    }

    // MARK: - Local Notifications (fallback when app is terminated)

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleLocalNotifications(for alarm: Alarm) {
        let center = UNUserNotificationCenter.current()

        for day in alarm.days {
            let content = UNMutableNotificationContent()
            content.title = "Silent Alarm"
            content.body  = "\(alarm.label) - 앱을 열어 이어폰 알람을 확인하세요."
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.weekday = day.rawValue
            dateComponents.hour    = alarm.hour
            dateComponents.minute  = alarm.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let requestID = notificationID(alarmID: alarm.id, day: day)
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)

            center.add(request)
        }
    }

    private func cancelLocalNotifications(for alarm: Alarm) {
        let ids = alarm.days.map { notificationID(alarmID: alarm.id, day: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func notificationID(alarmID: UUID, day: Weekday) -> String {
        "\(alarmID.uuidString)_\(day.rawValue)"
    }
}
