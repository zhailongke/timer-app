import AppKit

final class MVClockView: NSView {
  override var mouseDownCanMoveWindow: Bool { false }

  /// 内部所有坐标都按这个尺寸设计，缩放窗口时靠 frame / bounds 的比值整体放大缩小
  static let designSize: CGFloat = 150
  /// 回车键码；改名提交后要靠它认出那个漏下来的 keyUp
  static let returnKeyCode: UInt16 = 36
  /// 大号时间比早期版本小一号：底下要腾出地方放事件的倒计时
  static let minutesFont = NSFont.monospacedDigitSystemFont(ofSize: 27, weight: .medium)
  static let secondsFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
  /// 秒表整块「时:分:秒」自适应字号的上限，跟着大号时间一起收
  static let stopwatchMaxFontSize: CGFloat = 26
  static let countdownFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)

  let progressView = MVClockProgressView()
  let arrowView = MVClockArrowView(center: CGPoint(x: 75, y: 75))
  let clockFaceView = MVClockFaceView(frame: NSRect(x: 16, y: 15, width: 118, height: 118))

  let pauseIconImageView: NSImageView = {
    let view = NSImageView(frame: NSRect(x: 70, y: 99, width: 10, height: 12))
    view.image = MVResource.image("icon-pause")
    view.alphaValue = 0.0
    return view
  }()

  let timerTimeLabel: MVLabel = {
    let label = MVLabel(frame: NSRect(x: 0, y: 100, width: 150, height: 16))
    label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
    label.alignment = .center
    label.textColor = MVResource.color("timerTime")
    return label
  }()

  let minutesLabel: MVLabel = {
    let label = MVLabel(frame: NSRect(x: 0, y: 76, width: 150, height: 24))
    label.string = ""
    label.font = MVClockView.minutesFont
    label.alignment = .center
    label.textColor = MVResource.color("minutes")
    return label
  }()

  let secondsLabel: MVLabel = {
    let label = MVLabel(frame: NSRect(x: 0, y: 60, width: 150, height: 16))
    label.font = MVClockView.secondsFont
    label.alignment = .center
    label.textColor = MVResource.color("seconds")
    return label
  }()

  /// 秒表开始计时后，在大号时间下方显示起跑时刻
  let startTimeLabel: MVLabel = {
    let label = MVLabel(frame: NSRect(x: 0, y: 60, width: 150, height: 14))
    label.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    label.alignment = .center
    label.textColor = MVResource.color("seconds")
    return label
  }()

  /// 事件倒计时：最多三条，排在表盘下沿。
  /// 越往下越靠近圆边，能用的宽度越小，所以每行的宽度按它所在的高度收窄
  let countdownLabels: [MVLabel] = MVClockView.makeCountdownLabels()

  /// 倒计时最下面那一行：最近那条日子还剩多少个小时（天和小时折成一个整数）
  let totalHoursLabel: MVLabel = MVClockView.makeTotalHoursLabel()

  /// 子时钟的名字，例如「子时钟1」；主时钟为空。
  /// 放在圆框外（时钟圆的下沿 y=15 之下），不挡表盘上的数字
  let titleLabel: MVLabel = {
    let label = MVLabel(frame: NSRect(x: 6, y: 1, width: 138, height: 14))
    label.font = NSFont.systemFont(ofSize: 10, weight: .medium)
    label.lineBreakMode = .byTruncatingTail
    label.alignment = .center
    label.textColor = .white
    return label
  }()

  /// 改名字用的真输入框：点铅笔后盖在名字同一个位置，回车确认，esc 撤销
  let titleInputField: NSTextField = {
    let field = NSTextField(frame: NSRect(x: 6, y: 0, width: 138, height: 16))
    field.font = NSFont.systemFont(ofSize: 10, weight: .medium)
    field.alignment = .center
    field.textColor = .white
    field.isEditable = true
    field.isSelectable = true
    field.isBezeled = true
    field.bezelStyle = .roundedBezel
    field.drawsBackground = true
    field.backgroundColor = NSColor(white: 1, alpha: 0.14)
    field.focusRingType = .none
    field.isHidden = true
    return field
  }()

  /// 右上角的暂停 / 继续按钮，蓝底圆点 + 白色符号；中心与左上角两个交通灯齐平
  let controlButton = MVClockControlButton(frame: NSRect(x: 124, y: 125, width: 18, height: 18))

  /// 名字右边的改名按钮（蓝色圆点 + 铅笔）：点它进入改名；只有能改名的子时钟才显示
  let renameButton = MVRenameButton(frame: NSRect(x: 111, y: 1, width: 14, height: 14))

  /// 右上角的置顶按钮：紧挨着暂停 / 继续按钮左边，同样大小，管这个窗口浮不浮在其他窗口之上
  let pinButton = MVPinButton(frame: NSRect(x: 100, y: 125, width: 18, height: 18))

  /// 按钮小，点击区域往外扩一圈，好点
  var renameHitFrame: NSRect {
    self.renameButton.frame.insetBy(dx: -6, dy: -5)
  }
  /// 名字区域用来接「鼠标移入 / 移出」，好在悬停时提示可以改名
  var titleTrackingArea: NSTrackingArea?

  let minutesLabelSuffixWidth = "'".size(withAttributes: [.font: MVClockView.minutesFont]).width
  let minutesLabelSecondsSuffixWidth = "\"".size(withAttributes: [.font: MVClockView.minutesFont]).width
  let secondsSuffixWidth = "'".size(withAttributes: [.font: MVClockView.secondsFont]).width
  /// 上次算倒计时是哪一分钟；同一分钟内不用反复算（指定了时刻的倒计时要一分钟一跳）
  var countdownRefreshMinute: TimeInterval?
  /// 这个时钟关联的事件（从模板建出来的子时钟才有）：表盘显示它的倒计时
  var eventID: UUID?
  /// 轮播轮到第几个事件
  var rotationIndex = 0
  /// 轮播定时器：只在轮播模式开着、事件不止一个时跑
  var rotationTimer: Timer?

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
      if oldValue != self.mode {
        self.onModeChanged?(self.mode)
      }
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
    set {
      self.titleLabel.string = newValue
      self.layoutRenameButton()
    }
  }
  /// 子时钟可以改名（点名字右边的铅笔）；主时钟没有名字，不能改
  var isTitleEditable = false {
    didSet {
      // 主时钟没有名字，按钮整个不出现；子时钟常驻但半透明，鼠标移上去才变亮
      self.renameButton.isHidden = !self.isTitleEditable
      self.renameButton.alphaValue = self.isTitleEditable ? 0.75 : 0
      if !self.isTitleEditable {
        self.titleLabel.isSelectable = false
      }
    }
  }
  /// 正在输入名字：此时点击不起停时钟、Tab 也不切模式
  var isEditingTitle: Bool { !self.titleInputField.isHidden }
  /// 改名前的值，名字清空时回滚到它
  var titleBeforeEditing = ""
  /// 这一次点击只是为了给改名收尾，不要再顺手起停时钟
  var justEndedTitleEditing = false
  /// 回车提交改名后，那个 keyUp 会漏到快捷键里被当成"起停"，下一次 keyUp 要丢掉
  var swallowNextReturnKeyUp = false
  /// 按 s 键请求切换模式，只切这个时钟自己
  var onModeToggleRequest: (() -> Void)?
  /// 模式真的变了（Tab / s / 右键 / 模板都会走这里），用来同步窗口置顶
  var onModeChanged: ((TimerMode) -> Void)?
  /// 点左下角的图钉：切换「窗口置顶」
  var onToggleStaysOnTop: (() -> Void)?
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
  /// 真正起跑那一瞬间回调（秒表 / 有时长的倒计时），历史记录靠它记起始时间
  var onStart: (() -> Void)?
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
    for label in self.countdownLabels {
      self.addSubview(label)
    }
    self.addSubview(self.totalHoursLabel)
    self.addSubview(self.titleLabel)
    self.addSubview(self.renameButton)
    self.addSubview(self.controlButton)
    self.addSubview(self.pinButton)
    self.addSubview(self.titleInputField)

    self.titleInputField.delegate = self
    self.renameButton.isHidden = true
    self.renameButton.onTap = { [weak self] in self?.toggleTitleEditing() }
    self.controlButton.onTap = { [weak self] in self?.handleClick() }
    self.pinButton.onTap = { [weak self] in self?.onToggleStaysOnTop?() }
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

    // 起跑时就按当前的轮播开关把定时器带上；之后的起停靠通知
    self.syncRotationTimer()

    // 事件被增删改、折算方式改了、轮播切到下一个了、或者过了午夜：时钟停着时没人每秒刷新，倒计时得自己重算
    for name in [
      MVEventStore.didChangeNotification,
      MVEventSettings.didChangeNotification,
      Notification.Name.NSCalendarDayChanged
    ] {
      self.notificationTasks.append(
        Task { [weak self] in
          for await _ in NotificationCenter.default.mvNotifications(named: name) {
            self?.updateCountdownLabels(force: true)
            // 每日时长改了，正计时的蓝条占比也得跟着重画；
            // 轮播开关或事件个数变了，轮播定时器也要跟着起停
            self?.layoutSubviews()
            self?.syncRotationTimer()
          }
        }
      )
    }

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
