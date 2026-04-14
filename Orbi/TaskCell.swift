import UIKit

// MARK: - TaskCell

final class TaskCell: UITableViewCell {
    static let id = "TaskCell"

    private let dotView   = UIView()
    private let titleL    = UILabel()
    private let timeL     = UILabel()
    private let checkView = UIView()
    private let checkIcon = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        contentView.addSubview(card)

        dotView.layer.cornerRadius = 5
        dotView.translatesAutoresizingMaskIntoConstraints = false

        titleL.font = .systemFont(ofSize: 15, weight: .medium)
        titleL.textColor = .label
        titleL.translatesAutoresizingMaskIntoConstraints = false

        timeL.font = .systemFont(ofSize: 12)
        timeL.textColor = .secondaryLabel
        timeL.translatesAutoresizingMaskIntoConstraints = false

        checkView.layer.cornerRadius = 11
        checkView.layer.borderWidth  = 1.5
        checkView.translatesAutoresizingMaskIntoConstraints = false

        checkIcon.image = UIImage(systemName: "checkmark")
        checkIcon.tintColor = .white
        checkIcon.contentMode = .scaleAspectFit
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkView.addSubview(checkIcon)

        [dotView, titleL, timeL, checkView].forEach { card.addSubview($0) }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            dotView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            dotView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 10),
            dotView.heightAnchor.constraint(equalToConstant: 10),

            titleL.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 10),
            titleL.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleL.trailingAnchor.constraint(equalTo: checkView.leadingAnchor, constant: -8),

            timeL.leadingAnchor.constraint(equalTo: titleL.leadingAnchor),
            timeL.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 2),
            timeL.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            checkView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            checkView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 22),
            checkView.heightAnchor.constraint(equalToConstant: 22),

            checkIcon.centerXAnchor.constraint(equalTo: checkView.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: checkView.centerYAnchor),
            checkIcon.widthAnchor.constraint(equalToConstant: 12),
            checkIcon.heightAnchor.constraint(equalToConstant: 12),
        ])
    }

    func configure(with task: Task) {
        dotView.backgroundColor = task.color.uiColor
        titleL.text = task.title
        titleL.alpha = task.isCompleted ? 0.4 : 1.0

        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        if let start = task.startTime {
            if let end = task.endTime {
                timeL.text = "\(tf.string(from: start)) - \(tf.string(from: end))"
            } else {
                timeL.text = tf.string(from: start)
            }
        } else {
            timeL.text = "終日"
        }

        if task.isCompleted {
            checkView.backgroundColor = task.color.uiColor
            checkView.layer.borderColor = task.color.uiColor.cgColor
            checkIcon.isHidden = false
        } else {
            checkView.backgroundColor = .clear
            checkView.layer.borderColor = UIColor.separator.cgColor
            checkIcon.isHidden = true
        }

        // 打ち消し線
        if task.isCompleted {
            let attr = NSAttributedString(string: task.title, attributes: [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: UIColor.secondaryLabel
            ])
            titleL.attributedText = attr
            titleL.textColor = .secondaryLabel
        } else {
            titleL.attributedText = nil
            titleL.text = task.title
            titleL.textColor = .label
        }
    }
}

// MARK: - DayCell (Calendar)

final class DayCell: UICollectionViewCell {
    static let id = "DayCell"

    private let numberL   = UILabel()
    private let circle    = UIView()
    private let chipStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        contentView.clipsToBounds = true

