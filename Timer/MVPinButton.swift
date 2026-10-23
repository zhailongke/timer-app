import AppKit

/// 左上角的置顶按钮：圆点 + 图钉，跟右上角的起停按钮同一套样式。
/// 置顶：亮蓝实心 + 完整图钉；不置顶：半透明白 + 划掉的图钉，一眼能分清
final class MVPinButton: NSView {
  /// 是否置顶：跟着换底色和符号（完整图钉 / 划掉的图钉）
  var isPinned = true {
    didSet {
      self.updateSymbol()
      self.needsDisplay = true
    }
  }

  /// 点一下切换置顶，交给 AppDelegate 统一改（菜单栏里的「窗口置顶」跟着变）
  var onTap: (() -> Void)?

  private var isPressed = false {
    didSet { self.needsDisplay = true }
  }

  private let symbolView: NSImageView = {
    let view = NSImageView(frame: .zero)
    view.contentTintColor = .white
    return view
  }()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.toolTip = "窗口置顶"
    self.addSubview(self.symbolView)
    self.updateSymbol()
    self.layoutSymbol()
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    self.layoutSymbol()
  }

  /// 图钉占圆点的一半高，居中放
  private func layoutSymbol() {
    let side = min(self.bounds.width, self.bounds.height) * 0.5
    self.symbolView.frame = NSRect(
      x: (self.bounds.width - side) / 2,
      y: (self.bounds.height - side) / 2,
      width: side,
      height: side
    )
  }

  private func updateSymbol() {
    // 两个状态用两个不同的符号：实心图钉 = 钉住了，划掉的图钉 = 没钉
    let symbol = NSImage(
      systemSymbolName: self.isPinned ? "pin.fill" : "pin.slash",
      accessibilityDescription: "置顶"
    )
    symbol?.isTemplate = true
    self.symbolView.image = symbol
    self.toolTip = self.isPinned ? "已置顶，点击取消" : "未置顶，点击置顶"
  }

  override func draw(_: NSRect) {
    let circle = NSBezierPath(ovalIn: self.bounds)
    self.fillColor.setFill()
    circle.fill()
  }

  private var fillColor: NSColor {
    let base = self.isPinned ? NSColor.systemBlue : NSColor(white: 1, alpha: 0.18)
    guard self.isPressed else { return base }
    return base.blended(withFraction: 0.25, of: .black) ?? base
  }

  override func mouseDown(with _: NSEvent) {
    self.isPressed = true
  }

  override func mouseUp(with event: NSEvent) {
    self.isPressed = false

    let point = self.convert(event.locationInWindow, from: nil)
    if self.bounds.contains(point) {
      self.onTap?()
    }
  }

  // MARK: - Accessibility

  override func isAccessibilityElement() -> Bool { true }
  override func accessibilityRole() -> NSAccessibility.Role? { .button }
  override func accessibilityLabel() -> String? { "窗口置顶" }
  override func accessibilityValue() -> Any? { self.isPinned ? "开" : "关" }
  override func accessibilityPerformPress() -> Bool {
    self.onTap?()
    return true
  }
}
