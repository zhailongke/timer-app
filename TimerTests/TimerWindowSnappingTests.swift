import AppKit
@testable import Timer
import XCTest

private let testScreen = NSRect(x: 0, y: 0, width: 1_440, height: 900)
private let testSize = NSSize(width: 150, height: 150)

private func snapTarget(
  _ dragged: NSRect,
  among others: [NSRect],
  visibleFrame: NSRect? = testScreen
) -> NSPoint? {
  MVWindowSnapper.snapTarget(for: dragged, among: others, visibleFrame: visibleFrame)
}

final class TimerWindowSnappingTests: XCTestCase {
  /// 拖到右边差一点点：拼在右边，缝归零、顶边对齐
  func testSnapsToRightEdgeWithoutGap() {
    let other = NSRect(origin: NSPoint(x: 400, y: 300), size: testSize)
    let dragged = NSRect(origin: NSPoint(x: 558, y: 307), size: testSize)

    guard let origin = snapTarget(dragged, among: [other]) else {
      XCTFail("够近了就该拼上")
      return
    }

    XCTAssertEqual(origin, NSPoint(x: 550, y: 300))
    XCTAssertFalse(NSRect(origin: origin, size: testSize).intersects(other), "拼完不能压住对方")
  }

  /// 拖到下方：贴住底边、左边对齐
  func testSnapsBelowOtherWindow() {
    let other = NSRect(origin: NSPoint(x: 400, y: 300), size: testSize)
    let dragged = NSRect(origin: NSPoint(x: 405, y: 143), size: testSize)

    XCTAssertEqual(snapTarget(dragged, among: [other]), NSPoint(x: 400, y: 150))
  }

  /// 够不着就别硬拽过去
  func testIgnoresFarAwayWindow() {
    let other = NSRect(origin: NSPoint(x: 400, y: 300), size: testSize)
    let dragged = NSRect(origin: NSPoint(x: 800, y: 300), size: testSize)

    XCTAssertNil(snapTarget(dragged, among: [other]))
  }

  /// 刚过阈值就散开：想拆散只要拖远一点，不会被咬住
  func testReleasesBeyondSnapDistance() {
    let other = NSRect(origin: NSPoint(x: 400, y: 300), size: testSize)
    let dragged = NSRect(origin: NSPoint(x: 567, y: 300), size: testSize)

    XCTAssertNil(snapTarget(dragged, among: [other]))
  }

  /// 拼上去会压住第三个窗口的位置不算数
  func testSkipsTargetThatWouldOverlapThirdWindow() {
    let other = NSRect(origin: NSPoint(x: 400, y: 300), size: testSize)
    let occupied = NSRect(origin: NSPoint(x: 550, y: 300), size: testSize)
    let dragged = NSRect(origin: NSPoint(x: 556, y: 304), size: testSize)

    XCTAssertNil(snapTarget(dragged, among: [other, occupied]))
  }

  /// 尺寸不同：横向拼接按离得近的那条边对齐（小窗口贴大窗口右边、顶边齐平）
  func testAlignsToNearestEdgeWithDifferentSizes() {
    let other = NSRect(x: 400, y: 300, width: 300, height: 300)
    let dragged = NSRect(x: 706, y: 495, width: 100, height: 100)

    // 贴右边 x = 700，顶边齐平 → y = 600 - 100 = 500
    XCTAssertEqual(snapTarget(dragged, among: [other]), NSPoint(x: 700, y: 500))
  }

  /// 同时够得着两个窗口时挑更近的那个
  func testPicksNearestOfSeveralTargets() {
    let left = NSRect(x: 200, y: 300, width: 150, height: 150)
    let right = NSRect(x: 700, y: 300, width: 150, height: 150)
    let dragged = NSRect(x: 544, y: 302, width: 150, height: 150)

    XCTAssertEqual(snapTarget(dragged, among: [left, right]), NSPoint(x: 550, y: 300))
  }

  /// 会把窗口吸出屏幕的位置不要
  func testSkipsTargetOutsideVisibleFrame() {
    let other = NSRect(x: 0, y: 300, width: 150, height: 150)
    let dragged = NSRect(x: -145, y: 302, width: 150, height: 150)

    XCTAssertNil(snapTarget(dragged, among: [other]))
  }
}

// MARK: - 真窗口接线

extension TimerWindowSnappingTests {
  /// 拖动中挪动窗口：真的会被吸到旁边那个时钟的边上（缝归零、边对齐）
  @MainActor
  func testWindowSnapsToNeighborWhileDragging() {
    let first = MVTimerController()
    let second = MVTimerController()
    guard let firstWindow = first.window as? MVWindow, let secondWindow = second.window as? MVWindow else {
      XCTFail("两个时钟窗口都该建出来")
      return
    }

    // 把这两个窗口挪到屏幕上的空地，免得撞到别的测试留下的窗口
    let mine: [NSWindow] = [firstWindow, secondWindow]
    let occupied = NSApplication.shared.windows.compactMap { window -> NSRect? in
      guard !mine.contains(where: { $0 === window }), window.windowController is MVTimerController else { return nil }
      return window.frame
    }
    let side = max(firstWindow.frame.width, secondWindow.frame.width)
    guard let spot = Self.freeSpot(width: side * 2 + 60, height: side + 20, avoiding: occupied) else {
      XCTFail("屏幕上找不到放得下两个窗口的空地")
      return
    }

    firstWindow.setFrameOrigin(spot)
    secondWindow.setFrameOrigin(NSPoint(x: spot.x + side + 40, y: spot.y))
    XCTAssertEqual(secondWindow.frame.origin.x, spot.x + side + 40, accuracy: 0.5, "没在拖动就别乱吸")

    secondWindow.beginUserDrag()
    secondWindow.setFrameOrigin(NSPoint(x: firstWindow.frame.maxX + 8, y: firstWindow.frame.minY + 7))
    secondWindow.endUserDrag()

    XCTAssertEqual(secondWindow.frame.origin.x, firstWindow.frame.maxX, accuracy: 0.5, "横向要贴死")
    XCTAssertEqual(secondWindow.frame.origin.y, firstWindow.frame.minY, accuracy: 0.5, "顶边要对齐")

    // 松手后就散得开：再挪远一点不该被拽回去
    secondWindow.setFrameOrigin(NSPoint(x: firstWindow.frame.maxX + 80, y: firstWindow.frame.minY))
    XCTAssertEqual(secondWindow.frame.origin.x, firstWindow.frame.maxX + 80, accuracy: 0.5)
  }

  /// 在屏幕上找一块不与任何已有窗口相交的空地
  private static func freeSpot(width: CGFloat, height: CGFloat, avoiding frames: [NSRect]) -> NSPoint? {
    guard let visible = NSScreen.main?.visibleFrame else { return nil }
    let step: CGFloat = 40

    var spotY = visible.minY + 10
    while spotY + height <= visible.maxY {
      var spotX = visible.minX + 10
      while spotX + width <= visible.maxX {
        let candidate = NSRect(x: spotX, y: spotY, width: width, height: height)
        if !frames.contains(where: { $0.intersects(candidate) }) { return NSPoint(x: spotX, y: spotY) }
        spotX += step
      }
      spotY += step
    }
    return nil
  }
}
