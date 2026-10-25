import AppKit

// MARK: - 时间文字渲染

extension MVClockView {
  func updateLabels() {
    // 每秒都会走到这里：同一天内倒计时不变，内部自己判断要不要重算
    self.updateCountdownLabels()

    if self.mode == .stopwatch {
      self.updateStopwatchLabel()
      return
    }

    self.startTimeLabel.string = ""
    self.minutesLabel.font = Self.minutesFont
    self.minutesLabel.string = TimerLogic.minutesDisplayString(seconds: self.seconds)
    let suffixWidth: CGFloat = self.seconds < 60 ? self.minutesLabelSecondsSuffixWidth : self.minutesLabelSuffixWidth
    self.minutesLabel.sizeToFit()

    var frame = self.minutesLabel.frame
    frame.origin.x = round((self.bounds.width - (frame.size.width - suffixWidth)) / 2)
    self.minutesLabel.frame = frame

    self.secondsLabel.string = TimerLogic.secondsDisplayString(seconds: self.seconds)
    if self.seconds >= 60 {
      self.secondsLabel.sizeToFit()

      frame = self.secondsLabel.frame
      frame.origin.x = round((self.bounds.width - (frame.size.width - self.secondsSuffixWidth)) / 2)
      self.secondsLabel.frame = frame
    }
  }

  /// 秒表：整块显示「时:分:秒」，字号按宽度自适应，隐藏小号秒标签
  func updateStopwatchLabel() {
    let text = TimerLogic.stopwatchDisplayString(seconds: self.seconds)
    self.minutesLabel.string = text
    self.minutesLabel.font = MVLabel.monospacedDigitFont(
      fitting: text,
      maxWidth: 120,
      maxSize: Self.stopwatchMaxFontSize
    )
    self.secondsLabel.string = ""

    self.minutesLabel.sizeToFit()
    var frame = self.minutesLabel.frame
    frame.origin.x = round((self.bounds.width - frame.size.width) / 2)
    self.minutesLabel.frame = frame

    self.updateStartTimeLabel()
  }

  /// 只在秒表跑起来（含暂停）之后显示起始时刻，归零/切模式后清空
  func updateStartTimeLabel() {
    guard let origin = self.stopwatchOriginDate, self.timerTask != nil || self.paused else {
      self.startTimeLabel.string = ""
      return
    }
    self.startTimeLabel.string = "起始 \(self.startTimeFormatter.string(from: origin))"
  }

  func updateTimeLabel() {
    let timeString = self.timerTimeLabelFormatter.string(from: self.timerTime ?? Date())
    self.timerTimeLabel.string = timeString

    if let ampmRange = (
      timeString.range(of: " AM", options: [.caseInsensitive]) ??
      timeString.range(of: " PM", options: [.caseInsensitive])
    ) {
      self.timerTimeLabel.setFont(
        NSFont.systemFont(ofSize: 11, weight: .medium),
        range: NSRange(ampmRange, in: timeString)
      )
    }
  }
}