        let rightLine = UIView()
        rightLine.backgroundColor = UIColor.separator.withAlphaComponent(0.25)
        rightLine.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rightLine)

        let bottomLine = UIView()
        bottomLine.backgroundColor = UIColor.separator.withAlphaComponent(0.25)
        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bottomLine)

        circle.layer.cornerRadius = 13
        circle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(circle)

        numberL.textAlignment = .center
        numberL.font = .systemFont(ofSize: 13, weight: .medium)
        numberL.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(numberL)

        chipStack.axis      = .vertical
        chipStack.spacing   = 2
        chipStack.alignment = .fill
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chipStack)

        NSLayoutConstraint.activate([
            rightLine.topAnchor.constraint(equalTo: contentView.topAnchor),
            rightLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            rightLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rightLine.widthAnchor.constraint(equalToConstant: 0.5),

            bottomLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomLine.heightAnchor.constraint(equalToConstant: 0.5),

            circle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            circle.widthAnchor.constraint(equalToConstant: 26),
            circle.heightAnchor.constraint(equalToConstant: 26),

            numberL.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            numberL.centerYAnchor.constraint(equalTo: circle.centerYAnchor),

            chipStack.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 2),
            chipStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            chipStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            chipStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -2),
        ])
    }

    // タスクタップ・ドラッグのコールバック
    var onTaskTapped: ((Task) -> Void)?
    var onTaskDrag  : ((Task, UILongPressGestureRecognizer) -> Void)?
    private var chipTasks: [Task] = []

    func configure(day: Int, isToday: Bool, isSelected: Bool, isCurrentMonth: Bool, tasks: [Task], dayOfWeek: Int = -1) {
        let accent  = UIColor(red: 0.26, green: 0.54, blue: 0.96, alpha: 1)
        let satBlue = UIColor(red: 0.20, green: 0.48, blue: 0.95, alpha: 1)
        let sunRed  = UIColor(red: 0.90, green: 0.28, blue: 0.28, alpha: 1)

        contentView.backgroundColor = isSelected ? accent.withAlphaComponent(0.12) : .clear
        contentView.layer.cornerRadius = 4

        numberL.text = "\(day)"
        if isSelected {
            numberL.textColor = .white
        } else if !isCurrentMonth {
            numberL.textColor = .quaternaryLabel
        } else if isToday {
            numberL.textColor = accent
        } else if dayOfWeek == 5 {   // 土
            numberL.textColor = satBlue
        } else if dayOfWeek == 6 {   // 日
            numberL.textColor = sunRed
        } else {
            numberL.textColor = .label
        }
        numberL.font = .systemFont(ofSize: 13, weight: isToday || isSelected ? .bold : .medium)

        circle.backgroundColor = isSelected ? accent : isToday ? accent.withAlphaComponent(0.15) : .clear

        chipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        chipTasks = []

        guard isCurrentMonth else { return }

        let maxChips = 3
        let shown    = Array(tasks.prefix(maxChips))
        let overflow = tasks.count - maxChips

        for (i, task) in shown.enumerated() {
            let chip = makeChip(task: task, index: i, cellSelected: false)
            chipStack.addArrangedSubview(chip)
            chipTasks.append(task)
        }

        if overflow > 0 {
            let more = makeOverflowChip(count: overflow, cellSelected: false)
            chipStack.addArrangedSubview(more)
        }
    }

    private func makeChip(task: Task, index: Int, cellSelected: Bool) -> TaskChipView {
        let color = task.color.uiColor
        let chip  = TaskChipView(task: task)
        chip.backgroundColor    = cellSelected ? UIColor.white.withAlphaComponent(0.25) : color.withAlphaComponent(0.15)
        chip.layer.cornerRadius = 3
        chip.translatesAutoresizingMaskIntoConstraints = false
        chip.heightAnchor.constraint(equalToConstant: 16).isActive = true
        chip.tag = index
        chip.isUserInteractionEnabled = true

        // タップ
        let tap = UITapGestureRecognizer(target: self, action: #selector(chipTapped(_:)))
        chip.addGestureRecognizer(tap)

        // ロングプレス（ドラッグ用）
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(chipLongPressed(_:)))
        lp.minimumPressDuration = 0.4
        lp.allowableMovement    = .greatestFiniteMagnitude
        chip.addGestureRecognizer(lp)

        let bar = UIView()
        bar.backgroundColor    = cellSelected ? UIColor.white : color
        bar.layer.cornerRadius = 1.5
        bar.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(bar)

        let tf = DateFormatter(); tf.dateFormat = "H:mm"
        var timeStr = ""
        if let start = task.startTime { timeStr = tf.string(from: start) + " " }

        let l = UILabel()
        l.font = .systemFont(ofSize: 9, weight: .medium)
        l.textColor = cellSelected ? .white : (task.isCompleted ? .secondaryLabel : color.darker())
        l.numberOfLines = 1; l.lineBreakMode = .byTruncatingTail
        l.translatesAutoresizingMaskIntoConstraints = false

        if !timeStr.isEmpty {
            let attr = NSMutableAttributedString()
            attr.append(NSAttributedString(string: timeStr, attributes: [
                .font: UIFont.systemFont(ofSize: 8.5, weight: .semibold),
                .foregroundColor: cellSelected ? UIColor.white : color.darker(by: 0.2)
            ]))
            attr.append(NSAttributedString(string: task.isCompleted ? "✓ \(task.title)" : task.title, attributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: cellSelected ? UIColor.white : (task.isCompleted ? UIColor.secondaryLabel : color.darker())
            ]))
            l.attributedText = attr
        } else {
            l.text = task.isCompleted ? "✓ \(task.title)" : task.title
        }

        chip.addSubview(l)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: chip.leadingAnchor),
            bar.topAnchor.constraint(equalTo: chip.topAnchor),
            bar.bottomAnchor.constraint(equalTo: chip.bottomAnchor),
            bar.widthAnchor.constraint(equalToConstant: 3),
            l.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 3),
            l.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -2),
            l.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
        ])
        return chip
    }

    private func makeOverflowChip(count: Int, cellSelected: Bool) -> UIView {
        let wrap = UIView()
        wrap.backgroundColor    = cellSelected
            ? UIColor.white.withAlphaComponent(0.25)
            : UIColor.systemGray5
        wrap.layer.cornerRadius = 3
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let l = UILabel()
        l.text      = "+\(count) 件"
        l.font      = .systemFont(ofSize: 9, weight: .medium)
        l.textColor = cellSelected ? .white : .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(l)
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 5),
            l.centerYAnchor.constraint(equalTo: wrap.centerYAnchor),
        ])
        return wrap
    }

    @objc private func chipTapped(_ g: UITapGestureRecognizer) {
        guard let idx = g.view?.tag, idx < chipTasks.count else { return }
        onTaskTapped?(chipTasks[idx])
    }

    @objc private func chipLongPressed(_ g: UILongPressGestureRecognizer) {
        guard let idx = g.view?.tag, idx < chipTasks.count else { return }
        onTaskDrag?(chipTasks[idx], g)
    }
}

