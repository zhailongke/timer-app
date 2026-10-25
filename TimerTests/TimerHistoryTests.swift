import AppKit
@testable import Timer
import XCTest

@MainActor
final class TimerHistoryTests: XCTestCase {
  /// 历史记录现在存文件：每个用例给一个临时文件，互不干扰
  private func makeStoreURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("TimerHistoryTests-\(UUID().uuidString)")
      .appendingPathComponent("history.json")
  }

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
    let url = self.makeStoreURL()
    MVHistoryStore.save([self.makeRecord(name: "第一次", duration: 60)], to: url)

    let loaded = MVHistoryStore.load(from: url)
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.name, "第一次")
    XCTAssertEqual(loaded.first?.duration, 60)
  }

  /// 只留最近 totalLimit 条（含下级），免得越积越多
  func testSaveTrimsOldest() {
    let url = self.makeStoreURL()
    var records: [ClockRecord] = []
    for index in 0..<(MVHistoryStore.totalLimit + 5) {
      records.append(self.makeRecord(name: "第\(index)条", duration: 1))
    }
    MVHistoryStore.save(records, to: url)

    let loaded = MVHistoryStore.load(from: url)
    XCTAssertEqual(loaded.count, MVHistoryStore.totalLimit)
    XCTAssertEqual(loaded.first?.name, "第5条")
    XCTAssertEqual(loaded.last?.name, "第\(MVHistoryStore.totalLimit + 4)条")
  }

  /// 下级也算进总数：只裁根层的话，一棵树能无限长
  func testTrimCountsChildren() {
    var records: [ClockRecord] = []
    for _ in 0..<3 {
      let children = (0..<10).map { self.makeRecord(name: "子\($0)", duration: 1) }
      records.append(self.makeRecord(name: "主", duration: 1, children: children))
    }
    XCTAssertEqual(records.totalCount, 33)

    records.trim(toTotal: 15)
    XCTAssertEqual(records.count, 1, "整条整条地丢，丢到只剩一条")
    XCTAssertLessThanOrEqual(records.totalCount, 15)
  }

  /// 一条记录自己的下级就超了：往下一层继续丢
  func testTrimDigsIntoChildrenOfLastRecord() {
    let children = (0..<30).map { self.makeRecord(name: "子\($0)", duration: 1) }
    var records = [self.makeRecord(name: "主", duration: 1, children: children)]

    records.trim(toTotal: 5)

    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(records.totalCount, 5)
    XCTAssertEqual(records[0].children.count, 4)
  }

  /// 同一条记录只能挂一份：以前递归不把「找到了」往回传，
  /// 后面每棵子树都会走到兜底分支再插一份，树就这么指数级涨起来
  func testAppendToParentInsertsExactlyOnce() {
    let parent = self.makeRecord(name: "主时钟", duration: 300)
    var records = [parent, self.makeRecord(name: "另一次主时钟", duration: 10)]

    records.append(self.makeRecord(name: "子时钟1", duration: 90), toParent: parent.id)

    XCTAssertEqual(records.totalCount, 3)
    XCTAssertEqual(records[0].children.count, 1)
    XCTAssertEqual(records[1].children.count, 0)
  }

  func testNestedChildrenSurviveRoundTrip() {
    let url = self.makeStoreURL()
    let grandchild = self.makeRecord(name: "子时钟2", duration: 30)
    let child = self.makeRecord(name: "子时钟1", duration: 90, children: [grandchild])
    MVHistoryStore.save(
      [self.makeRecord(name: "主时钟", duration: 300, children: [child])],
      to: url
    )

    let loaded = MVHistoryStore.load(from: url)
    XCTAssertEqual(loaded.first?.children.count, 1)
    XCTAssertEqual(loaded.first?.children.first?.children.first?.name, "子时钟2")
  }

  /// 老版本把记录留在 UserDefaults 里：搬一次到文件，搬完把旧 key 删掉（plist 才有机会瘦回去）
  func testMigrateFromUserDefaultsMovesRecordsAndClearsKey() {
    let defaults = self.makeDefaults()
    let url = self.makeStoreURL()
    let data = try? JSONEncoder().encode([self.makeRecord(name: "第一次", duration: 60)])
    defaults.set(data, forKey: MVUserDefaultsKeys.historyRecords)

    MVHistoryStore.migrateFromUserDefaults(defaults, to: url)

    XCTAssertEqual(MVHistoryStore.load(from: url).count, 1)
    XCTAssertNil(defaults.data(forKey: MVUserDefaultsKeys.historyRecords), "旧 key 要删掉")
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
    let tracker = MVHistoryTracker(storeURL: self.makeStoreURL(), defaults: self.makeDefaults())
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
    let tracker = MVHistoryTracker(storeURL: self.makeStoreURL(), defaults: self.makeDefaults())
    let record = ClockRecord.starting(mode: .countdown)
    tracker.mutate { $0.append(record) }

    tracker.finalizeRecord(id: record.id, elapsed: 0)

    XCTAssertTrue(tracker.records.isEmpty)
  }

  /// 有下级记录就要留着，哪怕自己没跑
  func testFinalizeKeepsRecordWithChildren() {
    let tracker = MVHistoryTracker(storeURL: self.makeStoreURL(), defaults: self.makeDefaults())
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
