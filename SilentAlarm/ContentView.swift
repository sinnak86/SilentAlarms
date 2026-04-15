import SwiftUI

// MARK: - Root View

struct ContentView: View {

    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var audioManager: AudioManager

    @State private var showAddSheet = false
    @State private var editingAlarm: Alarm?

    var body: some View {
        ZStack {
            // ── Main screen ──────────────────────────────────────
            NavigationView {
                VStack(spacing: 0) {
                    headphoneStatusBanner
                    alarmList
                }
                .navigationTitle("Silent Alarm")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            editingAlarm = nil
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3)
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)

            // ── Alarm ringing overlay ────────────────────────────
            if let ringing = alarmManager.currentlyRingingAlarm {
                AlarmRingingView(alarm: ringing) {
                    alarmManager.stopCurrentAlarm()
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: alarmManager.currentlyRingingAlarm != nil)
        // ── Add / Edit sheet ─────────────────────────────────────
        .sheet(isPresented: $showAddSheet) {
            AddAlarmView(editingAlarm: editingAlarm) { alarm in
                if editingAlarm != nil {
                    alarmManager.updateAlarm(alarm)
                } else {
                    alarmManager.addAlarm(alarm)
                }
                showAddSheet = false
                editingAlarm = nil
            }
            .environmentObject(audioManager)
        }
        // ── Force dark colour scheme throughout ─────────────────
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headphoneStatusBanner: some View {
        if audioManager.isHeadphonesConnected {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("이어폰/헤드폰이 연결되었습니다")
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.85))
        } else {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("이어폰/헤드폰이 연결되지 않았습니다. 연결 없이는 알람이 울리지 않습니다.")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.red.opacity(0.85))
        }
    }

    private var alarmList: some View {
        Group {
            if alarmManager.alarms.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("등록된 알람이 없습니다")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("+ 버튼으로 알람을 추가하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(alarmManager.alarms) { alarm in
                        AlarmRowView(alarm: alarm) {
                            alarmManager.toggleAlarm(alarm)
                        } onEdit: {
                            editingAlarm = alarm
                            showAddSheet = true
                        }
                    }
                    .onDelete { offsets in
                        alarmManager.deleteAlarm(at: offsets)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - AlarmRowView

struct AlarmRowView: View {
    let alarm: Alarm
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.system(size: 40, weight: .thin, design: .rounded))
                    .foregroundColor(alarm.isEnabled ? .primary : .secondary)
                HStack(spacing: 6) {
                    Text(alarm.daysString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(alarm.soundID.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .padding(.vertical, 4)
    }
}

// MARK: - AddAlarmView

struct AddAlarmView: View {

    let editingAlarm: Alarm?
    let onSave: (Alarm) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var audioManager: AudioManager

    @State private var selectedTime: Date
    @State private var selectedDays: Set<Weekday>
    @State private var selectedSound: AlarmSound
    @State private var label: String

    init(editingAlarm: Alarm?, onSave: @escaping (Alarm) -> Void) {
        self.editingAlarm = editingAlarm
        self.onSave = onSave

        if let a = editingAlarm {
            var comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
            comps.hour   = a.hour
            comps.minute = a.minute
            let date = Calendar.current.date(from: comps) ?? Date()
            _selectedTime  = State(initialValue: date)
            _selectedDays  = State(initialValue: a.days)
            _selectedSound = State(initialValue: a.soundID)
            _label         = State(initialValue: a.label)
        } else {
            _selectedTime  = State(initialValue: Date())
            _selectedDays  = State(initialValue: [.mon, .tue, .wed, .thu, .fri])
            _selectedSound = State(initialValue: .gentle)
            _label         = State(initialValue: "알람")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // ── Time picker ──────────────────────────────────
                Section {
                    DatePicker("시간 선택", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                // ── Label ────────────────────────────────────────
                Section(header: Text("알람 이름")) {
                    TextField("알람 이름 (선택)", text: $label)
                }

                // ── Day selection ────────────────────────────────
                Section(header: Text("반복")) {
                    HStack(spacing: 6) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            DayToggleButton(
                                day: day,
                                isSelected: selectedDays.contains(day)
                            ) {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── Sound selection ──────────────────────────────
                Section(header: Text("알람음")) {
                    ForEach(AlarmSound.allCases, id: \.self) { sound in
                        HStack {
                            Text(sound.displayName)
                            Spacer()
                            if selectedSound == sound {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.caption)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSound = sound
                            // Preview the sound immediately when selected
                            audioManager.previewSound(sound)
                        }
                    }
                }
            }
            .navigationTitle(editingAlarm != nil ? "알람 편집" : "알람 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") { saveAlarm() }
                        .fontWeight(.semibold)
                        .disabled(selectedDays.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveAlarm() {
        let cal = Calendar.current
        let hour   = cal.component(.hour,   from: selectedTime)
        let minute = cal.component(.minute, from: selectedTime)

        let alarm = Alarm(
            id:       editingAlarm?.id ?? UUID(),
            label:    label,
            hour:     hour,
            minute:   minute,
            days:     selectedDays,
            soundID:  selectedSound,
            isEnabled: editingAlarm?.isEnabled ?? true
        )
        onSave(alarm)
    }
}

// MARK: - DayToggleButton

struct DayToggleButton: View {
    let day: Weekday
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Text(day.shortName)
            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? .white : .primary)
            .frame(width: 36, height: 36)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .clipShape(Circle())
            .onTapGesture { onTap() }
    }
}

// MARK: - AlarmRingingView

struct AlarmRingingView: View {
    let alarm: Alarm
    let onStop: () -> Void

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Bell icon
                Image(systemName: "bell.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.yellow)

                // Current time
                Text(timeString(from: currentTime))
                    .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                    .foregroundColor(.white)
                    .onReceive(timer) { currentTime = $0 }

                // Alarm label
                Text(alarm.label)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))

                // Sound name
                Text(alarm.soundID.displayName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                // Slide to stop
                VStack(spacing: 8) {
                    SlideToStopButton(onStop: onStop)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 60)
            }
        }
    }

    private func timeString(from date: Date) -> String {
        let cal = Calendar.current
        let h = cal.component(.hour,   from: date)
        let m = cal.component(.minute, from: date)
        return String(format: "%02d:%02d", h, m)
    }
}

// MARK: - SlideToStopButton

struct SlideToStopButton: View {

    let onStop: () -> Void

    @GestureState private var dragOffset: CGFloat = 0
    @State private var didStop = false

    private let thumbSize: CGFloat = 64
    private let trackHeight: CGFloat = 68

    var body: some View {
        GeometryReader { geo in
            let maxOffset = geo.size.width - thumbSize

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: trackHeight)

                // Progress fill
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.red.opacity(0.5))
                    .frame(width: max(thumbSize, dragOffset + thumbSize), height: trackHeight)
                    .animation(.interactiveSpring(), value: dragOffset)

                // Label (fades out as thumb moves right)
                Text("밀어서 종료  →")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(max(0, 1 - dragOffset / (maxOffset * 0.5))))
                    .frame(maxWidth: .infinity)

                // Draggable thumb
                Circle()
                    .fill(Color.red)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Image(systemName: "stop.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    )
                    .offset(x: min(max(0, dragOffset), maxOffset))
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                guard !didStop else { return }
                                state = max(0, value.translation.width)
                            }
                            .onEnded { value in
                                guard !didStop else { return }
                                if value.translation.width > maxOffset * 0.75 {
                                    didStop = true
                                    onStop()
                                }
                            }
                    )
            }
        }
        .frame(height: trackHeight)
    }
}
