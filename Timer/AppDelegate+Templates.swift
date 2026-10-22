import AppKit

// MARK: - 模板管理

extension AppDelegate {
  /// 右键「子时钟 ▸ 管理模板…」：打开管理窗口，可以修改内容或删除模板
  @objc func manageTemplates(_: Any?) {
    MVTemplateManager.shared.show()
  }
}
