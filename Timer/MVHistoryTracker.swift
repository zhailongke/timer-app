import AppKit

/// 历史记录的总账：根一层是每次主时钟的记录，**正在跑的那条也在里面**，
/// 子时钟的记录挂在它所属的那条上级记录下面。
/// 一点击开始计时（或一建出子时钟）就立刻建记录，之后每秒刷新时长，关闭时才收尾
@MainActor
final class MVHistoryTracker {
  static let shared = MVHistoryTracker()

  private let defaults: UserDefaults
  private(set) var records: [ClockRecord] = []
  /// 记录有变化就通知一声（历史记录窗口靠它自动刷新）
  var onChange: (() -> Void)?

  private var tickTask: Task<Void, Never>?
  private var lastSaveDate = Date.distantPast
  /// 每条进行中的记录开始那一刻，时钟已经走过的秒数：
  /// 「另起一条」之后秒表还在继续走，时长要减掉这个底数才算新这一段
  private var elapsedBaselines: [UUID: TimeInterval] = [:]

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.records = MVHistoryStore.load(from: defaults)
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

  /// 右键「另起一条记录」：不关闭也把这一段结算掉，立刻开新的一条
  func cutRecord(for controller: MVTimerController) {
    self.finalize(controller: controller)
    self.ensureRecord(for: controller)
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

    // 每秒写盘太勤，攒几秒写一次；建记录 / 收尾 / 改名这些才是立刻写
    if Date().timeIntervalSince(self.lastSaveDate) >= 3 {
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

  /// 退出前用：把没落盘的记录刷到磁盘，免得这次白记
  func flush() {
    self.save()
    self.defaults.synchronize()
  }

  private func save() {
    if self.records.count > MVHistoryStore.limit {
      self.records.removeFirst(self.records.count - MVHistoryStore.limit)
    }
    MVHistoryStore.save(self.records, to: self.defaults)
    self.lastSaveDate = Date()
  }

  private static func appControllers() -> [MVTimerController] {
    (NSApplication.shared.delegate as? AppDelegate)?.controllers ?? []
  }
}
