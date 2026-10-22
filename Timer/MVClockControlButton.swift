import AppKit

/// 右上角的暂停 / 继续按钮：蓝底圆点 + 白色符号。
/// 符号表示「点了会发生什么」——在跑就显示暂停，停着就显示继续。
final class MVClockControlButton: NSView {
  /// 正在计时（true → 暂停符号；false → 继续符号）
  var isRunning = false {
    didSet { self.needsDisplay = true }
  }

  /// 点击后交给 MVClockView.handleClick，和点时钟表面是同一套起停逻辑
  var onTap: (() -> Void)?

  private var isPressed = false {
    didSet { self.needsDisplay = true }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.toolTip = "暂停 / 继续"
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func draw(_: NSRect) {
    let circle = NSBezierPath(ovalIn: self.bounds)
    self.fillColor.setFill()
    circle.fill()

    NSColor.white.setFill()
    if self.isRunning {
      self.drawPauseSymbol()
    } else {
      self.drawPlaySymbol()
    }
  }

  private var fillColor: NSColor {
    guard self.isPressed else { return .systemBlue }
    return NSColor.systemBlue.blended(withFraction: 0.25, of: .black) ?? .systemBlue
  }

  /// 暂停符号：两道竖杠
  private func drawPauseSymbol() {
    let side = self.bounds.width
    let barWidth = side * 0.13
    let barHeight = side * 0.38
    let gap = side * 0.09

    let left = (self.bounds.width - (barWidth * 2 + gap)) / 2
    let bottom = (self.bounds.height - barHeight) / 2

    for offset in [0, barWidth + gap] {
      let rect = NSRect(x: left + offset, y: bottom, width: barWidth, height: barHeight)
      NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
    }
  }

  /// 继续符号：一个朝右的三角
  private func drawPlaySymbol() {
    let side = self.bounds.width
    let height = side * 0.40
    let width = side * 0.34

    // 三角形视觉重心偏左，整体往右挪一点才像居中
    let centerX = self.bounds.midX + width * 0.12
    let centerY = self.bounds.midY

    let path = NSBezierPath()
    path.move(to: NSPoint(x: centerX - width / 2, y: centerY - height / 2))
    path.line(to: NSPoint(x: centerX - width / 2, y: centerY + height / 2))
    path.line(to: NSPoint(x: centerX + width / 2, y: centerY))
    path.close()
    path.fill()
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
  override func accessibilityLabel() -> String? { self.isRunning ? "暂停" : "继续" }
  override func accessibilityPerformPress() -> Bool {
    self.onTap?()
    return true
  }
}
