import AppKit

// MARK: - Accessibility

extension MVClockView {
  override func isAccessibilityElement() -> Bool { true }
  override func accessibilityRole() -> NSAccessibility.Role? { .group }
  override func accessibilityLabel() -> String? {
    self.clockTitle.isEmpty ? "Timer" : self.clockTitle
  }
  override func accessibilityValue() -> Any? { self.accessibilityTimerDescription }

  private var accessibilityTimerDescription: String {
    let hours = Int(self.seconds) / 3_600
    let mins = Int(self.minutes) % 60
    let secs = Int(self.seconds.truncatingRemainder(dividingBy: 60))

    if self.seconds <= 0, self.timerTask == nil {
      return "准备就绪"
    }

    let timeDescription = TimerLogic.accessibilityTimeDescription(minutes: mins, seconds: secs)
    let fullDescription = hours > 0 ? "\(hours) 小时 \(timeDescription)" : timeDescription

    if self.paused {
      return "已暂停 \(fullDescription)"
    }
    if self.timerTask != nil {
      return self.mode == .stopwatch ? "已计时 \(fullDescription)" : "剩余 \(fullDescription)"
    }
    return fullDescription
  }

  func postAccessibilityValueChanged() {
    NSAccessibility.post(element: self, notification: .valueChanged)
  }
}
