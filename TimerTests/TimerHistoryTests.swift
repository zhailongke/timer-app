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

  func testSaveAndLoad() {
    let defaults = self.makeDefaults()
    MVHistoryStore.save([self.makeRecord(name: "第一次", duration: 60)], to: defaults)

    let loaded = MVHistoryStore.load(from: defaults)
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.name, "第一次")
    XCTAssertEqual(loaded.first?.duration, 60)
  }

  /// 只留最近 limit 条，免得越积越多
  func testSaveTrimsOldest() {
    let defaults = self.makeDefaults()
    var records: [ClockRecord] = []
    for index in 0..<(MVHistoryStore.limit + 5) {
      records.append(self.makeRecord(name: "第\(index)条", duration: 1))
    }
    MVHistoryStore.save(records, to: defaults)

    let loaded = MVHistoryStore.load(from: defaults)
    XCTAssertEqual(loaded.count, MVHistoryStore.limit)
    XCTAssertEqual(loaded.first?.name, "第5条")
    XCTAssertEqual(loaded.last?.name, "第\(MVHistoryStore.limit + 4)条")
  }

  func testNestedChildrenSurviveRoundTrip() {
    let defaults = self.makeDefaults()
    let grandchild = self.makeRecord(name: "子时钟2", duration: 30)
    let child = self.makeRecord(name: "子时钟1", duration: 90, children: [grandchild])
    MVHistoryStore.save(
      [self.makeRecord(name: "主时钟", duration: 300, children: [child])],
      to: defaults
    )

    let loaded = MVHistoryStore.load(from: defaults)
    XCTAssertEqual(loaded.first?.children.count, 1)
    XCTAssertEqual(loaded.first?.children.first?.children.first?.name, "子时钟2")
  }

  /// 子时钟的记录挂在上级那条下面，不进根层
  func testAppendToParentNestsRecord() {
    let parent = self.makeRecord(name: "主时钟", duration: 300)
    let child = self.makeRecord(name: "子时钟1", duration: 90)

    var records = [parent]
    records.append(child, toParent: parent.id)

    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(records[0].children.count, 1)
    XCTAssertEqual(records[0].children.first?.name, "子时钟1")
  }

  /// 上级记录被删掉后落根层，总比丢了强
  func testAppendToUnknownParentFallsBackToRoot() {
    var records = [self.makeRecord(name: "主时钟", duration: 300)]
    records.append(self.makeRecord(name: "子时钟1", duration: 90), toParent: UUID())

    XCTAssertEqual(records.count, 2)
  }

  /// 正在跑的记录每秒按 id 刷新时长
  func testUpdateRecordByIDRefreshesLiveValues() {
    let child = self.makeRecord(name: "子时钟1", duration: 90)
    var records = [self.makeRecord(name: "主时钟", duration: 300, children: [child])]

    records.update(id: child.id) { record in
      record.duration = 120
      record.endDate = Date()
    }

    XCTAssertEqual(records[0].children.first?.duration, 120)
  }

  func testContainsIDLooksIntoChildren() {
    let child = self.makeRecord(name: "子时钟1", duration: 90)
    let records = [self.makeRecord(name: "主时钟", duration: 300, children: [child])]

    XCTAssertTrue(records.contains(id: child.id))
    XCTAssertFalse(records.contains(id: UUID()))
  }

  /// 关闭时钟：这一段收尾，结束时间定下来
  func testFinalizeRecordEndsSession() {
    let tracker = MVHistoryTracker(defaults: self.makeDefaults())
    let record = ClockRecord.starting(mode: .stopwatch, title: "数学")
    tracker.mutate { $0.append(record) }

    tracker.finalizeRecord(id: record.id, elapsed: 90, title: "数学")

    XCTAssertEqual(tracker.records.count, 1)
    XCTAssertEqual(tracker.records.first?.duration, 90)
    XCTAssertEqual(tracker.records.first?.title, "数学")
    XCTAssertEqual(tracker.records.first?.isOpenEnded, false)
  }

  /// 没真正跑过、又没下级的，关掉不留空行
  func testFinalizeDropsEmptyRecord() {
    let tracker = MVHistoryTracker(defaults: self.makeDefaults())
    let record = ClockRecord.starting(mode: .countdown)
    tracker.mutate { $0.append(record) }

    tracker.finalizeRecord(id: record.id, elapsed: 0)

    XCTAssertTrue(tracker.records.isEmpty)
  }

  /// 有下级记录就要留着，哪怕自己没跑
  func testFinalizeKeepsRecordWithChildren() {
    let tracker = MVHistoryTracker(defaults: self.makeDefaults())
    let child = ClockRecord.starting(mode: .stopwatch, title: "子时钟1")
    let parent = ClockRecord.starting(mode: .stopwatch)
    tracker.mutate { records in
      records.append(parent)
      records.append(child, toParent: parent.id)
    }

    tracker.finalizeRecord(id: parent.id, elapsed: 0)

    XCTAssertEqual(tracker.records.count, 1)
    XCTAssertEqual(tracker.records.first?.children.count, 1)
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
