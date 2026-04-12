import UIKit

// MARK: - TaskDetailViewController

final class TaskDetailViewController: UIViewController {

    private var task: Task
    var onUpdate: ((Task) -> Void)?
    var onDelete: (() -> Void)?

    private let accentColor = UIColor(red: 0.26, green: 0.54, blue: 0.96, alpha: 1)
    private let scrollView  = UIScrollView()
    private let contentView = UIView()
    private let colorBar    = UIView()
    private let titleL      = UILabel()
    private let timeL       = UILabel()
    private let dateL       = UILabel()
    private let divider     = UIView()
    private let memoTitle   = UILabel()
    private let memoView    = UITextView()
    private let completeBtn = UIButton(type: .system)

    // MARK: Init

    init(task: Task) {
        self.task = task
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "タスク詳細"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "pencil"),
            style: .plain, target: self, action: #selector(editTapped))
        navigationItem.rightBarButtonItem?.tintColor = accentColor

        let deleteBtn = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain, target: self, action: #selector(deleteTapped))
        deleteBtn.tintColor = .systemRed
        navigationItem.leftBarButtonItem = deleteBtn

        buildUI()
        populate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // メモを自動保存
        saveMemo()
    }

    // MARK: Build UI

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

        // カラーバー付きヘッダーカード
        let headerCard = UIView()
        headerCard.backgroundColor = .secondarySystemGroupedBackground
        headerCard.layer.cornerRadius = 14
        headerCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerCard)

        colorBar.layer.cornerRadius = 3
        colorBar.translatesAutoresizingMaskIntoConstraints = false

        titleL.font          = .systemFont(ofSize: 20, weight: .semibold)
        titleL.textColor     = .label
        titleL.numberOfLines = 0
        titleL.translatesAutoresizingMaskIntoConstraints = false

        timeL.font      = .systemFont(ofSize: 14)
        timeL.textColor = .secondaryLabel
        timeL.translatesAutoresizingMaskIntoConstraints = false

        dateL.font      = .systemFont(ofSize: 13)
        dateL.textColor = .tertiaryLabel
        dateL.translatesAutoresizingMaskIntoConstraints = false

        [colorBar, titleL, timeL, dateL].forEach { headerCard.addSubview($0) }

        NSLayoutConstraint.activate([
            headerCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            colorBar.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor),
            colorBar.topAnchor.constraint(equalTo: headerCard.topAnchor),
            colorBar.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor),
            colorBar.widthAnchor.constraint(equalToConstant: 6),

            titleL.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 16),
            titleL.leadingAnchor.constraint(equalTo: colorBar.trailingAnchor, constant: 14),
            titleL.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -16),

            timeL.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 8),
            timeL.leadingAnchor.constraint(equalTo: titleL.leadingAnchor),

            dateL.topAnchor.constraint(equalTo: timeL.bottomAnchor, constant: 4),
            dateL.leadingAnchor.constraint(equalTo: titleL.leadingAnchor),
            dateL.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -16),
        ])

        // 完了ボタン
        completeBtn.layer.cornerRadius = 12
        completeBtn.titleLabel?.font   = .systemFont(ofSize: 15, weight: .semibold)
        completeBtn.translatesAutoresizingMaskIntoConstraints = false
        completeBtn.addTarget(self, action: #selector(completeTapped), for: .touchUpInside)
        contentView.addSubview(completeBtn)

        NSLayoutConstraint.activate([
            completeBtn.topAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: 12),
            completeBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            completeBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            completeBtn.heightAnchor.constraint(equalToConstant: 48),
        ])

        // メモカード
        let memoCard = UIView()
        memoCard.backgroundColor  = .secondarySystemGroupedBackground
        memoCard.layer.cornerRadius = 14
        memoCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(memoCard)

        memoTitle.text      = "メモ"
        memoTitle.font      = .systemFont(ofSize: 13, weight: .semibold)
        memoTitle.textColor = .secondaryLabel
        memoTitle.translatesAutoresizingMaskIntoConstraints = false

        memoView.font             = .systemFont(ofSize: 15)
        memoView.backgroundColor  = .clear
        memoView.isScrollEnabled  = false
        memoView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        memoView.translatesAutoresizingMaskIntoConstraints = false
        memoView.delegate         = self

        [memoTitle, memoView].forEach { memoCard.addSubview($0) }
        NSLayoutConstraint.activate([
            memoCard.topAnchor.constraint(equalTo: completeBtn.bottomAnchor, constant: 24),
            memoCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            memoCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            memoCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),

            memoTitle.topAnchor.constraint(equalTo: memoCard.topAnchor, constant: 14),
            memoTitle.leadingAnchor.constraint(equalTo: memoCard.leadingAnchor, constant: 16),

            memoView.topAnchor.constraint(equalTo: memoTitle.bottomAnchor, constant: 8),
            memoView.leadingAnchor.constraint(equalTo: memoCard.leadingAnchor, constant: 12),
            memoView.trailingAnchor.constraint(equalTo: memoCard.trailingAnchor, constant: -12),
            memoView.bottomAnchor.constraint(equalTo: memoCard.bottomAnchor, constant: -14),
            memoView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])

        // キーボード対応
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    // MARK: Populate

    private func populate() {
        colorBar.backgroundColor = task.color.uiColor
        titleL.text = task.title

        let df = DateFormatter()
        df.locale     = Locale(identifier: "ja_JP")
        df.dateFormat = "M月d日（E）"
        dateL.text = df.string(from: task.date)

        let tf = DateFormatter()
        tf.dateFormat = "H:mm"
        if let start = task.startTime {
            let startStr = tf.string(from: start)
            if let end = task.endTime {
                timeL.text = "🕐 \(startStr) 〜 \(tf.string(from: end))"
            } else {
                timeL.text = "🕐 \(startStr)"
            }
        } else {
            timeL.text = "終日"
        }

        memoView.text = task.memo.isEmpty ? "" : task.memo
        if task.memo.isEmpty {
            memoView.text = "ここにメモを入力..."
            memoView.textColor = .placeholderText
        } else {
            memoView.text  = task.memo
            memoView.textColor = .label
        }

        updateCompleteButton()
    }

    private func updateCompleteButton() {
        if task.isCompleted {
            completeBtn.setTitle("✓  完了済み　　未完了に戻す", for: .normal)
            completeBtn.backgroundColor = UIColor.systemGray5
            completeBtn.setTitleColor(.secondaryLabel, for: .normal)
        } else {
            completeBtn.setTitle("完了にする", for: .normal)
            completeBtn.backgroundColor = task.color.uiColor
            completeBtn.setTitleColor(.white, for: .normal)
        }
    }

    // MARK: Actions

    @objc private func completeTapped() {
        task.isCompleted.toggle()
        TaskStore.shared.update(task)
        onUpdate?(task)
        UIView.animate(withDuration: 0.2) { self.updateCompleteButton() }
    }

    @objc private func editTapped() {
        let vc = TaskEditViewController()
        vc.task = task
        vc.onSave = { [weak self] updated in
            guard let self else { return }
            self.task = updated
            TaskStore.shared.update(updated)
            self.onUpdate?(updated)
            self.populate()
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    @objc private func deleteTapped() {
        let alert = UIAlertController(title: "タスクを削除しますか？",
                                      message: task.title,
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "削除", style: .destructive) { [weak self] _ in
            guard let self else { return }
            TaskStore.shared.delete(self.task)
            self.onDelete?()
            self.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        present(alert, animated: true)
    }

    private func saveMemo() {
        let text = memoView.textColor == .placeholderText ? "" : (memoView.text ?? "")
        guard text != task.memo else { return }
        task.memo = text
        TaskStore.shared.update(task)
        onUpdate?(task)
    }

    @objc private func keyboardChanged(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let inset = max(0, view.bounds.height - frame.origin.y)
        scrollView.contentInset.bottom = inset + 20
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITextViewDelegate

extension TaskDetailViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .placeholderText {
            textView.text      = ""
            textView.textColor = .label
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text      = "ここにメモを入力..."
            textView.textColor = .placeholderText
        }
        saveMemo()
    }
}
