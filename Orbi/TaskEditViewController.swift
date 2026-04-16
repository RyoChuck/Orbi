import UIKit

// MARK: - TaskEditViewController

final class TaskEditViewController: UIViewController {

    var onSave: ((Task) -> Void)?
    var onDelete: (() -> Void)?
    var defaultDate      : Date  = Date()
    var defaultStartTime : Date? = nil
    var defaultEndTime   : Date? = nil
    private var isNewTask: Bool = true

    var task: Task
    private let accentColor = UIColor(red: 0.28, green: 0.72, blue: 1.00, alpha: 1)

    // UI
    private let scrollView   = UIScrollView()
    private let contentView  = UIView()
    private let titleField   = UITextField()
    private let datePicker   = UIDatePicker()
    private let startPicker  = UIDatePicker()
    private let endPicker    = UIDatePicker()
    private let memoField    = UITextView()
    private var timeEnabled  = false

    // イベント種別・カテゴリ
    private let typeSegment  = UISegmentedControl(items: ["👤 顧客紐付き", "📋 一般"])
    private var selectedCategory: EventCategory = .other
    private var categoryButtons: [UIButton] = []

    // 顧客紐付け（将来NeXuSから選択）
    private var linkedCustomerId  : String? = nil
    private var linkedCustomerName: String? = nil
    private let customerBtn = UIButton(type: .system)

    // 時間ピッカー表示管理
    private var timePickerViews: [UIView] = []
    private var timeCardCollapsedConstraint: NSLayoutConstraint?

    // 連日・繰り返し
    private let endDatePicker      = UIDatePicker()
    private var endDateEnabled     = false
    private var endDateViews       : [UIView] = []
    private var endDateCollapsed   : NSLayoutConstraint?
    private var selectedRepeat     : RepeatRule = .none
    private let repeatEndPicker    = UIDatePicker()
    private var repeatEndEnabled   = false
    private var repeatEndViews     : [UIView] = []
    private var repeatButtons      : [UIButton] = []

    // カラー
    private var selectedColor: TaskColor = .blue
    private var colorButtons : [UIButton] = []

    init(task: Task? = nil) {
        self.task      = task ?? Task(title: "", date: Date())
        self.isNewTask = (task == nil)
        super.init(nibName: nil, bundle: nil)
        if let t = task {
            timeEnabled      = t.startTime != nil
            selectedColor    = t.color
            selectedCategory = t.category
            linkedCustomerId   = t.linkedCustomerId
            linkedCustomerName = t.linkedCustomerName
            selectedRepeat   = t.repeatRule
            endDateEnabled   = t.endDate != nil
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .clear
        applyGradientBackground()
        title = task.title.isEmpty ? "予定を追加" : "予定を編集"

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = navAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        navigationController?.navigationBar.tintColor = accentColor

        navigationItem.leftBarButtonItem  = UIBarButtonItem(
            title: "キャンセル", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存", style: .prominent, target: self, action: #selector(saveTapped))
        navigationItem.rightBarButtonItem?.tintColor = accentColor

        buildUI()
        fillFields()

        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    private func applyGradientBackground() {
        let g = CAGradientLayer()
        g.colors = [
            UIColor(red: 0.04, green: 0.09, blue: 0.26, alpha: 1).cgColor,
            UIColor(red: 0.07, green: 0.22, blue: 0.52, alpha: 1).cgColor,
        ]
        g.startPoint = CGPoint(x: 0.2, y: 0); g.endPoint = CGPoint(x: 0.8, y: 1)
        g.frame      = UIScreen.main.bounds
        view.layer.insertSublayer(g, at: 0)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Build UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView); scrollView.addSubview(contentView)

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
        func add(_ v: UIView, top: CGFloat = 16) {
            contentView.addSubview(v); v.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? contentView.topAnchor, constant: top),
                v.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                v.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            ])
            prev = v
        }

