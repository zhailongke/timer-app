import AppKit

// MARK: - 关键日子

extension AppDelegate {
  /// 右键「关键日子…」：打开管理窗口，加 / 改 / 删要在表盘上倒计时的日子
  @objc func showKeyDates(_: Any?) {
    MVKeyDateManager.shared.show()
  }
}
