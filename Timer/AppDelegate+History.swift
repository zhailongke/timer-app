import AppKit

// MARK: - 历史记录

extension AppDelegate {
  /// 右键「历史记录…」：打开历史记录窗口
  @objc func showHistory(_: Any?) {
    MVHistoryWindowController.shared.show()
  }

  /// 直接退出时窗口不一定走 willClose，这里把还在的主时钟都记一笔，免得这次白跑
  func applicationWillTerminate(_: Notification) {
    for controller in self.controllers where controller.parentController == nil {
      controller.recordHistoryOnClose()
    }
  }
}
