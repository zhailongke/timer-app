import AppKit

// MARK: - 关键日子倒计时

extension MVClockView {
  /// 倒计时区的四行位置：圆心在 (75, 75)、半径 59，越靠下能用的横向宽度越小。
  /// 前三条放倒计时，第四条留给总小时数
  private static let countdownLineFrames: [(originY: CGFloat, width: CGFloat)] = [
    (49, 100), (38, 88), (27, 72), (16, 46)
  ]

  static func makeCountdownLabels() -> [MVLabel] {
    Self.countdownLineFrames
      .prefix(MVKeyDateCountdown.maxLines)
      .map { Self.countdownLabel(originY: $0.originY, width: $0.width) }
  }

  /// 总小时数那一行：位置随显示了几条倒计时走，见 updateCountdownLabels
  static func makeTotalHoursLabel() -> MVLabel {
    Self.countdownLabel(originY: 16, width: 46)
  }

  private static func countdownLabel(originY: CGFloat, width: CGFloat) -> MVLabel {
    let label = MVLabel(frame: NSRect(x: (Self.designSize - width) / 2, y: originY, width: width, height: 11))
    label.font = Self.countdownFont
    label.alignment = .center
    label.lineBreakMode = .byTruncatingTail
    label.textColor = MVResource.color("seconds")
    label.alphaValue = 0.9
    return label
  }

  /// 刷新表盘下沿的倒计时。同一分钟内不重复算（每秒钟都会走到这里）；
  /// 关键日子改了或跨过午夜时用 force 强制重算
  func updateCountdownLabels(force: Bool = false) {
    let calendar = Calendar.current
    let now = Date()
    let minute = floor(now.timeIntervalSinceReferenceDate / 60)

    if !force, self.countdownRefreshMinute == minute { return }
    self.countdownRefreshMinute = minute

    let items = MVKeyDateCountdown.upcoming(from: MVKeyDateStore.load(), now: now, calendar: calendar)

    for (index, label) in self.countdownLabels.enumerated() {
      guard index < items.count else {
        label.string = ""
        continue
      }
      label.string = MVKeyDateCountdown.line(items[index])
    }

    // 总小时数只给最近那条算，紧跟在最后一条倒计时下面：显示几条就占第几条的位置
    let hoursPerDay = MVKeyDateSettings.hoursPerDay()
    let totalHours = items.first.map { MVKeyDateCountdown.totalHoursText($0, hoursPerDay: hoursPerDay) ?? "" } ?? ""
    self.totalHoursLabel.string = totalHours
    guard !totalHours.isEmpty else { return }

    let index = min(items.count, Self.countdownLineFrames.count - 1)
    let line = Self.countdownLineFrames[index]
    self.totalHoursLabel.frame = NSRect(
      x: (Self.designSize - line.width) / 2,
      y: line.originY,
      width: line.width,
      height: 11
    )
  }
}
