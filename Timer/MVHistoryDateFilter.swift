import Foundation

/// 历史记录的日期区间筛选：按最外层（主时钟）那条记录的起始时间筛。
/// `start` 是含在内的第一天 00:00，`end` 是不含的区间末端（最后一日的次日 00:00），
/// 这样「某一天」就是一个自然日，不用到处写 23:59:59，跨夏令时也安全
struct MVHistoryDateFilter: Codable, Equatable, Sendable {
  var start: Date
  var end: Date

  // MARK: - 构造

  init(start: Date, end: Date) {
    self.start = start
    self.end = end
  }

  /// 单个自然日：那天 00:00 到次日 00:00
  init(day: Date, calendar: Calendar = .current) {
    let beginning = calendar.startOfDay(for: day)
    self.init(
      start: beginning,
      end: calendar.date(byAdding: .day, value: 1, to: beginning) ?? beginning
    )
  }

  /// 月历里点出来的起止两天（都含），顺序反了也能用
  init(startDay: Date, endDay: Date, calendar: Calendar = .current) {
    let first = calendar.startOfDay(for: startDay)
    let second = calendar.startOfDay(for: endDay)
    let lower = min(first, second)
    let upper = max(first, second)
    self.init(start: lower, end: calendar.date(byAdding: .day, value: 1, to: upper) ?? upper)
  }

  // MARK: - 预设

  static func today(calendar: Calendar = .current, now: Date = Date()) -> Self {
    Self(day: now, calendar: calendar)
  }

  static func yesterday(calendar: Calendar = .current, now: Date = Date()) -> Self {
    let today = calendar.startOfDay(for: now)
    return Self(day: calendar.date(byAdding: .day, value: -1, to: today) ?? today, calendar: calendar)
  }

  /// 含今天在内的最近 count 天
  static func lastDays(_ count: Int, calendar: Calendar = .current, now: Date = Date()) -> Self {
    let today = calendar.startOfDay(for: now)
    let first = calendar.date(byAdding: .day, value: -(count - 1), to: today) ?? today
    return Self(
      start: first,
      end: calendar.date(byAdding: .day, value: 1, to: today) ?? today
    )
  }

  // MARK: - 判定与展示

  func contains(_ date: Date) -> Bool {
    date >= self.start && date < self.end
  }

  /// 区间里的最后一天（含）；用来把区间回填给月历
  var lastDay: Date {
    Calendar.current.date(byAdding: .day, value: -1, to: self.end) ?? self.start
  }

  var displayText: String {
    let calendar = Calendar.current
    if calendar.isDate(self.start, inSameDayAs: self.lastDay) {
      return Self.dayText(self.start)
    }
    return "\(Self.dayText(self.start)) – \(Self.dayText(self.lastDay))"
  }

  /// 同年就只写月日，跨年才带上年份，免得标题太长
  private static func dayText(_ date: Date) -> String {
    let calendar = Calendar.current
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    guard let month = parts.month, let day = parts.day else { return "" }

    if let year = parts.year, year != calendar.component(.year, from: Date()) {
      return "\(year)年\(month)月\(day)日"
    }
    return "\(month)月\(day)日"
  }
}

/// 筛选区间存在 UserDefaults 里：关掉历史窗口再打开还是上次那个区间；存 nil 就是「全部记录」
enum MVHistoryFilterStore {
  static func load(from defaults: UserDefaults = .standard) -> MVHistoryDateFilter? {
    guard let data = defaults.data(forKey: MVUserDefaultsKeys.historyDateFilter) else { return nil }
    return try? JSONDecoder().decode(MVHistoryDateFilter.self, from: data)
  }

  static func save(_ filter: MVHistoryDateFilter?, to defaults: UserDefaults = .standard) {
    guard let filter else {
      defaults.removeObject(forKey: MVUserDefaultsKeys.historyDateFilter)
      return
    }
    guard let data = try? JSONEncoder().encode(filter) else { return }
    defaults.set(data, forKey: MVUserDefaultsKeys.historyDateFilter)
  }
}
