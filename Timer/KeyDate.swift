import Foundation

/// 关键日子：一个名字 + 一个日期（例如「考研 12 月 19 日」），表盘上显示还有多久
struct KeyDate: Codable, Equatable, Identifiable, Sendable {
  var id: UUID
  var title: String
  /// 没指定时刻时是当天 0 点，指定了就是精确到分的那一刻（秒归零）
  var date: Date
  /// 有没有指定具体时刻：指定了倒计时才算到小时分钟，否则只算到天
  var hasTime: Bool

  init(
    title: String,
    date: Date,
    id: UUID = UUID(),
    hasTime: Bool = false,
    calendar: Calendar = .current
  ) {
    self.title = title
    self.id = id
    self.hasTime = hasTime
    self.date = Self.normalized(date, hasTime: hasTime, calendar: calendar)
  }

  /// 只算到天的日子归一到当天 0 点：天数按自然日算，不受具体时刻与夏令时影响。
  /// 指定了时刻的只把秒抹掉，免得界面上出现「3分」「4分」来回跳
  static func normalized(_ date: Date, hasTime: Bool, calendar: Calendar) -> Date {
    guard hasTime else { return calendar.startOfDay(for: date) }
    return calendar.date(bySetting: .second, value: 0, of: date) ?? date
  }

  private enum CodingKeys: String, CodingKey {
    case date, hasTime, id, title
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.title = try container.decode(String.self, forKey: .title)
    // 老版本存的日子没有这个字段：当它没指定时刻，行为跟以前一样
    self.hasTime = try container.decodeIfPresent(Bool.self, forKey: .hasTime) ?? false
    let date = try container.decode(Date.self, forKey: .date)
    self.date = Self.normalized(date, hasTime: self.hasTime, calendar: .current)
  }
}

/// 距离某个日子还剩多久
struct MVKeyDateRemaining: Equatable {
  /// 整天的部分。没指定时刻时是自然日天数，指定了是按 24 小时折算的
  var days: Int
  var hours: Int
  var minutes: Int
  /// 已经到了或者过了
  var isPast: Bool
}

extension KeyDate {
  /// 还有多久：没指定时刻的只算到天（今天就是 0 天），指定了的精确到分钟
  func remaining(from now: Date = Date(), calendar: Calendar = .current) -> MVKeyDateRemaining {
    guard self.hasTime else {
      let days = MVKeyDateCountdown.days(to: self.date, from: now, calendar: calendar)
      return MVKeyDateRemaining(days: days, hours: 0, minutes: 0, isPast: days < 0)
    }

    let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: self.date)
    let days = components.day ?? 0
    let hours = components.hour ?? 0
    let minutes = components.minute ?? 0
    return MVKeyDateRemaining(
      // 过了的分量是负数，这里只留给显示用，判「过没过」看 isPast
      days: Swift.max(0, days),
      hours: Swift.max(0, hours),
      minutes: Swift.max(0, minutes),
      isPast: self.date <= now
    )
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

/// 一条要显示的倒计时：哪个日子 + 还有多久
struct MVKeyDateCountdownItem: Equatable {
  var keyDate: KeyDate
  var remaining: MVKeyDateRemaining
}

/// 总小时数按「一天算几小时」折算的设置。一天 24 小时太粗时用得上：
/// 比如一天只打算学 10 小时，还剩 55 天就是 550 小时
enum MVKeyDateSettings {
  static let didChangeNotification = Notification.Name("MVKeyDateSettingsDidChange")

  /// 没设置过就按一天 24 小时
  static let defaultHoursPerDay: Double = 24

  static func hoursPerDay(from defaults: UserDefaults = .standard) -> Double {
    let value = defaults.double(forKey: MVUserDefaultsKeys.keyDatesHoursPerDay)
    // 没存过（0）或填了不合理的数都按默认的来
    return Self.validated(value)
  }

