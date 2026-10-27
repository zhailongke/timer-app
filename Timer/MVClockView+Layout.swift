import AppKit

// MARK: - 进度环与拖拽箭头

extension MVClockView {
  private var progress: CGFloat {
    if self.mode == .stopwatch {
      // 正计时：蓝条是「今天已经学了多少」—— 今天所有计时之和（含正在跑的那条），
      // 分母按事件进度里的每日时长
      return Self.stopwatchDayProgress(
        elapsed: CGFloat(MVHistoryTracker.shared.secondsToday()),
        dayHours: MVEventSettings.hoursPerDay()
      )
    }
    // 倒计时：蓝条还是小时刻度
    return self.invertProgressToScale(self.seconds / 60.0 / 60.0)
  }

  /// 正计时模式下的蓝条占比：已经计时的时长占一天的比例，用满了就满圈
  static func stopwatchDayProgress(elapsed: CGFloat, dayHours: Double) -> CGFloat {
    let daySeconds = CGFloat(dayHours) * 3_600
    guard daySeconds > 0 else { return 0 }
    return min(1, max(0, elapsed / daySeconds))
  }

  func center(_ view: NSView) {
    var frame = view.frame
    frame.origin.x = round((self.bounds.width - frame.size.width) / 2)
    frame.origin.y = round((self.bounds.height - frame.size.height) / 2)
    view.frame = frame
  }

  func layoutSubviews() {
    let angle = -self.progress * .pi * 2 + .pi / 2

    // swiftlint:disable identifier_name
    let x = self.bounds.width / 2 + cos(angle) * self.progressView.bounds.width / 2
    let y = self.bounds.height / 2 + sin(angle) * self.progressView.bounds.height / 2
    // swiftlint:enable identifier_name

    let point = NSPoint(x: x - self.arrowView.bounds.width / 2, y: y - self.arrowView.bounds.height / 2)
    var frame = self.arrowView.frame
    frame.origin = point
    self.arrowView.frame = frame

    self.progressView.progress = self.progress
    // 正计时的蓝条表示「占一天多少」，六等份的刻度才有意义；倒计时是小时刻度，不画
    self.progressView.ticks = self.mode == .stopwatch ? 6 : 0
    self.arrowView.progress = self.progress
  }

  func handleArrowControl(progress rawProgress: CGFloat) {
    guard self.mode == .countdown else { return }

    var progressValue = rawProgress
    progressValue = self.convertProgressToScale(progressValue)
    var seconds: CGFloat = round(progressValue * 60.0 * 60.0)
    if seconds <= 300 {
      seconds -= seconds.truncatingRemainder(dividingBy: 10)
    } else {
      seconds -= seconds.truncatingRemainder(dividingBy: 60)
    }
    self.setCountdownSeconds(seconds)
    self.updateTimerTime()

    self.stop()

    self.paused = false
  }

  func handleArrowControlMouseUp() {
    guard self.mode == .countdown else { return }

    self.updateTimerTime()
    self.start()
  }

  private func convertProgressToScale(_ progress: CGFloat) -> CGFloat {
    TimerLogic.convertProgressToScale(progress, minutes: self.minutes)
  }

  private func invertProgressToScale(_ progress: CGFloat) -> CGFloat {
    TimerLogic.invertProgressToScale(progress, minutes: self.minutes)
  }
}
