import AppKit
@testable import Timer
import XCTest

final class TimerHistoryFilterTests: XCTestCase {
  // MARK: - 日期区间

  func testTodayCoversExactlyOneDay() throws {
    let calendar = Self.gmtCalendar()
    let now = try Self.makeDate(year: 2_026, month: 10, day: 23, calendar: calendar, hour: 12)
    let filter = MVHistoryDateFilter.today(calendar: calendar, now: now)

    XCTAssertTrue(filter.contains(now), "当天中午要算在区间里")
    XCTAssertTrue(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 23, calendar: calendar, hour: 0)))
    XCTAssertFalse(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 22, calendar: calendar, hour: 23)))
    XCTAssertFalse(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 24, calendar: calendar, hour: 0)))
  }

  func testYesterdayCoversThePreviousDay() throws {
    let calendar = Self.gmtCalendar()
    let now = try Self.makeDate(year: 2_026, month: 10, day: 23, calendar: calendar, hour: 12)
    let filter = MVHistoryDateFilter.yesterday(calendar: calendar, now: now)

    XCTAssertTrue(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 22, calendar: calendar, hour: 23)))
    XCTAssertFalse(filter.contains(now))
    XCTAssertFalse(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 21, calendar: calendar, hour: 23)))
  }

  func testLastDaysIncludesTodayAndSixEarlierDays() throws {
    let calendar = Self.gmtCalendar()
    let now = try Self.makeDate(year: 2_026, month: 10, day: 23, calendar: calendar, hour: 12)
    let filter = MVHistoryDateFilter.lastDays(7, calendar: calendar, now: now)

    XCTAssertTrue(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 17, calendar: calendar, hour: 0)))
    XCTAssertFalse(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 16, calendar: calendar, hour: 23)))
    XCTAssertTrue(filter.contains(now))
  }

  func testSpanningFilterEndsAtStartOfNextDay() throws {
    let calendar = Self.gmtCalendar()
    let filter = MVHistoryDateFilter(
      startDay: try Self.makeDate(year: 2_026, month: 10, day: 20, calendar: calendar),
      endDay: try Self.makeDate(year: 2_026, month: 10, day: 21, calendar: calendar),
      calendar: calendar
    )

    XCTAssertFalse(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 19, calendar: calendar, hour: 23)))
    XCTAssertTrue(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 20, calendar: calendar, hour: 0)))
    XCTAssertTrue(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 21, calendar: calendar, hour: 23)))
    XCTAssertFalse(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 22, calendar: calendar, hour: 0)))
  }

  func testReversedSelectionIsReordered() throws {
    let calendar = Self.gmtCalendar()
    let filter = MVHistoryDateFilter(
      startDay: try Self.makeDate(year: 2_026, month: 10, day: 21, calendar: calendar),
      endDay: try Self.makeDate(year: 2_026, month: 10, day: 20, calendar: calendar),
      calendar: calendar
    )

    XCTAssertTrue(filter.contains(try Self.makeDate(year: 2_026, month: 10, day: 20, calendar: calendar, hour: 12)))
    XCTAssertEqual(filter.lastDay, try Self.makeDate(year: 2_026, month: 10, day: 21, calendar: calendar))
  }

  func testDisplayTextUsesMonthAndDay() {
    let filter = MVHistoryDateFilter.today()
    let parts = Calendar.current.dateComponents([.month, .day], from: Date())
    XCTAssertEqual(filter.displayText, "\(parts.month ?? 0)月\(parts.day ?? 0)日")
  }

  func testFilterKeepsOnlyRecordsStartingInsideRange() throws {
    let calendar = Self.gmtCalendar()
    let filter = MVHistoryDateFilter(
      startDay: try Self.makeDate(year: 2_026, month: 10, day: 20, calendar: calendar),
      endDay: try Self.makeDate(year: 2_026, month: 10, day: 21, calendar: calendar),
      calendar: calendar
    )
    let records = [
      self.record(
        name: "太早",
        startDate: try Self.makeDate(year: 2_026, month: 10, day: 19, calendar: calendar, hour: 23),
        duration: 60
      ),
      self.record(
        name: "第一天",
        startDate: try Self.makeDate(year: 2_026, month: 10, day: 20, calendar: calendar, hour: 9),
        duration: 60
      ),
      self.record(
        name: "第二天",
        startDate: try Self.makeDate(year: 2_026, month: 10, day: 21, calendar: calendar, hour: 21),
        duration: 60
      ),
      self.record(
        name: "太晚",
        startDate: try Self.makeDate(year: 2_026, month: 10, day: 22, calendar: calendar, hour: 0),
        duration: 60
      )
    ]

    XCTAssertEqual(records.filter { filter.contains($0.startDate) }.map(\.name), ["第一天", "第二天"])
  }

  // MARK: - 排序

  func testDefaultSortPutsNewestFirst() throws {
    let calendar = Self.gmtCalendar()
    let records = [
      self.record(
        name: "早",
        startDate: try Self.makeDate(year: 2_026, month: 10, day: 21, calendar: calendar, hour: 9),
        duration: 60
      ),
      self.record(
        name: "晚",
        startDate: try Self.makeDate(year: 2_026, month: 10, day: 23, calendar: calendar, hour: 9),
        duration: 60
      )
    ]

    XCTAssertEqual(records.sorted(by: MVHistorySort()).map(\.name), ["晚", "早"])
    XCTAssertEqual(
      records.sorted(by: MVHistorySort(key: .startDate, ascending: true)).map(\.name),
      ["早", "晚"]
    )
  }

  func testSortByDuration() throws {
    let calendar = Self.gmtCalendar()
    let startDate = try Self.makeDate(year: 2_026, month: 10, day: 23, calendar: calendar, hour: 9)
    let records = [
      self.record(name: "长", startDate: startDate, duration: 600),
      self.record(name: "短", startDate: startDate, duration: 60)
    ]

    XCTAssertEqual(records.sorted(by: MVHistorySort(key: .duration, ascending: true)).map(\.name), ["短", "长"])
    XCTAssertEqual(records.sorted(by: MVHistorySort(key: .duration, ascending: false)).map(\.name), ["长", "短"])
  }

  func testSortByNameIsCaseInsensitiveAndStable() throws {
    let calendar = Self.gmtCalendar()
    let startDate = try Self.makeDate(year: 2_026, month: 10, day: 23, calendar: calendar, hour: 9)
    let records = [
      self.record(name: "b", startDate: startDate, duration: 60),
      self.record(name: "A", startDate: startDate, duration: 60)
    ]

    XCTAssertEqual(records.sorted(by: MVHistorySort(key: .name, ascending: true)).map(\.name), ["A", "b"])
  }

  func testPreferredAscendingPerColumn() {
    XCTAssertTrue(MVHistorySort.preferredAscending(for: .name))
    XCTAssertTrue(MVHistorySort.preferredAscending(for: .title))
    XCTAssertFalse(MVHistorySort.preferredAscending(for: .startDate))
    XCTAssertFalse(MVHistorySort.preferredAscending(for: .duration))
  }

  // MARK: - 打开时默认的区间

  func testFirstOpenDefaultsToToday() throws {
    let suiteName = "TimerHistoryFilterDefaultTests"
    let defaults = try self.emptyDefaults(suiteName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let loaded = MVHistoryFilterStore.load(from: defaults)
    XCTAssertEqual(loaded, .default)
    XCTAssertNotNil(loaded.range, "第一次打开不能是「全部记录」")
    XCTAssertTrue(loaded.range?.contains(Date()) ?? false, "默认区间要含今天")
  }

  // MARK: - 记住上次的区间

  func testStoreRoundTrip() throws {
    let suiteName = "TimerHistoryFilterTests"
    let defaults = try self.emptyDefaults(suiteName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    XCTAssertEqual(MVHistoryFilterStore.load(from: defaults), .default)

    let calendar = Self.gmtCalendar()
    let now = try Self.makeDate(year: 2_026, month: 10, day: 23, calendar: calendar, hour: 12)
    let filter = MVHistoryDateFilter.today(calendar: calendar, now: now)
    MVHistoryFilterStore.save(filter, to: defaults)
    XCTAssertEqual(MVHistoryFilterStore.load(from: defaults).range, filter)

    MVHistoryFilterStore.save(nil, to: defaults)
    XCTAssertNil(MVHistoryFilterStore.load(from: defaults).range, "存 nil 等于记住「全部记录」，不该退回今天")
  }

  func testLegacyPayloadFallsBackToDefault() throws {
    let suiteName = "TimerHistoryFilterLegacyTests"
    let defaults = try self.emptyDefaults(suiteName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    // 更早的版本把区间直接存成 JSON，没有 range 这一层：当没存过处理
    let calendar = Self.gmtCalendar()
    let filter = MVHistoryDateFilter.today(
      calendar: calendar,
      now: try Self.makeDate(year: 2_026, month: 10, day: 23, calendar: calendar, hour: 12)
    )
    defaults.set(try JSONEncoder().encode(filter), forKey: MVUserDefaultsKeys.historyDateFilter)

    XCTAssertEqual(MVHistoryFilterStore.load(from: defaults), .default)
  }

  // MARK: - 列表里的日期文案

  func testStartDateDisplayUsesChineseMonthAndDay() throws {
    let date = try XCTUnwrap(
      Calendar.current.date(from: DateComponents(year: 2_026, month: 10, day: 23, hour: 21, minute: 30))
    )
    let record = self.record(name: "中文日期", startDate: date, duration: 60)

    XCTAssertTrue(record.startDateDisplay.hasPrefix("10月23日"), record.startDateDisplay)
    XCTAssertFalse(record.startDateDisplay.contains("Oct"), record.startDateDisplay)
  }

  func testOpenEndedRecordEndsWithUntilNow() {
    XCTAssertEqual(ClockRecord.starting(mode: .stopwatch).endDateDisplay, "至今")
  }

  // MARK: - 辅助

  /// 每个用例用独立的 UserDefaults，先清干净免得互相串
  private func emptyDefaults(suiteName: String) throws -> UserDefaults {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  private static func gmtCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }

  private static func makeDate(
    year: Int,
    month: Int,
    day: Int,
    calendar: Calendar,
    hour: Int = 0
  ) throws -> Date {
    try XCTUnwrap(
      calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))
    )
  }

  private func record(name: String, startDate: Date, duration: TimeInterval) -> ClockRecord {
    var record = ClockRecord.starting(mode: .stopwatch)
    record.name = name
    record.startDate = startDate
    record.duration = duration
    return record
  }
}
