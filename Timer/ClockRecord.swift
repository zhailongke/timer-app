import Foundation

/// 一次计时的历史记录：起始时间、时长、结束时间。
/// 子时钟的记录挂在它所属的那条上级记录下面，一层层嵌套
struct ClockRecord: Codable, Equatable, Identifiable, Sendable {
  var id: UUID
  /// 默认用起始时间命名，可以在历史记录窗口里改
  var name: String
  /// 时钟界面上的名字（如「子时钟1」）；主时钟为空
  var title: String
  var startDate: Date
  var endDate: Date
  /// 真正计时的秒数（暂停的时间不算）
  var duration: TimeInterval
  var mode: TimerMode
  /// 没关闭就先记了一笔：结束时间写的是"至今"
  var isOpenEnded: Bool
  var children: [Self]

  init(
    id: UUID,
    name: String,
    startDate: Date,
    duration: TimeInterval,
    mode: TimerMode,
    title: String = "",
    endDate: Date? = nil,
    isOpenEnded: Bool = false,
    children: [Self] = []
  ) {
    self.id = id
    self.name = name
    self.title = title
    self.startDate = startDate
    self.endDate = endDate ?? startDate
    self.duration = duration
    self.mode = mode
    self.isOpenEnded = isOpenEnded
    self.children = children
  }

  /// 开一段新记录：起始时间就是现在，默认拿它当名字
  static func starting(mode: TimerMode, title: String = "") -> Self {
    let now = Date()
    return Self(
      id: UUID(),
      name: Self.defaultName(for: now),
      startDate: now,
      duration: 0,
      mode: mode,
      title: title,
      isOpenEnded: true
    )
  }

  static func defaultName(for date: Date) -> String {
    "\(Self.monthDayFormatter.string(from: date)) \(Self.timeFormatter.string(from: date))"
  }

  // MARK: - 列表显示

  /// 月日固定写中文（10月23日），不跟系统语言走，免得中文界面里冒出 Oct 之类的英文月份。
  /// 格式写死而不是用 Md 模板：zh_CN 的模板给出来的是 M/d，不是中文
  private static let monthDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日"
    return formatter
  }()

  /// 时分仍然跟系统的 12/24 小时制走：jj 模板会按系统设置给出 h:mm a 或 HH:mm
  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "jj:mm", options: 0, locale: Locale.current)
    return formatter
  }()

  var startDateDisplay: String { Self.defaultName(for: self.startDate) }

  var endDateDisplay: String {
    self.isOpenEnded ? "至今" : Self.defaultName(for: self.endDate)
  }

  var durationDisplay: String {
    TimerLogic.stopwatchDisplayString(seconds: CGFloat(self.duration))
  }

  var summary: String {
    "\(self.startDateDisplay) → \(self.endDateDisplay) · \(self.durationDisplay)"
  }
}

extension Array where Element == ClockRecord {
  /// 按 id 找记录（含所有下级）
  func first(matching id: UUID) -> ClockRecord? {
    for record in self {
      if record.id == id { return record }
      if let found = record.children.first(matching: id) { return found }
    }
    return nil
  }

  /// 沿 path 一层层走到最后一级，交给 body 改；path 为空就是根这一层
  mutating func mutate(at path: [UUID], _ body: (inout [ClockRecord]) -> Void) {
    guard let head = path.first else {
      body(&self)
      return
    }
    guard let index = self.firstIndex(where: { $0.id == head }) else { return }
    self[index].children.mutate(at: [UUID](path.dropFirst()), body)
  }

  /// 挂到 parentID 那条记录下面；parentID 为 nil 就挂到根层（主时钟那一层）
  mutating func append(_ record: ClockRecord, toParent parentID: UUID?) {
    guard let parentID else {
      self.append(record)
      return
    }
    for index in self.indices {
      if self[index].id == parentID {
        self[index].children.append(record)
        return
      }
      self[index].children.append(record, toParent: parentID)
    }
    // 上级记录已经被删掉了就落到根层，总比丢了好
    self.append(record)
  }

  /// 按 id 改一条记录（含所有下级）
  mutating func update(id: UUID, _ body: (inout ClockRecord) -> Void) {
    for index in self.indices {
      if self[index].id == id {
        body(&self[index])
        return
      }
      self[index].children.update(id: id, body)
    }
  }

  func contains(id: UUID) -> Bool {
    if self.contains(where: { $0.id == id }) { return true }
    return self.contains { $0.children.contains(id: id) }
  }

  /// 走到 path 指的那一级，把记录取出来
  func records(at path: [UUID]) -> [ClockRecord] {
    guard let head = path.first else { return self }
    guard let index = self.firstIndex(where: { $0.id == head }) else { return [] }
    return self[index].children.records(at: [UUID](path.dropFirst()))
  }

  mutating func rename(id: UUID, to name: String) {
    for index in self.indices {
      if self[index].id == id {
        self[index].name = name
        return
      }
      self[index].children.rename(id: id, to: name)
    }
  }

  mutating func remove(id: UUID) {
    self.removeAll { $0.id == id }
    for index in self.indices {
      self[index].children.remove(id: id)
    }
  }
}

/// 历史记录存在 UserDefaults 里，根一层是每次主时钟的记录
enum MVHistoryStore {
  /// 最多留多少条主时钟记录，再旧的从头丢掉
  static let limit = 200

  static func load(from defaults: UserDefaults = .standard) -> [ClockRecord] {
    guard let data = defaults.data(forKey: MVUserDefaultsKeys.historyRecords),
      let records = try? JSONDecoder().decode([ClockRecord].self, from: data)
    else { return [] }
    return records
  }

  static func save(_ records: [ClockRecord], to defaults: UserDefaults = .standard) {
    var trimmed = records
    if trimmed.count > Self.limit {
      trimmed.removeFirst(trimmed.count - Self.limit)
    }
    guard let data = try? JSONEncoder().encode(trimmed) else { return }
    defaults.set(data, forKey: MVUserDefaultsKeys.historyRecords)
  }
}
