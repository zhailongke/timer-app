import AppKit

// MARK: - Event Handling

extension MVClockView {
  override func mouseDown(with event: NSEvent) {
    self.didDrag = false
    self.updateClockFaceView(highlighted: true)
    self.nextResponder?.mouseDown(with: event)
  }

  override func mouseDragged(with event: NSEvent) {
    guard !self.didDrag else { return }
    self.didDrag = true
    self.updateClockFaceView()
    // 内容视图铺满整个窗口后没有标题栏可拖，这里自己接管拖动
    self.window?.performDrag(with: event)
  }

  override func scrollWheel(with event: NSEvent) {
    guard self.timerTask == nil, !self.paused, self.mode == .countdown else { return }

    let delta: CGFloat
    if event.hasPreciseScrollingDeltas {
      delta = event.scrollingDeltaY * 3
    } else {
      delta = event.scrollingDeltaY * 30
    }

    guard delta != 0 else { return }

    var newSeconds = self.seconds + delta
    newSeconds = max(0, newSeconds)

    if newSeconds <= 300 {
      newSeconds -= newSeconds.truncatingRemainder(dividingBy: 10)
    } else {
      newSeconds -= newSeconds.truncatingRemainder(dividingBy: 60)
    }

    self.setCountdownSeconds(newSeconds)
    self.updateTimerTime()
  }

  override func mouseUp(with event: NSEvent) {
    let point = self.convert(event.locationInWindow, from: nil)
    if self.hitTest(point) == self, !self.didDrag {
      self.handleClick()
    }
    self.updateClockFaceView()
  }

  override func keyUp(with event: NSEvent) {
    let modifiers = event.modifierFlags
    let chars = event.charactersIgnoringModifiers
    let minuteAmount = modifiers.contains(.shift) ? 10 : 1

    // Use the physical key ("=" is the +/= key; shift state isn't reliable on keyUp)
    if chars == "\u{F700}" || chars == "=" { // up arrow or +/= key
      self.adjustMinutesIfCountdown(by: minuteAmount)
      return
    }
    if chars == "\u{F701}" || chars == "-" { // down arrow or -/_ key
      self.adjustMinutesIfCountdown(by: -minuteAmount)
      return
    }
    if chars == "s" { // 切换秒表 / 倒计时
      self.onModeToggleRequest?()
      return
    }
    self.handleCommand(chars: chars, event: event)
  }

  /// 秒表只保留起停与归零，一切"设定时长"的输入都禁用
  private func handleCommand(chars: String?, event: NSEvent) {
    if self.mode == .stopwatch, chars != "\u{1B}", chars != "\r", chars != " ", chars != "\u{03}" {
      return
    }

    switch chars {
    case ".":
      self.inputSeconds.toggle()

    case "\u{1B}": // escape
      self.resetTimer()

    case "\u{7F}", "\u{F728}": // delete, forward delete
      self.handleBackspace()

    case "\r", " ", "\u{03}": // return, space, keypad enter
      self.handleClick()

    case "r":
      self.restartLastTimer()

    default:
      self.handleDigitInput(event)
    }
  }

  private func restartLastTimer() {
    if self.timerTask == nil, !self.paused, let seconds = self.lastTimerSeconds {
      self.setCountdownSeconds(seconds)
      self.handleClick()
    }
  }

  private func adjustMinutesIfCountdown(by minutes: Int) {
    guard self.mode == .countdown else { return }
    self.adjustMinutes(by: minutes)
  }

  private func adjustMinutes(by minutes: Int) {
    self.setCountdownSeconds(self.seconds + CGFloat(minutes * 60))
    self.updateTimerTime()
  }

  private func resetTimer() {
    self.paused = false
    self.stop()
    self.setCountdownSeconds(0)
    self.stopwatchAccumulated = 0
    self.stopwatchStartDate = nil
    self.stopwatchOriginDate = nil
    self.updateTimerTime()
    self.inputSeconds = false
  }

  private func handleBackspace() {
    let currentSeconds = self.seconds.truncatingRemainder(dividingBy: 60)
    let currentMinutes = floor(self.seconds / 60)
    self.paused = false
    self.stop()
    self.setCountdownSeconds(
      TimerLogic.processBackspace(
        currentSeconds: currentSeconds,
        currentMinutes: currentMinutes,
        inputSeconds: self.inputSeconds
      )
    )
    self.updateTimerTime()
  }

