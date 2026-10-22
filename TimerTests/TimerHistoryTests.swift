import AppKit
@testable import Timer
import XCTest

@MainActor
final class TimerHistoryTests: XCTestCase {
  private func makeDefaults() -> UserDefaults {
    let suite = "TimerHistoryTests-\(UUID().uuidString)"
    return UserDefaults(suiteName: suite) ?? .standard
  }

  private func makeRecord(
    name: String,
    duration: TimeInterval,
    children: [ClockRecord] = []
  ) -> ClockRecord {
    ClockRecord(
      id: UUID(),
      name: name,
      startDate: Date(),
      duration: duration,
      mode: .stopwatch,
      children: children
    )
  }

  func testAppendAndLoad() {
    let defaults = self.makeDefaults()
    MVHistoryStore.append(self.makeRecord(name: "第一次", duration: 60), to: defaults)

    let loaded = MVHistoryStore.load(from: defaults)
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.name, "第一次")
    XCTAssertEqual(loaded.first?.duration, 60)
  }

  /// 只留最近 limit 条，免得越积越多
  func testAppendTrimsOldest() {
    let defaults = self.makeDefaults()
    for index in 0..<(MVHistoryStore.limit + 5) {
      MVHistoryStore.append(self.makeRecord(name: "第\(index)条", duration: 1), to: defaults)
    }

    let loaded = MVHistoryStore.load(from: defaults)
    XCTAssertEqual(loaded.count, MVHistoryStore.limit)
    XCTAssertEqual(loaded.first?.name, "第5条")
    XCTAssertEqual(loaded.last?.name, "第\(MVHistoryStore.limit + 4)条")
  }

  func testNestedChildrenSurviveRoundTrip() {
    let defaults = self.makeDefaults()
    let grandchild = self.makeRecord(name: "子时钟2", duration: 30)
    let child = self.makeRecord(name: "子时钟1", duration: 90, children: [grandchild])
    MVHistoryStore.append(self.makeRecord(name: "主时钟", duration: 300, children: [child]), to: defaults)

    let loaded = MVHistoryStore.load(from: defaults)
    XCTAssertEqual(loaded.first?.children.count, 1)
    XCTAssertEqual(loaded.first?.children.first?.children.first?.name, "子时钟2")
  }

  /// 历史窗口里改名：按 path 走到那一层，改到指定 id
  func testRenameRecordInNestedLevel() {
    let child = self.makeRecord(name: "子时钟1", duration: 90)
    var records = [self.makeRecord(name: "主时钟", duration: 300, children: [child])]

    records.mutate(at: [records[0].id]) { level in
      level.rename(id: child.id, to: "数学")
    }

    XCTAssertEqual(records[0].children.first?.name, "数学")
    XCTAssertEqual(records[0].name, "主时钟")
  }

  func testRemoveRecordInNestedLevel() {
    let child = self.makeRecord(name: "子时钟1", duration: 90)
    var records = [self.makeRecord(name: "主时钟", duration: 300, children: [child])]

    records.mutate(at: [records[0].id]) { level in
      level.remove(id: child.id)
    }

    XCTAssertTrue(records[0].children.isEmpty)
  }

  func testRecordsAtPath() {
    let child = self.makeRecord(name: "子时钟1", duration: 90)
    let records = [self.makeRecord(name: "主时钟", duration: 300, children: [child])]

    XCTAssertEqual(records.records(at: []).count, 1)
    XCTAssertEqual(records.records(at: [records[0].id]).count, 1)
    XCTAssertEqual(records.records(at: [UUID()]).count, 0)
  }

  func testOpenEndedShowsUntilNow() {
    let record = ClockRecord(
      id: UUID(),
      name: "进行中",
      startDate: Date(),
      duration: 120,
      mode: .stopwatch,
      isOpenEnded: true
    )
    XCTAssertEqual(record.endDateDisplay, "至今")
  }

  func testDurationDisplay() {
    let record = self.makeRecord(name: "一次", duration: 1_500)
    XCTAssertEqual(record.durationDisplay, "0:25:00")
  }

  func testElapsedSecondsForCountdown() {
    let view = MVClockView()
    view.setMode(.countdown)
    view.setCountdownSeconds(1_500)
    XCTAssertEqual(view.elapsedSeconds, 0, "刚开始，还没走")

    view.seconds = 900
    XCTAssertEqual(view.elapsedSeconds, 600, "25 分钟走了 10 分钟，剩 15 分钟")
  }

  func testElapsedSecondsForStopwatch() {
    let view = MVClockView()
    view.setMode(.stopwatch)
    view.seconds = 75
    XCTAssertEqual(view.elapsedSeconds, 75)
  }
}
