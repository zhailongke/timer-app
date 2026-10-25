import AppKit
import UserNotifications

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  private(set) var controllers: [MVTimerController] = []
  private var currentlyInDock: MVTimerController?
  private var notificationTasks: [Task<Void, Never>] = []

  /// 窗口是否浮在其他窗口之上；默认开，打开就看得见
  private var staysOnTop = false {
    didSet {
      self.applyWindowPresentation()
      self.syncStaysOnTopControls()
    }
  }

  /// 新开窗口的默认模式：最近一次切到的那个。已经在跑的时钟互不影响
  private(set) var lastUsedMode: TimerMode = .stopwatch

  override init() {
    super.init()
    self.registerDefaults()
  }

  func applicationDidFinishLaunching(_: Notification) {
    MVMenu.installMainMenuIfNeeded()
    // 计时一开始就有记录，之后每秒刷新时长
    MVHistoryTracker.shared.startTicking()

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
    controller.clockView.pinButton.isPinned = self.staysOnTop
    controller.setMode(self.lastUsedMode)
    self.applyWindowPresentation()
  }

  // MARK: - 计时模式

  /// 某个时钟切了模式：只有它自己跟着变，顺手把它记成新窗口的默认模式
  func modeDidChange(to mode: TimerMode, in _: MVTimerController) {
    self.lastUsedMode = mode
  }

  @objc func toggleStaysOnTop(_ sender: NSMenuItem) {
    self.toggleStaysOnTop()
    sender.state = self.staysOnTop ? .on : .off
  }

  /// 图钉按钮走这里（没有菜单项，改完要把菜单里的勾选也刷新一遍）
  func toggleStaysOnTop() {
    let value = !self.staysOnTop
    UserDefaults.standard.set(value, forKey: MVUserDefaultsKeys.staysOnTop)
    self.staysOnTop = value
  }

  /// 图钉按钮和菜单栏里的「窗口置顶」都跟着当前状态走
  private func syncStaysOnTopControls() {
    for controller in self.controllers {
      controller.clockView.pinButton.isPinned = self.staysOnTop
    }
    let item = NSApplication.shared.mainMenu?.item(withTitle: "窗口")?.submenu?.item(withTitle: "窗口置顶")
    item?.state = self.staysOnTop ? .on : .off
  }

  private func handleClose(_ notification: MVNotification) {
    guard let window = notification.object as? NSWindow,
      let controller = window.windowController as? MVTimerController
    else { return }

    // 关掉 = 这一段记录到此结束；要在摘掉上下级关系之前记，子时钟才知道挂到谁下面
    controller.finalizeHistoryRecord()

    // 关掉一个时钟，它的所有下级跟着关（主时钟关闭 → 整棵树关闭）
    for child in controller.childControllers where child.window != nil {
      child.closeHierarchy()
    }
    controller.childControllers.removeAll()
    controller.parentController?.childControllers.removeAll { $0 === controller }

    // 关掉就真的放掉：否则控制器会留在列表里，下次打开又冒出来
    if self.currentlyInDock === controller {
      self.removeBadgeFromDock()
      self.currentlyInDock = nil
    }
    if let index = self.controllers.firstIndex(of: controller) {
      self.controllers.remove(at: index)
    }

    // 没有窗口了就退出，下次打开是一个干净的主时钟
    if self.controllers.isEmpty {
      Task { NSApplication.shared.terminate(nil) }
    }
  }

  private func handleOcclusionChange(_ notification: MVNotification) {
    if let window = notification.object as? NSWindow,
      let controller = window.windowController as? MVTimerController {
      controller.windowVisibilityChanged(window.occlusionState.contains(.visible))
    }
  }

  private func handleUserDefaultsChange() {
    // 先比一下再赋值：didSet 不管值变没变都会跑，而每次写盘都会来一次通知。
    // 不挡住的话，所有窗口的 level / collectionBehavior 会被反复重设，拖动窗口时会顿
    let staysOnTop = UserDefaults.standard.bool(forKey: MVUserDefaultsKeys.staysOnTop)
    if staysOnTop != self.staysOnTop {
      self.staysOnTop = staysOnTop
    }
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

  /// 置顶开着：浮在所有窗口之上，且能跟着去到每个 Space（含全屏 App 所在的那个）
  private func applyWindowPresentation() {
    for window in NSApplication.shared.windows {
      window.level = self.staysOnTop ? .floating : .normal
      if self.staysOnTop {
        window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
      } else {
        window.collectionBehavior.remove([.canJoinAllSpaces, .fullScreenAuxiliary])
      }
    }
  }

  private func registerDefaults() {
    UserDefaults.standard.register(defaults: [
      MVUserDefaultsKeys.staysOnTop: true,
      MVUserDefaultsKeys.soundIndex: 0
    ])
  }
}
