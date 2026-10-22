import AppKit
@testable import Timer
import XCTest

@MainActor
final class TimerTemplateTests: XCTestCase {
  private func makeDefaults() -> UserDefaults {
    let suite = "TimerTemplateTests-\(UUID().uuidString)"
    return UserDefaults(suiteName: suite) ?? .standard
  }

  func testSaveAndLoad() {
    let defaults = self.makeDefaults()
    let template = ChildClockTemplate(id: UUID(), name: "数学", mode: .countdown, duration: 1_500, autoStart: true)

    MVTemplateStore.save([template], to: defaults)
    let loaded = MVTemplateStore.load(from: defaults)

    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.name, "数学")
    XCTAssertEqual(loaded.first?.mode, .countdown)
    XCTAssertEqual(loaded.first?.duration, 1_500)
    XCTAssertTrue(loaded.first?.autoStart ?? false)
  }

  func testUpsertReplacesSameName() {
    let defaults = self.makeDefaults()
    MVTemplateStore.save(
      [ChildClockTemplate(id: UUID(), name: "数学", mode: .countdown, duration: 600)],
      to: defaults
    )

    // upsert 走的是 standard；同名覆盖的判定在这里单独验
    var templates = MVTemplateStore.load(from: defaults)
    let updated = ChildClockTemplate(id: UUID(), name: "数学", mode: .stopwatch)
    if let index = templates.firstIndex(where: { $0.name == updated.name }) {
      templates[index] = updated
    } else {
      templates.append(updated)
    }
    MVTemplateStore.save(templates, to: defaults)

    let loaded = MVTemplateStore.load(from: defaults)
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.mode, .stopwatch)
  }

  func testRemoveTemplate() {
    let defaults = self.makeDefaults()
    let kept = ChildClockTemplate(id: UUID(), name: "英语", mode: .stopwatch)
    let dropped = ChildClockTemplate(id: UUID(), name: "政治", mode: .countdown, duration: 300)
    MVTemplateStore.save([kept, dropped], to: defaults)

    MVTemplateStore.save(MVTemplateStore.load(from: defaults).filter { $0.id != dropped.id }, to: defaults)

    let names = MVTemplateStore.load(from: defaults).map(\.name)
    XCTAssertEqual(names, ["英语"])
  }

  func testSummary() {
    let countdown = ChildClockTemplate(id: UUID(), name: "数学", mode: .countdown, duration: 1_500)
    XCTAssertEqual(countdown.summary, "倒计时 25:00")

    let stopwatch = ChildClockTemplate(id: UUID(), name: "英语", mode: .stopwatch)
    XCTAssertEqual(stopwatch.summary, "秒表")
  }

  /// 名字要落在圆框外：时钟圆的下沿在 y=15，名字整块都在它下面
  func testTitleSitsOutsideClockFace() {
    let view = MVClockView()

    XCTAssertLessThanOrEqual(view.titleLabel.frame.maxY, 15)
  }

  func testRenamingKeepsPreviousNameWhenCleared() {
    let view = MVClockView()
    view.isTitleEditable = true
    view.clockTitle = "数学"

    view.beginTitleEditing()
    XCTAssertTrue(view.isEditingTitle)

    view.titleLabel.string = "   "
    view.endTitleEditing()

    XCTAssertEqual(view.clockTitle, "数学", "清空输入就回滚到原来的名字")
    XCTAssertFalse(view.isEditingTitle)
  }

  func testRenamingAppliesNewName() {
    let view = MVClockView()
    view.isTitleEditable = true
    view.clockTitle = "子时钟1"

    view.beginTitleEditing()
    view.titleLabel.string = "英语"
    view.endTitleEditing()

    XCTAssertEqual(view.clockTitle, "英语")
  }

  func testMainClockTitleIsNotEditable() {
    let view = MVClockView()

    view.beginTitleEditing()

    XCTAssertFalse(view.isEditingTitle)
  }
}
