import AppKit

// MARK: - 事件进度

extension AppDelegate {
  /// 右键「事件进度…」：打开管理窗口，加 / 改 / 删事件
  @objc func showTimerEvents(_: Any?) {
    MVEventManager.shared.show()
  }

  /// 右键「倒计时显示 ▸ 某事件」：表盘下方固定显示这条
  @objc func pickDisplayedEvent(_ sender: NSMenuItem) {
    guard let eventID = sender.representedObject as? UUID else { return }

    // 选了具体哪条，就把轮播关掉；轮播开着时这个勾只是个指示
    if MVEventSettings.isRotating() {
      MVEventSettings.save(isRotating: false)
    }
    MVEventSettings.save(selectedEventID: eventID)
  }

  /// 右键「倒计时显示 ▸ 轮播显示」：每隔几秒自动换一个事件
  @objc func toggleEventRotation(_ sender: NSMenuItem) {
    MVEventSettings.save(isRotating: sender.state != .on)
  }
}
