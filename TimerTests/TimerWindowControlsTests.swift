import AppKit
@testable import Timer
import XCTest

@MainActor
final class TimerWindowControlsTests: XCTestCase {
  /// 左上角要有能用的最小化按钮
  func testMiniaturizeButtonIsAvailable() {
    let window = MVWindow(mainView: NSView())

    XCTAssertTrue(window.styleMask.contains(.miniaturizable))
    let button = window.standardWindowButton(.miniaturizeButton)
    XCTAssertNotNil(button, "窗口该有最小化按钮")
    XCTAssertFalse(button?.isHidden ?? true, "最小化按钮不该被藏起来")
  }

  /// 左下角的图钉：点了要把「切置顶」交给外面处理
  func testPinButtonForwardsTap() {
    let view = MVClockView()
    var tapped = false
    view.onToggleStaysOnTop = { tapped = true }

    view.pinButton.onTap?()

    XCTAssertTrue(tapped)
  }
}
