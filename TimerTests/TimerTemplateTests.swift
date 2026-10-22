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
    MVTemplateStore.upsert(
      ChildClockTemplate(id: UUID(), name: "数学", mode: .countdown, duration: 600),
      to: defaults
    )
    MVTemplateStore.upsert(
      ChildClockTemplate(id: UUID(), name: "数学", mode: .stopwatch),
      to: defaults
    )

    let loaded = MVTemplateStore.load(from: defaults)
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.mode, .stopwatch)
  }

  func testUpsertKeepsDifferentNames() {
    let defaults = self.makeDefaults()
    MVTemplateStore.upsert(ChildClockTemplate(id: UUID(), name: "数学", mode: .countdown, duration: 600), to: defaults)
    MVTemplateStore.upsert(ChildClockTemplate(id: UUID(), name: "英语", mode: .stopwatch), to: defaults)

    XCTAssertEqual(MVTemplateStore.load(from: defaults).map(\.name), ["数学", "英语"])
  }

  func testRemoveTemplate() {
    let defaults = self.makeDefaults()
    let kept = ChildClockTemplate(id: UUID(), name: "英语", mode: .stopwatch)
    let dropped = ChildClockTemplate(id: UUID(), name: "政治", mode: .countdown, duration: 300)
    MVTemplateStore.save([kept, dropped], to: defaults)

    MVTemplateStore.remove(id: dropped.id, from: defaults)

    XCTAssertEqual(MVTemplateStore.load(from: defaults).map(\.name), ["英语"])
  }

  func testNestedChildrenSurviveRoundTrip() {
    let defaults = self.makeDefaults()
    let grandChild = ChildClockTemplate(id: UUID(), name: "作文", mode: .countdown, duration: 1_800)
    let child = ChildClockTemplate(
      id: UUID(),
      name: "英语",
      mode: .stopwatch,
      children: [grandChild]
    )
    let root = ChildClockTemplate(
      id: UUID(),
      name: "数学",
      mode: .countdown,
      duration: 3_600,
      children: [child]
    )

    MVTemplateStore.save([root], to: defaults)
    let loaded = MVTemplateStore.load(from: defaults).first

    XCTAssertEqual(loaded?.children.count, 1)
    XCTAssertEqual(loaded?.children.first?.name, "英语")
    XCTAssertEqual(loaded?.children.first?.children.first?.name, "作文")
    XCTAssertEqual(loaded?.children.first?.children.first?.duration, 1_800)
  }

  /// 早期版本存的模板没有 children，读回来应该当没有下级，而不是整份丢掉
  func testLegacyTemplateWithoutChildren() throws {
    let json = """
    [{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","name":"数学","mode":"countdown","duration":1500,"autoStart":true}]
    """
    let decoded = try JSONDecoder().decode([ChildClockTemplate].self, from: Data(json.utf8))

    XCTAssertEqual(decoded.count, 1)
    XCTAssertTrue(decoded.first?.children.isEmpty ?? false)
  }

  func testFlattenedDescendantsIsPreOrder() {
    let deep = ChildClockTemplate(id: UUID(), name: "作文", mode: .stopwatch)
    let child = ChildClockTemplate(id: UUID(), name: "英语", mode: .stopwatch, children: [deep])
    let sibling = ChildClockTemplate(id: UUID(), name: "政治", mode: .stopwatch)
    let root = ChildClockTemplate(id: UUID(), name: "数学", mode: .countdown, children: [child, sibling])

    XCTAssertEqual(root.flattenedDescendants.map(\.name), ["英语", "作文", "政治"])
  }

  func testApplyEditsRewritesNamesAndAutoStart() {
    var root = ChildClockTemplate(
      id: UUID(),
      name: "数学",
      mode: .countdown,
      children: [
        ChildClockTemplate(
          id: UUID(),
          name: "英语",
          mode: .stopwatch,
          autoStart: true,
          children: [ChildClockTemplate(id: UUID(), name: "作文", mode: .stopwatch, autoStart: true)]
        )
      ]
    )

    root.applyEdits([(name: "英语阅读", autoStart: false), (name: "", autoStart: false)])

    XCTAssertEqual(root.children.first?.name, "英语阅读")
    XCTAssertEqual(root.children.first?.autoStart, false)
    XCTAssertEqual(root.children.first?.children.first?.name, "作文", "名字留空就保持原样")
    XCTAssertEqual(root.children.first?.children.first?.autoStart, false)
  }

  func testSummaryCountsDescendants() {
    let root = ChildClockTemplate(
      id: UUID(),
      name: "数学",
      mode: .countdown,
      duration: 1_500,
      children: [
        ChildClockTemplate(id: UUID(), name: "大题", mode: .stopwatch),
        ChildClockTemplate(id: UUID(), name: "检查", mode: .stopwatch)
      ]
    )

    XCTAssertEqual(root.summary, "倒计时 25:00 · 含 2 个下级")
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

    view.titleDraft = "   "
    view.endTitleEditing()

    XCTAssertEqual(view.clockTitle, "数学", "清空输入就回滚到原来的名字")
    XCTAssertFalse(view.isEditingTitle)
  }

  func testRenamingAppliesNewName() {
    let view = MVClockView()
    view.isTitleEditable = true
    view.clockTitle = "子时钟1"

    view.beginTitleEditing()
    view.titleDraft = "英语"
    view.endTitleEditing()

    XCTAssertEqual(view.clockTitle, "英语")
  }

  func testMainClockTitleIsNotEditable() {
    let view = MVClockView()

    view.beginTitleEditing()

    XCTAssertFalse(view.isEditingTitle)
  }
  /// 管理窗口里改名 / 改内容：按 id 覆盖，不会留下旧名字那一份
  func testUpdateKeepsOneEntryWhenRenamed() {
    let defaults = self.makeDefaults()
    let template = ChildClockTemplate(id: UUID(), name: "数学", mode: .countdown, duration: 1_500)
    MVTemplateStore.save([template], to: defaults)

    var renamed = template
    renamed.name = "数学（新版）"
    renamed.duration = 3_000
    MVTemplateStore.update(renamed, to: defaults)

    let loaded = MVTemplateStore.load(from: defaults)
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.name, "数学（新版）")
    XCTAssertEqual(loaded.first?.duration, 3_000)
  }

  func testUpdateAppendsWhenIdIsUnknown() {
    let defaults = self.makeDefaults()
    let existing = ChildClockTemplate(id: UUID(), name: "数学", mode: .countdown, duration: 1_500)
    MVTemplateStore.save([existing], to: defaults)

    let other = ChildClockTemplate(id: UUID(), name: "英语", mode: .stopwatch)
    MVTemplateStore.update(other, to: defaults)

    XCTAssertEqual(MVTemplateStore.load(from: defaults).count, 2)
  }
}
