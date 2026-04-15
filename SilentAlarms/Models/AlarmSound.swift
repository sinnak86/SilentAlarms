import Foundation

struct AlarmSound: Identifiable {
    let id: String
    let displayName: String
    let fileExtension: String

    var fileName: String { "\(id).\(fileExtension)" }

    static let available: [AlarmSound] = [
        AlarmSound(id: "alarm_gentle",   displayName: "부드러운 기상",  fileExtension: "caf"),
        AlarmSound(id: "alarm_digital",  displayName: "디지털 비프",    fileExtension: "caf"),
        AlarmSound(id: "alarm_classic",  displayName: "클래식 벨",      fileExtension: "caf"),
        AlarmSound(id: "alarm_birds",    displayName: "새소리",         fileExtension: "caf"),
        AlarmSound(id: "alarm_chime",    displayName: "소프트 차임",     fileExtension: "caf"),
    ]

    static func sound(for id: String) -> AlarmSound {
        available.first { $0.id == id } ?? available[0]
    }
}
