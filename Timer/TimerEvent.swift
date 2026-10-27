import Foundation

/// 事件：一个名字 + 一个截止日期（例如「考研 12 月 19 日」），表盘上显示还有多久
struct TimerEvent: Codable, Equatable, Identifiable, Sendable {
  var id: UUID
  var title: String
  /// 没指定时刻时是当天 0 点，指定了就是精确到分的那一刻（秒归零）
  var date: Date
  /// 有没有指定具体时刻：指定了倒计时才算到小时分钟，否则只算到天
  var hasTime: Bool
  /// 这个事件自己的每日时长（小时）：折算「还剩多少小时」用它自己的。
  /// 没填就回落到全局设置，全局没有按 24
  var hoursPerDay: Double?
  /// 创建事件时生成的子时钟模板：模板靠它决定子时钟表盘显示哪个事件的倒计时
  var templateID: UUID?

  init(
    title: String,
    date: Date,
    id: UUID = UUID(),
    hasTime: Bool = false,
    hoursPerDay: Double? = nil,
    templateID: UUID? = nil,
    calendar: Calendar = .current
  ) {
    self.title = title
    self.id = id
    self.hasTime = hasTime
    self.hoursPerDay = hoursPerDay
    self.templateID = templateID
    self.date = Self.normalized(date, hasTime: hasTime, calendar: calendar)
  }

  /// 折算总小时数用的一天几小时：自己的优先，没填回落全局。
  /// defaults 可指定，测试好注入自己的那份
  func effectiveHoursPerDay(from defaults: UserDefaults = .standard) -> Double {
    guard let hoursPerDay = self.hoursPerDay, hoursPerDay >= 1, hoursPerDay <= 24 else {
      return MVEventSettings.hoursPerDay(from: defaults)
    }
    return hoursPerDay
  }

  /// 只算到天的日子归一到当天 0 点：天数按自然日算，不受具体时刻与夏令时影响。
  /// 指定了时刻的只把秒抹掉，免得界面上出现「3分」「4分」来回跳
  static func normalized(_ date: Date, hasTime: Bool, calendar: Calendar) -> Date {
    guard hasTime else { return calendar.startOfDay(for: date) }
    return calendar.date(bySetting: .second, value: 0, of: date) ?? date
  }

  private enum CodingKeys: String, CodingKey {
    case date, hasTime, hoursPerDay, id, templateID, title
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.title = try container.decode(String.self, forKey: .title)
    // 老版本存的日子没有这些字段：当它没指定时刻、用全局每日时长、没关联模板
    self.hasTime = try container.decodeIfPresent(Bool.self, forKey: .hasTime) ?? false
    self.hoursPerDay = try container.decodeIfPresent(Double.self, forKey: .hoursPerDay)
    self.templateID = try container.decodeIfPresent(UUID.self, forKey: .templateID)
    let date = try container.decode(Date.self, forKey: .date)
    self.date = Self.normalized(date, hasTime: self.hasTime, calendar: .current)
  }
}

/// 距离某个日子还剩多久
struct MVEventRemaining: Equatable {
  /// 整天的部分。没指定时刻时是自然日天数，指定了是按 24 小时折算的
  var days: Int
  var hours: Int
  var minutes: Int
  /// 已经到了或者过了
  var isPast: Bool
}

extension TimerEvent {
  /// 还有多久：没指定时刻的只算到天（今天就是 0 天），指定了的精确到分钟
  func remaining(from now: Date = Date(), calendar: Calendar = .current) -> MVEventRemaining {
    guard self.hasTime else {
      let days = MVEventCountdown.days(to: self.date, from: now, calendar: calendar)
      return MVEventRemaining(days: days, hours: 0, minutes: 0, isPast: days < 0)
    }

    let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: self.date)
    let days = components.day ?? 0
    let hours = components.hour ?? 0
    let minutes = components.minute ?? 0
    return MVEventRemaining(
      // 过了的分量是负数，这里只留给显示用，判「过没过」看 isPast
      days: Swift.max(0, days),
      hours: Swift.max(0, hours),
      minutes: Swift.max(0, minutes),
      isPast: self.date <= now
    )
  }
}

/// 事件存在 UserDefaults 里；改完会发通知，表盘上的倒计时立刻跟着变
enum MVEventStore {
  static let didChangeNotification = Notification.Name("MVEventStoreDidChange")

  static func load(from defaults: UserDefaults = .standard) -> [TimerEvent] {
    guard let data = defaults.data(forKey: MVUserDefaultsKeys.events),
      let dates = try? JSONDecoder().decode([TimerEvent].self, from: data)
    else { return [] }
    return dates
  }

  static func save(_ dates: [TimerEvent], to defaults: UserDefaults = .standard) {
    guard let data = try? JSONEncoder().encode(dates) else { return }
    defaults.set(data, forKey: MVUserDefaultsKeys.events)
    NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
  }

  static func add(_ date: TimerEvent, to defaults: UserDefaults = .standard) {
    var dates = Self.load(from: defaults)
    dates.append(date)
    Self.save(dates, to: defaults)
  }

