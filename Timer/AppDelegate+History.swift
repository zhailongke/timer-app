import AppKit

// MARK: - 历史记录

extension AppDelegate {
  /// 右键「历史记录…」：打开历史记录窗口
  @objc func showHistory(_: Any?) {
    MVHistoryWindowController.shared.show()
  }

  /// 退出 App：还在跑的记录都收尾（不然会一直挂着「至今」）
  func applicationWillTerminate(_: Notification) {
    MVHistoryTracker.shared.finalizeAll()
    MVHistoryTracker.shared.flush()
  }
}
