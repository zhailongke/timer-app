import AppKit

final class MVClockView: NSView {
  override var mouseDownCanMoveWindow: Bool { false }

  /// 内部所有坐标都按这个尺寸设计，缩放窗口时靠 frame / bounds 的比值整体放大缩小
  static let designSize: CGFloat = 150
  static let minutesFont = NSFont.monospacedDigitSystemFont(ofSize: 35, weight: .medium)
  static let secondsFont = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular)

  private let progressView = MVClockProgressView()
  private let arrowView = MVClockArrowView(center: CGPoint(x: 75, y: 75))
  private let clockFaceView = MVClockFaceView(frame: NSRect(x: 16, y: 15, width: 118, height: 118))

  private let pauseIconImageView: NSImageView = {
    let view = NSImageView(frame: NSRect(x: 70, y: 99, width: 10, height: 12))
    view.image = MVResource.image("icon-pause")
    view.alphaValue = 0.0
    return view
  }()

  let timerTimeLabel: MVLabel = {
    let label = MVLabel(frame: NSRect(x: 0, y: 94, width: 150, height: 20))
    label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
    label.alignment = .center
    label.textColor = MVResource.color("timerTime")
    return label
  }()

  let minutesLabel: MVLabel = {
    let label = MVLabel(frame: NSRect(x: 0, y: 57, width: 150, height: 30))
    label.string = ""
    label.font = MVClockView.minutesFont
    label.alignment = .center
    label.textColor = MVResource.color("minutes")
    return label
  }()

  let secondsLabel: MVLabel = {
    let label = MVLabel(frame: NSRect(x: 0, y: 38, width: 150, height: 20))
    label.font = MVClockView.secondsFont
    label.alignment = .center
    label.textColor = MVResource.color("seconds")
    return label
  }()

  /// 秒表开始计时后，在大号时间下方显示起跑时刻
  let startTimeLabel: MVLabel = {
    let label = MVLabel(frame: NSRect(x: 0, y: 37, width: 150, height: 18))
    label.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    label.alignment = .center
    label.textColor = MVResource.color("seconds")
    return label
  }()

  /// 子时钟的名字，例如「子时钟1」；主时钟为空。
  /// 放在圆框外（时钟圆的下沿 y=15 之下），不挡表盘上的数字
  let titleLabel: MVLabel = {
    let label = MVLabel(frame: NSRect(x: 6, y: 1, width: 138, height: 14))
    label.font = NSFont.systemFont(ofSize: 10, weight: .medium)
    label.lineBreakMode = .byTruncatingTail
    label.alignment = .center
    label.textColor = MVResource.color("seconds")
    return label
  }()

  let minutesLabelSuffixWidth = "'".size(withAttributes: [.font: MVClockView.minutesFont]).width
  let minutesLabelSecondsSuffixWidth = "\"".size(withAttributes: [.font: MVClockView.minutesFont]).width
  let secondsSuffixWidth = "'".size(withAttributes: [.font: MVClockView.secondsFont]).width
  /// 顶部时钟用 jj:mm，秒表起始时刻用 jj:mm:ss，都跟随系统 12/24 小时制
  private static func formatter(template: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: Locale.current)
    return formatter
  }
  lazy var timerTimeLabelFormatter = MVClockView.formatter(template: "jj:mm")
  lazy var startTimeFormatter = MVClockView.formatter(template: "jj:mm:ss")
  var inputSeconds: Bool = false
  /// 默认秒表模式；秒表没有可调箭头，拖拽设定时长只在倒计时下有意义
  var mode: TimerMode = .stopwatch {
    didSet {
      self.arrowView.isHidden = self.mode == .stopwatch
    }
  }
  var lastTimerSeconds: CGFloat?
  /// 上级时钟（子时钟持有），用于继承倒计时时长上限
  weak var parentClockView: MVClockView?
  /// 本次设定的倒计时时长，下级时钟不能比它更长
  var countdownDuration: CGFloat = 0
  /// 界面上标记的层级名，例如「子时钟1」；主时钟为空
  var clockTitle: String {
    get { self.titleLabel.string }
    set { self.titleLabel.string = newValue }
  }
  /// 子时钟可以双击改名；主时钟没有名字，不能改
  var isTitleEditable = false {
    didSet {
      if !self.isTitleEditable {
        self.titleLabel.isSelectable = false
      }
    }
  }
  /// 正在输入名字：此时点击不起停时钟、Tab 也不切模式
  var isEditingTitle: Bool { self.titleLabel.isEditable }
  /// 改名前的值，名字清空时回滚到它
  var titleBeforeEditing = ""
  /// 按 s 键请求切换模式，由 AppDelegate 统一处理（含窗口置顶）
  var onModeToggleRequest: (() -> Void)?
  var inDock: Bool = false {
    didSet {
      if !self.inDock {
        self.removeBadge()
      }
      self.updateBadge()
    }
  }
  var windowIsVisible: Bool = false {
    didSet {
      if self.windowIsVisible {
        self.startClockTimer()
        self.updateAllViews()
      } else {
        self.stopClockTimer()
      }
    }
  }
  var timerTime: Date? {
    didSet {
      if self.windowIsVisible {
        self.updateTimeLabel()
      }
    }
  }
  var onTimerComplete: (() -> Void)?
  private var notificationTasks: [Task<Void, Never>] = []
  var currentTimeTask: Task<Void, Never>?
  var timerTask: Task<Void, Never>?
  var paused: Bool = false {
    didSet {
      self.layoutPauseViews()
    }
  }

  var seconds: CGFloat = 0.0 {
    didSet {
      if self.windowIsVisible {
        self.updateLabels()
        self.layoutSubviews()
      }
      self.updateBadge()
    }
  }

  var minutes: CGFloat {
    floor(self.seconds / 60)
  }

  private var progress: CGFloat {
    if self.mode == .stopwatch {
      // 秒表：每小时绕满一圈
      return self.seconds.truncatingRemainder(dividingBy: 3_600) / 3_600
    }
    return self.invertProgressToScale(self.seconds / 60.0 / 60.0)
  }
  var didDrag: Bool = false
  var stopwatchStartDate: Date?
  /// 本次计时的真正起点，暂停再继续不会变
  var stopwatchOriginDate: Date?
  var stopwatchAccumulated: CGFloat = 0

  // MARK: -

  convenience init() {
    self.init(frame: NSRect(x: 0, y: 0, width: Self.designSize, height: Self.designSize))

    self.center(self.progressView)
    self.addSubview(self.progressView)

    self.arrowView.onProgressChanged = { [weak self] progress in self?.handleArrowControl(progress: progress) }
    self.arrowView.onMouseUp = { [weak self] in self?.handleArrowControlMouseUp() }
    self.layoutSubviews()
    self.addSubview(self.arrowView)

    self.addSubview(self.clockFaceView)
    self.addSubview(self.pauseIconImageView)
    self.addSubview(self.timerTimeLabel)
    self.addSubview(self.minutesLabel)
    self.addSubview(self.secondsLabel)
    self.addSubview(self.startTimeLabel)
    self.addSubview(self.titleLabel)

    self.arrowView.isHidden = self.mode == .stopwatch
    self.startTimeLabel.string = ""
    self.updateClockFaceView()
    self.updateAllViews()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    self.notificationTasks.forEach { $0.cancel() }
    self.notificationTasks.removeAll()

    guard let window = self.window else { return }

    for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
      self.notificationTasks.append(
        Task { [weak self] in
          for await _ in NotificationCenter.default.mvNotifications(named: name, object: window) {
            self?.updateClockFaceView()
            self?.arrowView.needsDisplay = true
            self?.progressView.needsDisplay = true
          }
        }
      )
    }
  }

  deinit {
    MainActor.assumeIsolated {
      self.notificationTasks.forEach { $0.cancel() }
      self.timerTask?.cancel()
      self.currentTimeTask?.cancel()
    }
  }
}

