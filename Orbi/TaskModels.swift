import UIKit

// MARK: - Repeat Rule

enum RepeatRule: String, Codable, CaseIterable {
    case none    = "none"
    case daily   = "daily"
    case weekly  = "weekly"
    case monthly = "monthly"
    case yearly  = "yearly"

    var displayName: String {
        switch self {
        case .none:    return "繰り返しなし"
        case .daily:   return "毎日"
        case .weekly:  return "毎週"
        case .monthly: return "毎月"
        case .yearly:  return "毎年"
        }
    }
}

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

    // 連日・繰り返し
    var endDate            : Date?          = nil
    var repeatRule         : RepeatRule     = .none
    var repeatEndDate      : Date?          = nil

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
        let cal     = Calendar.current
        let dayStart = date.startOfDay
        return tasks.filter { task in
            let taskStart = task.date.startOfDay
            // 直接の日付一致
            if taskStart == dayStart { return true }
            // 連日スパン
            if let ed = task.endDate, dayStart > taskStart && dayStart <= ed.startOfDay { return true }
            // 繰り返し
            if task.repeatRule != .none && dayStart > taskStart {
                if let re = task.repeatEndDate, dayStart > re.startOfDay { return false }
                switch task.repeatRule {
                case .none:    return false
                case .daily:   return true
                case .weekly:
                    return cal.component(.weekday, from: date) == cal.component(.weekday, from: task.date)
                case .monthly:
                    return cal.component(.day, from: date) == cal.component(.day, from: task.date)
                case .yearly:
                    return cal.component(.month, from: date) == cal.component(.month, from: task.date)
                        && cal.component(.day, from: date) == cal.component(.day, from: task.date)
                }
            }
            return false
        }
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

// MARK: - Japanese Holiday Calendar

struct JapaneseHolidayCalendar {

    static func isHoliday(_ date: Date) -> Bool {
        holidays(for: Calendar.current.component(.year, from: date)).contains(date.startOfDay)
    }

    static func holidays(for year: Int) -> Set<Date> {
        var dates: Set<Date> = []
        func d(_ m: Int, _ day: Int) -> Date? { date(year: year, month: m, day: day) }
        func monday(_ m: Int, _ week: Int) -> Date? { nthWeekday(2, week: week, month: m, year: year) }

        // 固定祝日
        let fixed: [(Int,Int)] = [
            (1,1),(2,11),(2,23),(4,29),(5,3),(5,4),(5,5),(8,11),(11,3),(11,23)
        ]
        for (m,day) in fixed { if let dt = d(m, day) { dates.insert(dt) } }

        // ハッピーマンデー
        if let dt = monday(1, 2)  { dates.insert(dt) }  // 成人の日
        if let dt = monday(7, 3)  { dates.insert(dt) }  // 海の日
        if let dt = monday(9, 3)  { dates.insert(dt) }  // 敬老の日
        if let dt = monday(10, 2) { dates.insert(dt) }  // スポーツの日

        // 春分の日・秋分の日（近似式）
        let y = Double(year)
        let shunbun = Int(20.8431 + 0.242194 * (y - 1980) - floor((y - 1980) / 4))
        let shubun  = Int(23.2488 + 0.242194 * (y - 1980) - floor((y - 1980) / 4))
        if let dt = d(3, shunbun) { dates.insert(dt) }
        if let dt = d(9, shubun)  { dates.insert(dt) }

        // 振替休日（日曜日の翌月曜日）
        var substitutes: Set<Date> = []
        let cal = Calendar.current
        for dt in dates {
            if cal.component(.weekday, from: dt) == 1 { // 日曜
                if let mon = cal.date(byAdding: .day, value: 1, to: dt) {
                    substitutes.insert(mon.startOfDay)
                }
            }
        }
        dates.formUnion(substitutes)

        return dates
    }

    private static func date(year: Int, month: Int, day: Int) -> Date? {
        var c = DateComponents(); c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c)?.startOfDay
    }

    private static func nthWeekday(_ weekday: Int, week: Int, month: Int, year: Int) -> Date? {
        var c = DateComponents()
        c.year = year; c.month = month; c.weekday = weekday; c.weekdayOrdinal = week
        return Calendar.current.date(from: c)?.startOfDay
    }
}
