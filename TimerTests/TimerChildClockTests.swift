import AppKit
@testable import Timer
import XCTest

@MainActor
final class TimerChildClockTests: XCTestCase {
  func testChildCountdownCappedByParent() {
    let parent = MVClockView()
    parent.setMode(.countdown)
    parent.setCountdownSeconds(600) // 10 分钟

    let child = MVClockView()
    child.setMode(.countdown)
    child.parentClockView = parent

    XCTAssertEqual(child.countdownLimit, 600)

    child.setCountdownSeconds(900) // 想设 15 分钟
    XCTAssertEqual(child.seconds, 600)
    XCTAssertEqual(child.countdownDuration, 600)
  }

  func testGrandChildCappedByItsParent() {
    let root = MVClockView()
    root.setMode(.countdown)
    root.setCountdownSeconds(1_800) // 30 分钟

    let child = MVClockView()
    child.setMode(.countdown)
    child.parentClockView = root
    child.setCountdownSeconds(600) // 10 分钟

    let grandChild = MVClockView()
    grandChild.setMode(.countdown)
    grandChild.parentClockView = child

    grandChild.setCountdownSeconds(900)
    XCTAssertEqual(grandChild.seconds, 600, "不能超过上一级子时钟")

    child.setCountdownSeconds(300)
    grandChild.setCountdownSeconds(900)
    XCTAssertEqual(grandChild.seconds, 300, "上级改短后下级跟着收紧")
  }

  func testStopwatchPassesParentLimitDown() {
    let root = MVClockView()
    root.setMode(.countdown)
    root.setCountdownSeconds(1_200)

    let stopwatchChild = MVClockView()
    stopwatchChild.parentClockView = root
    stopwatchChild.setMode(.stopwatch)
    XCTAssertEqual(stopwatchChild.countdownLimit, 1_200, "秒表没有自己的时长，上限继续往上传")

    let countdownGrandChild = MVClockView()
    countdownGrandChild.setMode(.countdown)
    countdownGrandChild.parentClockView = stopwatchChild
    countdownGrandChild.setCountdownSeconds(1_500)
    XCTAssertEqual(countdownGrandChild.seconds, 1_200)
  }

  func testNoParentMeansNoLimit() {
    let view = MVClockView()
    view.setMode(.countdown)

    XCTAssertNil(view.countdownLimit)

    view.setCountdownSeconds(3_600)
    XCTAssertEqual(view.seconds, 3_600)
  }

  func testResetClearsLimitForChildren() {
    let parent = MVClockView()
    parent.setMode(.countdown)
    parent.setCountdownSeconds(600)

    let child = MVClockView()
    child.setMode(.countdown)
    child.parentClockView = parent
    child.setCountdownSeconds(300)
    XCTAssertEqual(child.countdownLimit, 300)

    child.keyUp(with: Self.keyEvent(characters: "\u{1B}")) // escape 归零
    XCTAssertEqual(child.countdownLimit, 600, "归零后自己的时长作废，回退到上级的上限")
  }

  func testChildTitle() {
    let view = MVClockView()
    XCTAssertEqual(view.clockTitle, "")

    view.clockTitle = "子时钟1"
    XCTAssertEqual(view.clockTitle, "子时钟1")
  }

  func testTypingTitleDoesNotTriggerShortcuts() {
    let view = MVClockView()
    view.setMode(.countdown)
    view.isTitleEditable = true
    view.clockTitle = "数学"

    view.beginTitleEditing()
    view.keyUp(with: Self.keyEvent(characters: "5"))
    view.keyUp(with: Self.keyEvent(characters: "s"))

    XCTAssertEqual(view.seconds, 0, "改名时打数字不该去设时长")
    XCTAssertEqual(view.mode, .countdown, "改名时打 s 不该切模式")
  }

  func testRenameButtonShowsOnlyForEditableTitle() {
    let view = MVClockView()
    XCTAssertTrue(view.renameButton.isHidden)

    view.isTitleEditable = true
    XCTAssertFalse(view.renameButton.isHidden)
    XCTAssertGreaterThan(view.renameButton.alphaValue, 0)

    view.setTitleHovered(true)
    XCTAssertEqual(view.renameButton.alphaValue, 1)

    view.setTitleHovered(false)
    XCTAssertEqual(view.renameButton.alphaValue, 0.75)
  }

  /// 悬停 / 改名会换成 attributedStringValue，少了段落样式文字就会跳到左边
  func testTitleKeepsCenteredAlignmentWhenAttributed() {
    let view = MVClockView()
    view.isTitleEditable = true
    view.clockTitle = "数学"

    view.setTitleHovered(true)

    let style = view.titleLabel.attributedStringValue
      .attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    XCTAssertEqual(style?.alignment, .center)
  }

  /// 按钮小，点区域要往外扩一圈
  func testRenameButtonHitAreaIsLargerThanIcon() {
    let view = MVClockView()
    view.isTitleEditable = true
    view.clockTitle = "数学"

    let buttonFrame = view.renameButton.frame
    let hitFrame = view.renameHitFrame

    XCTAssertTrue(hitFrame.contains(buttonFrame.origin))
    XCTAssertGreaterThan(hitFrame.width, buttonFrame.width)
  }

  /// 输入框默认短短一个，名字长了跟着变宽，但不超出名字那一行的宽度
  func testTitleInputWidthAdaptsToDraft() {
    let view = MVClockView()
    view.isTitleEditable = true
    view.clockTitle = "数学"
    view.beginTitleEditing()

    let shortWidth = view.titleInputField.frame.width

    view.titleDraft = "这是一个很长很长很长的名字"
    view.controlTextDidChange(
      Notification(name: NSControl.textDidChangeNotification, object: view.titleInputField)
    )

    XCTAssertGreaterThan(view.titleInputField.frame.width, shortWidth)
    XCTAssertLessThanOrEqual(view.titleInputField.frame.width, view.titleLabel.frame.width)
  }

  /// 回车提交后漏下来的那个 keyUp 不能再去起停时钟
  func testReturnAfterRenameDoesNotToggleClock() {
    let view = MVClockView()
    view.setMode(.stopwatch)
    view.isTitleEditable = true
    view.clockTitle = "数学"
    view.beginTitleEditing()
    view.swallowNextReturnKeyUp = true
    view.endTitleEditing()

    guard let event = NSEvent.keyEvent(
      with: .keyUp,
      location: .zero,
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: "\r",
      charactersIgnoringModifiers: "\r",
      isARepeat: false,
      keyCode: MVClockView.returnKeyCode
    ) else {
      XCTFail("构造回车事件失败")
      return
    }
    view.keyUp(with: event)

    XCTAssertNil(view.timerTask, "回车提交不该顺手起停时钟")
  }

  func testChildTitleIsWhite() {
    let view = MVClockView()
    let color = view.titleLabel.textColor?.usingColorSpace(.deviceRGB)

    XCTAssertEqual(color?.redComponent ?? 0, 1, accuracy: 0.01)
    XCTAssertEqual(color?.greenComponent ?? 0, 1, accuracy: 0.01)
    XCTAssertEqual(color?.blueComponent ?? 0, 1, accuracy: 0.01)
  }

  private static func keyEvent(characters: String) -> NSEvent {
    guard let event = NSEvent.keyEvent(
      with: .keyUp,
      location: .zero,
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: characters,
      isARepeat: false,
      keyCode: 0
    ) else {
      fatalError("测试用键盘事件构造失败")
    }
    return event
  }
}
