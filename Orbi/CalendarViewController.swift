import UIKit

// MARK: - CalendarViewController

final class CalendarViewController: UIViewController {

    // MARK: - State
    private var selectedDate  = Date()
    private var displayMonth  = Date()
    private var weekStartDate = Date()
    private var monthDays     : [(date: Date, isCurrentMonth: Bool)] = []
    private var weekDates     : [Date] = []

    // Timeline
    private var tlDate        : Date?
    private let tlHourH       : CGFloat = 60
    private let tlLblW        : CGFloat = 44
    private let tlStartHour   = 9
    private let tlEndHour     = 18
    private var tlHalfH       : CGFloat { tlHourH / 2 }
    private var tlGridH       : CGFloat { tlHourH * CGFloat(tlEndHour - tlStartHour) }
    private var tlSV          : UIScrollView?
    private var tlCV          : UIView?
    private var tlTimedTasks  : [Task] = []

    // Month chip drag
    private var chipDragTask  : Task?
    private var chipDragFloat : UIView?
    private var chipDragOffset: CGPoint = .zero

    // Timeline drag
    private var tlDragTask    : Task?
    private var tlDragFloat   : UIView?
    private var tlDragOffset  : CGPoint = .zero
    private var tlInsertLine  : UIView?
    private var tlDragging    = false

    // Timeline resize
    private var tlResizeTask  : Task?
    private var tlResizeBlock : UIView?
    private var tlResizeOrigH : CGFloat = 0

    private let store         = TaskStore.shared
    private let accent        = UIColor(red: 0.26, green: 0.54, blue: 0.96, alpha: 1)

