import AppKit

final class MVWindow: NSWindow {
  convenience init(mainView: NSView) {
    // fullSizeContentView 让内容视图铺满整个窗口（含标题栏区域），
    // 这样时钟可以随意缩放，不会被标题栏容器裁掉。
    let styleMask: NSWindow.StyleMask = [.closable, .miniaturizable, .titled, .resizable, .fullSizeContentView]
    let size: CGFloat = 150.0

    let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
    let windowFrame = NSRect(
      x: screenFrame.width / 2 - size / 2,
      y: screenFrame.height / 2 - size / 2,
      width: size,
      height: size
    )

    self.init(
      contentRect: windowFrame,
      styleMask: styleMask,
      backing: .buffered,
      defer: true
    )

    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true

    // 保持正方形，缩放时钟不会变形
    self.aspectRatio = NSSize(width: 1, height: 1)
    self.minSize = NSSize(width: 96, height: 96)
    self.maxSize = NSSize(width: 640, height: 640)

    mainView.frame = NSRect(x: 0, y: 0, width: size, height: size)
    mainView.autoresizingMask = [.width, .height]
    self.contentView = mainView

    // 只留关闭和最小化；缩放按钮收起（窗口保持正方形，缩放没意义）
    self.standardWindowButton(.zoomButton)?.isHidden = true

    // 两个留下的按钮一起往下挪一点，视觉上跟时钟对齐
    for button in [self.standardWindowButton(.closeButton), self.standardWindowButton(.miniaturizeButton)] {
      guard let button else { continue }
      var frame = button.frame
      frame.origin.y -= 2
      button.frame = frame
    }
  }

  /// Tab 默认被窗口拿去做焦点切换，这里提前截获，交给 controller 切换模式；
  /// 若事件没经过窗口而是直接到达响应链末端，由 MVTimerController.keyDown 兜底
  override func keyDown(with event: NSEvent) {
    if event.keyCode == MVTimerController.tabKeyCode {
      (self.windowController as? MVTimerController)?.toggleMode()
      return
    }
    super.keyDown(with: event)
  }
}
