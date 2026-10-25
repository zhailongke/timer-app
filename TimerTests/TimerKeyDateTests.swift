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

  /// 倒计时只算到分：基准时刻也把秒抹掉，不然算出来会少一分钟
  private func now() -> Date {
    self.calendar.date(bySetting: .second, value: 0, of: Date()) ?? Date()
  }

  /// 以 now 为基准，往后推 hour 小时 minute 分钟的那个时刻
  private func moment(_ hour: Int, _ minute: Int, from now: Date = Date()) -> Date {
    var components = self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
    components.hour = (components.hour ?? 0) + hour
    components.minute = (components.minute ?? 0) + minute
    return self.calendar.date(from: components) ?? now
  }

  private func timedKeyDate(
    _ title: String,
    hour: Int,
    minute: Int,
    from now: Date = Date()
  ) -> KeyDate {
    KeyDate(
      title: title,
      date: self.moment(hour, minute, from: now),
      hasTime: true,
      calendar: self.calendar
    )
  }

  func testKeyDateNormalizesToStartOfDay() {
    let afternoon = self.calendar.date(byAdding: .hour, value: 15, to: self.day(0)) ?? Date()
    let keyDate = KeyDate(title: "考研", date: afternoon, calendar: self.calendar)

    XCTAssertEqual(keyDate.date, self.calendar.startOfDay(for: afternoon))
  }

  func testDaysUntil() {
    let now = self.now()

    XCTAssertEqual(MVKeyDateCountdown.days(to: self.day(0, from: now), from: now, calendar: self.calendar), 0)
    XCTAssertEqual(MVKeyDateCountdown.days(to: self.day(1, from: now), from: now, calendar: self.calendar), 1)
    XCTAssertEqual(MVKeyDateCountdown.days(to: self.day(55, from: now), from: now, calendar: self.calendar), 55)
    XCTAssertEqual(MVKeyDateCountdown.days(to: self.day(-1, from: now), from: now, calendar: self.calendar), -1)
  }

  func testUpcomingDropsPastAndSortsByDays() {
    let now = self.now()
    let later = self.keyDate("复试", offset: 120, from: now)
    let nearer = self.keyDate("考研", offset: 19, from: now)
    let gone = self.keyDate("报名", offset: -3, from: now)

    let items = MVKeyDateCountdown.upcoming(from: [later, gone, nearer], now: now, calendar: self.calendar)

    XCTAssertEqual(items.count, 2)
    XCTAssertEqual(items[0].keyDate.title, "考研")
    XCTAssertEqual(items[0].remaining.days, 19)
    XCTAssertEqual(items[1].keyDate.title, "复试")
    XCTAssertEqual(items[1].remaining.days, 120)
  }

  func testUpcomingKeepsTodayAndCapsAtThreeLines() {
    let now = self.now()
    let dates = (0..<5).map { self.keyDate("日子\($0)", offset: $0, from: now) }

    let items = MVKeyDateCountdown.upcoming(from: dates, now: now, calendar: self.calendar)

    XCTAssertEqual(items.count, MVKeyDateCountdown.maxLines)
    XCTAssertEqual(items.map(\.remaining.days), [0, 1, 2])
  }

  func testLineText() {
    let now = self.now()

    // 只算到天：跟以前一样
    XCTAssertEqual(
      MVKeyDateCountdown.line(self.item(self.keyDate("考研", offset: 0, from: now), now: now)),
      "考研 今天"
    )
    XCTAssertEqual(
      MVKeyDateCountdown.line(self.item(self.keyDate("考研", offset: 55, from: now), now: now)),
      "考研 55天"
    )

    // 指定了时刻：按还有几小时几分钟算
    XCTAssertEqual(
      MVKeyDateCountdown.line(self.item(self.timedKeyDate("考研", hour: 50, minute: 20, from: now), now: now)),
      "考研 2天2时"
    )
    XCTAssertEqual(
      MVKeyDateCountdown.line(self.item(self.timedKeyDate("考研", hour: 5, minute: 20, from: now), now: now)),
      "考研 5时20分"
    )
    XCTAssertEqual(
      MVKeyDateCountdown.line(self.item(self.timedKeyDate("考研", hour: 0, minute: 25, from: now), now: now)),
      "考研 25分"
    )
  }

  /// 管理窗口「还有」列比表盘写得完整
  func testManagerText() {
    let now = self.now()

    XCTAssertEqual(
      MVKeyDateCountdown.text(self.item(self.keyDate("考研", offset: 55, from: now), now: now)),
      "55 天"
    )
    XCTAssertEqual(
      MVKeyDateCountdown.text(self.item(self.timedKeyDate("考研", hour: 50, minute: 20, from: now), now: now)),
      "2天2时20分"
    )
  }

  /// 同一天里：只算到天的（当天 0 点）排在指定了时刻的前面
  func testUpcomingPutsWholeDayBeforeTimedOnSameDay() {
    let now = self.now()
    let wholeDay = self.keyDate("出分", offset: 0, from: now)
    let timed = self.timedKeyDate("开考", hour: 3, minute: 0, from: now)

    let items = MVKeyDateCountdown.upcoming(from: [timed, wholeDay], now: now, calendar: self.calendar)

    XCTAssertEqual(items.map(\.keyDate.title), ["出分", "开考"])
  }

  /// 时刻已过的日子不再显示（只算到天的当天仍算「今天」）
  func testUpcomingDropsPastMoments() {
    let now = self.now()
    let gone = self.timedKeyDate("报名", hour: -2, minute: 0, from: now)
    let wholeDay = self.keyDate("今天", offset: 0, from: now)

    let items = MVKeyDateCountdown.upcoming(from: [gone, wholeDay], now: now, calendar: self.calendar)

    XCTAssertEqual(items.map(\.keyDate.title), ["今天"])
  }

  /// 指定了时刻的只把秒抹掉，日期不变
  func testTimedKeyDateKeepsHourAndMinute() {
    let now = self.now()
    let keyDate = self.timedKeyDate("考研", hour: 2, minute: 30, from: now)

    XCTAssertEqual(keyDate.date, self.moment(2, 30, from: now), "时分秒之外的部分不动，秒归零")
    XCTAssertEqual(self.calendar.component(.second, from: keyDate.date), 0)
  }

  /// 表盘最下面那一行：天和小时折成一个总小时数
  func testTotalHoursText() {
    let now = self.now()

    XCTAssertEqual(
      MVKeyDateCountdown.totalHoursText(
        self.item(self.timedKeyDate("考研", hour: 50, minute: 20, from: now), now: now)
      ),
      "50小时",
      "2 天 2 小时"
    )
    XCTAssertEqual(
      MVKeyDateCountdown.totalHoursText(
        self.item(self.timedKeyDate("考研", hour: 5, minute: 20, from: now), now: now)
      ),
      "5小时"
    )
  }

  /// 只按天算的日子没有准确时刻，总小时数不显示
  func testTotalHoursTextIsNilWithoutTime() {
    let now = self.now()

    XCTAssertNil(
      MVKeyDateCountdown.totalHoursText(self.item(self.keyDate("考研", offset: 55, from: now), now: now))
    )
  }

  /// 老版本存的日子没有 hasTime 字段：解出来当「没指定时刻」
  func testDecodesLegacyKeyDateWithoutHasTime() throws {
    let legacy = KeyDate(title: "考研", date: Date(), calendar: self.calendar)
    var json = try JSONEncoder().encode([legacy])
    let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: json) as? [[String: Any]])
    let stripped = object.map { $0.filter { $0.key != "hasTime" } }
    json = try JSONSerialization.data(withJSONObject: stripped)

    let decoded = try JSONDecoder().decode([KeyDate].self, from: json)

    XCTAssertEqual(decoded.count, 1)
    XCTAssertFalse(decoded[0].hasTime)
    XCTAssertEqual(decoded[0].date, legacy.date)
  }

  private func item(_ keyDate: KeyDate, now: Date = Date()) -> MVKeyDateCountdownItem {
    MVKeyDateCountdownItem(keyDate: keyDate, remaining: keyDate.remaining(from: now, calendar: self.calendar))
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
