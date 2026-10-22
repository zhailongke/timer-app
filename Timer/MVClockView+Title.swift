import AppKit

// MARK: - 子时钟改名

/// 点名字右边的铅笔进入编辑；回车或点到别处结束，esc 撤销
extension MVClockView: NSTextFieldDelegate {
  func beginTitleEditing() {
    guard self.isTitleEditable, !self.isEditingTitle else { return }

    self.titleBeforeEditing = self.clockTitle
    self.titleLabel.isEditable = true
    self.titleLabel.isSelectable = true
    self.titleLabel.delegate = self
    self.renameHintImageView.alphaValue = 0
    self.setTitleUnderlined(false)

    // 面板可能不是 key window，那时 makeFirstResponder 会悄悄失败；
    // 没真的进到编辑态就回滚，绝不留一个「正在编辑」却打不了字的假状态
    if let window = self.window {
      if !window.isKeyWindow { window.makeKey() }
      window.makeFirstResponder(self.titleLabel)

      let editingStarted =
        self.titleLabel.currentEditor() != nil
        || window.firstResponder === self.titleLabel
        || window.firstResponder is NSText
      guard editingStarted else {
        self.titleLabel.isEditable = false
        self.titleLabel.isSelectable = self.isTitleEditable
        self.setTitleHovered(false)
        return
      }
    }

    self.titleLabel.selectText(nil)
  }

  func endTitleEditing() {
    guard self.isEditingTitle else { return }

    // 先关掉可编辑，controlTextDidEndEditing 回来时不会重复走一遍
    self.titleLabel.isEditable = false
    self.titleLabel.isSelectable = self.isTitleEditable
    self.window?.endEditing(for: nil)

    let edited = self.titleLabel.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    self.clockTitle = edited.isEmpty ? self.titleBeforeEditing : edited

    if self.window?.firstResponder === self.titleLabel {
      self.window?.makeFirstResponder(nil)
    }
    self.setTitleHovered(false)
    self.postAccessibilityValueChanged()
  }

  func controlTextDidEndEditing(_: Notification) {
    self.endTitleEditing()
  }

  /// 回车确认，esc 撤销（输入框里的默认行为会被窗口的按键处理吃掉，这里自己接）
  func control(
    _: NSControl,
    textView _: NSTextView,
    doCommandBy commandSelector: Selector
  ) -> Bool {
    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      self.endTitleEditing()
      return true
    }
    if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
      self.titleLabel.abortEditing()
      self.endTitleEditing()
      return true
    }
    return false
  }

  /// 鼠标停在名字上：铅笔变亮，名字加下划线，暗示这块可以编辑
  func setTitleHovered(_ hovered: Bool) {
    guard self.isTitleEditable, !self.isEditingTitle else { return }

    self.layoutRenameHint()
    self.renameHintImageView.alphaValue = hovered ? 1 : 0.6
    self.setTitleUnderlined(hovered)
  }

  /// 铅笔紧跟在名字后面，名字太长就贴在右边不出界
  func layoutRenameHint() {
    let font = self.titleLabel.font ?? NSFont.systemFont(ofSize: 10, weight: .medium)
    let textWidth = (self.titleLabel.stringValue as NSString).size(withAttributes: [.font: font]).width
    let hintX = min(self.titleLabel.frame.midX + textWidth / 2 + 4, self.bounds.width - 16)

    self.renameHintImageView.frame = NSRect(x: hintX, y: 1, width: 12, height: 14)
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
