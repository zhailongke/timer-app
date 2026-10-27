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
    let clamped = min(1, max(0, progress))
    guard clamped > 0 else { return }

    let center = NSPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
    let radius = self.bounds.width / 2

    // 从 12 点起顺时针扫 clamped 圈，围成扇形当裁剪区。
    // 不用 appendArc 的 clockwise 参数：它的旋转方向跟这里「90° 递减」的算法是反的，
    // 进度只有 3% 时反而裁出 97% 的扇形，整圈都染成了蓝色
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: center.y + radius))
    let steps = max(2, Int((clamped * 360 / 3).rounded(.up)))
    for step in 1...steps {
      let degrees = 90 - clamped * 360 * CGFloat(step) / CGFloat(steps)
      let radians = degrees * .pi / 180
      path.line(to: NSPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius))
    }
    path.line(to: center)
    path.close()

    let image = (self.window?.isKeyWindow ?? false) ? Self.progressImage : Self.progressUnfocusImage

    // 裁剪只包住画图片这一步。不恢复的话后面画的刻度也会被切在扇形里
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    image.draw(in: self.bounds)
    NSGraphicsContext.restoreGraphicsState()
  }
}
