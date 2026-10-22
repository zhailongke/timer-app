import AppKit

// MARK: - 子时钟改名

/// 名字在圆框外，双击进入编辑；回车或点到别处结束，esc 撤销
extension MVClockView: NSTextFieldDelegate {
  func beginTitleEditing() {
    guard self.isTitleEditable, !self.isEditingTitle else { return }

    self.titleBeforeEditing = self.clockTitle
    self.titleLabel.isEditable = true
    self.titleLabel.isSelectable = true
    self.titleLabel.delegate = self
    self.window?.makeFirstResponder(self.titleLabel)
    self.titleLabel.selectText(nil)
  }

  func endTitleEditing() {
    guard self.isEditingTitle else { return }

    let edited = self.titleLabel.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    self.clockTitle = edited.isEmpty ? self.titleBeforeEditing : edited
    self.titleLabel.isEditable = false
    self.titleLabel.isSelectable = self.isTitleEditable
    if self.window?.firstResponder === self.titleLabel {
      self.window?.makeFirstResponder(nil)
    }
    self.postAccessibilityValueChanged()
  }

  func controlTextDidEndEditing(_: Notification) {
    self.endTitleEditing()
  }
}
