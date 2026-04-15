import UIKit

final class AddEditAlarmView: UIView {

    var onSave: ((Alarm) -> Void)?
    var onCancel: (() -> Void)?

    private var editingAlarm: Alarm?

    // MARK: - Subviews

    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 20
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.clipsToBounds = true
        return v
    }()

    private let dragHandle: UIView = {
        let v = UIView()
        v.backgroundColor = .systemFill
        v.layer.cornerRadius = 2.5
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.textAlignment = .center
        return l
    }()

    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("취소", for: .normal)
        b.tintColor = .systemGray
        return b
    }()

    private let saveButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("저장", for: .normal)
        b.tintColor = .systemOrange
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return b
    }()

    private let timePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .time
        dp.preferredDatePickerStyle = .wheels
        dp.locale = Locale(identifier: "ko_KR")
        return dp
    }()

    private let dayButtons: [UIButton] = Alarm.Weekday.allCases.map { day in
        let b = UIButton(type: .system)
        b.setTitle(day.shortName, for: .normal)
        b.tag = day.rawValue
        b.layer.cornerRadius = 18
        b.layer.borderWidth = 1.5
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        b.setTitleColor(.systemOrange, for: .normal)
        b.layer.borderColor = UIColor.systemOrange.cgColor
        b.backgroundColor = .clear
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    private let soundLabel: UILabel = {
        let l = UILabel()
        l.text = "알람음"
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = .label
        return l
    }()

    private let soundPicker: UIPickerView = {
        let p = UIPickerView()
        p.translatesAutoresizingMaskIntoConstraints = false
        // Suppress intrinsic content size conflict with explicit height constraint
        p.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        p.setContentHuggingPriority(.defaultLow, for: .vertical)
        return p
    }()

    private let alarmLabelField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "알람 이름 (선택)"
        tf.font = .systemFont(ofSize: 15)
        tf.borderStyle = .roundedRect
        tf.backgroundColor = .tertiarySystemBackground
        tf.returnKeyType = .done
        return tf
    }()

    private var selectedDays: Set<Alarm.Weekday> = []
    private var selectedSoundIndex: Int = 0
    private var containerBottomConstraint: NSLayoutConstraint!

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupKeyboardObservers()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupViews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.4)

        soundPicker.dataSource = self
        soundPicker.delegate = self
        alarmLabelField.delegate = self

        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        dayButtons.forEach { $0.addTarget(self, action: #selector(dayToggled(_:)), for: .touchUpInside) }

        let tapDismiss = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        addGestureRecognizer(tapDismiss)
        containerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(containerTapped)))

        // Build day selector row
        let dayStack = UIStackView(arrangedSubviews: dayButtons)
        dayStack.axis = .horizontal
        dayStack.distribution = .fillEqually
        dayStack.spacing = 6

        dayButtons.forEach { b in
            b.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }

        // Sound row
        let soundRow = UIStackView(arrangedSubviews: [soundLabel, soundPicker])
        soundRow.axis = .horizontal
        soundRow.spacing = 8
        soundRow.alignment = .center
        soundPicker.heightAnchor.constraint(equalToConstant: 100).isActive = true

        // Label field row
        let labelSectionLabel = UILabel()
        labelSectionLabel.text = "이름"
        labelSectionLabel.font = .systemFont(ofSize: 15, weight: .medium)

        let labelRow = UIStackView(arrangedSubviews: [labelSectionLabel, alarmLabelField])
        labelRow.axis = .horizontal
        labelRow.spacing = 8
        labelRow.alignment = .center
        alarmLabelField.widthAnchor.constraint(equalToConstant: 200).isActive = true

        // Main stack inside container
        let mainStack = UIStackView(arrangedSubviews: [timePicker, dayStack, soundRow, labelRow])
        mainStack.axis = .vertical
        mainStack.spacing = 16
        mainStack.alignment = .fill

        // Header row
        let headerStack = UIStackView(arrangedSubviews: [cancelButton, titleLabel, saveButton])
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        headerStack.alignment = .center

        [dragHandle, headerStack, mainStack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        containerView.addSubview(dragHandle)
        containerView.addSubview(headerStack)
        containerView.addSubview(mainStack)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: bottomAnchor)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerBottomConstraint,

            dragHandle.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            dragHandle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 40),
            dragHandle.heightAnchor.constraint(equalToConstant: 5),

            headerStack.topAnchor.constraint(equalTo: dragHandle.bottomAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            mainStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - Configure

    func configure(with alarm: Alarm? = nil) {
        editingAlarm = alarm
        titleLabel.text = alarm == nil ? "새 알람" : "알람 편집"

        if let alarm = alarm {
            var comps = DateComponents()
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            if let date = Calendar.current.date(from: comps) {
                timePicker.setDate(date, animated: false)
            }
            selectedDays = alarm.days
            if let idx = AlarmSound.available.firstIndex(where: { $0.id == alarm.soundName }) {
                selectedSoundIndex = idx
                soundPicker.selectRow(idx, inComponent: 0, animated: false)
            }
            alarmLabelField.text = alarm.label
        } else {
            selectedDays = []
            selectedSoundIndex = 0
            alarmLabelField.text = ""
        }

        updateDayButtonAppearance()
    }

    private func updateDayButtonAppearance() {
        for button in dayButtons {
            guard let day = Alarm.Weekday(rawValue: button.tag) else { continue }
            let isSelected = selectedDays.contains(day)
            button.backgroundColor = isSelected ? .systemOrange : .clear
            button.setTitleColor(isSelected ? .white : .systemOrange, for: .normal)
        }
    }

    // MARK: - Actions

    @objc private func dayToggled(_ sender: UIButton) {
        guard let day = Alarm.Weekday(rawValue: sender.tag) else { return }
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
        updateDayButtonAppearance()
    }

    @objc private func saveTapped() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timePicker.date)
        let minute = calendar.component(.minute, from: timePicker.date)
        let sound = AlarmSound.available[selectedSoundIndex]

        let alarm = Alarm(
            id: editingAlarm?.id ?? UUID(),
            isEnabled: editingAlarm?.isEnabled ?? true,
            hour: hour,
            minute: minute,
            days: selectedDays,
            soundName: sound.id,
            label: alarmLabelField.text ?? ""
        )
        onSave?(alarm)
        hide()
    }

    @objc private func cancelTapped() {
        onCancel?()
        hide()
    }

    @objc private func backgroundTapped() { hide() }
    @objc private func containerTapped() {}

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        containerBottomConstraint.constant = -keyboardFrame.height
        UIView.animate(withDuration: 0.3) { self.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        containerBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.3) { self.layoutIfNeeded() }
    }

    // MARK: - Presentation

    func show(in parentView: UIView) {
        frame = parentView.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alpha = 0
        containerView.transform = CGAffineTransform(translationX: 0, y: 400)
        parentView.addSubview(self)

        UIView.animate(withDuration: 0.45, delay: 0,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.5) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
    }

    private func hide() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.containerView.transform = CGAffineTransform(translationX: 0, y: 400)
        }) { _ in
            self.removeFromSuperview()
        }
    }
}

// MARK: - UIPickerViewDataSource / Delegate

extension AddEditAlarmView: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        AlarmSound.available.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        AlarmSound.available[row].displayName
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedSoundIndex = row
    }
}

// MARK: - UITextFieldDelegate

extension AddEditAlarmView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
