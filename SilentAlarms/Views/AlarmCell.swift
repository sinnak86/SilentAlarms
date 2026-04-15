import UIKit

final class AlarmCell: UITableViewCell {
    static let reuseIdentifier = "AlarmCell"

    var onToggle: ((Bool) -> Void)?

    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 42, weight: .thin)
        l.textColor = .label
        return l
    }()

    private let daysLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = .secondaryLabel
        return l
    }()

    private let soundLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .tertiaryLabel
        return l
    }()

    private let labelLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        return l
    }()

    let enableSwitch: UISwitch = {
        let s = UISwitch()
        s.onTintColor = .systemOrange
        return s
    }()

    private let textStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 2
        sv.alignment = .leading
        return sv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .secondarySystemGroupedBackground

        enableSwitch.addTarget(self, action: #selector(switchToggled), for: .valueChanged)

        let daysSound = UIStackView(arrangedSubviews: [daysLabel, soundLabel])
        daysSound.axis = .horizontal
        daysSound.spacing = 8

        textStack.addArrangedSubview(timeLabel)
        textStack.addArrangedSubview(daysSound)
        textStack.addArrangedSubview(labelLabel)

        [textStack, enableSwitch].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

            enableSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            enableSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            enableSwitch.leadingAnchor.constraint(greaterThanOrEqualTo: textStack.trailingAnchor, constant: 12),
        ])
    }

    func configure(with alarm: Alarm) {
        timeLabel.text = alarm.timeString
        daysLabel.text = alarm.daysString
        soundLabel.text = AlarmSound.sound(for: alarm.soundName).displayName
        labelLabel.text = alarm.label
        labelLabel.isHidden = alarm.label.isEmpty
        enableSwitch.isOn = alarm.isEnabled
        timeLabel.alpha = alarm.isEnabled ? 1.0 : 0.4
        daysLabel.alpha = alarm.isEnabled ? 1.0 : 0.4
    }

    @objc private func switchToggled() {
        onToggle?(enableSwitch.isOn)
    }
}
