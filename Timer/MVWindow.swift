import AppKit

final class MVWindow: NSWindow {
  convenience init(mainView: NSView) {
    // fullSizeContentView 让内容视图铺满整个窗口（含标题栏区域），
    // 这样时钟可以随意缩放，不会被标题栏容器裁掉。
    let styleMask: NSWindow.StyleMask = [.closable, .titled, .resizable, .fullSizeContentView]
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

    // Hide the buttons we don't use; the close button keeps working over the clock face
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true

    if let closeButton = self.standardWindowButton(.closeButton) {
      var closeFrame = closeButton.frame
      closeFrame.origin.y -= 2
      closeButton.frame = closeFrame
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
