import AppKit
@testable import Timer
import XCTest

@MainActor
final class TimerStopwatchTests: XCTestCase {
  func testDefaultModeIsStopwatch() {
    let view = MVClockView()

    XCTAssertEqual(view.mode, .stopwatch)
    XCTAssertEqual(view.seconds, 0)
  }

  func testControlButtonFollowsRunningState() {
    let view = MVClockView()

    XCTAssertFalse(view.controlButton.isRunning)

    view.start()
    XCTAssertTrue(view.controlButton.isRunning)

    view.stop()
    XCTAssertFalse(view.controlButton.isRunning)
  }

  func testControlButtonTapsLikeClickingTheClock() {
    let view = MVClockView()

    view.controlButton.onTap?()
    XCTAssertTrue(view.controlButton.isRunning)

    view.controlButton.onTap?()
    XCTAssertFalse(view.controlButton.isRunning)
    XCTAssertTrue(view.paused)
  }

  func testSwitchingModeResets() {
    let view = MVClockView()
    view.setMode(.countdown)
    view.seconds = 120

    view.setMode(.stopwatch)

    XCTAssertEqual(view.mode, .stopwatch)
    XCTAssertEqual(view.seconds, 0)
    XCTAssertNil(view.timerTask)
  }

  func testStopwatchStartsFromZeroAndCountsUp() async throws {
    let view = MVClockView()
    view.setMode(.stopwatch)

    view.handleClick() // 从 0 起跑
    XCTAssertNotNil(view.timerTask)

    try await Task.sleep(for: .milliseconds(1_400))
    XCTAssertGreaterThanOrEqual(view.seconds, 1)

    // 暂停后不再增长
    view.handleClick()
    XCTAssertTrue(view.paused)
    let pausedSeconds = view.seconds
    try await Task.sleep(for: .milliseconds(1_400))
    XCTAssertEqual(view.seconds, pausedSeconds)

    // 继续后从暂停点接着累加
    view.handleClick()
    XCTAssertFalse(view.paused)
    try await Task.sleep(for: .milliseconds(1_400))
    XCTAssertGreaterThan(view.seconds, pausedSeconds)

    view.stop()
  }

  func testStopwatchIgnoresDurationInput() {
    let view = MVClockView()
    view.setMode(.stopwatch)

    view.keyUp(with: Self.keyEvent(characters: "5"))
    XCTAssertEqual(view.seconds, 0)

    view.keyUp(with: Self.keyEvent(characters: "\u{F700}")) // up arrow，+1 分钟
    XCTAssertEqual(view.seconds, 0)
  }

  func testCountdownStillAcceptsDurationInput() {
    let view = MVClockView()
    view.setMode(.countdown)

    view.keyUp(with: Self.keyEvent(characters: "5"))

    XCTAssertEqual(view.seconds, 300)
  }

  func testEscapeResetsStopwatch() async throws {
    let view = MVClockView()
    view.setMode(.stopwatch)
    view.handleClick()
    try await Task.sleep(for: .milliseconds(1_400))
    XCTAssertGreaterThanOrEqual(view.seconds, 1)

    view.keyUp(with: Self.keyEvent(characters: "\u{1B}")) // escape
    XCTAssertEqual(view.seconds, 0)

    // 归零后等待，不应继续累加
    try await Task.sleep(for: .milliseconds(1_400))
    XCTAssertEqual(view.seconds, 0)
  }

  func testOriginDateRecordedOnStartAndClearedOnReset() {
    let view = MVClockView()

    XCTAssertNil(view.stopwatchOriginDate)

    view.handleClick() // 起跑
    let origin = view.stopwatchOriginDate
    XCTAssertNotNil(origin)

    // 暂停再继续，起点不变
    view.handleClick()
    view.handleClick()
    XCTAssertEqual(view.stopwatchOriginDate, origin)

    view.keyUp(with: Self.keyEvent(characters: "\u{1B}")) // escape 归零
    XCTAssertNil(view.stopwatchOriginDate)

    view.stop()
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
