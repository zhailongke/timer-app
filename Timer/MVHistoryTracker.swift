import AppKit

/// 历史记录的总账：根一层是每次主时钟的记录，**正在跑的那条也在里面**，
/// 子时钟的记录挂在它所属的那条上级记录下面。
/// 一点击开始计时（或一建出子时钟）就立刻建记录，之后每秒刷新时长，关闭时才收尾
@MainActor
final class MVHistoryTracker {
  static let shared = MVHistoryTracker()

  private let defaults: UserDefaults
  /// 历史记录写在这个文件里，不再走 UserDefaults
  private let storeURL: URL
  private(set) var records: [ClockRecord] = []
  /// 记录有变化就通知一声（历史记录窗口靠它自动刷新）
  var onChange: (() -> Void)?

  private var tickTask: Task<Void, Never>?
  private var lastSaveDate = Date.distantPast
  /// 兜底落盘的间隔：正在跑的时钟每秒都在长，别每 3 秒就把整个文件重写一遍
  private static let idleSaveInterval: TimeInterval = 60
  /// 每条记录建出来那一刻，时钟已经走过的秒数：
  /// 时长要减掉它才算这一段自己的（比如在历史里删掉了还在跑的那条，重新建出来时秒表已经走了一段）
  private var elapsedBaselines: [UUID: TimeInterval] = [:]

  init(storeURL: URL = MVHistoryStore.fileURL(), defaults: UserDefaults = .standard) {
    self.storeURL = storeURL
    self.defaults = defaults
    // 只有老版本把记录留在 UserDefaults 里才需要搬；搬完那个 key 就被删了
    MVHistoryStore.migrateFromUserDefaults(defaults, to: storeURL)
    self.records = MVHistoryStore.load(from: storeURL)
  }

  // MARK: - 建记录

  /// 保证这个时钟、以及它的所有上级都有一条正在进行的记录。
  /// 上级还没开始也会先建出来，子时钟才挂得上去
  func ensureRecord(for controller: MVTimerController) {
    var chain: [MVTimerController] = []
    var node: MVTimerController? = controller
    while let current = node {
      chain.append(current)
      node = current.parentController
    }

    var parentID: UUID?
    for ancestor in chain.reversed() {
      if let id = ancestor.recordID, self.records.contains(id: id) {
        parentID = id
        continue
      }
      let record = ClockRecord.starting(
        mode: ancestor.clockView.mode,
        title: ancestor.clockView.clockTitle
      )
      ancestor.recordID = record.id
      self.elapsedBaselines[record.id] = TimeInterval(ancestor.clockView.elapsedSeconds)
      self.records.append(record, toParent: parentID)
      parentID = record.id
    }

    self.save()
    self.onChange?()
  }

  /// 关闭时钟：这一段到此结束
  func finalize(controller: MVTimerController) {
    guard let id = controller.recordID else { return }
    controller.recordID = nil
    self.elapsedBaselines[id] = nil
    self.finalizeRecord(
      id: id,
      elapsed: self.liveElapsed(for: controller, recordID: id),
      title: controller.clockView.clockTitle
    )
  }

  /// 这一段真正走过的秒数：秒表的总走过时间要减掉开始时的底数
  private func liveElapsed(for controller: MVTimerController, recordID: UUID) -> TimeInterval {
    let elapsed = TimeInterval(controller.clockView.elapsedSeconds)
    return max(0, elapsed - (self.elapsedBaselines[recordID] ?? 0))
  }

  /// 收尾一条记录：没真正跑过、又没下级的就撤掉，不留空行
  func finalizeRecord(id: UUID, elapsed: TimeInterval, title: String = "") {
    if elapsed < 1, let record = self.records.first(matching: id), record.children.isEmpty {
      self.records.remove(id: id)
    } else {
      self.records.update(id: id) { record in
        record.isOpenEnded = false
        record.endDate = Date()
        record.duration = max(record.duration, elapsed)
        if !title.isEmpty { record.title = title }
      }
    }
    self.save()
    self.onChange?()
  }

  /// 退出 App：还在跑的都收尾，免得一直挂着「至今」
  func finalizeAll() {
    for controller in Self.appControllers() {
      self.finalize(controller: controller)
    }
  }

  // MARK: - 每秒刷新

  /// 每秒把还在跑的记录时长、结束时间刷新一遍（历史窗口里能看着它长）
  func startTicking() {
    guard self.tickTask == nil else { return }

    self.tickTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1), tolerance: .milliseconds(200))
        self?.refreshLive()
      }
    }
  }

  func refreshLive() {
    let controllers = Self.appControllers()
    var touched = false

    for controller in controllers {
      guard let id = controller.recordID else { continue }
      let elapsed = self.liveElapsed(for: controller, recordID: id)
      let title = controller.clockView.clockTitle
      self.records.update(id: id) { record in
        // 暂停不该把已经跑出来的时长缩回去
        record.duration = max(record.duration, elapsed)
        record.endDate = Date()
        record.title = title
      }
      touched = true
    }

    guard touched else { return }

    // 每秒只改内存里的时长，落盘交给建记录 / 收尾 / 改名这些真正的变动。
    // 这里只留一个兜底：跑久了万一崩了，最多丢这一分钟的时长
    if Date().timeIntervalSince(self.lastSaveDate) >= Self.idleSaveInterval {
      self.save()
    }
    self.onChange?()
  }

  // MARK: - 历史记录窗口改名 / 删除

  func mutate(_ body: (inout [ClockRecord]) -> Void) {
    body(&self.records)
    self.save()
    self.onChange?()
  }

  /// 今天已经计时的总秒数：记在历史里今天的那些记录之和。
  /// 正在跑的那条也在 records 里（每秒刷新时长），所以不用另外再加当前计时
  func secondsToday(now: Date = Date(), calendar: Calendar = .current) -> TimeInterval {
    let dayStart = calendar.startOfDay(for: now)
    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }

    let summed = self.records.duration(within: dayStart, dayEnd: dayEnd)
    // 主时钟和子时钟会同时在跑，直接相加把同一段时间算了两三遍（实测今天 8 小时被算成 16.8 小时，
    // 直接顶满圈）；但暂停的时间按墙钟并集又会被算进去。两个都是真实值的上限，取小的那个更接近
    let covered = self.records.mergedSpan(within: dayStart, dayEnd: dayEnd)
    return Swift.min(summed, covered)
  }

  /// 退出前用：把没落盘的记录刷到磁盘，免得这次白记
  func flush() {
    self.save()
  }

  private func save() {
    // 内存里也一起裁，不然树会一直留在进程里
    self.records.trim(toTotal: MVHistoryStore.totalLimit)
    MVHistoryStore.save(self.records, to: self.storeURL)
    self.lastSaveDate = Date()
  }

  private static func appControllers() -> [MVTimerController] {
    (NSApplication.shared.delegate as? AppDelegate)?.controllers ?? []
  }
}
