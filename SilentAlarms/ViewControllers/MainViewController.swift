import UIKit
import AVFoundation

final class MainViewController: UIViewController {

    // MARK: - Subviews

    private let warningBanner: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
        v.layer.borderColor = UIColor.systemOrange.cgColor
        v.layer.borderWidth = 1
        v.layer.cornerRadius = 10
        v.isHidden = true
        return v
    }()

    private let warningIcon: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iv.image = UIImage(systemName: "headphones.slash", withConfiguration: config)
        iv.tintColor = .systemOrange
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let warningLabel: UILabel = {
        let l = UILabel()
        l.text = "이어폰이 연결되지 않았습니다. 알람이 울리지 않습니다."
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = .systemOrange
        l.numberOfLines = 2
        return l
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .systemGroupedBackground
        tv.register(AlarmCell.self, forCellReuseIdentifier: AlarmCell.reuseIdentifier)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 88
        return tv
    }()

    private let emptyStateLabel: UILabel = {
        let l = UILabel()
        l.text = "알람이 없습니다\n아래 + 버튼을 눌러 추가하세요"
        l.font = .systemFont(ofSize: 16)
        l.textColor = .tertiaryLabel
        l.textAlignment = .center
        l.numberOfLines = 2
        return l
    }()

    private let addButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "plus", withConfiguration:
            UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .systemOrange
        config.baseForegroundColor = .white
        let b = UIButton(configuration: config)
        b.layer.shadowColor = UIColor.systemOrange.cgColor
        b.layer.shadowOpacity = 0.4
        b.layer.shadowOffset = CGSize(width: 0, height: 4)
        b.layer.shadowRadius = 8
        return b
    }()

    private var dismissView: AlarmDismissView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupObservers()
        configureAudio()
        AlarmManager.shared.loadAlarms()
        tableView.reloadData()
        updateWarningBanner()
        updateEmptyState()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "Silent Alarm"

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        tableView.dataSource = self
        tableView.delegate = self

        addButton.addTarget(self, action: #selector(addAlarmTapped), for: .touchUpInside)

        let warningRow = UIStackView(arrangedSubviews: [warningIcon, warningLabel])
        warningRow.axis = .horizontal
        warningRow.spacing = 8
        warningRow.alignment = .center
        warningRow.translatesAutoresizingMaskIntoConstraints = false
        warningBanner.addSubview(warningRow)
        NSLayoutConstraint.activate([
            warningRow.leadingAnchor.constraint(equalTo: warningBanner.leadingAnchor, constant: 12),
            warningRow.trailingAnchor.constraint(equalTo: warningBanner.trailingAnchor, constant: -12),
            warningRow.topAnchor.constraint(equalTo: warningBanner.topAnchor, constant: 10),
            warningRow.bottomAnchor.constraint(equalTo: warningBanner.bottomAnchor, constant: -10),
            warningIcon.widthAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func setupConstraints() {
        [warningBanner, tableView, emptyStateLabel, addButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            warningBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            warningBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            warningBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: warningBanner.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            addButton.widthAnchor.constraint(equalToConstant: 60),
            addButton.heightAnchor.constraint(equalToConstant: 60),
        ])
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAlarmFire(_:)),
                                               name: .alarmDidFire, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNoEarphones),
                                               name: .alarmFiredNoEarphones, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAlarmsUpdate),
                                               name: .alarmsDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)),
                                               name: .audioRouteDidChange, object: nil)
    }

    private func configureAudio() {
        AlarmManager.shared.configureAudioSession()
        AudioRouteManager.shared.onRouteChange = { [weak self] _ in
            self?.updateWarningBanner()
        }
    }

    // MARK: - Notifications

    @objc private func handleAlarmFire(_ notification: Notification) {
        guard let alarm = notification.object as? Alarm else { return }
        showDismissView(for: alarm)
    }

    @objc private func handleNoEarphones() {
        let alert = UIAlertController(
            title: "이어폰 없음",
            message: "이어폰/헤드폰이 연결되지 않아 알람이 울리지 않습니다.\n연결 후 30초 내에 다시 시도합니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    @objc private func handleAlarmsUpdate() {
        tableView.reloadData()
        updateEmptyState()
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        updateWarningBanner()
    }

    // MARK: - UI Updates

    private func updateWarningBanner() {
        let connected = AudioRouteManager.shared.areEarphonesConnected
        UIView.animate(withDuration: 0.3) {
            self.warningBanner.isHidden = connected
        }
    }

    private func updateEmptyState() {
        emptyStateLabel.isHidden = !AlarmManager.shared.alarms.isEmpty
    }

    // MARK: - Actions

    @objc private func addAlarmTapped() {
        presentAddEdit(alarm: nil)
    }

    private func presentAddEdit(alarm: Alarm?) {
        let editView = AddEditAlarmView()
        editView.configure(with: alarm)
        editView.onSave = { [weak self] savedAlarm in
            if alarm == nil {
                AlarmManager.shared.addAlarm(savedAlarm)
            } else {
                AlarmManager.shared.updateAlarm(savedAlarm)
            }
        }
        editView.show(in: view)
    }

    private func showDismissView(for alarm: Alarm) {
        dismissView?.removeFromSuperview()
        let dv = AlarmDismissView()
        dv.configure(with: alarm)
        dv.onDismiss = { [weak self] in
            AlarmManager.shared.dismissCurrentAlarm()
            self?.dismissView?.hide(animated: true)
            self?.dismissView = nil
        }
        dv.show(in: view)
        dismissView = dv
    }
}

// MARK: - UITableViewDataSource

extension MainViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        AlarmManager.shared.alarms.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AlarmCell.reuseIdentifier, for: indexPath) as! AlarmCell
        let alarm = AlarmManager.shared.alarms[indexPath.row]
        cell.configure(with: alarm)
        cell.onToggle = { [weak self] isOn in
            var updated = AlarmManager.shared.alarms[indexPath.row]
            updated.isEnabled = isOn
            AlarmManager.shared.updateAlarm(updated)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alarm = AlarmManager.shared.alarms[indexPath.row]
        presentAddEdit(alarm: alarm)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            let alarm = AlarmManager.shared.alarms[indexPath.row]
            AlarmManager.shared.deleteAlarm(id: alarm.id)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}
