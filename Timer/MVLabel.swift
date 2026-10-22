import AppKit

final class MVLabel: NSTextField {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    self.isEditable = false
    self.isSelectable = false
    self.isBezeled = false
    self.drawsBackground = false
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Convenience to match the NSTextView `string` API used throughout the codebase.
  var string: String {
    get { self.stringValue }
    set { self.stringValue = newValue }
  }

  /// Sets the font for a specific range of the displayed text.
  func setFont(_ font: NSFont, range: NSRange) {
    let attributed = NSMutableAttributedString(attributedString: self.attributedStringValue)
    attributed.addAttribute(.font, value: font, range: range)
    self.attributedStringValue = attributed
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    // 改名中的标题要接住点击（放光标）；其余标签一律透传给上层
    self.isEditable ? super.hitTest(point) : nil
  }

  /// 文本长度会变时（如秒表的「时:分:秒」）用它挑一个放得下的最大等宽字号
  static func monospacedDigitFont(
    fitting text: String,
    maxWidth: CGFloat,
    maxSize: CGFloat = 30
  ) -> NSFont {
    var size = maxSize
    while size > 12 {
      let font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
      if text.size(withAttributes: [.font: font]).width <= maxWidth {
        return font
      }
      size -= 1
    }
    return NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
  }
}
