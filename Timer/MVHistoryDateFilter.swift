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

/// 存下来的筛选偏好：`range` 为 nil 表示用户选了「全部记录」，
/// 整个偏好不存在（第一次打开）时取 `default`
struct MVHistoryFilterPreference: Codable, Equatable, Sendable {
  var range: MVHistoryDateFilter?

  private enum CodingKeys: String, CodingKey {
    case range
  }

  init(range: MVHistoryDateFilter?) {
    self.range = range
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.range = try container.decodeIfPresent(MVHistoryDateFilter.self, forKey: .range)
  }

  /// 没有区间也要把 range 写成 null：省略的话，「全部记录」和「从没存过」在存档里就分不开了
  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.range, forKey: .range)
  }

  /// 第一次打开只看今天，免得一进来先看到一堆旧记录
  static let `default` = Self(range: .today())
}

/// 筛选区间存在 UserDefaults 里：关掉历史窗口再打开还是上次那个区间（含「全部记录」）
enum MVHistoryFilterStore {
  static func load(from defaults: UserDefaults = .standard) -> MVHistoryFilterPreference {
    guard let data = defaults.data(forKey: MVUserDefaultsKeys.historyDateFilter),
      let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      // 更早的版本直接存的是区间本身，没有 range 这一层：那种数据当没存过，回到默认区间
      payload.keys.contains("range"),
      let preference = try? JSONDecoder().decode(MVHistoryFilterPreference.self, from: data)
    else { return .default }

    return preference
  }

  static func save(_ filter: MVHistoryDateFilter?, to defaults: UserDefaults = .standard) {
    let preference = MVHistoryFilterPreference(range: filter)
    guard let data = try? JSONEncoder().encode(preference) else { return }
    defaults.set(data, forKey: MVUserDefaultsKeys.historyDateFilter)
  }
}