  /// 按 id 覆盖：管理窗口里改名、改日期都用它
  static func update(_ date: TimerEvent, to defaults: UserDefaults = .standard) {
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
struct MVEventCountdownItem: Equatable {
  var event: TimerEvent
  var remaining: MVEventRemaining
}

/// 总小时数按「一天算几小时」折算的设置。一天 24 小时太粗时用得上：
/// 比如一天只打算学 10 小时，还剩 55 天就是 550 小时
enum MVEventSettings {
  static let didChangeNotification = Notification.Name("MVEventSettingsDidChange")

  /// 没设置过就按一天 24 小时
  static let defaultHoursPerDay: Double = 24

  static func hoursPerDay(from defaults: UserDefaults = .standard) -> Double {
    let value = defaults.double(forKey: MVUserDefaultsKeys.eventsHoursPerDay)
    // 没存过（0）或填了不合理的数都按默认的来
    return Self.validated(value)
  }

  /// 存进去；nil 或超出范围就清掉，回到默认
  static func save(hoursPerDay: Double?, to defaults: UserDefaults = .standard) {
    if let hoursPerDay, hoursPerDay >= 1, hoursPerDay <= 24 {
      defaults.set(hoursPerDay, forKey: MVUserDefaultsKeys.eventsHoursPerDay)
    } else {
      defaults.removeObject(forKey: MVUserDefaultsKeys.eventsHoursPerDay)
    }
    NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
  }

  private static func validated(_ value: Double) -> Double {
    guard value >= 1, value <= 24 else { return Self.defaultHoursPerDay }
    return value
  }

  // MARK: - 表盘显示哪个事件

  /// 表盘显示哪个事件的倒计时（存 UUID 字符串）。没存过 = 自动选最近的那条；
  /// 轮播模式开着时这个仍记着「手动选过谁」，关掉轮播就回到它
  static func selectedEventID(from defaults: UserDefaults = .standard) -> UUID? {
    guard let text = defaults.string(forKey: MVUserDefaultsKeys.eventDisplaySelected) else { return nil }
    return UUID(uuidString: text)
  }

  static func save(selectedEventID: UUID?, to defaults: UserDefaults = .standard) {
    if let selectedEventID {
      defaults.set(selectedEventID.uuidString, forKey: MVUserDefaultsKeys.eventDisplaySelected)
    } else {
      defaults.removeObject(forKey: MVUserDefaultsKeys.eventDisplaySelected)
    }
    NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
  }

  /// 轮播模式：表盘每隔几秒自动切到下一个事件
  static func isRotating(from defaults: UserDefaults = .standard) -> Bool {
    defaults.bool(forKey: MVUserDefaultsKeys.eventDisplayRotate)
  }

  static func save(isRotating: Bool, to defaults: UserDefaults = .standard) {
    defaults.set(isRotating, forKey: MVUserDefaultsKeys.eventDisplayRotate)
    NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
  }
}

/// 倒计时怎么算、怎么排版
enum MVEventCountdown {
  /// 表盘下沿放得下的条数；再多只显示最近的前几条
  static let maxLines = 3

  /// 轮播模式每隔几秒切到下一个事件
  static let rotationInterval: TimeInterval = 5

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
    from dates: [TimerEvent],
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> [MVEventCountdownItem] {
    let items = dates
      .sorted { $0.date < $1.date }
      .map {
        MVEventCountdownItem(
          event: $0,
          remaining: $0.remaining(from: now, calendar: calendar)
        )
      }
    return Array(items.filter { !$0.remaining.isPast }.prefix(Self.maxLines))
  }

  /// 表盘上那一行：字号小、地方窄，名字过长会被截断
  static func line(_ item: MVEventCountdownItem) -> String {
    "\(item.event.title) \(Self.shortText(item))"
  }

  // MARK: - 表盘显示哪一条

  /// 表盘下方只显示一条：先看有没有钦点的（这个时钟自己关联的、或全局选中的），
  /// 钦点的过没期都照显；没人钦点就按日期取最近的
  static func item(
    from events: [TimerEvent],
    preferredEventID: UUID?,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> MVEventCountdownItem? {
    if let id = preferredEventID, let event = events.first(where: { $0.id == id }) {
      return MVEventCountdownItem(event: event, remaining: event.remaining(from: now, calendar: calendar))
    }
    return Self.upcoming(from: events, now: now, calendar: calendar).first
  }

  /// 轮播用的：还没到的按日期排，轮到第 index 个；取余防越界，一个也能转
  static func rotatingItem(
    from events: [TimerEvent],
    index: Int,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> MVEventCountdownItem? {
    let items = Self.upcoming(from: events, now: now, calendar: calendar)
    guard !items.isEmpty else { return nil }
    return items[((index % items.count) + items.count) % items.count]
  }

  /// 表盘放得下的写法：够一天就写到「天 + 时」，不够一天就写「时 + 分」
  static func shortText(_ item: MVEventCountdownItem) -> String {
    // 没指定时刻的只按天算：目标是 0 点，硬算时分只会得到负数
    guard item.event.hasTime else {
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
    _ remaining: MVEventRemaining,
    hoursPerDay: Double = MVEventSettings.defaultHoursPerDay
  ) -> Int {
    // 先把零头折成天再乘：不足一天的部分也按同一比例走，不会出现「一天 10 小时却剩 20 小时」
    let totalDays = Double(remaining.days)
      + Double(remaining.hours) / 24
      + Double(remaining.minutes) / 1_440
    return Int(totalDays * hoursPerDay)
  }

  /// 表盘最下面那一行。没指定时刻的日子只按天算，硬折成小时会偏多，干脆不显示
  static func totalHoursText(
    _ item: MVEventCountdownItem,
    hoursPerDay: Double = MVEventSettings.defaultHoursPerDay
  ) -> String? {
    guard item.event.hasTime, !item.remaining.isPast else { return nil }
    return "\(Self.totalHours(item.remaining, hoursPerDay: hoursPerDay))小时"
  }

  /// 管理窗口「还有」那一列：地方够，写完整
  static func text(_ item: MVEventCountdownItem) -> String {
    guard item.event.hasTime else {
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
