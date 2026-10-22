import AppKit

extension MVClockView {
  /// 已经计时的秒数（暂停期间不再增长）：
  /// 秒表看已经走过的时间，倒计时看总时长减掉剩余
  var elapsedSeconds: CGFloat {
    if self.mode == .stopwatch {
      return max(0, self.seconds)
    }
    return max(0, self.countdownDuration - self.seconds)
  }
}
