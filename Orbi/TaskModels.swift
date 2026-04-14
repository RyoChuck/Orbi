import UIKit

// MARK: - Task Color

enum TaskColor: String, CaseIterable, Codable {
    case blue   = "blue"
    case green  = "green"
    case orange = "orange"
    case red    = "red"
    case purple = "purple"
    case yellow = "yellow"

    var uiColor: UIColor {
        switch self {
        case .blue:   return UIColor(red: 0.26, green: 0.54, blue: 0.96, alpha: 1)
        case .green:  return UIColor(red: 0.20, green: 0.73, blue: 0.47, alpha: 1)
        case .orange: return UIColor(red: 1.00, green: 0.58, blue: 0.20, alpha: 1)
        case .red:    return UIColor(red: 0.95, green: 0.32, blue: 0.32, alpha: 1)
        case .purple: return UIColor(red: 0.60, green: 0.40, blue: 0.95, alpha: 1)
        case .yellow: return UIColor(red: 0.98, green: 0.78, blue: 0.10, alpha: 1)
        }
    }

    var displayName: String {
        switch self {
        case .blue:   return "ブルー"
        case .green:  return "グリーン"
        case .orange: return "オレンジ"
        case .red:    return "レッド"
        case .purple: return "パープル"
        case .yellow: return "イエロー"
        }
    }
}

// MARK: - Event Type（顧客紐付き / 一般）

enum EventType: String, Codable {
    case customer = "customer"  // 顧客紐付き（Orbi↔NeXuS）
    case general  = "general"   // 一般（顧客紐付きなし）
}

// MARK: - Event Category

enum EventCategory: String, CaseIterable, Codable {
    // 顧客紐付き系
    case visit       = "訪問"
    case call        = "電話・Web"
    case proposal    = "提案"
    case contract    = "契約手続き"
    case followUp    = "フォロー"

    // 一般系
    case meeting     = "会議・打合せ"
    case training    = "研修・勉強会"
    case admin       = "事務作業"
    case personal    = "プライベート"
    case other       = "その他"

    var icon: String {
        switch self {
        case .visit:    return "figure.walk"
        case .call:     return "phone.fill"
        case .proposal: return "doc.text.fill"
        case .contract: return "signature"
        case .followUp: return "heart.fill"
        case .meeting:  return "person.3.fill"
        case .training: return "book.fill"
        case .admin:    return "tray.fill"
        case .personal: return "house.fill"
        case .other:    return "ellipsis.circle.fill"
        }
    }

    var isCustomerCategory: Bool {
        switch self {
        case .visit, .call, .proposal, .contract, .followUp: return true
        default: return false
        }
    }

    static var customerCategories: [EventCategory] {
        allCases.filter { $0.isCustomerCategory }
    }
    static var generalCategories: [EventCategory] {
        allCases.filter { !$0.isCustomerCategory }
    }
}

// MARK: - Task Model

struct Task: Codable, Equatable {
    var id                 : UUID
    var title              : String
    var date               : Date
    var startTime          : Date?
    var endTime            : Date?
    var memo               : String
    var color              : TaskColor
    var isCompleted        : Bool

    // イベント種別・カテゴリ・顧客紐付き
    var eventType          : EventType      = .general
    var category           : EventCategory  = .other
    var linkedCustomerId   : String?        = nil
    var linkedCustomerName : String?        = nil

    init(title: String, date: Date, startTime: Date? = nil, endTime: Date? = nil,
         memo: String = "", color: TaskColor = .blue,
         eventType: EventType = .general, category: EventCategory = .other,
         linkedCustomerId: String? = nil, linkedCustomerName: String? = nil) {
        self.id                  = UUID()
        self.title               = title
        self.date                = date
        self.startTime           = startTime
        self.endTime             = endTime
        self.memo                = memo
        self.color               = color
        self.isCompleted         = false
        self.eventType           = eventType
        self.category            = category
        self.linkedCustomerId    = linkedCustomerId
        self.linkedCustomerName  = linkedCustomerName
    }

    var isCustomerLinked: Bool {
        eventType == .customer && linkedCustomerId != nil
    }

    var dayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    var subtitle: String {
        var parts: [String] = [category.rawValue]
        if let name = linkedCustomerName { parts.append(name) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - TaskStore

final class TaskStore {
    static let shared = TaskStore()
    private let key = "EMG.TaskApp.tasks"
    private(set) var tasks: [Task] = []

    private init() { load() }

    func add(_ task: Task)    { tasks.append(task); save() }

    func update(_ task: Task) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task; save()
    }

    func delete(_ task: Task) {
        tasks.removeAll { $0.id == task.id }; save()
    }

    func toggleComplete(_ task: Task) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted.toggle(); save()
    }

    func tasks(for date: Date) -> [Task] {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let key = f.string(from: date)
        return tasks.filter { $0.dayKey == key }
            .sorted {
                let a = $0.startTime ?? $0.date
                let b = $1.startTime ?? $1.date
                return a < b
            }
    }

    func hasTask(on date: Date) -> [Task] { tasks(for: date) }

    // 顧客に紐付いたタスクを取得（将来のNeXuS連携用）
    func tasks(forCustomerId id: String) -> [Task] {
        tasks.filter { $0.linkedCustomerId == id }.sorted { $0.date < $1.date }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: .taskStoreDidChange, object: nil)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Task].self, from: data) else { return }
        tasks = decoded
    }
}

extension Notification.Name {
    static let taskStoreDidChange = Notification.Name("TaskStoreDidChange")
}

// MARK: - Date Helpers

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self)!
    }

    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self)!
    }

    var dayOfWeek: Int {
        let w = Calendar.current.component(.weekday, from: self)
        return (w + 5) % 7
    }

    var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: self)!.count
    }
}
