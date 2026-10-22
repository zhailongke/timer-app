import AppKit

/// 用代码构建主菜单。Xcode 构建时 MainMenu.xib 已经提供菜单，此处不会重复安装；
/// 无 Xcode 构建（Scripts/build.sh）没有 nib，靠这里补上菜单栏。
@MainActor
enum MVMenu {
  static func installMainMenuIfNeeded() {
    let app = NSApplication.shared
    guard app.mainMenu == nil else { return }

    let mainMenu = NSMenu(title: "主菜单")
    mainMenu.addItem(Self.applicationMenuItem(for: app))
    mainMenu.addItem(Self.fileMenuItem())

    let windowMenuItem = Self.windowMenuItem()
    mainMenu.addItem(windowMenuItem)
    app.windowsMenu = windowMenuItem.submenu

    app.mainMenu = mainMenu
  }

  // MARK: - 应用菜单

  private static func applicationMenuItem(for app: NSApplication) -> NSMenuItem {
    let item = NSMenuItem()
    let menu = NSMenu(title: "Timer")
    menu.addItem(
      withTitle: "关于 Timer",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
      keyEquivalent: ""
    )
    menu.addItem(.separator())

    let servicesItem = NSMenuItem(title: "服务", action: nil, keyEquivalent: "")
    let servicesMenu = NSMenu(title: "服务")
    servicesItem.submenu = servicesMenu
    app.servicesMenu = servicesMenu
    menu.addItem(servicesItem)
    menu.addItem(.separator())

    menu.addItem(
      withTitle: "隐藏 Timer", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    let hideOthersItem = NSMenuItem(
      title: "隐藏其他",
      action: #selector(NSApplication.hideOtherApplications(_:)),
      keyEquivalent: "h"
    )
    hideOthersItem.keyEquivalentModifierMask = [.command, .option]
    menu.addItem(hideOthersItem)
    menu.addItem(
      withTitle: "显示全部",
      action: #selector(NSApplication.unhideAllApplications(_:)),
      keyEquivalent: ""
    )
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "退出 Timer",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    item.submenu = menu
    return item
  }

  // MARK: - 文件菜单

  private static func fileMenuItem() -> NSMenuItem {
    let item = NSMenuItem()
    let menu = NSMenu(title: "文件")
    menu.addItem(
      withTitle: "新建",
      action: #selector(AppDelegate.newDocument(_:)),
      keyEquivalent: "n"
    )
    menu.addItem(
      withTitle: "关闭",
      action: #selector(NSWindow.performClose(_:)),
      keyEquivalent: "w"
    )
    item.submenu = menu
    return item
  }

  // MARK: - 窗口菜单

  private static func windowMenuItem() -> NSMenuItem {
    let item = NSMenuItem()
    let menu = NSMenu(title: "窗口")
    menu.addItem(
      withTitle: "最小化",
      action: #selector(NSWindow.performMiniaturize(_:)),
      keyEquivalent: "m"
    )
    menu.addItem(
      withTitle: "缩放",
      action: #selector(NSWindow.performZoom(_:)),
      keyEquivalent: ""
    )

    let staysOnTopItem = NSMenuItem(
      title: "窗口置顶",
      action: #selector(AppDelegate.toggleStaysOnTop(_:)),
      keyEquivalent: ""
    )
    staysOnTopItem.target = NSApplication.shared.delegate
    let staysOnTop = UserDefaults.standard.bool(forKey: MVUserDefaultsKeys.staysOnTop)
    staysOnTopItem.state = staysOnTop ? .on : .off
    menu.addItem(staysOnTopItem)

    menu.addItem(.separator())
    menu.addItem(
      withTitle: "前置全部窗口",
      action: #selector(NSApplication.arrangeInFront(_:)),
      keyEquivalent: ""
    )
    item.submenu = menu
    return item
  }
}