  private func handleDigitInput(_ event: NSEvent) {
    guard let characters = event.characters, let number = Int(characters) else { return }

    let currentSeconds = self.seconds.truncatingRemainder(dividingBy: 60)
    let currentMinutes = floor(self.seconds / 60)
    let result = TimerLogic.processDigitInput(
      digit: number,
      currentSeconds: currentSeconds,
      currentMinutes: currentMinutes,
      totalSeconds: self.seconds,
      inputSeconds: self.inputSeconds
    )
    if result.accepted {
      self.paused = false
      self.stop()
      self.setCountdownSeconds(result.seconds)
      self.updateTimerTime()
    }
  }
}

// MARK: - Timer

extension MVClockView {
  func start() {
    if self.mode == .stopwatch {
      self.paused = false
      self.stop()
      self.stopwatchStartDate = Date()
      // 暂停再继续不更新起点，起始时间保持第一次起跑的时刻
      if self.stopwatchOriginDate == nil {
        self.stopwatchOriginDate = self.stopwatchStartDate
      }
      self.updateTimerTime()
      self.startTicker()
      self.updateStartTimeLabel()
      return
    }

    guard self.seconds > 0 else { return }
    self.lastTimerSeconds = self.seconds

    self.paused = false
    self.stop()
    self.startTicker()
  }

  private func startTicker() {
    self.timerTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1), tolerance: .milliseconds(30))
        self?.tick()
      }
    }
  }

  func stop() {
    self.timerTask?.cancel()
    self.timerTask = nil

    if self.inDock, !self.paused {
      self.removeBadge()
    }
  }

  func startTimer(seconds: CGFloat) {
    self.setMode(.countdown)
    self.paused = false
    self.stop()
    self.setCountdownSeconds(seconds)
    self.updateTimerTime()
    self.start()
  }

  private func tick() {
    guard self.timerTask != nil else { return }

    if self.mode == .stopwatch {
      guard let startDate = self.stopwatchStartDate else { return }
      let elapsed = CGFloat(Date().timeIntervalSince(startDate))
      self.seconds = self.stopwatchAccumulated + floor(elapsed)
      self.timerTime = Date()
      return
    }

    guard let timerTime = self.timerTime else { return }

    let secondsRemaining = CGFloat(timerTime.timeIntervalSinceNow)

    self.seconds = max(0, round(secondsRemaining))

    if self.seconds <= 0 {
      self.stop()
      self.postAccessibilityValueChanged()
      self.onTimerComplete?()
    }
  }

  func startClockTimer() {
    guard self.currentTimeTask == nil else { return }

    if self.timerTask == nil {
      self.timerTime = Date()
    }

    self.currentTimeTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1), tolerance: .milliseconds(500))
        self?.maintainCurrentTime()
      }
    }
  }

  func stopClockTimer() {
    self.currentTimeTask?.cancel()
    self.currentTimeTask = nil
  }

  private func maintainCurrentTime() {
    guard self.timerTask == nil else { return }

    let time = Date()
    if Calendar.current.component(.second, from: time) == 0 {
      self.timerTime = time
    }
  }
}

// MARK: - 子时钟时长约束

extension MVClockView {
  /// 下级时钟能设到的最大时长：自己设了倒计时就用自己的，否则继续往上级传
  var countdownLimit: CGFloat? {
    if self.mode == .countdown, self.countdownDuration > 0 {
      return self.countdownDuration
    }
    return self.parentClockView?.countdownLimit
  }

  private var inheritedCountdownLimit: CGFloat? {
    self.parentClockView?.countdownLimit
  }

  /// 设定倒计时时长：拖拽、输入、启动都走这里，不能超过上级，同时记录供下级继承
  func setCountdownSeconds(_ value: CGFloat) {
    let bounded = max(0, value)
    let result = min(bounded, self.inheritedCountdownLimit ?? bounded)
    self.countdownDuration = result
    self.seconds = result
  }
}

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

// MARK: - Dock 角标

extension MVClockView {
  func updateBadge() {
    guard self.inDock else { return }

    guard self.timerTask != nil || self.paused else {
      self.removeBadge()
      return
    }

    if self.mode == .stopwatch, self.seconds >= 3_600 {
      NSApplication.shared.dockTile.badgeLabel = TimerLogic.stopwatchDisplayString(seconds: self.seconds)
      return
    }

    let badgeSeconds = Int(self.seconds.truncatingRemainder(dividingBy: 60))
    let badgeMinutes = Int(self.minutes) % 60
    NSApplication.shared.dockTile.badgeLabel = TimerLogic.badgeString(minutes: badgeMinutes, seconds: badgeSeconds)
  }

  func removeBadge() {
    NSApplication.shared.dockTile.badgeLabel = ""
  }
}
