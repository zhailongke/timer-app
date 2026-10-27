import Foundation
@testable import Timer
import XCTest

/// 按天切分计时时长：正计时的蓝条「今天学了多少」就靠它算
@MainActor
final class TimerHistoryDayTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    return calendar
  }

  private func makeStoreURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("TimerHistoryDayTests-\(UUID().uuidString)")
      .appendingPathComponent("history.json")
  }

  private func makeDefaults() -> UserDefaults {
    let suite = "TimerHistoryDayTests-\(UUID().uuidString)"
    return UserDefaults(suiteName: suite) ?? .standard
  }

  /// 某一天的某个时刻
  private func at(hour: Int, day: Date, minute: Int = 0) -> Date {
    self.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
  }

  private func record(
    name: String,
    from start: Date,
    seconds: TimeInterval,
    endDate: Date? = nil,
    children: [ClockRecord] = []
  ) -> ClockRecord {
    ClockRecord(
      id: UUID(),
      name: name,
      startDate: start,
      duration: seconds,
      mode: .stopwatch,
      endDate: endDate ?? start.addingTimeInterval(seconds),
      children: children
    )
  }

  /// 跨天的计时按天切开：第二天从 0 点重新算，前一天的时长归前一天
  func testDurationWithinDaySplitsAcrossMidnight() {
    let today = self.calendar.startOfDay(for: Date())
    let tomorrow = self.calendar.date(byAdding: .day, value: 1, to: today) ?? today
    let yesterday = self.calendar.date(byAdding: .day, value: -1, to: today) ?? today

    // 昨晚 23:00 学到凌晨 1 点：墙钟两小时，两小时都计时了
    let start = self.at(hour: 23, day: yesterday)
    let end = self.at(hour: 1, day: today)
    let record = self.record(name: "跨天", from: start, seconds: 7_200, endDate: end)

    XCTAssertEqual(record.duration(within: today, dayEnd: tomorrow), 3_600, accuracy: 1)
    XCTAssertEqual(record.duration(within: yesterday, dayEnd: today), 3_600, accuracy: 1)
  }

  /// 暂停过：墙钟跨度 2 小时、实际只计了 1 小时，按跨度比例摊
  func testDurationWithinDayScalesWithPausedTime() {
    let today = self.calendar.startOfDay(for: Date())
    let tomorrow = self.calendar.date(byAdding: .day, value: 1, to: today) ?? today
    let start = self.at(hour: 10, day: today)

    // 10:00 到 12:00 挂在那儿，中间暂停了一半，只计了 1 小时
    let record = self.record(
      name: "暂停过",
      from: start,
      seconds: 3_600,
      endDate: start.addingTimeInterval(7_200)
    )

    XCTAssertEqual(record.duration(within: today, dayEnd: tomorrow), 3_600, accuracy: 1)
  }

  /// 完全在昨天的记录不该算进今天
  func testDurationWithinDayIgnoresOtherDays() {
    let today = self.calendar.startOfDay(for: Date())
    let tomorrow = self.calendar.date(byAdding: .day, value: 1, to: today) ?? today
    let yesterday = self.calendar.date(byAdding: .day, value: -1, to: today) ?? today

    let record = self.record(name: "昨天", from: self.at(hour: 9, day: yesterday), seconds: 3_600)

    XCTAssertEqual(record.duration(within: today, dayEnd: tomorrow), 0)
  }

  /// 主时钟跑着、子时钟也在跑：同一段时间只能算一次，不然今天 8 小时会被算成 16.8 小时
  func testSecondsTodayDoesNotCountOverlapTwice() {
    let today = self.calendar.startOfDay(for: Date())
    let tracker = MVHistoryTracker(storeURL: self.makeStoreURL(), defaults: self.makeDefaults())
    let start = self.at(hour: 10, day: today)
    // 主时钟 10:00-11:00，子时钟同一段（子时钟就是主时钟细分的）
    let main = self.record(
      name: "主时钟",
      from: start,
      seconds: 3_600,
      children: [self.record(name: "子时钟", from: start, seconds: 3_600)]
    )

    tracker.mutate { $0.append(main) }

    XCTAssertEqual(tracker.secondsToday(now: start.addingTimeInterval(7_200)), 3_600, accuracy: 1)
  }

  /// 不重叠的两段照常相加
  func testSecondsTodayAddsSessionsThatDoNotOverlap() {
    let today = self.calendar.startOfDay(for: Date())
    let tracker = MVHistoryTracker(storeURL: self.makeStoreURL(), defaults: self.makeDefaults())
    let morning = self.record(name: "上午", from: self.at(hour: 10, day: today), seconds: 3_600)
    let afternoon = self.record(name: "下午", from: self.at(hour: 14, day: today), seconds: 3_600)

    tracker.mutate { records in
      records.append(morning)
      records.append(afternoon)
    }

    XCTAssertEqual(tracker.secondsToday(now: self.at(hour: 16, day: today)), 7_200, accuracy: 1)
  }

  /// 今天的总时长：所有记录（含子时钟）加在一起
  func testSecondsTodaySumsRecordsAndChildren() {
    let today = self.calendar.startOfDay(for: Date())
    let yesterday = self.calendar.date(byAdding: .day, value: -1, to: today) ?? today
    let tracker = MVHistoryTracker(storeURL: self.makeStoreURL(), defaults: self.makeDefaults())
    let child = self.record(name: "子时钟", from: self.at(hour: 14, day: today), seconds: 1_800)
    let parent = self.record(
      name: "主时钟",
      from: self.at(hour: 9, day: today),
      seconds: 3_600,
      children: [child]
    )
    let old = self.record(name: "昨天", from: self.at(hour: 9, day: yesterday), seconds: 7_200)

    tracker.mutate { records in
      records.append(parent)
      records.append(old)
    }

    XCTAssertEqual(tracker.secondsToday(now: today.addingTimeInterval(60 * 60 * 20)), 5_400, accuracy: 1)
  }
}
