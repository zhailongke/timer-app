import AppKit

final class MVMainView: NSView {
  private static let backgroundGradient = NSGradient(colors: [
    MVResource.color("backgroundTop"),
    MVResource.color("backgroundBottom")
  ])

  weak var controller: MVTimerController?
  weak var clockView: MVClockView? {
    didSet { self.tileClockView() }
  }

  private let contextMenu = NSMenu(title: "菜单")
  private(set) var menuItem: NSMenuItem?

  private let stopwatchMenuItem = NSMenuItem(
    title: "秒表模式",
    action: #selector(AppDelegate.toggleStopwatchMode(_:)),
    keyEquivalent: ""
  )

  override var menu: NSMenu? {
    get { self.contextMenu }
    set { /* ignored */ }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    self.stopwatchMenuItem.target = NSApplication.shared.delegate

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.windowDidResize(_:)),
      name: NSWindow.didResizeNotification,
      object: nil
    )

    self.menuItem = NSMenuItem(
      title: "在 Dock 中显示角标",
      action: #selector(self.toggleShowInDock),
      keyEquivalent: ""
    )
    let submenu = NSMenu()
    let menuItemSoundChoice = NSMenuItem(
      title: "提示音",
      action: nil,
      keyEquivalent: ""
    )
    let soundOptions = [
      (title: "提示音 1", value: 0),
      (title: "提示音 2", value: 1),
      (title: "提示音 3", value: 2),
      (title: "无提示音", value: -1)
    ]
    let savedSoundIndex = UserDefaults.standard.integer(forKey: MVUserDefaultsKeys.soundIndex)
    for option in soundOptions {
      let soundItem = NSMenuItem(title: option.title, action: #selector(self.pickSound), keyEquivalent: "")
      soundItem.tag = option.value
      soundItem.state = option.value == savedSoundIndex ? .on : .off
      submenu.addItem(soundItem)
    }

    self.contextMenu.addItem(self.stopwatchMenuItem)
    if let menuItem = self.menuItem {
      self.contextMenu.addItem(menuItem)
    }
    self.contextMenu.addItem(menuItemSoundChoice)
    self.contextMenu.setSubmenu(submenu, for: menuItemSoundChoice)
    self.contextMenu.delegate = self
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc func toggleShowInDock() {
    guard let appDelegate = NSApplication.shared.delegate as? AppDelegate,
          let controller = self.controller else { return }

    if self.menuItem?.state == .on {
      appDelegate.removeBadgeFromDock()
    } else {
      appDelegate.addBadgeToDock(controller: controller)
    }
  }

  @objc func pickSound(_ sender: NSMenuItem) {
    for item in sender.menu?.items ?? [] {
      item.state = item == sender ? .on : .off
    }
    self.controller?.pickSound(sender.tag)
  }

  override func draw(_: NSRect) {
    let radius: CGFloat = 4.53
    let path = NSBezierPath(roundedRect: self.bounds, xRadius: radius, yRadius: radius)
    Self.backgroundGradient?.draw(in: path, angle: -90)
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    self.tileClockView()
  }

  @objc private func windowDidResize(_ notification: Notification) {
    guard let window = notification.object as? NSWindow, window === self.window else { return }
    self.tileClockView()
  }

  /// 主视图始终铺满整个窗口外框（含标题栏区域），不依赖 autoresizing 是否被触发
  private func fillWindow() {
    guard let window = self.window else { return }
    let size = window.frame.size
    if abs(self.frame.width - size.width) > 0.5 || abs(self.frame.height - size.height) > 0.5 {
      self.frame = NSRect(origin: .zero, size: size)
    }
  }

  /// 时钟始终居中且保持正方形；bounds 固定为设计尺寸，靠 frame / bounds 比值等比放大内容
  private func tileClockView() {
    guard let clockView = self.clockView else { return }
    let side = min(self.bounds.width, self.bounds.height)
    clockView.frame = NSRect(
      x: round((self.bounds.width - side) / 2),
      y: round((self.bounds.height - side) / 2),
      width: side,
      height: side
    )
    clockView.bounds = NSRect(x: 0, y: 0, width: MVClockView.designSize, height: MVClockView.designSize)
  }
}

extension MVMainView: NSMenuDelegate {
  func menuWillOpen(_: NSMenu) {
    guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
    self.stopwatchMenuItem.state = appDelegate.currentMode == .stopwatch ? .on : .off
  }
}
