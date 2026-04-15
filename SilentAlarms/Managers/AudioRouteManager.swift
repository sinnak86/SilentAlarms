import AVFoundation
import Foundation

final class AudioRouteManager: NSObject {
    static let shared = AudioRouteManager()

    var onRouteChange: ((Bool) -> Void)?

    var areEarphonesConnected: Bool {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        let connectedTypes: [AVAudioSession.Port] = [
            .headphones,
            .bluetoothA2DP,
            .bluetoothHFP,
            .bluetoothLE,
            .carAudio
        ]
        return outputs.contains { connectedTypes.contains($0.portType) }
    }

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        let connected = areEarphonesConnected
        DispatchQueue.main.async { [weak self] in
            self?.onRouteChange?(connected)
            NotificationCenter.default.post(
                name: .audioRouteDidChange,
                object: nil,
                userInfo: ["connected": connected]
            )
        }
    }
}

extension Notification.Name {
    static let alarmDidFire           = Notification.Name("alarmDidFire")
    static let alarmFiredNoEarphones  = Notification.Name("alarmFiredNoEarphones")
    static let alarmsDidUpdate        = Notification.Name("alarmsDidUpdate")
    static let audioRouteDidChange    = Notification.Name("audioRouteDidChange")
}
