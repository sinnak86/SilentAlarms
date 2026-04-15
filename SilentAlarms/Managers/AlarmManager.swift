import AVFoundation
import Foundation
import UIKit

final class AlarmManager: NSObject {
    static let shared = AlarmManager()

    private(set) var alarms: [Alarm] = []
    private(set) var firingAlarm: Alarm?
    private var alarmPlayer: AVAudioPlayer?
    private var silentLoopPlayer: AVAudioPlayer?
    private var checkTimer: Timer?
    private var lastFiredMinute: String = ""

    private let alarmsFileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("alarms.json")
    }()

    private override init() { super.init() }

    // MARK: - Persistence

    func loadAlarms() {
        guard let data = try? Data(contentsOf: alarmsFileURL),
              let loaded = try? JSONDecoder().decode([Alarm].self, from: data) else { return }
        alarms = loaded
    }

    func saveAlarms() {
        guard let data = try? JSONEncoder().encode(alarms) else { return }
        try? data.write(to: alarmsFileURL)
        rescheduleAllNotifications()
        NotificationCenter.default.post(name: .alarmsDidUpdate, object: nil)
    }

    // MARK: - CRUD

    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        saveAlarms()
    }

    func updateAlarm(_ alarm: Alarm) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx] = alarm
        saveAlarms()
    }

    func deleteAlarm(id: UUID) {
        if let alarm = alarms.first(where: { $0.id == id }) {
            NotificationManager.shared.cancelNotifications(for: alarm)
        }
        alarms.removeAll { $0.id == id }
        saveAlarms()
    }

    // MARK: - Notifications reschedule

    private func rescheduleAllNotifications() {
        NotificationManager.shared.cancelAllNotifications()
        for alarm in alarms where alarm.isEnabled {
            NotificationManager.shared.scheduleNotifications(for: alarm)
        }
    }

    // MARK: - Background Keep-Alive

    func startBackgroundKeepAlive() {
        configureAudioSession()
        startSilentLoop()
        startCheckTimer()
    }

    func stopBackgroundKeepAlive() {
        silentLoopPlayer?.stop()
        silentLoopPlayer = nil
        checkTimer?.invalidate()
        checkTimer = nil
        // Re-activate session for foreground use
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func startSilentLoop() {
        guard let url = Bundle.main.url(forResource: "silent_loop", withExtension: "caf") else {
            print("[AlarmManager] silent_loop.caf not found")
            return
        }
        silentLoopPlayer = try? AVAudioPlayer(contentsOf: url)
        silentLoopPlayer?.numberOfLoops = -1
        silentLoopPlayer?.volume = 0.01
        silentLoopPlayer?.play()
    }

    private func startCheckTimer() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.handlePotentialAlarmFire()
        }
        // Also check immediately
        handlePotentialAlarmFire()
    }

    // MARK: - Alarm Fire Logic

    func handlePotentialAlarmFire() {
        guard firingAlarm == nil else { return }

        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)
        let minuteKey = "\(currentHour):\(currentMinute)"

        guard minuteKey != lastFiredMinute else { return }

        for alarm in alarms where alarm.isEnabled {
            guard alarm.hour == currentHour && alarm.minute == currentMinute else { continue }

            let shouldFire: Bool
            if alarm.days.isEmpty {
                shouldFire = true
            } else {
                shouldFire = alarm.days.contains(where: { $0.rawValue == currentWeekday })
            }

            guard shouldFire else { continue }

            lastFiredMinute = minuteKey
            fireAlarm(alarm)
            break
        }
    }

    private func fireAlarm(_ alarm: Alarm) {
        firingAlarm = alarm

        if AudioRouteManager.shared.areEarphonesConnected {
            playAlarmSound(for: alarm)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .alarmDidFire, object: alarm)
            }
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .alarmFiredNoEarphones, object: alarm)
            }
            // Re-check every 30s for up to 2 minutes in case earphones are connected later
            var retryCount = 0
            Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] timer in
                retryCount += 1
                if retryCount >= 4 { timer.invalidate(); self?.firingAlarm = nil; return }
                if AudioRouteManager.shared.areEarphonesConnected {
                    timer.invalidate()
                    self?.playAlarmSound(for: alarm)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .alarmDidFire, object: alarm)
                    }
                }
            }
        }

        // Disable one-time alarms after firing
        if alarm.days.isEmpty {
            var updated = alarm
            updated.isEnabled = false
            updateAlarm(updated)
        }
    }

    private func playAlarmSound(for alarm: Alarm) {
        let sound = AlarmSound.sound(for: alarm.soundName)
        guard let url = Bundle.main.url(forResource: sound.id, withExtension: sound.fileExtension) else {
            print("[AlarmManager] Sound file not found: \(sound.fileName)")
            return
        }
        // Stop silent loop temporarily while alarm plays
        silentLoopPlayer?.stop()

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [])
        try? session.setActive(true)

        alarmPlayer = try? AVAudioPlayer(contentsOf: url)
        alarmPlayer?.numberOfLoops = -1
        alarmPlayer?.volume = 1.0
        alarmPlayer?.play()
    }

    // MARK: - Dismiss

    func dismissCurrentAlarm() {
        alarmPlayer?.stop()
        alarmPlayer = nil
        firingAlarm = nil
        // Restart silent loop if backgrounded
        if UIApplication.shared.applicationState == .background {
            startSilentLoop()
        }
    }
}
