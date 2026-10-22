import AppKit

// MARK: - 历史记录

extension MVTimerController {
  /// 开一段新记录：新建时钟、或者刚把上一段存进历史之后
  func startHistorySegment() {
    self.historySegment = .starting(mode: self.clockView.mode, title: self.clockView.clockTitle)
  }

  /// 把当前这一段收尾：填结束时间与时长，把还在的子时钟也一并收进来，然后开一段新的。
  /// 已经关掉的子时钟早就挂在 `historySegment.children` 上了，不会丢
  @discardableResult
  func cutHistorySegment(openEnded: Bool) -> ClockRecord {
    var record = self.historySegment
    record.title = self.clockView.clockTitle
    record.mode = self.clockView.mode
    record.endDate = Date()
    record.duration = TimeInterval(self.clockView.elapsedSeconds)
    record.isOpenEnded = openEnded
    record.children = self.historySegment.children
      + self.childControllers.map { $0.cutHistorySegment(openEnded: openEnded) }

    self.startHistorySegment()
    return record
  }

  /// 右键「记入历史」：不关闭也能先存一笔，结束时间记为现在（显示「至今」），
  /// 主要用来把当时还在跑的子时钟一起存下来
  @objc func addHistoryRecord(_: Any?) {
    self.attachToHistory(self.cutHistorySegment(openEnded: true))
  }

  /// 关闭窗口 = 这一段到此结束。子时钟的记录挂到上级，主时钟的记录进根层
  func recordHistoryOnClose() {
    let record = self.cutHistorySegment(openEnded: false)

    // 没真正计时、又没有子时钟记录的，不写进历史（免得随手一关就多一条空记录）
    guard record.duration >= 1 || !record.children.isEmpty else { return }

    self.attachToHistory(record)
  }

  private func attachToHistory(_ record: ClockRecord) {
    if let parent = self.parentController {
      parent.historySegment.children.append(record)
    } else {
      MVHistoryStore.append(record)
    }
  }
}
