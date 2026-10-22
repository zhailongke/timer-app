import AppKit
@testable import Timer
import XCTest

@MainActor
final class TimerModeIndependenceTests: XCTestCase {
  /// 子时钟切模式不该动上级：上级既不能换模式，也不能被清零
  func testChildModeChangeLeavesParentAlone() {
    let parent = MVTimerController()
    parent.setMode(.countdown)
    parent.clockView.setCountdownSeconds(600)

    let child = MVTimerController(parent: parent)
    XCTAssertEqual(child.clockView.mode, .stopwatch)

    child.toggleMode()
    XCTAssertEqual(child.clockView.mode, .countdown)

    child.setMode(.stopwatch)
    XCTAssertEqual(child.clockView.mode, .stopwatch)
    XCTAssertEqual(parent.clockView.mode, .countdown, "上级模式不受下级影响")
    XCTAssertEqual(parent.clockView.seconds, 600, "上级的时长不该被清零")
  }

  /// 右键菜单那条路径：菜单项指向本窗口的时钟，触发后只动本窗口
  func testModeMenuItemChangesOnlyItsOwnClock() {
    let parent = MVTimerController()
    parent.setMode(.countdown)
    parent.clockView.setCountdownSeconds(600)

    let other = MVTimerController()
    other.setMode(.countdown)
    other.clockView.setCountdownSeconds(300)

    let mainView = MVMainView(frame: .zero)
    mainView.controller = parent
    mainView.clockView = parent.clockView

    guard let item = mainView.menu?.item(withTitle: "计时模式")?.submenu?.item(withTitle: "秒表模式") else {
      XCTFail("找不到「秒表模式」菜单项")
      return
    }
    XCTAssertIdentical(item.target, parent, "模式菜单项该指向本窗口的时钟")
    guard let action = item.action else {
      XCTFail("菜单项没有动作")
      return
    }
    XCTAssertTrue(NSApplication.shared.sendAction(action, to: item.target, from: item))

    XCTAssertEqual(parent.clockView.mode, .stopwatch)
    XCTAssertEqual(other.clockView.mode, .countdown, "别的时钟不受影响")
    XCTAssertEqual(other.clockView.seconds, 300, "别的时钟不该被清零")
  }
}
