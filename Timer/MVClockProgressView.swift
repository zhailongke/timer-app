import AppKit

final class MVClockProgressView: NSView {
  private static let ringColor = NSColor(srgbRed: 0.7255, green: 0.7255, blue: 0.7255, alpha: 0.15)
  /// 刻度画得很淡：只是标记，不抢数字的注意力
  private static let tickColor = NSColor(white: 1, alpha: 0.28)
  private static let progressImage = MVResource.image("progress")
  private static let progressUnfocusImage = MVResource.image("progress-unfocus")

  var progress: CGFloat = 0.0 {
    didSet {
      self.needsDisplay = true
    }
  }

  /// 圆周上画几个刻度：0 就是不画。正计时模式画六等份，一天分成六格
  var ticks: Int = 0 {
    didSet {
      // 每秒都会赋一次同样的值，值没变就别重画
      if self.ticks != oldValue { self.needsDisplay = true }
    }
  }

  convenience init() {
    self.init(frame: NSRect(x: 0, y: 0, width: 116, height: 116))
  }

  override func draw(_: NSRect) {
    Self.ringColor.setFill()
    NSBezierPath(ovalIn: self.bounds).fill()

    self.drawArc(self.progress)
    // 刻度画在蓝条上面，不然走到哪儿就被蓝条盖掉
    self.drawTicks(self.ticks)
  }

  /// 圆周上的小刻度：只做标记，不写文字
  private func drawTicks(_ count: Int) {
    guard count > 1 else { return }

    let center = NSPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
    let outer = self.bounds.width / 2
    let inner = outer - 5
    Self.tickColor.setStroke()

    for index in 0..<count {
      // 从 12 点起顺时针，跟蓝条走的方向一致
      let angle = CGFloat(index) / CGFloat(count) * 2 * .pi
      let path = NSBezierPath()
      path.lineWidth = 1
      path.move(to: NSPoint(x: center.x + sin(angle) * inner, y: center.y + cos(angle) * inner))
      path.line(to: NSPoint(x: center.x + sin(angle) * outer, y: center.y + cos(angle) * outer))
      path.stroke()
    }
  }

  private func drawArc(_ progress: CGFloat) {
    let center = NSPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
    let windowHasFocus = self.window?.isKeyWindow ?? false

    let path = NSBezierPath()
    path.move(to: NSPoint(x: self.bounds.width / 2, y: self.bounds.height))
    path.appendArc(
      withCenter: NSPoint(x: self.bounds.width / 2, y: self.bounds.height / 2),
      radius: self.bounds.width / 2,
      startAngle: 90,
      endAngle: 90 - (progress > 1 ? 1 : progress) * 360,
      clockwise: true
    )
    path.line(to: center)
    path.addClip()

    let ctx = NSGraphicsContext.current
    ctx?.saveGraphicsState()

    let cgTransform = CGAffineTransform(translationX: center.x, y: center.y)
      .rotated(by: -progress * 2 * .pi)
      .translatedBy(x: -center.x, y: -center.y)
    NSGraphicsContext.current?.cgContext.concatenate(cgTransform)

    let image = windowHasFocus ? Self.progressImage : Self.progressUnfocusImage
    image.draw(in: self.bounds)

    ctx?.restoreGraphicsState()
  }
}
