import AppKit

// MARK: - Layout & Updates

extension MVClockView {
  func updateClockFaceView(highlighted: Bool = false) {
    self.clockFaceView.update(highlighted: highlighted)
  }

  func handleClick() {
    if self.timerTask == nil {
      // 秒表从 0 也能起跑；倒计时必须有时长才启动
      guard self.mode == .stopwatch || self.seconds > 0 else { return }
      self.updateTimerTime()
      self.start()
    } else {
      if self.mode == .stopwatch {
        self.stopwatchAccumulated = self.seconds
        self.stopwatchStartDate = nil
      }
      self.paused = true
      self.stop()
    }
    self.postAccessibilityValueChanged()
  }

  /// 切换模式，切换即重置
  func setMode(_ newMode: TimerMode) {
    guard newMode != self.mode else { return }

    self.mode = newMode
    self.paused = false
    self.stop()
    self.setCountdownSeconds(0)
    self.stopwatchAccumulated = 0
    self.stopwatchStartDate = nil
    self.stopwatchOriginDate = nil
    self.inputSeconds = false
    self.updateTimerTime()
    self.updateAllViews()
    self.postAccessibilityValueChanged()
  }

  /// 右上角按钮跟着计时状态走：在跑显示「暂停」，停了显示「继续」
  func updateControlButton() {
    self.controlButton.isRunning = self.timerTask != nil
  }

  func layoutPauseViews() {
    self.updateControlButton()
    let showPauseIcon = self.paused && self.timerTask != nil
    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = 0.2
      ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      self.pauseIconImageView.animator().alphaValue = showPauseIcon ? 1 : 0
      self.timerTimeLabel.animator().alphaValue = showPauseIcon ? 0 : 1
    }
  }

  func updateAllViews() {
    self.updateLabels()
    self.updateTimeLabel()
    self.layoutSubviews()
  }

  func updateTimerTime() {
    if self.mode == .stopwatch {
      self.timerTime = Date()
      return
    }
    self.timerTime = Date(timeIntervalSinceNow: Double(self.seconds))
  }

  /// 窗口缩放时 frame 会变，bounds 始终保持设计尺寸，内部子视图因此自动等比缩放
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    self.bounds.size = NSSize(width: Self.designSize, height: Self.designSize)
  }

  override func hitTest(_ aPoint: NSPoint) -> NSView? {
    let view = super.hitTest(aPoint)
    if view == self.arrowView {
      return view
    }
    // 改名时把点击交给输入框，好在里面放光标
    if view == self.titleInputField {
      return view
    }
    // 这几个按钮（含按钮里的图标）自己接点击，不再当作点时钟表面
    for button in [self.renameButton, self.controlButton, self.pinButton]
    where view?.isDescendant(of: button) == true {
      return view
    }
    if view != nil {
      return self
    }
    return nil
  }
}
