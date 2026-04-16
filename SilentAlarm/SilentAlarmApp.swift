import SwiftUI

@main
struct SilentAlarmApp: App {

    @StateObject private var alarmManager = AlarmManager()
    @StateObject private var audioManager = AudioManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmManager)
                .environmentObject(audioManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Wire up the dependency after both objects are ready
                    alarmManager.audioManager = audioManager

                    // When headphones disconnect mid-alarm, stop the alarm entirely
                    // and never fall back to the phone speaker.
                    audioManager.onHeadphonesDisconnectedDuringAlarm = { [weak alarmManager] in
                        alarmManager?.stopCurrentAlarm()
                    }
                }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                // Start near-inaudible keepalive tone so the audio session stays alive,
                // which allows the alarm check timer to keep firing while screen is locked.
                audioManager.startSilentLoop()
            case .active:
                // Re-check headphone state when returning to foreground
                alarmManager.audioManager = audioManager
                audioManager.onHeadphonesDisconnectedDuringAlarm = { [weak alarmManager] in
                    alarmManager?.stopCurrentAlarm()
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
