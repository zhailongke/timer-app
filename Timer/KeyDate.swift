import Foundation

/// 关键日子：一个名字 + 一个日期（例如「考研 12 月 19 日」），表盘上显示还有多少天
struct KeyDate: Codable, Equatable, Identifiable, Sendable {
  var id: UUID
  var title: String
  /// 当天 0 点：存的时候归一过，天数按自然日算，不受具体时刻与夏令时影响
  var date: Date

  init(title: String, date: Date, id: UUID = UUID(), calendar: Calendar = .current) {
    self.title = title
    self.date = calendar.startOfDay(for: date)
    self.id = id
  }

  private enum CodingKeys: String, CodingKey {
    case date, id, title
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.title = try container.decode(String.self, forKey: .title)
    let date = try container.decode(Date.self, forKey: .date)
    self.date = Calendar.current.startOfDay(for: date)
  }
}

/// 关键日子存在 UserDefaults 里；改完会发通知，表盘上的倒计时立刻跟着变
enum MVKeyDateStore {
  static let didChangeNotification = Notification.Name("MVKeyDateStoreDidChange")

  static func load(from defaults: UserDefaults = .standard) -> [KeyDate] {
    guard let data = defaults.data(forKey: MVUserDefaultsKeys.keyDates),
      let dates = try? JSONDecoder().decode([KeyDate].self, from: data)
    else { return [] }
    return dates
  }

  static func save(_ dates: [KeyDate], to defaults: UserDefaults = .standard) {
    guard let data = try? JSONEncoder().encode(dates) else { return }
    defaults.set(data, forKey: MVUserDefaultsKeys.keyDates)
    NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
  }

  static func add(_ date: KeyDate, to defaults: UserDefaults = .standard) {
    var dates = Self.load(from: defaults)
    dates.append(date)
    Self.save(dates, to: defaults)
  }

  /// 按 id 覆盖：管理窗口里改名、改日期都用它
  static func update(_ date: KeyDate, to defaults: UserDefaults = .standard) {
    var dates = Self.load(from: defaults)
    if let index = dates.firstIndex(where: { $0.id == date.id }) {
      dates[index] = date
    } else {
      dates.append(date)
    }
    Self.save(dates, to: defaults)
  }

  static func remove(id: UUID, from defaults: UserDefaults = .standard) {
    Self.save(Self.load(from: defaults).filter { $0.id != id }, to: defaults)
  }
}

/// 倒计时怎么算、怎么排版
enum MVKeyDateCountdown {
  /// 表盘下沿放得下的条数；再多只显示最近的前几条
  static let maxLines = 3

  /// 相差的自然日天数：今天 0，明天 1，已经过了是负数
  static func days(to date: Date, from now: Date = Date(), calendar: Calendar = .current) -> Int {
    let components = calendar.dateComponents(
      [.day],
      from: calendar.startOfDay(for: now),
      to: calendar.startOfDay(for: date)
    )
    return components.day ?? 0
  }

  /// 还没过完的日子，按「还有几天」从小到大排：先显示日历上最近的那个
  static func upcoming(
    from dates: [KeyDate],
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> [(keyDate: KeyDate, days: Int)] {
    let items = dates.map { (keyDate: $0, days: Self.days(to: $0.date, from: now, calendar: calendar)) }
    let upcoming = items
      .filter { $0.days >= 0 }
      .sorted { $0.days == $1.days ? $0.keyDate.date < $1.keyDate.date : $0.days < $1.days }
    return Array(upcoming.prefix(Self.maxLines))
  }

  /// 天数怎么念：今天 / 已过 / 55 天
  static func daysText(_ days: Int) -> String {
    if days == 0 { return "今天" }
    if days < 0 { return "已过" }
    return "\(days) 天"
  }

  /// 表盘上那一行：字号小、地方窄，名字过长会被截断
  static func line(title: String, days: Int) -> String {
    if days == 0 { return "\(title) 今天" }
    if days < 0 { return "\(title) 已过" }
    return "\(title) \(days)天"
  }
}
