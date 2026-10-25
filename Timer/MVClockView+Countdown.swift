import AppKit

// MARK: - 关键日子倒计时

extension MVClockView {
  /// 三条倒计时的位置：圆心在 (75, 75)、半径 59，越靠下能用的横向宽度越小
  static func makeCountdownLabels() -> [MVLabel] {
    let lines: [(originY: CGFloat, width: CGFloat)] = [(42, 92), (31, 76), (20, 46)]
    return lines.map { originY, width in
      let label = MVLabel(frame: NSRect(x: (Self.designSize - width) / 2, y: originY, width: width, height: 11))
      label.font = Self.countdownFont
      label.alignment = .center
      label.lineBreakMode = .byTruncatingTail
      label.textColor = MVResource.color("seconds")
      label.alphaValue = 0.9
      return label
    }
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
  }
}
