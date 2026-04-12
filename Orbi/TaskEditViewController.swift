import UIKit

// MARK: - TaskEditViewController

final class TaskEditViewController: UIViewController {

    var task: Task?
    var defaultDate: Date = Date()
    var onSave: ((Task) -> Void)?

    private var selectedColor: TaskColor = .blue
    private var useTime = false

    // UI
    private let scrollView  = UIScrollView()
    private let contentView = UIView()
    private let titleField  = UITextField()
    private let memoView    = UITextView()
    private let datePicker  = UIDatePicker()
    private let timeToggle  = UISwitch()
    private let startPicker = UIDatePicker()
    private let endPicker   = UIDatePicker()
    private var colorButtons: [UIButton] = []
    private var timeRow: UIView!

    private let accentColor = UIColor(red: 0.26, green: 0.54, blue: 0.96, alpha: 1)

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = task == nil ? "タスクを追加" : "タスクを編集"
        navigationItem.leftBarButtonItem  = UIBarButtonItem(title: "キャンセル", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(save))
        navigationItem.rightBarButtonItem?.tintColor = accentColor

        if let t = task {
            selectedColor = t.color
            useTime       = t.startTime != nil
            defaultDate   = t.date
        }

        buildUI()
        populate()
    }

    // MARK: UI Construction

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        var prev: UIView? = nil
        func addSection(_ section: UIView) {
            contentView.addSubview(section)
            NSLayoutConstraint.activate([
                section.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? contentView.topAnchor, constant: 20),
                section.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                section.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            ])
            prev = section
        }

        addSection(buildTitleSection())
        addSection(buildColorSection())
        addSection(buildDateSection())
        addSection(buildTimeSection())
        addSection(buildMemoSection())

        if let last = prev {
            last.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40).isActive = true
        }
    }

    private func card(_ views: [UIView], spacing: CGFloat = 0) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemGroupedBackground
        v.layer.cornerRadius = 12
        var prev: UIView? = nil
        for sv in views {
            v.addSubview(sv)
            NSLayoutConstraint.activate([
                sv.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? v.topAnchor, constant: spacing == 0 ? (prev == nil ? 0 : 1) : spacing),
                sv.leadingAnchor.constraint(equalTo: v.leadingAnchor),
                sv.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            ])
            prev = sv
        }
        prev?.bottomAnchor.constraint(equalTo: v.bottomAnchor).isActive = true
        return v
    }

    private func buildTitleSection() -> UIView {
        titleField.placeholder = "タスク名"
        titleField.font = .systemFont(ofSize: 16)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.returnKeyType = .done
        titleField.delegate = self
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.backgroundColor = .secondarySystemGroupedBackground
        wrap.layer.cornerRadius = 12
        wrap.addSubview(titleField)
        NSLayoutConstraint.activate([
            titleField.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 14),
            titleField.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -14),
            titleField.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16),
            titleField.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
        ])
        return wrap
    }

    private func buildColorSection() -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.backgroundColor = .secondarySystemGroupedBackground
        wrap.layer.cornerRadius = 12

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(stack)

        for color in TaskColor.allCases {
            let btn = UIButton()
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.backgroundColor = color.uiColor
            btn.layer.cornerRadius = 16
            btn.widthAnchor.constraint(equalToConstant: 32).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
            btn.tag = TaskColor.allCases.firstIndex(of: color)!
            btn.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            colorButtons.append(btn)
            stack.addArrangedSubview(btn)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16),
        ])
        updateColorButtons()
        return wrap
    }

    private func buildDateSection() -> UIView {
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.locale = Locale(identifier: "ja_JP")
        datePicker.tintColor = accentColor
        datePicker.translatesAutoresizingMaskIntoConstraints = false

        let row = rowView(label: "日付", right: datePicker)
        return card([row])
    }

    private func buildTimeSection() -> UIView {
        timeToggle.onTintColor = accentColor
        timeToggle.isOn = useTime
        timeToggle.addTarget(self, action: #selector(timeSwitched), for: .valueChanged)
        timeToggle.translatesAutoresizingMaskIntoConstraints = false

        startPicker.datePickerMode = .time
        startPicker.preferredDatePickerStyle = .compact
        startPicker.locale = Locale(identifier: "ja_JP")
        startPicker.tintColor = accentColor
        startPicker.minuteInterval = 30
        startPicker.translatesAutoresizingMaskIntoConstraints = false

        endPicker.datePickerMode = .time
        endPicker.preferredDatePickerStyle = .compact
        endPicker.locale = Locale(identifier: "ja_JP")
        endPicker.tintColor = accentColor
        endPicker.minuteInterval = 30
        endPicker.translatesAutoresizingMaskIntoConstraints = false

        let toggleRow = rowView(label: "時間を設定", right: timeToggle)

        let startRow = rowView(label: "開始", right: startPicker)
        let endRow   = rowView(label: "終了", right: endPicker)

        let detailWrap = UIView()
        detailWrap.translatesAutoresizingMaskIntoConstraints = false
        detailWrap.isHidden = !useTime
        [startRow, endRow].forEach { detailWrap.addSubview($0) }
        let sep = sepView()
        detailWrap.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: detailWrap.topAnchor),
            sep.leadingAnchor.constraint(equalTo: detailWrap.leadingAnchor, constant: 16),
            sep.trailingAnchor.constraint(equalTo: detailWrap.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
            startRow.topAnchor.constraint(equalTo: sep.bottomAnchor),
            startRow.leadingAnchor.constraint(equalTo: detailWrap.leadingAnchor),
            startRow.trailingAnchor.constraint(equalTo: detailWrap.trailingAnchor),
            endRow.topAnchor.constraint(equalTo: startRow.bottomAnchor),
            endRow.leadingAnchor.constraint(equalTo: detailWrap.leadingAnchor),
            endRow.trailingAnchor.constraint(equalTo: detailWrap.trailingAnchor),
            endRow.bottomAnchor.constraint(equalTo: detailWrap.bottomAnchor),
        ])
        timeRow = detailWrap

        return card([toggleRow, detailWrap])
    }

    private func buildMemoSection() -> UIView {
        memoView.font = .systemFont(ofSize: 15)
        memoView.backgroundColor = .clear
        memoView.isScrollEnabled = false
        memoView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        memoView.translatesAutoresizingMaskIntoConstraints = false
        memoView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true

        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.backgroundColor = .secondarySystemGroupedBackground
        wrap.layer.cornerRadius = 12
        wrap.addSubview(memoView)
        NSLayoutConstraint.activate([
            memoView.topAnchor.constraint(equalTo: wrap.topAnchor),
            memoView.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            memoView.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            memoView.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
        ])
        return wrap
    }

    private func rowView(label: String, right: UIView) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        let l = UILabel()
        l.text = label
        l.font = .systemFont(ofSize: 15)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        right.translatesAutoresizingMaskIntoConstraints = true
        right.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(l); v.addSubview(right)
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            l.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            right.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),
            right.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            v.heightAnchor.constraint(equalToConstant: 48),
        ])
        return v
    }

    private func sepView() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    // MARK: Populate

    private func populate() {
        if let t = task {
            titleField.text = t.title
            memoView.text   = t.memo
            datePicker.date = t.date
            if let start = t.startTime { startPicker.date = start }
            if let end   = t.endTime   { endPicker.date   = end   }
        } else {
            datePicker.date  = defaultDate
            startPicker.date = defaultDate
            let end = Calendar.current.date(byAdding: .hour, value: 1, to: defaultDate) ?? defaultDate
            endPicker.date = end
        }
        updateColorButtons()
    }

    private func updateColorButtons() {
        for (i, btn) in colorButtons.enumerated() {
            let color = TaskColor.allCases[i]
            btn.layer.borderWidth  = color == selectedColor ? 3 : 0
            btn.layer.borderColor  = UIColor.white.cgColor
            btn.transform = color == selectedColor ? CGAffineTransform(scaleX: 1.15, y: 1.15) : .identity
        }
    }

    // MARK: Actions

    @objc private func colorTapped(_ sender: UIButton) {
        selectedColor = TaskColor.allCases[sender.tag]
        UIView.animate(withDuration: 0.15) { self.updateColorButtons() }
    }

    @objc private func timeSwitched() {
        useTime = timeToggle.isOn
        UIView.animate(withDuration: 0.25) {
            self.timeRow.isHidden = !self.useTime
        }
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    @objc private func save() {
        guard let title = titleField.text, !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            titleField.layer.borderColor = UIColor.systemRed.cgColor
            titleField.layer.borderWidth = 1
            titleField.layer.cornerRadius = 6
            return
        }

        var t = task ?? Task(title: "", date: datePicker.date)
        t.title     = title.trimmingCharacters(in: .whitespaces)
        t.date      = datePicker.date
        t.startTime = useTime ? startPicker.date : nil
        t.endTime   = useTime ? endPicker.date   : nil
        t.memo      = memoView.text ?? ""
        t.color     = selectedColor

        onSave?(t)
        dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension TaskEditViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
