import AppKit

/// 名字右边的改名按钮：蓝底圆点 + 白色铅笔，跟右上角的起停按钮同一套样式。
/// 高度和名字文字对齐，看起来就是名字旁边的一个小按钮。
final class MVRenameButton: NSView {
  /// 点击后交给 MVClockView 起停改名（已经在改名时再点一次就是完成）
  var onTap: (() -> Void)?

  private var isPressed = false {
    didSet { self.needsDisplay = true }
  }

  private let symbolView: NSImageView = {
    let view = NSImageView(frame: .zero)
    if let symbol = NSImage(systemSymbolName: "pencil", accessibilityDescription: "Rename") {
      symbol.isTemplate = true
      view.image = symbol
    }
    view.contentTintColor = .white
    return view
  }()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.toolTip = "改名"
    self.addSubview(self.symbolView)
    self.layoutSymbol()
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    self.layoutSymbol()
  }

  /// 铅笔占圆点的一半高，居中放
  private func layoutSymbol() {
    let side = min(self.bounds.width, self.bounds.height) * 0.5
    self.symbolView.frame = NSRect(
      x: (self.bounds.width - side) / 2,
      y: (self.bounds.height - side) / 2,
      width: side,
      height: side
    )
  }

  override func draw(_: NSRect) {
    let circle = NSBezierPath(ovalIn: self.bounds)
    self.fillColor.setFill()
    circle.fill()
  }

  private var fillColor: NSColor {
    guard self.isPressed else { return .systemBlue }
    return NSColor.systemBlue.blended(withFraction: 0.25, of: .black) ?? .systemBlue
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
  override func accessibilityLabel() -> String? { "改名" }
  override func accessibilityPerformPress() -> Bool {
    self.onTap?()
    return true
  }
}
