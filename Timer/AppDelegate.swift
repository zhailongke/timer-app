import AppKit
import UserNotifications

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  private var controllers: [MVTimerController] = []
  private var currentlyInDock: MVTimerController?
  private var notificationTasks: [Task<Void, Never>] = []

  private var staysOnTop = false {
    didSet {
      self.applyWindowPresentation()
    }
  }

  /// 启动即为秒表模式；按 Tab（或 s）切回倒计时
  private(set) var currentMode: TimerMode = .stopwatch

  override init() {
    super.init()
    self.registerDefaults()
  }

  func applicationDidFinishLaunching(_: Notification) {
    MVMenu.installMainMenuIfNeeded()

    let controller = MVTimerController()
    self.registerController(controller)
    self.addBadgeToDock(controller: controller)

    UNUserNotificationCenter.current().delegate = self
    Task {
      do {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
      } catch {
        NSLog("Notification authorization failed: %@", error.localizedDescription)
      }
    }

    self.observeNotifications()
    self.staysOnTop = UserDefaults.standard.bool(forKey: MVUserDefaultsKeys.staysOnTop)
    self.applyWindowPresentation()

    let parsed = Self.parseLaunchArguments(CommandLine.arguments)
    if let command = parsed.command {
      self.handleTimerCommand(command, window: parsed.window)
    }
  }

  func application(_: NSApplication, open urls: [URL]) {
    guard let url = urls.first, url.scheme == "timer" else { return }
    // Parse raw string to avoid URL treating ":" as port separator
    // e.g. timer://2:30?window=2 → command "2:30", window 2
    var raw = url.absoluteString
      .replacingOccurrences(of: "timer://", with: "")
      .removingPercentEncoding ?? ""
    var window: Int?
    if let queryStart = raw.firstIndex(of: "?") {
      let query = String(raw[raw.index(after: queryStart)...])
      raw = String(raw[..<queryStart])
      for param in query.split(separator: "&") {
        let pair = param.split(separator: "=", maxSplits: 1)
        if pair.count == 2, pair[0] == "window", let value = Int(pair[1]) {
          window = value
        }
      }
    }
    while raw.hasSuffix("/") { raw.removeLast() }
    self.handleTimerCommand(raw, window: window)
  }

  func handleTimerCommand(_ input: String, window: Int? = nil) {
    if input.lowercased() == "new" {
      self.newDocument(nil)
      return
    }

    let index = (window ?? 1) - 1
    guard self.controllers.indices.contains(index) else { return }
    let controller = self.controllers[index]
    let clockView = controller.clockView

    switch input.lowercased() {
    case "stop":
      clockView.paused = false
      clockView.stop()

    case "reset":
      clockView.paused = false
      clockView.stop()
      clockView.seconds = 0
      clockView.updateTimerTime()
      clockView.inputSeconds = false

    case "pause":
      if clockView.timerTask != nil {
        clockView.paused = true
        clockView.stop()
      } else if clockView.paused, clockView.seconds > 0 {
        clockView.updateTimerTime()
        clockView.start()
      }

    default:
      guard let seconds = self.parseTimeInput(input), seconds > 0 else { return }
      // 显式时长就是倒计时，先把全局模式对齐，再启动（默认秒表下也要能这样用）
      if self.currentMode != .countdown {
        self.toggleStopwatchMode()
      }
      clockView.startTimer(seconds: seconds)
    }

    controller.window?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  static func parseLaunchArguments(_ args: [String]) -> (command: String?, window: Int?) {
    // args[0] is the executable path; skip it
    var command: String?
    var window: Int?
    var skip = false
    for idx in 1..<args.count {
      if skip { skip = false; continue }
      if args[idx] == "--window" {
        if idx + 1 < args.count, let value = Int(args[idx + 1]) {
          window = value
          skip = true
        }
      } else {
        command = args[idx]
      }
    }
    return (command, window)
  }

  private static let maxTimerSeconds: CGFloat = 24 * 60 * 60 // 24 hours

  private func parseTimeInput(_ input: String) -> CGFloat? {
    let seconds: CGFloat

    // "2:50" → 2 minutes 50 seconds (colon = literal minutes:seconds)
    if input.contains(":") {
      let parts = input.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
      guard parts.count == 2, let minutes = Double(parts[0]), let secs = Double(parts[1]) else { return nil }
      seconds = CGFloat(minutes * 60 + secs)
    } else if let value = Double(input) {
      // "2.5" → 2.5 minutes = 2m30s (dot = fractional minutes)
      seconds = CGFloat(value * 60)
    } else {
      return nil
    }

    guard seconds.isFinite, seconds <= Self.maxTimerSeconds else { return nil }
    return seconds
  }

  func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
    for window in NSApplication.shared.windows {
      window.makeKeyAndOrderFront(self)
    }
    return true
  }

  nonisolated func userNotificationCenter(
    _: UNUserNotificationCenter,
    willPresent _: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
  }

  func addBadgeToDock(controller: MVTimerController) {
    if self.currentlyInDock != controller {
      self.removeBadgeFromDock()
    }
    self.currentlyInDock = controller
    controller.showInDock(true)
  }

  func removeBadgeFromDock() {
    self.currentlyInDock?.showInDock(false)
  }

  @objc func newDocument(_: AnyObject?) {
    let controller = MVTimerController(closeToWindow: NSApplication.shared.keyWindow)
    self.registerController(controller)
  }

  /// 登记新窗口（主窗口、CMD+N 新窗口、子时钟都走这里）
  func registerController(_ controller: MVTimerController) {
    self.controllers.append(controller)
    controller.clockView.onModeToggleRequest = { [weak self] in self?.toggleStopwatchMode() }
    controller.setMode(self.currentMode)
    self.applyWindowPresentation()
  }

  // MARK: - 秒表模式

  /// 在倒计时 / 秒表之间切换，切换即重置
  @objc func toggleStopwatchMode() {
    self.currentMode = self.currentMode == .countdown ? .stopwatch : .countdown
    for controller in self.controllers {
      controller.setMode(self.currentMode)
    }
    self.applyWindowPresentation()
  }

  @objc func toggleStopwatchMode(_ sender: NSMenuItem) {
    self.toggleStopwatchMode()
    sender.state = self.currentMode == .stopwatch ? .on : .off
  }

  @objc func toggleStaysOnTop(_ sender: NSMenuItem) {
    let value = !UserDefaults.standard.bool(forKey: MVUserDefaultsKeys.staysOnTop)
    UserDefaults.standard.set(value, forKey: MVUserDefaultsKeys.staysOnTop)
    sender.state = value ? .on : .off
  }

  private func handleClose(_ notification: MVNotification) {
    guard let window = notification.object as? NSWindow,
      let controller = window.windowController as? MVTimerController
    else { return }

    // 关掉一个时钟，它的所有下级跟着关（主时钟关闭 → 整棵树关闭）
    for child in controller.childControllers where child.window != nil {
      child.closeHierarchy()
    }
    controller.childControllers.removeAll()
    controller.parentController?.childControllers.removeAll { $0 === controller }

    if controller != self.currentlyInDock,
      let index = self.controllers.firstIndex(of: controller) {
      self.controllers.remove(at: index)
    }
  }

  private func handleOcclusionChange(_ notification: MVNotification) {
    if let window = notification.object as? NSWindow,
      let controller = window.windowController as? MVTimerController {
      controller.windowVisibilityChanged(window.occlusionState.contains(.visible))
    }
  }

  private func handleUserDefaultsChange() {
    self.staysOnTop = UserDefaults.standard.bool(forKey: MVUserDefaultsKeys.staysOnTop)
  }

  private func observeNotifications() {
    self.notificationTasks.append(
      Task { [weak self] in
        for await notification in NotificationCenter.default.mvNotifications(named: NSWindow.willCloseNotification) {
          self?.handleClose(notification)
        }
      }
    )

    self.notificationTasks.append(
      Task { [weak self] in
        for await _ in NotificationCenter.default.mvNotifications(named: UserDefaults.didChangeNotification) {
          self?.handleUserDefaultsChange()
        }
      }
    )

    self.notificationTasks.append(
      Task { [weak self] in
        for await notification in NotificationCenter.default.mvNotifications(
          named: NSWindow.didChangeOcclusionStateNotification
        ) {
          self?.handleOcclusionChange(notification)
        }
      }
    )
  }

  deinit {
    MainActor.assumeIsolated {
      self.notificationTasks.forEach { $0.cancel() }
    }
  }

  private var windowLevel: NSWindow.Level {
    (self.staysOnTop || self.currentMode == .stopwatch) ? .floating : .normal
  }

  /// 秒表要求"悬停在任何窗口之上"：浮窗级别 + 可加入所有 Space（含全屏 App 所在 Space）
  private func applyWindowPresentation() {
    for window in NSApplication.shared.windows {
      window.level = self.windowLevel
      if self.currentMode == .stopwatch {
        window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
      } else {
        window.collectionBehavior.remove([.canJoinAllSpaces, .fullScreenAuxiliary])
      }
    }
  }

  private func registerDefaults() {
    UserDefaults.standard.register(defaults: [
      MVUserDefaultsKeys.staysOnTop: false,
      MVUserDefaultsKeys.soundIndex: 0
    ])
  }
}
