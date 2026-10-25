import Foundation
@testable import Timer
import XCTest

@MainActor
final class TimerKeyDateTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    return calendar
  }

  private func makeDefaults() -> UserDefaults {
    let suite = "TimerKeyDateTests-\(UUID().uuidString)"
    return UserDefaults(suiteName: suite) ?? .standard
  }

  /// 以今天 0 点为基准，往前/往后推若干天的那个 0 点
  private func day(_ offset: Int, from now: Date = Date()) -> Date {
    self.calendar.date(byAdding: .day, value: offset, to: self.calendar.startOfDay(for: now)) ?? now
  }

  private func keyDate(_ title: String, offset: Int, from now: Date = Date()) -> KeyDate {
    KeyDate(title: title, date: self.day(offset, from: now), calendar: self.calendar)
  }

  func testKeyDateNormalizesToStartOfDay() {
    let afternoon = self.calendar.date(byAdding: .hour, value: 15, to: self.day(0)) ?? Date()
    let keyDate = KeyDate(title: "考研", date: afternoon, calendar: self.calendar)

    XCTAssertEqual(keyDate.date, self.calendar.startOfDay(for: afternoon))
  }

  func testDaysUntil() {
    let now = Date()

    XCTAssertEqual(MVKeyDateCountdown.days(to: self.day(0, from: now), from: now, calendar: self.calendar), 0)
    XCTAssertEqual(MVKeyDateCountdown.days(to: self.day(1, from: now), from: now, calendar: self.calendar), 1)
    XCTAssertEqual(MVKeyDateCountdown.days(to: self.day(55, from: now), from: now, calendar: self.calendar), 55)
    XCTAssertEqual(MVKeyDateCountdown.days(to: self.day(-1, from: now), from: now, calendar: self.calendar), -1)
  }

  func testUpcomingDropsPastAndSortsByDays() {
    let now = Date()
    let later = self.keyDate("复试", offset: 120, from: now)
    let nearer = self.keyDate("考研", offset: 19, from: now)
    let gone = self.keyDate("报名", offset: -3, from: now)

    let items = MVKeyDateCountdown.upcoming(from: [later, gone, nearer], now: now, calendar: self.calendar)

    XCTAssertEqual(items.count, 2)
    XCTAssertEqual(items[0].keyDate.title, "考研")
    XCTAssertEqual(items[0].days, 19)
    XCTAssertEqual(items[1].keyDate.title, "复试")
    XCTAssertEqual(items[1].days, 120)
  }

  func testUpcomingKeepsTodayAndCapsAtThreeLines() {
    let now = Date()
    let dates = (0..<5).map { self.keyDate("日子\($0)", offset: $0, from: now) }

    let items = MVKeyDateCountdown.upcoming(from: dates, now: now, calendar: self.calendar)

    XCTAssertEqual(items.count, MVKeyDateCountdown.maxLines)
    XCTAssertEqual(items.map(\.days), [0, 1, 2])
  }

  func testLineText() {
    XCTAssertEqual(MVKeyDateCountdown.line(title: "考研", days: 0), "考研 今天")
    XCTAssertEqual(MVKeyDateCountdown.line(title: "考研", days: 55), "考研 55天")
    XCTAssertEqual(MVKeyDateCountdown.daysText(-1), "已过")
    XCTAssertEqual(MVKeyDateCountdown.daysText(0), "今天")
    XCTAssertEqual(MVKeyDateCountdown.daysText(9), "9 天")
  }

  func testStoreSaveAndLoad() {
    let defaults = self.makeDefaults()
    let keyDate = self.keyDate("考研", offset: 30)

    MVKeyDateStore.add(keyDate, to: defaults)
    let loaded = MVKeyDateStore.load(from: defaults)

    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.title, "考研")
    XCTAssertEqual(loaded.first?.date, keyDate.date)
  }

  func testStoreUpdateAndRemove() {
    let defaults = self.makeDefaults()
    let keyDate = self.keyDate("考研", offset: 30)
    MVKeyDateStore.add(keyDate, to: defaults)

    var renamed = keyDate
    renamed.title = "考研初试"
    MVKeyDateStore.update(renamed, to: defaults)
    XCTAssertEqual(MVKeyDateStore.load(from: defaults).count, 1)
    XCTAssertEqual(MVKeyDateStore.load(from: defaults).first?.title, "考研初试")

    MVKeyDateStore.remove(id: keyDate.id, from: defaults)
    XCTAssertTrue(MVKeyDateStore.load(from: defaults).isEmpty)
  }
}
