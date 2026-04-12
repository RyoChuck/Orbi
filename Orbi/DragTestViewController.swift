import UIKit

// MARK: - DragTestViewController
// このファイル単体でドラッグ動作を確認するためのテスト画面
// SceneDelegateで rootViewController = DragTestViewController() に変えて確認する

final class DragTestViewController: UIViewController {

    // テスト用タスク（日付インデックス: タスク名の配列）
    private var tasksByDay: [Int: [String]] = [
        0: ["朝の会議", "書類提出"],
        2: ["お客様訪問"],
        4: ["報告書作成", "電話対応"],
        6: ["週次レビュー"]
    ]

    private let columns   = 7
    private let dayNames  = ["月","火","水","木","金","土","日"]
    private var cellSize  : CGSize = .zero

    // ドラッグ状態
    private var dragSourceDay : Int?
    private var dragTaskIndex : Int?
    private var dragFloating  : UIView?
    private var dragOffset    : CGPoint = .zero

    // UI
    private var grid          : UIView!
    private var dayViews      : [UIView] = []
    private var taskLabel     : UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "ドラッグテスト"
        buildGrid()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutDayViews()
        renderTasks()
    }

    // MARK: - Grid

    private func buildGrid() {
        // グリッドコンテナ
        grid = UIView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grid)

        // 説明ラベル
        taskLabel = UILabel()
        taskLabel.text = "イベントを長押し→ドラッグで移動"
        taskLabel.font = .systemFont(ofSize: 13)
        taskLabel.textColor = .secondaryLabel
        taskLabel.textAlignment = .center
        taskLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(taskLabel)

        NSLayoutConstraint.activate([
            taskLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            taskLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            grid.topAnchor.constraint(equalTo: taskLabel.bottomAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            grid.heightAnchor.constraint(equalTo: grid.widthAnchor, multiplier: 0.6),
        ])

        // 7列の日ビュー
        for i in 0..<columns {
            let dv = makeDayView(index: i)
            grid.addSubview(dv)
            dayViews.append(dv)
        }

        // ロングプレスをグリッドに1つだけ
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLP(_:)))
        lp.minimumPressDuration = 0.3
        lp.allowableMovement    = .greatestFiniteMagnitude
        grid.addGestureRecognizer(lp)
    }

    private func makeDayView(index: Int) -> UIView {
        let v = UIView()
        v.backgroundColor = .secondarySystemGroupedBackground
        v.layer.cornerRadius = 10
        v.layer.borderWidth  = 1
        v.layer.borderColor  = UIColor.separator.withAlphaComponent(0.3).cgColor
        v.tag = index

        let nameL = UILabel()
        nameL.text = dayNames[index]
        nameL.font = .systemFont(ofSize: 12, weight: .semibold)
        nameL.textColor = index == 5
            ? UIColor(red:0.2,green:0.5,blue:0.95,alpha:1)
            : index == 6
            ? UIColor(red:0.9,green:0.28,blue:0.28,alpha:1)
            : .secondaryLabel
        nameL.textAlignment = .center
        nameL.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(nameL)

        NSLayoutConstraint.activate([
            nameL.topAnchor.constraint(equalTo: v.topAnchor, constant: 8),
            nameL.centerXAnchor.constraint(equalTo: v.centerXAnchor),
        ])
        return v
    }

    private func layoutDayViews() {
        let w = grid.bounds.width / CGFloat(columns)
        let h = grid.bounds.height
        cellSize = CGSize(width: w, height: h)
        for (i, dv) in dayViews.enumerated() {
            dv.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h)
        }
    }

    private func renderTasks() {
        // 既存のタスクチップをすべて削除
        for dv in dayViews {
            dv.subviews.compactMap { $0 as? UILabel }.forEach { $0.removeFromSuperview() }
        }
        // タスクを描画
        let colors: [UIColor] = [
            .systemBlue, .systemGreen, .systemOrange,
            .systemPurple, .systemRed, .systemTeal
        ]
        for (day, tasks) in tasksByDay {
            guard day < dayViews.count else { continue }
            let dv = dayViews[day]
            for (i, name) in tasks.enumerated() {
                let chip = makeChip(name: name, color: colors[i % colors.count])
                chip.tag = i * 100 + day  // タスクインデックス * 100 + 日インデックス
                dv.addSubview(chip)
                let topOffset = 36 + CGFloat(i) * 26
                chip.frame = CGRect(x: 4, y: topOffset, width: dv.bounds.width - 8, height: 22)
            }
        }
    }

    private func makeChip(name: String, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = name
        l.font = .systemFont(ofSize: 9, weight: .medium)
        l.textColor = .white
        l.backgroundColor = color.withAlphaComponent(0.85)
        l.layer.cornerRadius = 4
        l.clipsToBounds = true
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.7
        return l
    }

    // MARK: - Long Press Drag

    @objc private func handleLP(_ g: UILongPressGestureRecognizer) {
        let pt = g.location(in: grid)

        switch g.state {
        case .began:
            // タッチ位置の日インデックスを取得
            let dayIdx = Int(pt.x / cellSize.width)
            guard dayIdx >= 0, dayIdx < columns else { return }

            // その日のチップを探す
            let dv = dayViews[dayIdx]
            let localPt = g.location(in: dv)
            guard let chip = dv.subviews.compactMap({ $0 as? UILabel })
                                        .first(where: { $0.frame.contains(localPt) }) else { return }

            let taskIdx = (chip.tag - dayIdx) / 100
            dragSourceDay = dayIdx
            dragTaskIndex = taskIdx

            // フローティングスナップショット
            let snap = UILabel()
            snap.text = chip.text
            snap.font = chip.font
            snap.textColor = chip.textColor
            snap.backgroundColor = chip.backgroundColor
            snap.layer.cornerRadius = 6
            snap.clipsToBounds = true
            snap.textAlignment = .center
            let chipInGrid = dv.convert(chip.frame, to: grid)
            snap.frame = chipInGrid
            snap.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            snap.alpha = 0.9
            snap.layer.shadowOpacity = 0.3
            snap.layer.shadowRadius  = 8
            snap.layer.shadowOffset  = CGSize(width: 0, height: 4)
            snap.clipsToBounds = false
            grid.addSubview(snap)
            dragFloating = snap
            dragOffset = CGPoint(x: pt.x - chipInGrid.midX, y: pt.y - chipInGrid.midY)

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // 元のチップを薄く
            chip.alpha = 0.3

        case .changed:
            guard let snap = dragFloating else { return }
            snap.center = CGPoint(x: pt.x - dragOffset.x, y: pt.y - dragOffset.y)

            // ターゲット日をハイライト
            let targetDay = Int(pt.x / cellSize.width)
            for (i, dv) in dayViews.enumerated() {
                UIView.animate(withDuration: 0.1) {
                    dv.backgroundColor = (i == targetDay && i != self.dragSourceDay)
                        ? UIColor.systemBlue.withAlphaComponent(0.15)
                        : .secondarySystemGroupedBackground
                }
            }

        case .ended:
            let targetDay = Int(pt.x / cellSize.width)

            // フローティングを消す
            UIView.animate(withDuration: 0.2, animations: {
                self.dragFloating?.alpha = 0
                self.dragFloating?.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { _ in
                self.dragFloating?.removeFromSuperview()
                self.dragFloating = nil
            }

            // ハイライトを戻す
            dayViews.forEach { $0.backgroundColor = .secondarySystemGroupedBackground }

            // タスクを移動
            guard let src = dragSourceDay,
                  let idx = dragTaskIndex,
                  targetDay >= 0, targetDay < columns,
                  targetDay != src else {
                // 元に戻す
                dayViews[dragSourceDay ?? 0].subviews
                    .compactMap { $0 as? UILabel }.forEach { $0.alpha = 1 }
                dragSourceDay = nil; dragTaskIndex = nil; return
            }

            // データ更新
            if var tasks = tasksByDay[src], idx < tasks.count {
                let moved = tasks.remove(at: idx)
                tasksByDay[src] = tasks.isEmpty ? nil : tasks
                var dest = tasksByDay[targetDay] ?? []
                dest.append(moved)
                tasksByDay[targetDay] = dest
            }

            dragSourceDay = nil; dragTaskIndex = nil
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            renderTasks()

        case .cancelled:
            dragFloating?.removeFromSuperview(); dragFloating = nil
            dayViews.forEach { $0.backgroundColor = .secondarySystemGroupedBackground }
            dayViews[dragSourceDay ?? 0].subviews
                .compactMap { $0 as? UILabel }.forEach { $0.alpha = 1 }
            dragSourceDay = nil; dragTaskIndex = nil

        default: break
        }
    }
}
