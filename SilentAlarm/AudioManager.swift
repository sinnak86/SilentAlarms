import AVFoundation
import Combine

final class AudioManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var isHeadphonesConnected: Bool = false
    @Published private(set) var isAlarmPlaying: Bool = false

    // MARK: - Callbacks

    /// Called on main thread when headphones disconnect while alarm is playing.
    var onHeadphonesDisconnectedDuringAlarm: (() -> Void)?

    // MARK: - Private

    private let session = AVAudioSession.sharedInstance()
    private var engine = AVAudioEngine()
    private var alarmNode = AVAudioPlayerNode()
    private var silentNode = AVAudioPlayerNode()
    private var routeCancellable: AnyCancellable?

    // MARK: - Init

    init() {
        setupAudioSession()
        setupEngine()
        observeRouteChanges()
        updateHeadphoneState()
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            // .playback with no options: never overrides to speaker automatically.
            // Audio routes to headphones when connected.
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[AudioManager] Session setup error: \(error)")
        }
    }

    private func setupEngine() {
        engine.attach(alarmNode)
        engine.attach(silentNode)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(alarmNode, to: engine.mainMixerNode, format: format)
        engine.connect(silentNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("[AudioManager] Engine start error: \(error)")
        }
    }

    // MARK: - Route monitoring

    private func observeRouteChanges() {
        routeCancellable = NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let wasConnected = self.isHeadphonesConnected
                self.updateHeadphoneState()

                // If headphones just disconnected while alarm is playing, stop immediately
                // and never fall back to speaker.
                if wasConnected && !self.isHeadphonesConnected && self.isAlarmPlaying {
                    self.stopAlarm()
                    self.onHeadphonesDisconnectedDuringAlarm?()
                }
            }
    }

    private func updateHeadphoneState() {
        isHeadphonesConnected = checkHeadphoneConnected()
    }

    func checkHeadphoneConnected() -> Bool {
        let wiredOrBT: [AVAudioSession.Port] = [
            .headphones,
            .bluetoothA2DP,
            .bluetoothHFP,
            .bluetoothLE
        ]
        return session.currentRoute.outputs.contains {
            wiredOrBT.contains($0.portType)
        }
    }

    // MARK: - Background keepalive

    /// Plays a near-inaudible low-amplitude tone to keep the audio session alive in background.
    /// Pure silence is ignored by iOS and allows the session to be suspended; a non-zero signal prevents this.
    func startSilentLoop() {
        guard !silentNode.isPlaying else { return }

        if !engine.isRunning {
            try? engine.start()
        }

        let buffer = makeKeepaliveBuffer(duration: 10.0)
        silentNode.scheduleBuffer(buffer, at: nil, options: .loops)
        silentNode.play()
    }

    func stopSilentLoop() {
        silentNode.stop()
    }

    // MARK: - Alarm playback

    func playAlarm(_ sound: AlarmSound) {
        guard checkHeadphoneConnected() else {
            print("[AudioManager] No headphones — alarm suppressed.")
            return
        }

        if !engine.isRunning {
            try? engine.start()
        }

        alarmNode.stop()
        let buffer = makeAlarmBuffer(for: sound, duration: 4.0)
        alarmNode.scheduleBuffer(buffer, at: nil, options: .loops)
        alarmNode.play()
        isAlarmPlaying = true
    }

    func stopAlarm() {
        alarmNode.stop()
        isAlarmPlaying = false
    }

    // MARK: - Sound preview (plays without requiring headphones — for picker UI)

    func previewSound(_ sound: AlarmSound) {
        if !engine.isRunning {
            try? engine.start()
        }
        // Stop any existing preview or alarm
        alarmNode.stop()
        // Play a 2-second preview (no loop); isAlarmPlaying stays false
        let buffer = makeAlarmBuffer(for: sound, duration: 2.0)
        alarmNode.scheduleBuffer(buffer, at: nil, options: [])
        alarmNode.play()
    }

    // MARK: - PCM Buffer generation

    /// Very low amplitude (0.001) sine tone — inaudible at normal volumes but non-zero,
    /// which prevents iOS from suspending the audio session during background operation.
    private func makeKeepaliveBuffer(duration: Double) -> AVAudioPCMBuffer {
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let t = Float(i) / Float(sampleRate)
                // 0.001 amplitude at 220 Hz — well below audible threshold through closed headphones
                data[i] = 0.001 * sin(2 * .pi * 220 * t)
            }
        }
        return buffer
    }

    private func makeAlarmBuffer(for sound: AlarmSound, duration: Double) -> AVAudioPCMBuffer {
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return buffer }

        switch sound {

        case .gentle:
            // 440 Hz soft sine, slow fade-in over 0.5 s, amplitude 0.35
            for i in 0..<Int(frameCount) {
                let t = Float(i) / Float(sampleRate)
                let envelope: Float = min(t / 0.5, 1.0) * 0.35
                data[i] = envelope * sin(2 * .pi * 440 * t)
            }

        case .classic:
            // 880 Hz beep pattern: 0.4 s on / 0.3 s off
            let on: Float = 0.4, period: Float = 0.7
            for i in 0..<Int(frameCount) {
                let t = Float(i) / Float(sampleRate)
                let phase = t.truncatingRemainder(dividingBy: period)
                data[i] = phase < on ? 0.5 * sin(2 * .pi * 880 * t) : 0
            }

        case .digital:
            // 1200 Hz fast pulse: 0.1 s on / 0.1 s off
            let on: Float = 0.1, period: Float = 0.2
            for i in 0..<Int(frameCount) {
                let t = Float(i) / Float(sampleRate)
                let phase = t.truncatingRemainder(dividingBy: period)
                data[i] = phase < on ? 0.45 * sin(2 * .pi * 1200 * t) : 0
            }

        case .chime:
            // Three notes: C5 (523 Hz) → E5 (659 Hz) → G5 (784 Hz), each ~1.2 s
            let notes: [(Float, Float)] = [(0, 523), (1.2, 659), (2.4, 784)]
            for i in 0..<Int(frameCount) {
                let t = Float(i) / Float(sampleRate)
                var sample: Float = 0
                for (startT, freq) in notes {
                    let local = t - startT
                    if local >= 0 && local < 1.2 {
                        let env = exp(-local * 2.5) * 0.5
                        sample += env * sin(2 * .pi * freq * t)
                    }
                }
                data[i] = sample
            }

        case .nature:
            // Sine sweep 300 → 800 Hz with 2 s period, gentle amplitude
            for i in 0..<Int(frameCount) {
                let t = Float(i) / Float(sampleRate)
                let sweep = t.truncatingRemainder(dividingBy: 2.0)
                let freq: Float = 300 + 500 * (sweep / 2.0)
                data[i] = 0.4 * sin(2 * .pi * freq * t)
            }

        case .pulse:
            // 700 Hz fast rhythm: 0.2 s on / 0.1 s off
            let on: Float = 0.2, period: Float = 0.3
            for i in 0..<Int(frameCount) {
                let t = Float(i) / Float(sampleRate)
                let phase = t.truncatingRemainder(dividingBy: period)
                data[i] = phase < on ? 0.5 * sin(2 * .pi * 700 * t) : 0
            }
        }

        return buffer
    }
}
