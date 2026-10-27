import AppKit
@testable import Timer
import XCTest

/// 事件自己的每日时长、表盘显示哪一条、轮播、模板带事件
@MainActor
final class TimerEventDisplayTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    return calendar
  }

  private func makeDefaults() -> UserDefaults {
    let suite = "TimerEventDisplayTests-\(UUID().uuidString)"
    return UserDefaults(suiteName: suite) ?? .standard
  }

  /// 以今天 0 点为基准，往后推若干天的那个 0 点
  private func day(_ offset: Int) -> Date {
    self.calendar.date(byAdding: .day, value: offset, to: self.calendar.startOfDay(for: Date())) ?? Date()
  }

  /// 倒计时只算到分：基准时刻也把秒抹掉，不然算出来会少一分钟
  private func now() -> Date {
    self.calendar.date(bySetting: .second, value: 0, of: Date()) ?? Date()
  }

  /// 以 now 为基准，往后推 hour 小时的那个时刻
  private func timedEvent(_ title: String, hour: Int, from now: Date) -> TimerEvent {
    var components = self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
    components.hour = (components.hour ?? 0) + hour
    let date = self.calendar.date(from: components) ?? now
    return TimerEvent(title: title, date: date, hasTime: true, calendar: self.calendar)
  }

  /// 事件自己的每日时长：填了用它的，没填回落全局，乱填（0 或 30）也回落
  func testEffectiveHoursPerDayFallsBackToGlobal() {
    let defaults = self.makeDefaults()
    MVEventSettings.save(hoursPerDay: 10, to: defaults)

    let own = TimerEvent(title: "考研", date: self.day(10), hoursPerDay: 12, calendar: self.calendar)
    let fallback = TimerEvent(title: "四级", date: self.day(10), calendar: self.calendar)
    let invalid = TimerEvent(title: "乱填", date: self.day(10), hoursPerDay: 30, calendar: self.calendar)

    XCTAssertEqual(own.effectiveHoursPerDay(from: defaults), 12.0)
    XCTAssertEqual(fallback.effectiveHoursPerDay(from: defaults), 10.0)
    XCTAssertEqual(invalid.effectiveHoursPerDay(from: defaults), 10.0)
  }

  /// 表盘显示哪条：有钦点的（哪怕不是最近的）就显示钦点的，没有就显示最近的
  func testDisplayedItemPrefersPreferredEvent() {
    let now = self.now()
    let near = timedEvent("近的", hour: 100, from: now)
    let far = timedEvent("远的", hour: 200, from: now)

    let picked = MVEventCountdown.item(from: [near, far], preferredEventID: far.id, now: now)
    XCTAssertEqual(picked?.event.title, "远的")

    let auto = MVEventCountdown.item(from: [near, far], preferredEventID: nil, now: now)
    XCTAssertEqual(auto?.event.title, "近的")
  }

  /// 轮播：按序号轮着来，转过头了取余回到开头
  func testRotatingItemWrapsAround() {
    let now = self.now()
    let events = [timedEvent("一", hour: 100, from: now), timedEvent("二", hour: 200, from: now)]

    XCTAssertEqual(MVEventCountdown.rotatingItem(from: events, index: 0, now: now)?.event.title, "一")
    XCTAssertEqual(MVEventCountdown.rotatingItem(from: events, index: 1, now: now)?.event.title, "二")
    XCTAssertEqual(MVEventCountdown.rotatingItem(from: events, index: 2, now: now)?.event.title, "一")
    XCTAssertEqual(MVEventCountdown.rotatingItem(from: events, index: -1, now: now)?.event.title, "二")
  }

  /// 选中哪个事件 / 轮播开关：存了能读回，改了会广播
  func testSelectedEventAndRotationSettings() {
    let defaults = self.makeDefaults()
    let event = TimerEvent(title: "考研", date: self.day(10), calendar: self.calendar)
    let rotateExpectation = self.expectation(
      forNotification: MVEventSettings.didChangeNotification, object: nil
    ) { _ in true }
    let pickExpectation = self.expectation(
      forNotification: MVEventSettings.didChangeNotification, object: nil
    ) { _ in true }

    XCTAssertNil(MVEventSettings.selectedEventID(from: defaults))
    XCTAssertFalse(MVEventSettings.isRotating(from: defaults))

    MVEventSettings.save(isRotating: true, to: defaults)
    MVEventSettings.save(selectedEventID: event.id, to: defaults)

    self.wait(for: [rotateExpectation, pickExpectation], timeout: 1)
    XCTAssertTrue(MVEventSettings.isRotating(from: defaults))
    XCTAssertEqual(MVEventSettings.selectedEventID(from: defaults), event.id)
  }

  /// 老数据没有 hoursPerDay / templateID：读得回来，当作用全局的
  func testDecodesLegacyTimerEventWithoutNewFields() throws {
    let full = TimerEvent(title: "考研", date: Date(), hasTime: true, calendar: self.calendar)
    var json = try JSONEncoder().encode([full])
    let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: json) as? [[String: Any]])
    let stripped = object.map { $0.filter { $0.key != "hoursPerDay" && $0.key != "templateID" } }
    json = try JSONSerialization.data(withJSONObject: stripped)

    let decoded = try JSONDecoder().decode([TimerEvent].self, from: json)

    XCTAssertEqual(decoded.count, 1)
    XCTAssertEqual(decoded[0].title, "考研")
    XCTAssertNil(decoded[0].hoursPerDay)
    XCTAssertNil(decoded[0].templateID)
  }

  /// 模板带了事件：编码解码丢不了 eventID；老模板没有这个字段也读得回
  func testTemplateCarriesEventID() throws {
    let eventID = UUID()
    let template = ChildClockTemplate(id: UUID(), name: "考研", mode: .stopwatch, eventID: eventID)

    let data = try JSONEncoder().encode(template)
    let decoded = try JSONDecoder().decode(ChildClockTemplate.self, from: data)
    XCTAssertEqual(decoded.eventID, eventID)

    let legacy = ChildClockTemplate(id: UUID(), name: "数学", mode: .stopwatch)
    var legacyJSON = try JSONEncoder().encode(legacy)
    let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: legacyJSON) as? [String: Any])
    let stripped = object.filter { $0.key != "eventID" }
    legacyJSON = try JSONSerialization.data(withJSONObject: stripped)

    let legacyDecoded = try JSONDecoder().decode(ChildClockTemplate.self, from: legacyJSON)
    XCTAssertEqual(legacyDecoded.name, "数学")
    XCTAssertNil(legacyDecoded.eventID)
  }
}
