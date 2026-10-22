import AppKit
import AVFoundation
import UserNotifications

final class MVTimerController: NSWindowController {
  private weak var dockMenuItem: NSMenuItem?
  let clockView = MVClockView()
  /// 这次计时在历史记录里的那条（一开始计时就有，关闭后清空）
  var recordID: UUID?

  /// 上级时钟；主时钟为 nil。关闭下级不影响上级，关闭上级会带走整棵子树
  private(set) weak var parentController: MVTimerController?
  /// 下级时钟。目前只能一层层往下加（同层并列留作后续）
  var childControllers: [MVTimerController] = []
  /// 主时钟为 0，子时钟按层级递增，界面上标记「子时钟N」
  private(set) var depth: Int = 0

  private var audioPlayer: AVAudioPlayer? // player must be kept in memory
  private var soundURL = Bundle.main.url(forResource: "alert-sound", withExtension: "caf")

  convenience init() {
    self.init(parent: nil)
  }

  convenience init(closeToWindow: NSWindow?) {
    self.init(parent: nil)

    // Secondary windows don't need autosave — clear it so they
    // don't overwrite the primary window's saved position.
    self.windowFrameAutosaveName = ""

    if let closeToWindow {
      var point = closeToWindow.frame.origin
      point.x += CGFloat(Int.random(in: -40...39))
      point.y += CGFloat(Int.random(in: -40...39))
      self.window?.setFrameOrigin(point)
    }
  }

  /// parent 非空时创建的是子时钟：标记层级、继承倒计时上限、摆在上级窗口旁边
  convenience init(parent: MVTimerController?) {
    let mainView = MVMainView(frame: .zero)

    let window = MVWindow(mainView: mainView)

    self.init(window: window)

    mainView.controller = self
    mainView.clockView = self.clockView
    self.clockView.onTimerComplete = { [weak self] in self?.handleClockTimer() }
    self.clockView.onStart = { [weak self] in self?.ensureHistoryRecord() }
    mainView.addSubview(self.clockView)
    self.dockMenuItem = mainView.menuItem

    self.windowFrameAutosaveName = "TimerWindowAutosaveFrame"

    let savedSound = UserDefaults.standard.integer(forKey: MVUserDefaultsKeys.soundIndex)
    if let sound = TimerLogic.soundFilename(forIndex: savedSound) {
      self.soundURL = Bundle.main.url(forResource: sound, withExtension: "caf")
    } else {
      self.soundURL = nil
    }

    if let parent {
      self.parentController = parent
      self.depth = parent.depth + 1
      parent.childControllers.append(self)
      self.clockView.parentClockView = parent.clockView
      self.clockView.clockTitle = "子时钟\(self.depth)"
      self.clockView.isTitleEditable = true
      self.windowFrameAutosaveName = ""
      window.setFrameOrigin(Self.originForChild(of: parent))
    }

    window.makeKeyAndOrderFront(self)
  }

  /// 子时钟摆在上级时钟右侧；右边放不下就换到下一行
  private static func originForChild(of parent: MVTimerController) -> NSPoint {
    guard let frame = parent.window?.frame else { return NSPoint(x: 200, y: 200) }

    let gap: CGFloat = 12
    var origin = NSPoint(x: frame.maxX + gap, y: frame.minY)

    if let screen = NSScreen.main?.visibleFrame {
      if origin.x + frame.width > screen.maxX {
        origin.x = frame.minX
        origin.y = frame.minY - frame.height - gap
      }
      if origin.y < screen.minY {
        origin.y = screen.maxY - frame.height
      }
    }
    return origin
  }

  deinit {
    MainActor.assumeIsolated {
      self.clockView.stop()
    }
  }

  func setMode(_ mode: TimerMode) {
    self.clockView.setMode(mode)
  }

  func showInDock(_ state: Bool) {
    self.clockView.inDock = state
    self.dockMenuItem?.state = state ? .on : .off
  }

  func windowVisibilityChanged(_ visible: Bool) {
    self.clockView.windowIsVisible = visible
  }

  private func playAlarmSound() {
    if let soundURL = self.soundURL {
      self.audioPlayer = try? AVAudioPlayer(contentsOf: soundURL)
      self.audioPlayer?.play()
    }
  }

  private func handleClockTimer() {
    let content = UNMutableNotificationContent()
    content.title = self.clockView.clockTitle.isEmpty ? "It's time! 🕘" : "\(self.clockView.clockTitle) 到点了 🕘"

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)

    NSApplication.shared.requestUserAttention(.criticalRequest)

    self.playAlarmSound()

    // 子时钟倒计时结束即自动关闭（连同它的下级）
    if self.parentController != nil {
      self.closeHierarchy()
    }
  }

  /// 是不是子时钟（有上级）；只有子时钟有名字、能改名、能存模板
  var isChild: Bool { self.parentController != nil }

  /// 右键「子时钟 ▸ 添加新的子时钟」：新建一个下级窗口，外观功能一致、独立计时
  @objc func addChildClock(_: Any?) {
    self.makeChildClock()
  }

  /// 新建一个子时钟并登记；名字默认「子时钟N」，秒表模式直接起跑
  @discardableResult
  func makeChildClock() -> MVTimerController? {
    guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return nil }

    let child = MVTimerController(parent: self)
    appDelegate.registerController(child)
    // 一建出来就挂到上级那条还没结束的记录下面（上级没建就一并建出来）
    child.ensureHistoryRecord()

    // 秒表模式的子时钟直接起跑，省掉新建后还要点一下
    if child.clockView.mode == .stopwatch {
      child.clockView.start()
    }
    return child
  }

  /// 关闭自己及所有下级；上级不受影响
  func closeHierarchy() {
    for child in self.childControllers {
      child.closeHierarchy()
    }
    self.window?.close()
  }

  /// Tab 键码；MVWindow 与这里共用，避免两处各写一份
  static let tabKeyCode: UInt16 = 48

  /// 正在输入框里打字（改名）：此时按键归输入框，不往下当时钟快捷键
  private var isTypingInTitle: Bool {
    guard self.clockView.isEditingTitle else { return false }
    guard let responder = self.window?.firstResponder else { return true }
    return responder === self.clockView.titleInputField || responder is NSText
  }

  override func keyUp(with event: NSEvent) {
    if self.isTypingInTitle { return }
    self.clockView.keyUp(with: event)
  }

  // Override required to suppress system beep on key press
  override func keyDown(with event: NSEvent) {
    if self.isTypingInTitle { return }

    if event.keyCode == Self.tabKeyCode {
      self.toggleMode()
      return
    }
    // Intentionally empty
  }

  /// Tab / s 键切换倒计时与秒表，实际切换统一交给 AppDelegate（含窗口置顶）
  func toggleMode() {
    // 正在改名字时 Tab 归输入框，不要切模式
    guard !self.clockView.isEditingTitle else { return }
    self.clockView.onModeToggleRequest?()
  }

  func pickSound(_ index: Int) {
    UserDefaults.standard.set(index, forKey: MVUserDefaultsKeys.soundIndex)
    if let sound = TimerLogic.soundFilename(forIndex: index) {
      self.soundURL = Bundle.main.url(forResource: sound, withExtension: "caf")
      self.playAlarmSound()
    } else {
      self.soundURL = nil
    }
  }
}