  /// 存进去；nil 或超出范围就清掉，回到默认
  static func save(hoursPerDay: Double?, to defaults: UserDefaults = .standard) {
    if let hoursPerDay, hoursPerDay >= 1, hoursPerDay <= 24 {
      defaults.set(hoursPerDay, forKey: MVUserDefaultsKeys.keyDatesHoursPerDay)
    } else {
      defaults.removeObject(forKey: MVUserDefaultsKeys.keyDatesHoursPerDay)
    }
    NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
  }

  private static func validated(_ value: Double) -> Double {
    guard value >= 1, value <= 24 else { return Self.defaultHoursPerDay }
    return value
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

  /// 还没到的日子，按先后排：先显示日历上最近的那个。
  /// 同一天里，没指定时刻的（当天 0 点）排在指定了时刻的前面
  static func upcoming(
    from dates: [KeyDate],
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> [MVKeyDateCountdownItem] {
    let items = dates
      .sorted { $0.date < $1.date }
      .map {
        MVKeyDateCountdownItem(
          keyDate: $0,
          remaining: $0.remaining(from: now, calendar: calendar)
        )
      }
    return Array(items.filter { !$0.remaining.isPast }.prefix(Self.maxLines))
  }

  /// 表盘上那一行：字号小、地方窄，名字过长会被截断
  static func line(_ item: MVKeyDateCountdownItem) -> String {
    "\(item.keyDate.title) \(Self.shortText(item))"
  }

  /// 表盘放得下的写法：够一天就写到「天 + 时」，不够一天就写「时 + 分」
  static func shortText(_ item: MVKeyDateCountdownItem) -> String {
    // 没指定时刻的只按天算：目标是 0 点，硬算时分只会得到负数
    guard item.keyDate.hasTime else {
      return item.remaining.days <= 0 ? "今天" : "\(item.remaining.days)天"
    }

    let remaining = item.remaining
    if remaining.isPast { return "已过" }
    if remaining.days > 0 {
      return remaining.hours > 0 ? "\(remaining.days)天\(remaining.hours)时" : "\(remaining.days)天"
    }
    if remaining.hours > 0 { return "\(remaining.hours)时\(remaining.minutes)分" }
    if remaining.minutes > 0 { return "\(remaining.minutes)分" }
    return "即将"
  }

  /// 还剩多少个小时。默认按一天 24 小时，也可以按「一天算几小时」折算
  /// （比如一天只算 10 小时，55 天就是 550 小时而不是 1320）
  static func totalHours(
    _ remaining: MVKeyDateRemaining,
    hoursPerDay: Double = MVKeyDateSettings.defaultHoursPerDay
  ) -> Int {
    // 先把零头折成天再乘：不足一天的部分也按同一比例走，不会出现「一天 10 小时却剩 20 小时」
    let totalDays = Double(remaining.days)
      + Double(remaining.hours) / 24
      + Double(remaining.minutes) / 1_440
    return Int(totalDays * hoursPerDay)
  }

  /// 表盘最下面那一行。没指定时刻的日子只按天算，硬折成小时会偏多，干脆不显示
  static func totalHoursText(
    _ item: MVKeyDateCountdownItem,
    hoursPerDay: Double = MVKeyDateSettings.defaultHoursPerDay
  ) -> String? {
    guard item.keyDate.hasTime, !item.remaining.isPast else { return nil }
    return "\(Self.totalHours(item.remaining, hoursPerDay: hoursPerDay))小时"
  }

  /// 管理窗口「还有」那一列：地方够，写完整
  static func text(_ item: MVKeyDateCountdownItem) -> String {
    guard item.keyDate.hasTime else {
      return item.remaining.days <= 0 ? "今天" : "\(item.remaining.days) 天"
    }

    let remaining = item.remaining
    if remaining.isPast { return "已过" }
    if remaining.days > 0 {
      let tail: String
      if remaining.hours > 0 {
        tail = "\(remaining.hours)时\(remaining.minutes)分"
      } else if remaining.minutes > 0 {
        tail = "\(remaining.minutes)分"
      } else {
        tail = ""
      }
      return "\(remaining.days)天" + tail
    }
    if remaining.hours > 0 { return "\(remaining.hours)时\(remaining.minutes)分" }
    return "\(remaining.minutes)分"
  }
}
