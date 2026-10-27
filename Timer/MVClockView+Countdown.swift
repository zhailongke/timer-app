import AppKit

// MARK: - 事件倒计时

extension MVClockView {
  /// 表盘下沿两行的位置：圆心在 (75, 75)、半径 59，越靠下能用的横向宽度越小。
  /// 第一行放倒计时（选中的或轮播到的那个事件），第二行放它的总小时数
  private static let countdownLineFrames: [(originY: CGFloat, width: CGFloat)] = [
    (49, 100), (38, 88)
  ]

  static func makeCountdownLabels() -> [MVLabel] {
    let line = Self.countdownLineFrames[0]
    return [Self.countdownLabel(originY: line.originY, width: line.width)]
  }

  static func makeTotalHoursLabel() -> MVLabel {
    let line = Self.countdownLineFrames[1]
    return Self.countdownLabel(originY: line.originY, width: line.width)
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

  /// 刷新表盘下沿的事件倒计时。同一分钟内不重复算（每秒钟都会走到这里）；
  /// 事件改了、选中变了、轮播切到下一个了、跨过午夜时用 force 强制重算
  func updateCountdownLabels(force: Bool = false) {
    let calendar = Calendar.current
    let now = Date()
    let minute = floor(now.timeIntervalSinceReferenceDate / 60)

    if !force, self.countdownRefreshMinute == minute { return }
    self.countdownRefreshMinute = minute

    let events = MVEventStore.load()
    let item: MVEventCountdownItem?

    if let ownEventID = self.eventID {
      // 从模板建出来的子时钟：显示它自己关联的那个事件
      item = MVEventCountdown.item(
        from: events, preferredEventID: ownEventID, now: now, calendar: calendar
      )
    } else if MVEventSettings.isRotating() {
      item = MVEventCountdown.rotatingItem(
        from: events, index: self.rotationIndex, now: now, calendar: calendar
      )
    } else {
      // 显示全局选中的；没人选过就按日期取最近的
      item = MVEventCountdown.item(
        from: events, preferredEventID: MVEventSettings.selectedEventID(), now: now, calendar: calendar
      )
    }

    self.countdownLabels.first?.string = item.map(MVEventCountdown.line) ?? ""

    // 总小时数按这条事件自己的每日时长折算（没填回落全局），紧跟在倒计时下面
    let totalHours = item.flatMap {
      MVEventCountdown.totalHoursText($0, hoursPerDay: $0.event.effectiveHoursPerDay())
    } ?? ""
    self.totalHoursLabel.string = totalHours
  }

  // MARK: - 轮播

  /// 轮播模式开着、事件不止一个、本时钟又没有自己关联的事件时，起一个定时器每几秒切一条；
  /// 别的情况把它停掉。事件列表或显示设置一变就调一次
  func syncRotationTimer() {
    let shouldRotate = self.eventID == nil
      && MVEventSettings.isRotating()
      && MVEventCountdown.upcoming(from: MVEventStore.load()).count > 1

    if shouldRotate {
      if self.rotationTimer == nil {
        self.rotationTimer = Timer.scheduledTimer(
          withTimeInterval: MVEventCountdown.rotationInterval,
          repeats: true
        ) { [weak self] _ in
          MainActor.assumeIsolated {
            self?.advanceRotation()
          }
        }
      }
    } else if self.rotationTimer != nil {
      self.rotationTimer?.invalidate()
      self.rotationTimer = nil
    }
  }

  @MainActor
  private func advanceRotation() {
    self.rotationIndex += 1
    self.updateCountdownLabels(force: true)
  }
}
