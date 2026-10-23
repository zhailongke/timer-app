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

    // 拖动中每动一下就看一眼能不能跟旁边的时钟拼上
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.handleWindowMove),
      name: NSWindow.didMoveNotification,
      object: self
    )
  }

  /// 用户正拖着这个窗口；只有这时候才吸附，代码挪窗口（比如新建子时钟）不参与
  private var isUserDragging = false
  /// 吸附自己挪出来的 didMove 不该再算一次（吸附位置是幂等的，但少绕一圈更稳）
  private var isApplyingSnap = false

  /// 拖拽开始前调用（MVClockView 接管拖动前）
  func beginUserDrag() {
    self.isUserDragging = true
  }

  /// 松手后调用；窗口就停在最后拼好的位置上
  func endUserDrag() {
    self.isUserDragging = false
  }

  @objc private func handleWindowMove() {
    guard self.isUserDragging, !self.isApplyingSnap else { return }

    let others = Self.otherTimerWindowFrames(excluding: self)
    guard let origin = MVWindowSnapper.snapTarget(
      for: self.frame,
      among: others,
      visibleFrame: self.screen?.visibleFrame
    ) else { return }
    guard abs(origin.x - self.frame.origin.x) > 0.5 || abs(origin.y - self.frame.origin.y) > 0.5 else { return }

    self.isApplyingSnap = true
    self.setFrameOrigin(origin)
    self.isApplyingSnap = false
  }

  /// 可以拼接的其它时钟窗口位置；历史记录窗口之类的不算
  private static func otherTimerWindowFrames(excluding window: NSWindow) -> [NSRect] {
    NSApplication.shared.windows.compactMap { candidate in
      guard candidate !== window,
            candidate.isVisible,
            !candidate.isMiniaturized,
            candidate.windowController is MVTimerController
      else { return nil }
      return candidate.frame
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
