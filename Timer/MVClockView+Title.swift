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
    self.renameHintImageView.alphaValue = 0
    self.setTitleUnderlined(false)
    self.window?.makeFirstResponder(self.titleLabel)
    self.titleLabel.selectText(nil)
  }

  func endTitleEditing() {
    guard self.isEditingTitle else { return }

    let edited = self.titleLabel.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    self.clockTitle = edited.isEmpty ? self.titleBeforeEditing : edited
    self.titleLabel.isEditable = false
    self.titleLabel.isSelectable = self.isTitleEditable
    self.setTitleHovered(false)
    if self.window?.firstResponder === self.titleLabel {
      self.window?.makeFirstResponder(nil)
    }
    self.postAccessibilityValueChanged()
  }

  func controlTextDidEndEditing(_: Notification) {
    self.endTitleEditing()
  }

  /// 鼠标停在名字上：铅笔变亮，名字加下划线，暗示这块可以编辑
  func setTitleHovered(_ hovered: Bool) {
    guard self.isTitleEditable, !self.isEditingTitle else { return }

    self.layoutRenameHint()
    self.renameHintImageView.alphaValue = hovered ? 1 : 0.45
    self.setTitleUnderlined(hovered)
  }

  /// 铅笔紧跟在名字后面，名字太长就贴在右边不出界
  private func layoutRenameHint() {
    let font = self.titleLabel.font ?? NSFont.systemFont(ofSize: 10, weight: .medium)
    let textWidth = (self.titleLabel.stringValue as NSString).size(withAttributes: [.font: font]).width
    let hintX = min(self.titleLabel.frame.midX + textWidth / 2 + 4, self.bounds.width - 14)

    self.renameHintImageView.frame = NSRect(x: hintX, y: 2, width: 10, height: 12)
  }

  private func setTitleUnderlined(_ underlined: Bool) {
    let font = self.titleLabel.font ?? NSFont.systemFont(ofSize: 10, weight: .medium)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.white,
      .underlineStyle: underlined ? NSUnderlineStyle.single.rawValue : 0
    ]
    self.titleLabel.attributedStringValue = NSAttributedString(
      string: self.titleLabel.stringValue,
      attributes: attributes
    )
  }
}
