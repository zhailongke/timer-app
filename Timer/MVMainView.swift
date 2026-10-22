import AppKit

final class MVMainView: NSView {
  private static let backgroundGradient = NSGradient(colors: [
    MVResource.color("backgroundTop"),
    MVResource.color("backgroundBottom")
  ])

  weak var controller: MVTimerController? {
    didSet {
      self.addChildMenuItem.target = self.controller
      self.saveTemplateMenuItem.target = self.controller
    }
  }

  weak var clockView: MVClockView? {
    didSet { self.tileClockView() }
  }

  private let contextMenu = NSMenu(title: "菜单")
  private(set) var menuItem: NSMenuItem?

  /// 计时模式：倒计时 / 秒表两个开关收在同一个子菜单里
  private let modeMenuItem = NSMenuItem(title: "计时模式", action: nil, keyEquivalent: "")

  private let countdownMenuItem = NSMenuItem(
    title: "倒计时模式",
    action: #selector(AppDelegate.switchToCountdown(_:)),
    keyEquivalent: ""
  )

  private let stopwatchMenuItem = NSMenuItem(
    title: "秒表模式",
    action: #selector(AppDelegate.switchToStopwatch(_:)),
    keyEquivalent: ""
  )

  /// 子时钟：新建、按模板新建、把当前子时钟存成模板
  private let childMenuItem = NSMenuItem(title: "子时钟", action: nil, keyEquivalent: "")

  private let addChildMenuItem = NSMenuItem(
    title: "添加新的子时钟",
    action: #selector(MVTimerController.addChildClock(_:)),
    keyEquivalent: ""
  )

  private let templateMenuItem = NSMenuItem(title: "从模板选择", action: nil, keyEquivalent: "")
  private let templateMenu = NSMenu(title: "从模板选择")
  private let childMenuSeparator = NSMenuItem.separator()

  private let saveTemplateMenuItem = NSMenuItem(
    title: "保存为模板…",
    action: #selector(MVTimerController.saveAsTemplate(_:)),
    keyEquivalent: ""
  )

  /// 模板管理窗口：改名 / 改模式时长 / 删除
  private let manageTemplatesMenuItem = NSMenuItem(
    title: "管理模板…",
    action: #selector(AppDelegate.manageTemplates(_:)),
    keyEquivalent: ""
  )

  override var menu: NSMenu? {
    get { self.contextMenu }
    set { /* ignored */ }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    self.countdownMenuItem.target = NSApplication.shared.delegate
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
    let menuItemSoundChoice = NSMenuItem(
      title: "提示音",
      action: nil,
      keyEquivalent: ""
    )

    let modeMenu = NSMenu(title: "计时模式")
    modeMenu.addItem(self.countdownMenuItem)
    modeMenu.addItem(self.stopwatchMenuItem)

    let childMenu = NSMenu(title: "子时钟")
    childMenu.addItem(self.addChildMenuItem)
    childMenu.addItem(self.templateMenuItem)
    childMenu.addItem(self.childMenuSeparator)
    childMenu.addItem(self.saveTemplateMenuItem)
    childMenu.addItem(self.manageTemplatesMenuItem)
    childMenu.setSubmenu(self.templateMenu, for: self.templateMenuItem)

    self.manageTemplatesMenuItem.target = NSApplication.shared.delegate

    self.contextMenu.addItem(self.modeMenuItem)
    self.contextMenu.addItem(self.childMenuItem)
    if let menuItem = self.menuItem {
      self.contextMenu.addItem(menuItem)
    }
    self.contextMenu.addItem(menuItemSoundChoice)
    self.contextMenu.setSubmenu(self.soundMenu(), for: menuItemSoundChoice)
    self.contextMenu.setSubmenu(modeMenu, for: self.modeMenuItem)
    self.contextMenu.setSubmenu(childMenu, for: self.childMenuItem)
    self.contextMenu.delegate = self
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func soundMenu() -> NSMenu {
    let menu = NSMenu(title: "提示音")
    let soundOptions = [
      (title: "提示音 1", value: 0),
      (title: "提示音 2", value: 1),
      (title: "提示音 3", value: 2),
      (title: "无提示音", value: -1)
    ]
    let savedSoundIndex = UserDefaults.standard.integer(forKey: MVUserDefaultsKeys.soundIndex)
    for option in soundOptions {
      let item = NSMenuItem(title: option.title, action: #selector(self.pickSound(_:)), keyEquivalent: "")
      item.target = self
      item.tag = option.value
      item.state = option.value == savedSoundIndex ? .on : .off
      menu.addItem(item)
    }
    return menu
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
    self.countdownMenuItem.state = appDelegate.currentMode == .countdown ? .on : .off
    self.stopwatchMenuItem.state = appDelegate.currentMode == .stopwatch ? .on : .off

    // 只有子时钟有名字，主时钟不显示「保存为模板」
    let isChild = self.controller?.isChild ?? false
    self.saveTemplateMenuItem.isHidden = !isChild
    self.childMenuSeparator.isHidden = !isChild

    self.rebuildTemplateMenu()
  }

  /// 模板列表每次开菜单重建，改名/新存都能立刻看到
  private func rebuildTemplateMenu() {
    self.templateMenu.removeAllItems()

    let templates = MVTemplateStore.load()
    guard !templates.isEmpty else {
      let emptyItem = NSMenuItem(title: "暂无模板", action: nil, keyEquivalent: "")
      emptyItem.isEnabled = false
      self.templateMenu.addItem(emptyItem)
      return
    }

    for template in templates {
      let item = NSMenuItem(
        title: template.name,
        action: #selector(MVTimerController.addChildClockFromTemplate(_:)),
        keyEquivalent: ""
      )
      item.target = self.controller
      item.representedObject = template
      item.toolTip = template.summary
      self.templateMenu.addItem(item)
    }
  }
}