// MARK: - TaskChipView

final class TaskChipView: UIView {
    let task: Task
    init(task: Task) {
        self.task = task
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }
}

extension UIColor {
    func darker(by amount: CGFloat = 0.3) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: min(s + 0.1, 1), brightness: max(b - amount, 0), alpha: a)
    }
}

// MARK: - WeekDayCell

final class WeekDayCell: UICollectionViewCell {
    static let id = "WeekDayCell"

    private let dayNameL = UILabel()
    private let numberL  = UILabel()
    private let dotView  = UIView()
    private let circle   = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        dayNameL.textAlignment = .center
        dayNameL.font = .systemFont(ofSize: 11)
        dayNameL.textColor = .secondaryLabel
        dayNameL.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayNameL)

        circle.layer.cornerRadius = 18
        circle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(circle)

        numberL.textAlignment = .center
        numberL.font = .systemFont(ofSize: 16, weight: .medium)
        numberL.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(numberL)

        dotView.layer.cornerRadius = 3
        dotView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dotView)

        NSLayoutConstraint.activate([
            dayNameL.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            dayNameL.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            circle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circle.topAnchor.constraint(equalTo: dayNameL.bottomAnchor, constant: 4),
            circle.widthAnchor.constraint(equalToConstant: 36),
            circle.heightAnchor.constraint(equalToConstant: 36),

            numberL.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            numberL.centerYAnchor.constraint(equalTo: circle.centerYAnchor),

            dotView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dotView.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 4),
            dotView.widthAnchor.constraint(equalToConstant: 6),
            dotView.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    func configure(date: Date, isSelected: Bool) {
        let days = ["月", "火", "水", "木", "金", "土", "日"]
        dayNameL.text = days[date.dayOfWeek]

        let day = Calendar.current.component(.day, from: date)
        numberL.text = "\(day)"

        let isToday = date.isSameDay(as: Date())
        let accent  = UIColor(red: 0.26, green: 0.54, blue: 0.96, alpha: 1)

        circle.backgroundColor = isSelected ? accent : .clear
        numberL.textColor = isSelected ? .white
            : isToday ? accent
            : .label
        numberL.font = .systemFont(ofSize: 16, weight: isToday ? .bold : .medium)

        let tasks = TaskStore.shared.tasks(for: date)
        dotView.isHidden = tasks.isEmpty
        dotView.backgroundColor = isSelected ? .white.withAlphaComponent(0.8) : (tasks.first?.color.uiColor ?? accent)
    }
}