        // ── タイトル
        add(sectionLabel("タイトル"), top: 20)
        let titleCard = makeCard()
        titleField.placeholder = "予定のタイトル（必須）"
        titleField.font = .systemFont(ofSize: 16)
        titleField.textColor = .white
        titleField.clearButtonMode = .whileEditing
        titleField.backgroundColor = .clear
        titleField.attributedPlaceholder = NSAttributedString(
            string: "予定のタイトル（必須）",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.40)]
        )
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleCard.addSubview(titleField)
        NSLayoutConstraint.activate([
            titleField.topAnchor.constraint(equalTo: titleCard.topAnchor, constant: 10),
            titleField.bottomAnchor.constraint(equalTo: titleCard.bottomAnchor, constant: -10),
            titleField.leadingAnchor.constraint(equalTo: titleCard.leadingAnchor, constant: 16),
            titleField.trailingAnchor.constraint(equalTo: titleCard.trailingAnchor, constant: -16),
            titleField.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])
        add(titleCard, top: 6)

        // ── イベント種別
        add(sectionLabel("種別"), top: 20)
        typeSegment.selectedSegmentIndex = task.eventType == .customer ? 0 : 1
        typeSegment.selectedSegmentTintColor = accentColor
        typeSegment.addTarget(self, action: #selector(typeChanged), for: .valueChanged)
        typeSegment.translatesAutoresizingMaskIntoConstraints = false
        add(typeSegment, top: 6)

        // ── カテゴリ
        add(sectionLabel("カテゴリ"), top: 16)
        let catGrid = buildCategoryGrid()
        add(catGrid, top: 6)

        // ── 顧客紐付け（種別が「顧客紐付き」の時のみ）
        add(sectionLabel("顧客"), top: 16)
        let customerCard = buildCustomerCard()
        add(customerCard, top: 6)

        // ── 日付
        add(sectionLabel("日付"), top: 20)
        let dateCard = makeCard()
        let dateLbl = UILabel(); dateLbl.text = "日付"; dateLbl.font = .systemFont(ofSize: 16)
        dateLbl.textColor = .white
        dateLbl.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.locale = Locale(identifier: "ja_JP")
        datePicker.tintColor = accentColor
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        dateCard.addSubview(dateLbl); dateCard.addSubview(datePicker)
        NSLayoutConstraint.activate([
            dateLbl.leadingAnchor.constraint(equalTo: dateCard.leadingAnchor, constant: 16),
            dateLbl.centerYAnchor.constraint(equalTo: dateCard.centerYAnchor),
            datePicker.trailingAnchor.constraint(equalTo: dateCard.trailingAnchor, constant: -16),
            datePicker.topAnchor.constraint(equalTo: dateCard.topAnchor, constant: 10),
            datePicker.bottomAnchor.constraint(equalTo: dateCard.bottomAnchor, constant: -10),
        ])
        add(dateCard, top: 6)

        // ── 終了日（連日）
        add(sectionLabel("終了日"), top: 20)
        let endDateCard = buildEndDateCard()
        add(endDateCard, top: 6)

        // ── 繰り返し
        add(sectionLabel("繰り返し"), top: 20)
        let repeatCard = buildRepeatCard()
        add(repeatCard, top: 6)

        // ── 時間
        add(sectionLabel("時間"), top: 20)
        let timeCard = buildTimeCard()
        add(timeCard, top: 6)

        // ── カラー
        add(sectionLabel("カラー"), top: 20)
        let colorCard = buildColorCard()
        add(colorCard, top: 6)

        // ── メモ
        add(sectionLabel("メモ"), top: 20)
        let memoCard = makeCard()
        memoField.font = .systemFont(ofSize: 15)
        memoField.backgroundColor = .clear
        memoField.textColor = .white
        memoField.isScrollEnabled = false
        memoField.translatesAutoresizingMaskIntoConstraints = false
        memoCard.addSubview(memoField)
        NSLayoutConstraint.activate([
            memoField.topAnchor.constraint(equalTo: memoCard.topAnchor, constant: 10),
            memoField.bottomAnchor.constraint(equalTo: memoCard.bottomAnchor, constant: -10),
            memoField.leadingAnchor.constraint(equalTo: memoCard.leadingAnchor, constant: 12),
            memoField.trailingAnchor.constraint(equalTo: memoCard.trailingAnchor, constant: -12),
            memoField.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])
        add(memoCard, top: 6)

        // ── 削除ボタン（編集時のみ）
        if !isNewTask {
            let deleteBtn = UIButton(type: .system)
            deleteBtn.setTitle("この予定を削除", for: .normal)
            deleteBtn.setTitleColor(.white, for: .normal)
            deleteBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            deleteBtn.backgroundColor  = UIColor.systemRed.withAlphaComponent(0.85)
            deleteBtn.layer.cornerRadius = 14
            deleteBtn.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
            add(deleteBtn, top: 32)
            deleteBtn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        }

        prev?.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40).isActive = true
    }

    // MARK: - End Date Card

    private func buildEndDateCard() -> UIView {
        let card = makeCard()

        let sw = UISwitch()
        sw.isOn = endDateEnabled; sw.onTintColor = accentColor
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.addTarget(self, action: #selector(endDateToggle(_:)), for: .valueChanged)

        let swLbl = UILabel(); swLbl.text = "終了日を設定"; swLbl.font = .systemFont(ofSize: 16)
        swLbl.textColor = .white
        swLbl.translatesAutoresizingMaskIntoConstraints = false

        endDatePicker.datePickerMode = .date
        endDatePicker.preferredDatePickerStyle = .compact
        endDatePicker.locale = Locale(identifier: "ja_JP")
        endDatePicker.tintColor = accentColor
        endDatePicker.isHidden = !endDateEnabled
        endDatePicker.translatesAutoresizingMaskIntoConstraints = false

        let sep = UIView(); sep.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.isHidden = !endDateEnabled

        let endLbl = UILabel(); endLbl.text = "終了日"; endLbl.font = .systemFont(ofSize: 15)
        endLbl.textColor = UIColor.white.withAlphaComponent(0.80)
        endLbl.translatesAutoresizingMaskIntoConstraints = false
        endLbl.isHidden = !endDateEnabled

        endDateViews = [sep, endLbl, endDatePicker]
        [swLbl, sw, sep, endLbl, endDatePicker].forEach { card.addSubview($0) }

        let collapsed = swLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        collapsed.isActive = !endDateEnabled
        endDateCollapsed = collapsed

        NSLayoutConstraint.activate([
            swLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            swLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            sw.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            sw.centerYAnchor.constraint(equalTo: swLbl.centerYAnchor),
            sep.topAnchor.constraint(equalTo: swLbl.bottomAnchor, constant: 10),
            sep.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            sep.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
            endLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            endLbl.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 10),
            endLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            endDatePicker.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            endDatePicker.centerYAnchor.constraint(equalTo: endLbl.centerYAnchor),
        ])
        return card
    }

    @objc private func endDateToggle(_ sw: UISwitch) {
        endDateEnabled = sw.isOn
        endDateCollapsed?.isActive = !endDateEnabled
        UIView.animate(withDuration: 0.25) {
            self.endDateViews.forEach { $0.isHidden = !self.endDateEnabled }
            self.scrollView.layoutIfNeeded()
        }
    }

    // MARK: - Repeat Card

    private func buildRepeatCard() -> UIView {
        let card = makeCard()
        let rules: [RepeatRule] = [.none, .daily, .weekly, .monthly, .yearly]
        let stack = UIStackView()
        stack.axis = .horizontal; stack.distribution = .fillEqually; stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for rule in rules {
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.layer.cornerRadius = 8
            btn.layer.borderWidth  = 0.5
            btn.layer.borderColor  = UIColor.separator.cgColor
            btn.titleLabel?.font   = .systemFont(ofSize: 11, weight: .medium)
            btn.setTitle(rule.displayName, for: .normal)
            btn.tag = rules.firstIndex(of: rule) ?? 0
            btn.addTarget(self, action: #selector(repeatTapped(_:)), for: .touchUpInside)
            repeatButtons.append(btn)
            stack.addArrangedSubview(btn)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.heightAnchor.constraint(equalToConstant: 36),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        refreshRepeatButtons()
        return card
    }

    private func refreshRepeatButtons() {
        let rules: [RepeatRule] = [.none, .daily, .weekly, .monthly, .yearly]
        for btn in repeatButtons {
            let rule = rules[btn.tag]
            let sel  = rule == selectedRepeat
            btn.backgroundColor = sel ? accentColor : .secondarySystemGroupedBackground
            btn.setTitleColor(sel ? .white : accentColor, for: .normal)
            btn.layer.borderWidth = sel ? 0 : 0.5
        }
    }

    @objc private func repeatTapped(_ sender: UIButton) {
        let rules: [RepeatRule] = [.none, .daily, .weekly, .monthly, .yearly]
        selectedRepeat = rules[sender.tag]
        refreshRepeatButtons()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Category Grid

    private func buildCategoryGrid() -> UIView {
        let wrap = UIView(); wrap.translatesAutoresizingMaskIntoConstraints = false
        categoryButtons.removeAll()
        updateCategoryGrid(wrap: wrap)
        return wrap
    }

    private func updateCategoryGrid(wrap: UIView) {
        wrap.subviews.forEach { $0.removeFromSuperview() }
        categoryButtons.removeAll()

        let isCustomer = typeSegment.selectedSegmentIndex == 0
        let cats = isCustomer ? EventCategory.customerCategories : EventCategory.generalCategories
        let gap  : CGFloat = 8
        let btnH : CGFloat = 44

        var vPrev: UIView? = nil
        var i = 0
        while i < cats.count {
            let isLast = (i == cats.count - 1) && (cats.count % 2 == 1)
            if isLast {
                let btn = makeCategoryBtn(cats[i])
                btn.heightAnchor.constraint(equalToConstant: btnH).isActive = true
                categoryButtons.append(btn); wrap.addSubview(btn)
                NSLayoutConstraint.activate([
                    btn.topAnchor.constraint(equalTo: vPrev?.bottomAnchor ?? wrap.topAnchor, constant: gap),
                    btn.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
                    btn.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
                    btn.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
                ])
                i += 1
            } else {
                let b1 = makeCategoryBtn(cats[i])
                let b2 = makeCategoryBtn(cats[i + 1])
                [b1, b2].forEach { $0.heightAnchor.constraint(equalToConstant: btnH).isActive = true; categoryButtons.append($0); wrap.addSubview($0) }
                let isLastRow = i + 2 >= cats.count
                NSLayoutConstraint.activate([
                    b1.topAnchor.constraint(equalTo: vPrev?.bottomAnchor ?? wrap.topAnchor, constant: vPrev == nil ? 0 : gap),
                    b1.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
                    b1.trailingAnchor.constraint(equalTo: b2.leadingAnchor, constant: -gap),
                    b2.topAnchor.constraint(equalTo: b1.topAnchor),
                    b2.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
                    b2.widthAnchor.constraint(equalTo: b1.widthAnchor),
                ])
                if isLastRow { b1.bottomAnchor.constraint(equalTo: wrap.bottomAnchor).isActive = true }
                vPrev = b1; i += 2
            }
        }
        refreshCategoryButtons()
    }

    private func makeCategoryBtn(_ cat: EventCategory) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.layer.cornerRadius = 10
        btn.tag = EventCategory.allCases.firstIndex(of: cat) ?? 0

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: cat.icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        config.title = cat.rawValue
        config.imagePadding = 6
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var b = a; b.font = .systemFont(ofSize: 12, weight: .medium); return b
        }
        btn.configuration = config
        btn.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func refreshCategoryButtons() {
        for btn in categoryButtons {
            let cat = EventCategory.allCases[btn.tag]
            let selected = cat == selectedCategory
            btn.backgroundColor = selected ? accentColor : UIColor.white.withAlphaComponent(0.10)
            btn.tintColor       = selected ? .white : accentColor
            var config = btn.configuration
            config?.baseForegroundColor = selected ? .white : accentColor
            btn.configuration = config
            btn.layer.borderWidth = selected ? 0 : 0.5
            btn.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
        }
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        selectedCategory = EventCategory.allCases[sender.tag]
        refreshCategoryButtons()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func typeChanged() {
        // カテゴリグリッドを更新
        if let gridView = categoryButtons.first?.superview {
            updateCategoryGrid(wrap: gridView)
        }
        // 顧客ボタンの表示切替
        customerBtn.isHidden = typeSegment.selectedSegmentIndex != 0
        // デフォルトカテゴリをリセット
        let isCustomer = typeSegment.selectedSegmentIndex == 0
        selectedCategory = isCustomer ? .visit : .meeting
        refreshCategoryButtons()
    }

    // MARK: - Customer Card

    private func buildCustomerCard() -> UIView {
        let card = makeCard()
        let iconIV = UIImageView(image: UIImage(systemName: "person.fill"))
        iconIV.tintColor = accentColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        customerBtn.translatesAutoresizingMaskIntoConstraints = false
        customerBtn.setTitle(linkedCustomerName ?? "顧客を選択（任意）", for: .normal)
        customerBtn.setTitleColor(linkedCustomerName != nil ? .white : UIColor.white.withAlphaComponent(0.40), for: .normal)
        customerBtn.titleLabel?.font = .systemFont(ofSize: 15)
        customerBtn.contentHorizontalAlignment = .left
        customerBtn.addTarget(self, action: #selector(selectCustomer), for: .touchUpInside)
        customerBtn.isHidden = typeSegment.selectedSegmentIndex != 0

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor.white.withAlphaComponent(0.40)
        chevron.translatesAutoresizingMaskIntoConstraints = false

        [iconIV, customerBtn, chevron].forEach { card.addSubview($0) }
        NSLayoutConstraint.activate([
            iconIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconIV.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconIV.widthAnchor.constraint(equalToConstant: 20),

            customerBtn.leadingAnchor.constraint(equalTo: iconIV.trailingAnchor, constant: 10),
            customerBtn.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            customerBtn.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            customerBtn.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 8),
        ])
        return card
    }

    @objc private func selectCustomer() {
        // 将来NeXuS連携実装予定
        // 現在は手入力アラートで代替
        let alert = UIAlertController(title: "顧客名を入力", message: "現在は手動入力です", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "例：田中 太郎"
            tf.text        = self.linkedCustomerName
        }
        alert.addAction(UIAlertAction(title: "クリア", style: .destructive) { [weak self] _ in
            self?.linkedCustomerId   = nil
            self?.linkedCustomerName = nil
            self?.customerBtn.setTitle("顧客を選択（任意）", for: .normal)
            self?.customerBtn.setTitleColor(UIColor.white.withAlphaComponent(0.40), for: .normal)
        })
        alert.addAction(UIAlertAction(title: "設定", style: .default) { [weak self] _ in
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces)
            if let name, !name.isEmpty {
                self?.linkedCustomerName = name
                self?.linkedCustomerId   = UUID().uuidString
                self?.customerBtn.setTitle(name, for: .normal)
                self?.customerBtn.setTitleColor(.white, for: .normal)
            }
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Time Card

    private func buildTimeCard() -> UIView {
        let card = makeCard()

        let sw = UISwitch()
        sw.isOn = timeEnabled; sw.onTintColor = accentColor
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.addTarget(self, action: #selector(timeToggle(_:)), for: .valueChanged)

        let swLbl = UILabel(); swLbl.text = "時間を設定"; swLbl.font = .systemFont(ofSize: 16)
        swLbl.textColor = .white
        swLbl.translatesAutoresizingMaskIntoConstraints = false

        startPicker.datePickerMode = .time
        startPicker.preferredDatePickerStyle = .compact
        startPicker.locale = Locale(identifier: "ja_JP")
        startPicker.tintColor = accentColor
        startPicker.minuteInterval = 30
        startPicker.isHidden = !timeEnabled
        startPicker.translatesAutoresizingMaskIntoConstraints = false

        endPicker.datePickerMode = .time
        endPicker.preferredDatePickerStyle = .compact
        endPicker.locale = Locale(identifier: "ja_JP")
        endPicker.tintColor = accentColor
        endPicker.minuteInterval = 30
        endPicker.isHidden = !timeEnabled
        endPicker.translatesAutoresizingMaskIntoConstraints = false

        let startLbl = UILabel(); startLbl.text = "開始"; startLbl.font = .systemFont(ofSize: 15)
        startLbl.textColor = UIColor.white.withAlphaComponent(0.80)
        startLbl.translatesAutoresizingMaskIntoConstraints = false
        startLbl.isHidden = !timeEnabled

        let endLbl = UILabel(); endLbl.text = "終了"; endLbl.font = .systemFont(ofSize: 15)
        endLbl.textColor = UIColor.white.withAlphaComponent(0.80)
        endLbl.translatesAutoresizingMaskIntoConstraints = false
        endLbl.isHidden = !timeEnabled

        let sep1 = UIView(); sep1.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        let sep2 = UIView(); sep2.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        sep1.translatesAutoresizingMaskIntoConstraints = false
        sep2.translatesAutoresizingMaskIntoConstraints = false
        sep1.isHidden = !timeEnabled; sep2.isHidden = !timeEnabled

        // トグルで表示切替する要素を保持
        timePickerViews = [sep1, startLbl, startPicker, sep2, endLbl, endPicker]

        [swLbl, sw, sep1, startLbl, startPicker, sep2, endLbl, endPicker].forEach { card.addSubview($0) }

        // OFF時：swLblをカード下端に固定する制約（切替用）
        let collapsed = swLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        collapsed.isActive = !timeEnabled
        timeCardCollapsedConstraint = collapsed

        NSLayoutConstraint.activate([
            swLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            swLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),

            sw.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            sw.centerYAnchor.constraint(equalTo: swLbl.centerYAnchor),

            sep1.topAnchor.constraint(equalTo: swLbl.bottomAnchor, constant: 10),
            sep1.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            sep1.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            sep1.heightAnchor.constraint(equalToConstant: 0.5),

            startLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            startLbl.topAnchor.constraint(equalTo: sep1.bottomAnchor, constant: 10),

            startPicker.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            startPicker.centerYAnchor.constraint(equalTo: startLbl.centerYAnchor),

            sep2.topAnchor.constraint(equalTo: startLbl.bottomAnchor, constant: 10),
            sep2.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            sep2.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            sep2.heightAnchor.constraint(equalToConstant: 0.5),

            endLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            endLbl.topAnchor.constraint(equalTo: sep2.bottomAnchor, constant: 10),
            endLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            endPicker.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            endPicker.centerYAnchor.constraint(equalTo: endLbl.centerYAnchor),
        ])

        return card
    }

    @objc private func timeToggle(_ sw: UISwitch) {
        timeEnabled = sw.isOn
        // OFF時のカード高さ固定制約を切替
        timeCardCollapsedConstraint?.isActive = !timeEnabled
        UIView.animate(withDuration: 0.25) {
            self.timePickerViews.forEach { $0.isHidden = !self.timeEnabled }
            self.scrollView.layoutIfNeeded()
        }
    }

    // MARK: - Color Card

    private func buildColorCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView(); stack.axis = .horizontal
        stack.distribution = .fillEqually; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for color in TaskColor.allCases {
            let btn = UIButton()
            btn.backgroundColor    = color.uiColor
            btn.layer.cornerRadius = 18
            btn.tag = TaskColor.allCases.firstIndex(of: color) ?? 0
            btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
            btn.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            colorButtons.append(btn); stack.addArrangedSubview(btn)
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        refreshColorButtons()
        return card
    }

    private func refreshColorButtons() {
        for btn in colorButtons {
            let color = TaskColor.allCases[btn.tag]
            let sel   = color == selectedColor
            btn.layer.borderWidth = sel ? 3 : 0
            btn.layer.borderColor = UIColor.label.withAlphaComponent(0.4).cgColor
            btn.transform = sel ? CGAffineTransform(scaleX: 1.15, y: 1.15) : .identity
        }
    }

    @objc private func colorTapped(_ sender: UIButton) {
        selectedColor = TaskColor.allCases[sender.tag]
        refreshColorButtons()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Fill Fields

    private func fillFields() {
        titleField.text   = task.title
        datePicker.date   = task.date.isSameDay(as: Date()) ? defaultDate : task.date
        memoField.text    = task.memo
        typeSegment.selectedSegmentIndex = task.eventType == .customer ? 0 : 1

        if let st = task.startTime { startPicker.date = st }
        if let et = task.endTime   { endPicker.date   = et }

        // 連日
        if let ed = task.endDate {
            endDatePicker.date = ed
        } else {
            endDatePicker.date = datePicker.date.adding(days: 1)
        }

        // 繰り返し
        selectedRepeat = task.repeatRule
        refreshRepeatButtons()

        // ドラッグで作成した場合の時間プリセット
        if let st = defaultStartTime {
            timeEnabled = true
            startPicker.date = st
            endPicker.date   = defaultEndTime ?? st.addingTimeInterval(3600)
            timePickerViews.forEach { $0.isHidden = false }
            timeCardCollapsedConstraint?.isActive = false
        }
    }

    // MARK: - Keyboard

    @objc private func keyboardChanged(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        let inset = max(0, view.bounds.height - frame.origin.y)
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = inset + 16
            self.scrollView.verticalScrollIndicatorInsets.bottom = inset + 16
        }
    }

    // MARK: - Save / Cancel

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func deleteTapped() {
        let alert = UIAlertController(title: "予定を削除しますか？",
                                      message: task.title,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "削除", style: .destructive) { [weak self] _ in
            guard let self else { return }
            TaskStore.shared.delete(self.task)
            self.onDelete?()
            self.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func saveTapped() {
        guard let title = titleField.text, !title.isEmpty else {
            shake(titleField); return
        }
        task.title               = title
        task.date                = datePicker.date
        task.memo                = memoField.text ?? ""
        task.color               = selectedColor
        task.eventType           = typeSegment.selectedSegmentIndex == 0 ? .customer : .general
        task.category            = selectedCategory
        task.linkedCustomerId    = typeSegment.selectedSegmentIndex == 0 ? linkedCustomerId : nil
        task.linkedCustomerName  = typeSegment.selectedSegmentIndex == 0 ? linkedCustomerName : nil
        task.startTime           = timeEnabled ? startPicker.date : nil
        task.endTime             = timeEnabled ? endPicker.date : nil
        task.endDate             = endDateEnabled ? endDatePicker.date : nil
        task.repeatRule          = selectedRepeat

        onSave?(task)
        dismiss(animated: true)
    }

    private func shake(_ v: UIView) {
        let a = CAKeyframeAnimation(keyPath: "transform.translation.x")
        a.values = [-8,8,-6,6,-4,4,0]; a.duration = 0.4
        v.layer.add(a, forKey: "shake")
    }

    // MARK: - Helpers

    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor    = UIColor.white.withAlphaComponent(0.10)
        v.layer.cornerRadius = 14
        v.layer.borderWidth  = 0.5
        v.layer.borderColor  = UIColor.white.withAlphaComponent(0.20).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let l = UILabel(); l.text = text.uppercased()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.55)
        l.translatesAutoresizingMaskIntoConstraints = false; return l
    }
}