    // MARK: - UI
    private let segment       = UISegmentedControl(items: ["月","週","日"])
    private let headerView    = UIView()
    private let monthLabel    = UILabel()
    private let prevBtn       = UIButton(type: .system)
    private let nextBtn       = UIButton(type: .system)
    private let wdHeader      = UIStackView()
    private var calCV         : UICollectionView!
    private var weekCV        : UICollectionView!
    private let tlContainer   = UIView()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "スケジュール"
        buildCollections()
        buildUI()
        setupNav()
        reload()
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged),
                                               name: .taskStoreDidChange, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup
    private func setupNav() {
        navigationItem.titleView = segment
        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(segChanged), for: .valueChanged)
        let add = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain,
                                  target: self, action: #selector(addTask))
        add.tintColor = accent
        navigationItem.rightBarButtonItem = add
        calCV.canCancelContentTouches = false
    }

    private func buildCollections() {
        let ml = UICollectionViewFlowLayout()
        ml.minimumInteritemSpacing = 0; ml.minimumLineSpacing = 0
        calCV = UICollectionView(frame: .zero, collectionViewLayout: ml)
        calCV.translatesAutoresizingMaskIntoConstraints = false
        calCV.backgroundColor = .clear; calCV.isScrollEnabled = false; calCV.tag = 1
        calCV.register(DayCell.self, forCellWithReuseIdentifier: DayCell.id)
        calCV.dataSource = self; calCV.delegate = self

        let wl = UICollectionViewFlowLayout()
        wl.scrollDirection = .horizontal
        wl.minimumInteritemSpacing = 0; wl.minimumLineSpacing = 0
        weekCV = UICollectionView(frame: .zero, collectionViewLayout: wl)
        weekCV.translatesAutoresizingMaskIntoConstraints = false
        weekCV.backgroundColor = .clear; weekCV.isScrollEnabled = false; weekCV.tag = 2
        weekCV.register(WeekDayCell.self, forCellWithReuseIdentifier: WeekDayCell.id)
        weekCV.dataSource = self; weekCV.delegate = self
    }

    private func buildUI() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .secondarySystemGroupedBackground

        prevBtn.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        prevBtn.tintColor = accent; prevBtn.translatesAutoresizingMaskIntoConstraints = false
        prevBtn.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)

        nextBtn.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextBtn.tintColor = accent; nextBtn.translatesAutoresizingMaskIntoConstraints = false
        nextBtn.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        monthLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        monthLabel.textAlignment = .center; monthLabel.translatesAutoresizingMaskIntoConstraints = false

        let todayBtn = UIButton(type: .system)
        todayBtn.setTitle("今日", for: .normal); todayBtn.tintColor = accent
        todayBtn.titleLabel?.font = .systemFont(ofSize: 13)
        todayBtn.translatesAutoresizingMaskIntoConstraints = false
        todayBtn.addTarget(self, action: #selector(goToday), for: .touchUpInside)

        [prevBtn, monthLabel, nextBtn, todayBtn].forEach { headerView.addSubview($0) }

        wdHeader.axis = .horizontal; wdHeader.distribution = .fillEqually
        wdHeader.translatesAutoresizingMaskIntoConstraints = false
        let wdNames = ["月","火","水","木","金","土","日"]
        for (i,d) in wdNames.enumerated() {
            let l = UILabel(); l.text = d; l.textAlignment = .center; l.font = .systemFont(ofSize: 12)
            l.textColor = i==5 ? accent : i==6 ? UIColor(red:0.9,green:0.28,blue:0.28,alpha:1) : .secondaryLabel
            wdHeader.addArrangedSubview(l)
        }

        tlContainer.translatesAutoresizingMaskIntoConstraints = false
        tlContainer.backgroundColor = .systemBackground
        tlContainer.isHidden = true
        weekCV.isHidden = true

        [headerView, wdHeader, calCV, weekCV, tlContainer].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),

            prevBtn.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            prevBtn.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            monthLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            monthLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            nextBtn.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            nextBtn.trailingAnchor.constraint(equalTo: todayBtn.leadingAnchor, constant: -8),
            todayBtn.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            todayBtn.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            wdHeader.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 4),
            wdHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wdHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wdHeader.heightAnchor.constraint(equalToConstant: 20),

            calCV.topAnchor.constraint(equalTo: wdHeader.bottomAnchor, constant: 4),
            calCV.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            calCV.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            calCV.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            weekCV.topAnchor.constraint(equalTo: wdHeader.bottomAnchor, constant: 4),
            weekCV.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            weekCV.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            weekCV.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            tlContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tlContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tlContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tlContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
    }

    // MARK: - Data
    private func reload() {
        let cal   = Calendar.current
        let start = displayMonth.startOfMonth
        let off   = start.dayOfWeek
        monthDays = (0..<42).map { i in
            let d = start.adding(days: i - off)
            return (d, cal.isDate(d, equalTo: displayMonth, toGranularity: .month))
        }
        weekStartDate = selectedDate.adding(days: -selectedDate.dayOfWeek)
        weekDates = (0..<7).map { weekStartDate.adding(days: $0) }

        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "yyyy年 M月"
        if segment.selectedSegmentIndex == 0 { monthLabel.text = f.string(from: displayMonth) }
        else if segment.selectedSegmentIndex == 1 { monthLabel.text = f.string(from: weekStartDate) }
        calCV.reloadData(); weekCV.reloadData()
    }

    // MARK: - Segment / Nav
    @objc private func segChanged() {
        let idx = segment.selectedSegmentIndex
        UIView.animate(withDuration: 0.2) {
            self.calCV.isHidden       = (idx != 0)
            self.weekCV.isHidden      = (idx != 1)
            self.wdHeader.isHidden    = (idx == 2)
            self.tlContainer.isHidden = (idx != 2)
        }
        if idx == 2 { buildTimeline(for: selectedDate) }
        else { reload() }
    }

    @objc private func prevTapped() {
        switch segment.selectedSegmentIndex {
        case 0: displayMonth = displayMonth.adding(months: -1); reload()
        case 1:
            weekStartDate = weekStartDate.adding(days: -7)
            selectedDate = weekStartDate; displayMonth = selectedDate.startOfMonth; reload()
        default:
            selectedDate = selectedDate.adding(days: -1); buildTimeline(for: selectedDate)
        }
    }

    @objc private func nextTapped() {
        switch segment.selectedSegmentIndex {
        case 0: displayMonth = displayMonth.adding(months: 1); reload()
        case 1:
            weekStartDate = weekStartDate.adding(days: 7)
            selectedDate = weekStartDate; displayMonth = selectedDate.startOfMonth; reload()
        default:
            selectedDate = selectedDate.adding(days: 1); buildTimeline(for: selectedDate)
        }
    }

    @objc private func goToday() {
        selectedDate = Date(); displayMonth = Date().startOfMonth; reload()
        if segment.selectedSegmentIndex == 2 { buildTimeline(for: selectedDate) }
    }

    @objc private func addTask() { addTaskFor(selectedDate) }
    @objc private func storeChanged() {
        reload()
        if segment.selectedSegmentIndex == 2, let d = tlDate { buildTimeline(for: d) }
    }

    private func addTaskFor(_ date: Date) {
        let vc = TaskEditViewController()
        vc.defaultDate = date
        vc.onSave = { [weak self] task in
            TaskStore.shared.add(task)
            self?.reload()
            if self?.segment.selectedSegmentIndex == 2 { self?.buildTimeline(for: date) }
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sh = nav.sheetPresentationController { sh.detents = [.large()]; sh.prefersGrabberVisible = true }
        present(nav, animated: true)
    }

    private func openDetail(_ task: Task) {
        let vc = TaskDetailViewController(task: task)
        vc.onUpdate = { [weak self] _ in
            self?.reload()
            if self?.segment.selectedSegmentIndex == 2, let d = self?.tlDate { self?.buildTimeline(for: d) }
        }
        vc.onDelete = { [weak self] in
            self?.reload()
            if self?.segment.selectedSegmentIndex == 2, let d = self?.tlDate { self?.buildTimeline(for: d) }
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sh = nav.sheetPresentationController { sh.detents = [.medium(),.large()]; sh.prefersGrabberVisible = true }
        present(nav, animated: true)
    }

    // MARK: - Month Chip Drag

    private func handleChipDrag(task: Task, gesture g: UILongPressGestureRecognizer) {
        let ptInView  = g.location(in: view)
        let ptInCalCV = g.location(in: calCV)

        switch g.state {
        case .began:
            chipDragTask = task
            guard let chip = g.view else { return }
            let chipInView = chip.convert(chip.bounds, to: view)
            let snap = UIView(frame: chipInView)
            snap.backgroundColor    = task.color.uiColor.withAlphaComponent(0.85)
            snap.layer.cornerRadius = 4
            snap.transform          = CGAffineTransform(scaleX: 1.12, y: 1.12)
            snap.alpha              = 0.88
            snap.layer.shadowOpacity = 0.25; snap.layer.shadowRadius = 8
            snap.layer.shadowOffset  = CGSize(width: 0, height: 4)
            let tl = UILabel(frame: CGRect(x: 4, y: 2, width: chipInView.width - 8, height: 14))
            tl.text = task.title; tl.font = .systemFont(ofSize: 9, weight: .semibold); tl.textColor = .white
            snap.addSubview(tl)
            view.addSubview(snap)
            chipDragFloat  = snap
            chipDragOffset = CGPoint(x: ptInView.x - chipInView.midX, y: ptInView.y - chipInView.midY)
            chip.alpha = 0.2
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        case .changed:
            guard let snap = chipDragFloat else { return }
            snap.center = CGPoint(x: ptInView.x - chipDragOffset.x, y: ptInView.y - chipDragOffset.y)
            calCV.visibleCells.forEach { $0.contentView.backgroundColor = .clear }
            if let ip = calCV.indexPathForItem(at: ptInCalCV) {
                calCV.cellForItem(at: ip)?.contentView.backgroundColor = accent.withAlphaComponent(0.12)
            }

        case .ended:
            g.view?.alpha = 1
            calCV.visibleCells.forEach { $0.contentView.backgroundColor = .clear }
            UIView.animate(withDuration: 0.2, animations: {
                self.chipDragFloat?.alpha = 0
            }) { _ in self.chipDragFloat?.removeFromSuperview(); self.chipDragFloat = nil }

            guard var movedTask = chipDragTask,
                  let ip = calCV.indexPathForItem(at: ptInCalCV) else {
                chipDragTask = nil; return
            }
            let targetDate = monthDays[ip.item].date
            if !targetDate.isSameDay(as: movedTask.date) {
                let cal = Calendar.current
                var tc  = cal.dateComponents([.year,.month,.day], from: targetDate)
                let dc  = cal.dateComponents([.hour,.minute], from: movedTask.date)
                tc.hour = dc.hour; tc.minute = dc.minute
                if let newDate = cal.date(from: tc) {
                    let diff = newDate.timeIntervalSince(movedTask.date)
                    movedTask.date = newDate
                    if let st = movedTask.startTime { movedTask.startTime = st.addingTimeInterval(diff) }
                    if let et = movedTask.endTime   { movedTask.endTime   = et.addingTimeInterval(diff) }
                    TaskStore.shared.update(movedTask)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    reload()
                }
            }
            chipDragTask = nil

        case .cancelled:
            g.view?.alpha = 1
            calCV.visibleCells.forEach { $0.contentView.backgroundColor = .clear }
            chipDragFloat?.removeFromSuperview(); chipDragFloat = nil; chipDragTask = nil

        default: break
        }
    }

    @objc private func chipDrag(_ g: UILongPressGestureRecognizer) {}

    // MARK: - Timeline Build

    private func buildTimeline(for date: Date) {
        tlDate = date
        tlContainer.subviews.forEach { $0.removeFromSuperview() }
        tlDragging = false; tlDragTask = nil; tlDragFloat = nil
        tlResizeTask = nil; tlResizeBlock = nil

        let sw = view.bounds.width > 0 ? view.bounds.width : 390

        let sv = UIScrollView(frame: tlContainer.bounds)
        sv.autoresizingMask    = [.flexibleWidth, .flexibleHeight]
        sv.contentSize         = CGSize(width: sw, height: tlGridH + 20)
        sv.backgroundColor     = .systemBackground
        sv.showsVerticalScrollIndicator = true
        sv.canCancelContentTouches      = false
        sv.delaysContentTouches         = false
        tlContainer.addSubview(sv)
        tlSV = sv

        let cv = UIView(frame: CGRect(x: 0, y: 0, width: sw, height: tlGridH + 20))
        cv.backgroundColor = .systemBackground
        sv.addSubview(cv)
        tlCV = cv

        // グリッド線
        for i in 0...(tlEndHour - tlStartHour) {
            let y = CGFloat(i) * tlHourH + 10
            let lbl = UILabel(frame: CGRect(x: 0, y: y - 8, width: tlLblW - 4, height: 16))
            lbl.text = String(format: "%02d:00", tlStartHour + i)
            lbl.font = .systemFont(ofSize: 9); lbl.textColor = .tertiaryLabel; lbl.textAlignment = .right
            cv.addSubview(lbl)

            let line = UIView(frame: CGRect(x: tlLblW, y: y, width: sw - tlLblW - 8, height: 0.5))
            line.backgroundColor = UIColor.separator.withAlphaComponent(i == 0 || i == tlEndHour - tlStartHour ? 0.4 : 0.2)
            cv.addSubview(line)

            if i < tlEndHour - tlStartHour {
                let half = UIView(frame: CGRect(x: tlLblW, y: y + tlHourH/2, width: sw - tlLblW - 8, height: 0.5))
                half.backgroundColor = UIColor.separator.withAlphaComponent(0.1)
                cv.addSubview(half)
            }
        }

        // 現在時刻ライン
        if date.isSameDay(as: Date()) {
            let cal = Calendar.current
            let h   = cal.component(.hour, from: Date())
            let m   = cal.component(.minute, from: Date())
            let y   = CGFloat(h - tlStartHour) * tlHourH + CGFloat(m) / 60.0 * tlHourH + 10
            if y >= 10 && y <= tlGridH + 10 {
                let dot = UIView(frame: CGRect(x: tlLblW - 4, y: y - 4, width: 8, height: 8))
                dot.backgroundColor = .systemRed; dot.layer.cornerRadius = 4
                cv.addSubview(dot)
                let rl = UIView(frame: CGRect(x: tlLblW + 4, y: y - 0.75, width: sw - tlLblW - 12, height: 1.5))
                rl.backgroundColor = .systemRed; cv.addSubview(rl)
            }
        }

        // イベントブロック
        let tasks  = store.tasks(for: date).filter { $0.startTime != nil }
        tlTimedTasks = tasks
        let gridW  = sw - tlLblW - 12
        let cal    = Calendar.current

        for (i, task) in tasks.enumerated() {
            guard let start = task.startTime else { continue }
            let sh   = cal.component(.hour, from: start)
            let sm   = cal.component(.minute, from: start)
            let sy   = CGFloat(sh - tlStartHour) * tlHourH + CGFloat(sm) / 60.0 * tlHourH + 10

            var blkH : CGFloat = tlHourH
            if let end = task.endTime {
                let eh = cal.component(.hour, from: end)
                let em = cal.component(.minute, from: end)
                let ey = CGFloat(eh - tlStartHour) * tlHourH + CGFloat(em) / 60.0 * tlHourH + 10
                blkH   = max(tlHalfH, ey - sy)
            }

            // ブロック
            let block = UIView(frame: CGRect(x: tlLblW + 2, y: sy, width: gridW, height: blkH))
            block.backgroundColor    = task.color.uiColor.withAlphaComponent(0.15)
            block.layer.cornerRadius = 6
            block.layer.borderWidth  = 1.5
            block.layer.borderColor  = task.color.uiColor.withAlphaComponent(0.6).cgColor
            block.clipsToBounds      = true
            block.tag                = i

            let bar = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: Int(blkH)))
            bar.backgroundColor = task.color.uiColor; block.addSubview(bar)

            let titleL = UILabel(frame: CGRect(x: 8, y: 4, width: Int(gridW) - 14, height: 16))
            titleL.text = task.title; titleL.font = .systemFont(ofSize: 12, weight: .semibold)
            titleL.textColor = task.color.uiColor.darker(by: 0.3); block.addSubview(titleL)

            let tf = DateFormatter(); tf.dateFormat = "H:mm"
            let timeStr = task.endTime.map { "\(tf.string(from: start)) 〜 \(tf.string(from: $0))" }
                        ?? tf.string(from: start)
            let timeL = UILabel(frame: CGRect(x: 8, y: 20, width: Int(gridW) - 14, height: 14))
            timeL.text = timeStr; timeL.font = .systemFont(ofSize: 10)
            timeL.textColor = task.color.uiColor.darker(by: 0.15); timeL.tag = 999
            block.addSubview(timeL)

            // リサイズハンドル
            let handle = TLResizeHandle(frame: CGRect(x: 0, y: blkH - 14, width: gridW, height: 14))
            handle.taskIndex = i
            let resizePan = UIPanGestureRecognizer(target: self, action: #selector(tlResize(_:)))
            resizePan.delegate = self
            handle.addGestureRecognizer(resizePan)
            block.addSubview(handle)

            // ロングプレスとリサイズはcvに追加（最後にまとめて）
            cv.addSubview(block)
        }

        // LP を cv に1つだけ追加（DragTestと同じ方式）
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(tlLP(_:)))
        lp.minimumPressDuration = 0.3
        lp.allowableMovement    = .greatestFiniteMagnitude
        lp.delegate             = self
        cv.addGestureRecognizer(lp)

        // 日付ヘッダー
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "yyyy年 M月d日（E）"
        monthLabel.text = f.string(from: date)

        // スクロール位置
        let h = cal.component(.hour, from: date.isSameDay(as: Date()) ? Date() : date)
        let targetH = max(tlStartHour, min(tlEndHour - 1, h))
        sv.setContentOffset(CGPoint(x: 0, y: max(0, CGFloat(targetH - tlStartHour - 1) * tlHourH)), animated: false)
    }

    // MARK: - Timeline Long Press (移動)

    @objc private func tlLP(_ g: UILongPressGestureRecognizer) {
        guard let sv = tlSV, let cv = tlCV else { return }
        let ptInCV   = g.location(in: cv)
        let ptInView = g.location(in: view)

        switch g.state {
        case .began:
            // タッチ位置のブロックを探す（リサイズハンドル以外）
            guard let hit  = cv.hitTest(ptInCV, with: nil),
                  !(hit is TLResizeHandle) else { return }

            // ブロック（直接の親がcvであるUIView）を特定
            var target: UIView? = hit
            while let t = target, t.superview !== cv { target = t.superview }
            guard let block = target, !(block is TLResizeHandle),
                  block.tag >= 0, block.tag < tlTimedTasks.count else { return }

            tlDragging = true
            tlDragTask = tlTimedTasks[block.tag]

            let blockInView = cv.convert(block.frame, to: view)
            let snap = UIView(frame: blockInView)
            snap.backgroundColor    = tlTimedTasks[block.tag].color.uiColor.withAlphaComponent(0.85)
            snap.layer.cornerRadius = 6
            snap.alpha              = 0.85
            snap.transform          = CGAffineTransform(scaleX: 1.03, y: 1.03)
            snap.layer.shadowOpacity = 0.25; snap.layer.shadowRadius = 8
            snap.layer.shadowOffset  = CGSize(width: 0, height: 4)
            let tl = UILabel(frame: CGRect(x: 8, y: 8, width: snap.frame.width - 16, height: 16))
            tl.text = tlTimedTasks[block.tag].title
            tl.font = .systemFont(ofSize: 12, weight: .semibold); tl.textColor = .white
            snap.addSubview(tl)
            view.addSubview(snap)
            tlDragFloat = snap
            tlDragOffset = CGPoint(x: ptInView.x - blockInView.midX, y: ptInView.y - blockInView.midY)
            block.alpha = 0.2
            sv.isScrollEnabled = false
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        case .changed:
            guard tlDragging, let snap = tlDragFloat else { return }
            snap.center = CGPoint(x: ptInView.x - tlDragOffset.x, y: ptInView.y - tlDragOffset.y)
            showTLInsertLine(at: ptInView, sv: sv)

            let ptInSV = g.location(in: sv)
            if ptInSV.y < 70 { sv.contentOffset.y = max(0, sv.contentOffset.y - 5) }
            else if ptInSV.y > sv.frame.height - 70 {
                sv.contentOffset.y = min(sv.contentSize.height - sv.frame.height, sv.contentOffset.y + 5)
            }

        case .ended, .cancelled:
            tlInsertLine?.removeFromSuperview(); tlInsertLine = nil
            UIView.animate(withDuration: 0.15, animations: {
                self.tlDragFloat?.alpha = 0; self.tlDragFloat?.transform = .identity
            }) { _ in self.tlDragFloat?.removeFromSuperview(); self.tlDragFloat = nil }

            if g.state == .ended, var task = tlDragTask {
                let ptInSV  = g.location(in: sv)
                let localY  = ptInSV.y + sv.contentOffset.y - 10
                let newStart = snapToTime(y: localY, date: task.startTime ?? tlDate ?? Date())
                let dur = task.endTime.flatMap { et -> TimeInterval? in
                    guard let st = task.startTime else { return nil }
                    return et.timeIntervalSince(st)
                }
                // 重複チェック
                let others = tlTimedTasks.filter { $0.id != task.id }
                let cal    = Calendar.current
                let conflict = others.contains { other in
                    guard let os = other.startTime else { return false }
                    return cal.component(.hour, from: os) == cal.component(.hour, from: newStart)
                        && cal.component(.minute, from: os) == cal.component(.minute, from: newStart)
                }
                if !conflict {
                    task.startTime = newStart
                    task.endTime   = dur.map { newStart.addingTimeInterval($0) }
                    TaskStore.shared.update(task)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
            sv.isScrollEnabled = true
            tlDragging = false; tlDragTask = nil
            buildTimeline(for: tlDate ?? selectedDate)

        default: break
        }
    }

    private func showTLInsertLine(at ptInView: CGPoint, sv: UIScrollView) {
        tlInsertLine?.removeFromSuperview()
        let ptInSV   = view.convert(ptInView, to: sv)
        let localY   = ptInSV.y + sv.contentOffset.y - 10
        let snappedY = (localY / tlHalfH).rounded() * tlHalfH
        let lineY    = sv.frame.minY + snappedY - sv.contentOffset.y + 10
        let line     = UIView(frame: CGRect(x: tlLblW, y: lineY - 1.5,
                                            width: sv.frame.width - tlLblW - 8, height: 3))
        line.backgroundColor    = accent
        line.layer.cornerRadius = 1.5
        view.addSubview(line)
        tlInsertLine = line
    }

    private func snapToTime(y: CGFloat, date: Date) -> Date {
        let totalMin  = Int((y / tlHalfH).rounded()) * 30 + tlStartHour * 60
        let clamped   = max(tlStartHour * 60, min((tlEndHour - 1) * 60 + 30, totalMin))
        let cal       = Calendar.current
        var comps     = cal.dateComponents([.year,.month,.day], from: tlDate ?? date)
        comps.hour    = clamped / 60
        comps.minute  = clamped % 60
        return cal.date(from: comps) ?? date
    }

    // MARK: - Timeline Resize

    @objc private func tlResize(_ g: UIPanGestureRecognizer) {
        guard let handle = g.view as? TLResizeHandle,
              let block  = handle.superview,
              let sv     = tlSV else { return }
        let idx = handle.taskIndex

        switch g.state {
        case .began:
            guard idx < tlTimedTasks.count else { return }
            sv.isScrollEnabled = false
            tlResizeTask  = tlTimedTasks[idx]
            tlResizeBlock = block
            tlResizeOrigH = block.frame.height
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        case .changed:
            guard let resizeBlock = tlResizeBlock else { return }
            let dy    = g.translation(in: block.superview).y
            let newH  = max(tlHalfH, tlResizeOrigH + dy)
            resizeBlock.frame.size.height = newH
            handle.frame.origin.y         = newH - 14
            block.subviews.compactMap { $0 as? UIView }.filter { $0.tag == 0 }.forEach {
                $0.frame.size.height = newH
            }

            // 時刻ラベルを更新
            if let task = tlResizeTask, let st = task.startTime {
                let cal       = Calendar.current
                let startTotalMin = cal.component(.hour, from: st) * 60 + cal.component(.minute, from: st)
                let endMin    = Int((newH / tlHalfH).rounded()) * 30 + startTotalMin
                let clamped   = max(startTotalMin + 30, min(tlEndHour * 60, endMin))
                let tf = DateFormatter(); tf.dateFormat = "H:mm"
                var endComps  = cal.dateComponents([.year,.month,.day], from: tlDate ?? st)
                endComps.hour = clamped / 60; endComps.minute = clamped % 60
                if let newEnd = cal.date(from: endComps) {
                    block.subviews.compactMap { $0 as? UILabel }.filter { $0.tag == 999 }.first?.text
                        = "\(tf.string(from: st)) 〜 \(tf.string(from: newEnd))"
                }
            }

        case .ended, .cancelled:
            guard var task = tlResizeTask, let block = tlResizeBlock,
                  let st   = task.startTime else {
                sv.isScrollEnabled = true; tlResizeTask = nil; tlResizeBlock = nil; return
            }
            let startTotalMin = Calendar.current.component(.hour, from: st) * 60
                              + Calendar.current.component(.minute, from: st)
            let endMin    = Int((block.frame.height / tlHalfH).rounded()) * 30 + startTotalMin
            let clamped   = max(startTotalMin + 30, min(tlEndHour * 60, endMin))
            var endComps  = Calendar.current.dateComponents([.year,.month,.day], from: tlDate ?? st)
            endComps.hour = clamped / 60; endComps.minute = clamped % 60
            task.endTime  = Calendar.current.date(from: endComps)
            TaskStore.shared.update(task)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            sv.isScrollEnabled = true; tlResizeTask = nil; tlResizeBlock = nil
            buildTimeline(for: tlDate ?? selectedDate)

        default: break
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension CalendarViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool {
        if g is UIPanGestureRecognizer { return false }
        return !tlDragging
    }
}

// MARK: - UICollectionView
extension CalendarViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int {
        cv.tag == 1 ? monthDays.count : 7
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        if cv.tag == 1 {
            let cell = cv.dequeueReusableCell(withReuseIdentifier: DayCell.id, for: ip) as! DayCell
            let item = monthDays[ip.item]
            let day  = Calendar.current.component(.day, from: item.date)
            cell.configure(day: day,
                           isToday: item.date.isSameDay(as: Date()),
                           isSelected: item.date.isSameDay(as: selectedDate),
                           isCurrentMonth: item.isCurrentMonth,
                           tasks: store.hasTask(on: item.date),
                           dayOfWeek: item.date.dayOfWeek)
            cell.onTaskTapped = { [weak self] task in self?.openDetail(task) }
            cell.onTaskDrag   = { [weak self] task, gesture in
                self?.handleChipDrag(task: task, gesture: gesture)
            }
            return cell
        } else {
            let cell = cv.dequeueReusableCell(withReuseIdentifier: WeekDayCell.id, for: ip) as! WeekDayCell
            cell.configure(date: weekDates[ip.item],
                           isSelected: weekDates[ip.item].isSameDay(as: selectedDate))
            return cell
        }
    }

    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAt ip: IndexPath) -> CGSize {
        let w = cv.bounds.width / 7
        return cv.tag == 1 ? CGSize(width: w, height: cv.bounds.height / 6)
                           : CGSize(width: w, height: cv.bounds.height)
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        if cv.tag == 1 {
            let tapped = monthDays[ip.item].date
            if tapped.isSameDay(as: selectedDate) { addTaskFor(selectedDate) }
            else {
                selectedDate = tapped
                if !monthDays[ip.item].isCurrentMonth { displayMonth = selectedDate.startOfMonth }
                reload()
            }
        } else {
            let tapped = weekDates[ip.item]
            if tapped.isSameDay(as: selectedDate) { addTaskFor(selectedDate) }
            else { selectedDate = tapped; cv.reloadData() }
        }
    }
}

// MARK: - TLResizeHandle

final class TLResizeHandle: UIView {
    var taskIndex: Int = 0
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.2)
        let bar = UIView()
        bar.backgroundColor    = UIColor.white.withAlphaComponent(0.8)
        bar.layer.cornerRadius = 1.5
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        NSLayoutConstraint.activate([
            bar.centerXAnchor.constraint(equalTo: centerXAnchor),
            bar.centerYAnchor.constraint(equalTo: centerYAnchor),
            bar.widthAnchor.constraint(equalToConstant: 28),
            bar.heightAnchor.constraint(equalToConstant: 3),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}
