import AppKit

// MARK: - 子时钟改名

/// 点名字右边的蓝色按钮 → 同一个位置盖一个真输入框；回车确认，esc 撤销，点别处也算确认
extension MVClockView: NSTextFieldDelegate {
  /// 输入框里正在敲的内容
  var titleDraft: String {
    get { self.titleInputField.stringValue }
    set { self.titleInputField.stringValue = newValue }
  }

  /// 点按钮：没在改名就进入，已经在改名就是完成
  func toggleTitleEditing() {
    if self.isEditingTitle {
      self.endTitleEditing()
    } else {
      self.beginTitleEditing()
    }
  }

  func beginTitleEditing() {
    guard self.isTitleEditable, !self.isEditingTitle else { return }

    self.titleBeforeEditing = self.clockTitle
    self.titleDraft = self.clockTitle
    self.layoutTitleInput()

    self.titleLabel.isHidden = true
    self.titleInputField.isHidden = false
    self.renameButton.isHidden = true

    if let window = self.window {
      if !window.isKeyWindow { window.makeKey() }
      window.makeFirstResponder(self.titleInputField)
    }
    // 全选，直接打字就替掉旧名字
    self.titleInputField.currentEditor()?.selectAll(nil)
  }

  func endTitleEditing() {
    guard self.isEditingTitle else { return }

    // field editor 里的字还没刷回 field，得从编辑器读；读不到就用 field 的值
    let draft = self.titleInputField.currentEditor()?.string ?? self.titleDraft
    // 先收起来：endEditing 触发的回调回来时 isEditingTitle 已经是 false，不会重入
    self.titleInputField.isHidden = true
    self.window?.endEditing(for: nil)

    self.titleLabel.isHidden = false
    self.renameButton.isHidden = !self.isTitleEditable
    self.clockTitle = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? self.titleBeforeEditing
      : draft.trimmingCharacters(in: .whitespacesAndNewlines)

    if self.window?.firstResponder is NSText {
      self.window?.makeFirstResponder(nil)
    }
    self.setTitleHovered(false)
    self.postAccessibilityValueChanged()
  }

  func controlTextDidEndEditing(_ notification: Notification) {
    guard notification.object as? NSView === self.titleInputField else { return }
    self.endTitleEditing()
  }

  /// 一边打字一边把输入框撑到合适的宽度
  func controlTextDidChange(_ notification: Notification) {
    guard notification.object as? NSView === self.titleInputField else { return }
    self.layoutTitleInput()
  }

  /// 回车确认，esc 撤销（输入框里的默认行为会被窗口的按键处理吃掉，这里自己接）
  func control(
    _ control: NSControl,
    textView _: NSTextView,
    doCommandBy commandSelector: Selector
  ) -> Bool {
    guard control === self.titleInputField else { return false }

    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      // 这次回车到此为止，别让它的 keyUp 漏出去当成"起停"
      self.swallowNextReturnKeyUp = true
      self.endTitleEditing()
      return true
    }
    if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
      self.titleInputField.abortEditing() // 丢掉输入，恢复成旧名字
      self.endTitleEditing()
      return true
    }
    return false
  }

  /// 默认只给一个短短的框，名字长了再跟着变宽，两边留白、整体居中
  private func layoutTitleInput() {
    let font = self.titleInputField.font ?? NSFont.systemFont(ofSize: 10, weight: .medium)
    let textWidth = (self.titleDraft as NSString).size(withAttributes: [.font: font]).width
    let width = min(max(textWidth + 26, 62), self.titleLabel.frame.width)

    self.titleInputField.frame = NSRect(
      x: self.titleLabel.frame.midX - width / 2,
      y: self.titleLabel.frame.midY - 8,
      width: width,
      height: 16
    )
  }

  /// 鼠标停在名字上：按钮变亮，名字加下划线，暗示这块可以编辑
  func setTitleHovered(_ hovered: Bool) {
    guard self.isTitleEditable, !self.isEditingTitle else { return }

    self.layoutRenameButton()
    self.renameButton.alphaValue = hovered ? 1 : 0.75
    self.setTitleUnderlined(hovered)
  }

  /// 按钮紧跟在名字后面，和文字同一中线；名字太长就贴在右边不出界
  func layoutRenameButton() {
    let font = self.titleLabel.font ?? NSFont.systemFont(ofSize: 10, weight: .medium)
    let textWidth = (self.titleLabel.stringValue as NSString).size(withAttributes: [.font: font]).width
    let side: CGFloat = 14
    let buttonX = min(self.titleLabel.frame.midX + textWidth / 2 + 4, self.bounds.width - 18)

    self.renameButton.frame = NSRect(
      x: buttonX,
      y: self.titleLabel.frame.midY - side / 2,
      width: side,
      height: side
    )
  }

  /// 必须带上段落样式：attributedStringValue 一设，文本框自己的 alignment 就失效了，
  /// 少了 .paragraphStyle 文字会跳到左边（框在 x=6，看着就像跑到左下角）
  private func setTitleUnderlined(_ underlined: Bool) {
    let font = self.titleLabel.font ?? NSFont.systemFont(ofSize: 10, weight: .medium)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byTruncatingTail

    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.white,
      .paragraphStyle: paragraph,
      .underlineStyle: underlined ? NSUnderlineStyle.single.rawValue : 0
    ]
    self.titleLabel.attributedStringValue = NSAttributedString(
      string: self.titleLabel.stringValue,
      attributes: attributes
    )
  }
}
