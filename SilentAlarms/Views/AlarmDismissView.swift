import UIKit

final class AlarmDismissView: UIView {

    var onDismiss: (() -> Void)?

    private let blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        return UIVisualEffectView(effect: effect)
    }()

    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 80, weight: .ultraLight)
        l.textColor = .white
        l.textAlignment = .center
        return l
    }()

    private let alarmLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .light)
        l.textColor = UIColor.white.withAlphaComponent(0.8)
        l.textAlignment = .center
        return l
    }()

    private let pulseRing: UIView = {
        let v = UIView()
        v.layer.borderColor = UIColor.systemOrange.cgColor
        v.layer.borderWidth = 2
        v.backgroundColor = .clear
        return v
    }()

    private let slideControl = SlideToStopControl()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)

        [pulseRing, timeLabel, alarmLabel, slideControl].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            pulseRing.centerXAnchor.constraint(equalTo: centerXAnchor),
            pulseRing.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -80),
            pulseRing.widthAnchor.constraint(equalToConstant: 160),
            pulseRing.heightAnchor.constraint(equalToConstant: 160),

            timeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -80),

            alarmLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 8),
            alarmLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            slideControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            slideControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            slideControl.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -48),
            slideControl.heightAnchor.constraint(equalToConstant: 64),
        ])

        pulseRing.layer.cornerRadius = 80
        slideControl.onDismiss = { [weak self] in self?.onDismiss?() }
        startPulseAnimation()
    }

    func configure(with alarm: Alarm) {
        timeLabel.text = alarm.timeString
        alarmLabel.text = alarm.label.isEmpty ? "알람" : alarm.label
    }

    private func startPulseAnimation() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.95
        pulse.toValue = 1.05
        pulse.duration = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseRing.layer.add(pulse, forKey: "pulse")

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.4
        fade.toValue = 1.0
        fade.duration = 1.0
        fade.autoreverses = true
        fade.repeatCount = .infinity
        pulseRing.layer.add(fade, forKey: "fade")
    }

    func show(in parentView: UIView, animated: Bool = true) {
        frame = parentView.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alpha = 0
        parentView.addSubview(self)

        if animated {
            UIView.animate(withDuration: 0.4) { self.alpha = 1 }
        } else {
            alpha = 1
        }
    }

    func hide(animated: Bool = true, completion: (() -> Void)? = nil) {
        if animated {
            UIView.animate(withDuration: 0.3, animations: { self.alpha = 0 }) { _ in
                self.removeFromSuperview()
                completion?()
            }
        } else {
            removeFromSuperview()
            completion?()
        }
    }
}

// MARK: - Slide To Stop Control

final class SlideToStopControl: UIView {
    var onDismiss: (() -> Void)?

    private let trackView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        v.layer.cornerRadius = 32
        v.clipsToBounds = true
        return v
    }()

    private let fillView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.4)
        return v
    }()

    private let thumb: UIView = {
        let v = UIView()
        v.backgroundColor = .systemOrange
        v.layer.cornerRadius = 28
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.3
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.layer.shadowRadius = 4
        return v
    }()

    private let thumbIcon: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        iv.image = UIImage(systemName: "chevron.right.2", withConfiguration: config)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let trackLabel: UILabel = {
        let l = UILabel()
        l.text = "밀어서 알람 끄기"
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.7)
        l.textAlignment = .center
        return l
    }()

    private var thumbLeadingConstraint: NSLayoutConstraint!
    private var trackWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        [trackView, trackLabel, fillView, thumb].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        thumbIcon.translatesAutoresizingMaskIntoConstraints = false

        addSubview(trackView)
        trackView.addSubview(fillView)
        addSubview(trackLabel)
        addSubview(thumb)
        thumb.addSubview(thumbIcon)

        NSLayoutConstraint.activate([
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.topAnchor.constraint(equalTo: topAnchor),
            trackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            fillView.topAnchor.constraint(equalTo: trackView.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),

            trackLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            trackLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            thumb.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            thumb.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            thumb.widthAnchor.constraint(equalTo: thumb.heightAnchor),

            thumbIcon.centerXAnchor.constraint(equalTo: thumb.centerXAnchor),
            thumbIcon.centerYAnchor.constraint(equalTo: thumb.centerYAnchor),
        ])

        thumbLeadingConstraint = thumb.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4)
        thumbLeadingConstraint.isActive = true

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        thumb.addGestureRecognizer(pan)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        trackWidth = bounds.width
        let thumbWidth = max(bounds.height - 8, 1)
        fillView.frame.size.width = thumbLeadingConstraint.constant + thumbWidth / 2
    }

    private var effectiveThumbWidth: CGFloat { max(bounds.height - 8, 1) }
    private var effectiveMaxX: CGFloat { max(trackWidth - effectiveThumbWidth - 4, effectiveThumbWidth + 4) }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard trackWidth > 0 else { return }
        let thumbWidth = effectiveThumbWidth
        let maxX = effectiveMaxX
        let translation = gesture.translation(in: self)
        let rawX = thumbLeadingConstraint.constant + translation.x
        let clampedX = max(4, min(rawX, maxX))
        let range = maxX - 4

        switch gesture.state {
        case .changed:
            thumbLeadingConstraint.constant = clampedX
            fillView.frame.size.width = clampedX + thumbWidth / 2
            trackLabel.alpha = range > 0 ? 1 - (clampedX - 4) / range : 0
            gesture.setTranslation(.zero, in: self)

        case .ended, .cancelled:
            let progress = range > 0 ? (clampedX - 4) / range : 0
            if progress >= 0.80 {
                completeDismiss()
            } else {
                snapBack()
            }

        default: break
        }
    }

    private func completeDismiss() {
        let maxX = effectiveMaxX
        let thumbWidth = effectiveThumbWidth
        UIView.animate(withDuration: 0.2) {
            self.thumbLeadingConstraint.constant = maxX
            self.fillView.frame.size.width = maxX + thumbWidth / 2
            self.trackLabel.alpha = 0
            self.layoutIfNeeded()
        } completion: { _ in
            self.onDismiss?()
        }
    }

    private func snapBack() {
        UIView.animate(withDuration: 0.4, delay: 0,
                       usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.thumbLeadingConstraint.constant = 4
            self.fillView.frame.size.width = self.thumb.bounds.width / 2
            self.trackLabel.alpha = 1
            self.layoutIfNeeded()
        }
    }
}
