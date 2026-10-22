import AppKit

// MARK: - 历史记录

extension MVTimerController {
  /// 一开始计时（或一建出子时钟）就立刻在历史里占一条；
  /// 上级还没开始就一并建出来，子时钟才挂得上去
  func ensureHistoryRecord() {
    MVHistoryTracker.shared.ensureRecord(for: self)
  }

  /// 关闭窗口 = 这一段到此结束
  func finalizeHistoryRecord() {
    MVHistoryTracker.shared.finalize(controller: self)
  }
}