// MARK: - Layout & Updates

extension MVClockView {
  func updateClockFaceView(highlighted: Bool = false) {
    self.clockFaceView.update(highlighted: highlighted)
  }

  private func center(_ view: NSView) {
    var frame = view.frame
    frame.origin.x = round((self.bounds.width - frame.size.width) / 2)
    frame.origin.y = round((self.bounds.height - frame.size.height) / 2)
    view.frame = frame
  }

  private func layoutSubviews() {
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

  private func handleArrowControl(progress rawProgress: CGFloat) {
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

  private func handleArrowControlMouseUp() {
    guard self.mode == .countdown else { return }

    self.updateTimerTime()
    self.start()
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

  private func layoutPauseViews() {
    let showPauseIcon = self.paused && self.timerTask != nil
    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = 0.2
      ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      self.pauseIconImageView.animator().alphaValue = showPauseIcon ? 1 : 0
      self.timerTimeLabel.animator().alphaValue = showPauseIcon ? 0 : 1
    }
  }

  private func updateAllViews() {
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
    if view == self.titleLabel {
      return view
    }
    if view != nil {
      return self
    }
    return nil
  }

  private func convertProgressToScale(_ progress: CGFloat) -> CGFloat {
    TimerLogic.convertProgressToScale(progress, minutes: self.minutes)
  }

  private func invertProgressToScale(_ progress: CGFloat) -> CGFloat {
    TimerLogic.invertProgressToScale(progress, minutes: self.minutes)
  }
}
