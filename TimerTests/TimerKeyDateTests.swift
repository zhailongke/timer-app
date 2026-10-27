import AppKit
@testable import Timer
import XCTest

@MainActor
final class TimerTimerEventTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    return calendar
  }

  private func makeDefaults() -> UserDefaults {
    let suite = "TimerTimerEventTests-\(UUID().uuidString)"
    return UserDefaults(suiteName: suite) ?? .standard
  }

  /// 以今天 0 点为基准，往前/往后推若干天的那个 0 点
  private func day(_ offset: Int, from now: Date = Date()) -> Date {
    self.calendar.date(byAdding: .day, value: offset, to: self.calendar.startOfDay(for: now)) ?? now
  }

  private func event(_ title: String, offset: Int, from now: Date = Date()) -> TimerEvent {
    TimerEvent(title: title, date: self.day(offset, from: now), calendar: self.calendar)
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

  private func timedTimerEvent(
    _ title: String,
    hour: Int,
    minute: Int,
    from now: Date = Date()
  ) -> TimerEvent {
    TimerEvent(
      title: title,
      date: self.moment(hour, minute, from: now),
      hasTime: true,
      calendar: self.calendar
    )
  }

  func testTimerEventNormalizesToStartOfDay() {
    let afternoon = self.calendar.date(byAdding: .hour, value: 15, to: self.day(0)) ?? Date()
    let event = TimerEvent(title: "考研", date: afternoon, calendar: self.calendar)

    XCTAssertEqual(event.date, self.calendar.startOfDay(for: afternoon))
  }

  func testDaysUntil() {
    let now = self.now()

    XCTAssertEqual(MVEventCountdown.days(to: self.day(0, from: now), from: now, calendar: self.calendar), 0)
    XCTAssertEqual(MVEventCountdown.days(to: self.day(1, from: now), from: now, calendar: self.calendar), 1)
    XCTAssertEqual(MVEventCountdown.days(to: self.day(55, from: now), from: now, calendar: self.calendar), 55)
    XCTAssertEqual(MVEventCountdown.days(to: self.day(-1, from: now), from: now, calendar: self.calendar), -1)
  }

  func testUpcomingDropsPastAndSortsByDays() {
    let now = self.now()
    let later = self.event("复试", offset: 120, from: now)
    let nearer = self.event("考研", offset: 19, from: now)
    let gone = self.event("报名", offset: -3, from: now)

    let items = MVEventCountdown.upcoming(from: [later, gone, nearer], now: now, calendar: self.calendar)

    XCTAssertEqual(items.count, 2)
    XCTAssertEqual(items[0].event.title, "考研")
    XCTAssertEqual(items[0].remaining.days, 19)
    XCTAssertEqual(items[1].event.title, "复试")
    XCTAssertEqual(items[1].remaining.days, 120)
  }

  func testUpcomingKeepsTodayAndCapsAtThreeLines() {
    let now = self.now()
    let dates = (0..<5).map { self.event("日子\($0)", offset: $0, from: now) }

    let items = MVEventCountdown.upcoming(from: dates, now: now, calendar: self.calendar)

    XCTAssertEqual(items.count, MVEventCountdown.maxLines)
    XCTAssertEqual(items.map(\.remaining.days), [0, 1, 2])
  }

  func testLineText() {
    let now = self.now()

    // 只算到天：跟以前一样
    XCTAssertEqual(
      MVEventCountdown.line(self.item(self.event("考研", offset: 0, from: now), now: now)),
      "考研 今天"
    )
    XCTAssertEqual(
      MVEventCountdown.line(self.item(self.event("考研", offset: 55, from: now), now: now)),
      "考研 55天"
    )

    // 指定了时刻：按还有几小时几分钟算
    XCTAssertEqual(
      MVEventCountdown.line(self.item(self.timedTimerEvent("考研", hour: 50, minute: 20, from: now), now: now)),
      "考研 2天2时"
    )
    XCTAssertEqual(
      MVEventCountdown.line(self.item(self.timedTimerEvent("考研", hour: 5, minute: 20, from: now), now: now)),
      "考研 5时20分"
    )
    XCTAssertEqual(
      MVEventCountdown.line(self.item(self.timedTimerEvent("考研", hour: 0, minute: 25, from: now), now: now)),
      "考研 25分"
    )
  }

  /// 管理窗口「还有」列比表盘写得完整
  func testManagerText() {
    let now = self.now()

    XCTAssertEqual(
      MVEventCountdown.text(self.item(self.event("考研", offset: 55, from: now), now: now)),
      "55 天"
    )
    XCTAssertEqual(
      MVEventCountdown.text(self.item(self.timedTimerEvent("考研", hour: 50, minute: 20, from: now), now: now)),
      "2天2时20分"
    )
  }

  /// 同一天里：只算到天的（当天 0 点）排在指定了时刻的前面
  func testUpcomingPutsWholeDayBeforeTimedOnSameDay() {
    let now = self.now()
    let wholeDay = self.event("出分", offset: 0, from: now)
    let timed = self.timedTimerEvent("开考", hour: 3, minute: 0, from: now)

    let items = MVEventCountdown.upcoming(from: [timed, wholeDay], now: now, calendar: self.calendar)

    XCTAssertEqual(items.map(\.event.title), ["出分", "开考"])
  }

  /// 时刻已过的日子不再显示（只算到天的当天仍算「今天」）
  func testUpcomingDropsPastMoments() {
    let now = self.now()
    let gone = self.timedTimerEvent("报名", hour: -2, minute: 0, from: now)
    let wholeDay = self.event("今天", offset: 0, from: now)

    let items = MVEventCountdown.upcoming(from: [gone, wholeDay], now: now, calendar: self.calendar)

    XCTAssertEqual(items.map(\.event.title), ["今天"])
  }

  /// 指定了时刻的只把秒抹掉，日期不变
  func testTimedTimerEventKeepsHourAndMinute() {
    let now = self.now()
    let event = self.timedTimerEvent("考研", hour: 2, minute: 30, from: now)

    XCTAssertEqual(event.date, self.moment(2, 30, from: now), "时分秒之外的部分不动，秒归零")
    XCTAssertEqual(self.calendar.component(.second, from: event.date), 0)
  }

  /// 表盘最下面那一行：天和小时折成一个总小时数
  func testTotalHoursText() {
    let now = self.now()

    XCTAssertEqual(
      MVEventCountdown.totalHoursText(
        self.item(self.timedTimerEvent("考研", hour: 50, minute: 20, from: now), now: now)
      ),
      "50小时",
      "2 天 2 小时"
    )
    XCTAssertEqual(
      MVEventCountdown.totalHoursText(
        self.item(self.timedTimerEvent("考研", hour: 5, minute: 20, from: now), now: now)
      ),
      "5小时"
    )
  }

  /// 一天只按 10 小时算：55 天就是 550 小时，不是 1320
  func testTotalHoursWithCustomHoursPerDay() {
    let now = self.now()
    let remaining = MVEventRemaining(days: 55, hours: 8, minutes: 20, isPast: false)

    XCTAssertEqual(MVEventCountdown.totalHours(remaining), 1_328, "默认一天 24 小时")
    XCTAssertEqual(MVEventCountdown.totalHours(remaining, hoursPerDay: 10), 553)
    XCTAssertEqual(
      MVEventCountdown.totalHoursText(
        self.item(self.timedTimerEvent("考研", hour: 2, minute: 0, from: now), now: now),
        hoursPerDay: 10
      ),
      "0小时",
      "不到一天：零头也按同一比例折，2 小时只算 0.8 小时"
    )
  }

  /// 正计时的蓝条：已经计时的时长占一天的比例，一天多长按每日时长算
  func testStopwatchDayProgress() {
    XCTAssertEqual(MVClockView.stopwatchDayProgress(elapsed: 0, dayHours: 10), 0)
    XCTAssertEqual(
      MVClockView.stopwatchDayProgress(elapsed: 3_600, dayHours: 10),
      0.1,
      accuracy: 0.0001,
      "学满 1 小时 / 一天 10 小时"
    )
    XCTAssertEqual(MVClockView.stopwatchDayProgress(elapsed: 10 * 3_600, dayHours: 10), 1)
    XCTAssertEqual(
      MVClockView.stopwatchDayProgress(elapsed: 20 * 3_600, dayHours: 10),
      1,
      "超时就满圈，不再绕第二圈"
    )
    XCTAssertEqual(
      MVClockView.stopwatchDayProgress(elapsed: 3_600, dayHours: 24),
      1.0 / 24,
      accuracy: 0.0001,
      "默认一天 24 小时"
    )
  }

  /// 折算比例存在 UserDefaults 里；没存过或填了不合理的数都按 24
  func testHoursPerDaySetting() {
    let defaults = self.makeDefaults()

    XCTAssertEqual(MVEventSettings.hoursPerDay(from: defaults), 24, "没存过按默认")

    MVEventSettings.save(hoursPerDay: 10, to: defaults)
    XCTAssertEqual(MVEventSettings.hoursPerDay(from: defaults), 10)

    MVEventSettings.save(hoursPerDay: 30, to: defaults)
    XCTAssertEqual(MVEventSettings.hoursPerDay(from: defaults), 24, "超出范围回到默认")

    MVEventSettings.save(hoursPerDay: nil, to: defaults)
    XCTAssertEqual(MVEventSettings.hoursPerDay(from: defaults), 24, "留空也回到默认")
  }

  /// 改完要广播一声：表盘的蓝条和总小时数靠这条通知刷新。
  /// 之前输入框的 action 只在回车 / 失焦时才发，改了数字常常根本没存，
  /// 表现就是「改了没反应，要再点一次添加关键日子才变」
  func testHoursPerDayChangePostsNotification() {
    let defaults = self.makeDefaults()
    let expectation = self.expectation(
      forNotification: MVEventSettings.didChangeNotification,
      object: nil
    ) { _ in true }

    MVEventSettings.save(hoursPerDay: 8, to: defaults)

    self.wait(for: [expectation], timeout: 1)
    XCTAssertEqual(MVEventSettings.hoursPerDay(from: defaults), 8)
  }

  /// 只按天算的日子没有准确时刻，总小时数不显示
  func testTotalHoursTextIsNilWithoutTime() {
    let now = self.now()

    XCTAssertNil(
      MVEventCountdown.totalHoursText(self.item(self.event("考研", offset: 55, from: now), now: now))
    )
  }

  /// 老版本存的日子没有 hasTime 字段：解出来当「没指定时刻」
  func testDecodesLegacyTimerEventWithoutHasTime() throws {
    let legacy = TimerEvent(title: "考研", date: Date(), calendar: self.calendar)
    var json = try JSONEncoder().encode([legacy])
    let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: json) as? [[String: Any]])
    let stripped = object.map { $0.filter { $0.key != "hasTime" } }
    json = try JSONSerialization.data(withJSONObject: stripped)

    let decoded = try JSONDecoder().decode([TimerEvent].self, from: json)

    XCTAssertEqual(decoded.count, 1)
    XCTAssertFalse(decoded[0].hasTime)
    XCTAssertEqual(decoded[0].date, legacy.date)
  }

  private func item(_ event: TimerEvent, now: Date = Date()) -> MVEventCountdownItem {
    MVEventCountdownItem(event: event, remaining: event.remaining(from: now, calendar: self.calendar))
  }

  func testStoreSaveAndLoad() {
    let defaults = self.makeDefaults()
    let event = self.event("考研", offset: 30)

    MVEventStore.add(event, to: defaults)
    let loaded = MVEventStore.load(from: defaults)

    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.title, "考研")
    XCTAssertEqual(loaded.first?.date, event.date)
  }

  func testStoreUpdateAndRemove() {
    let defaults = self.makeDefaults()
    let event = self.event("考研", offset: 30)
    MVEventStore.add(event, to: defaults)

    var renamed = event
    renamed.title = "考研初试"
    MVEventStore.update(renamed, to: defaults)
    XCTAssertEqual(MVEventStore.load(from: defaults).count, 1)
    XCTAssertEqual(MVEventStore.load(from: defaults).first?.title, "考研初试")

    MVEventStore.remove(id: event.id, from: defaults)
    XCTAssertTrue(MVEventStore.load(from: defaults).isEmpty)
  }
}
