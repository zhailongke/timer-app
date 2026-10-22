import AppKit

// MARK: - 进度环与拖拽箭头

extension MVClockView {
  private var progress: CGFloat {
    if self.mode == .stopwatch {
      // 秒表：每小时绕满一圈
      return self.seconds.truncatingRemainder(dividingBy: 3_600) / 3_600
    }
    return self.invertProgressToScale(self.seconds / 60.0 / 60.0)
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
