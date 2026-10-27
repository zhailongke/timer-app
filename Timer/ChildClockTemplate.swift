import Foundation

/// 子时钟模板：记下名字、模式与时长，之后可以从模板一键建一个同样的子时钟
struct ChildClockTemplate: Codable, Equatable, Identifiable, Sendable {
  var id: UUID
  var name: String
  var mode: TimerMode
  /// 倒计时时长（秒）；秒表模板用不到
  var duration: CGFloat
  /// 建好之后是否立刻开始跑
  var autoStart: Bool
  /// 勾选「记录下级子时钟」后记下的下级；用模板新建时一并建出来
  var children: [Self]
  /// 这个模板的「倒计时显示」：从模板建出来的子时钟，表盘下方显示这个事件的倒计时。
  /// 创建事件时勾「生成子时钟模板」就会带上
  var eventID: UUID?

  init(
    id: UUID,
    name: String,
    mode: TimerMode,
    duration: CGFloat = 0,
    autoStart: Bool = true,
    children: [Self] = [],
    eventID: UUID? = nil
  ) {
    self.id = id
    self.name = name
    self.mode = mode
    self.duration = duration
    self.autoStart = autoStart
    self.children = children
    self.eventID = eventID
  }

  // 早期版本存的模板没有 children / eventID，读不到就当没有
  private enum CodingKeys: String, CodingKey {
    case autoStart, children, duration, eventID, id, mode, name
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.mode = try container.decode(TimerMode.self, forKey: .mode)
    self.duration = try container.decode(CGFloat.self, forKey: .duration)
    self.autoStart = try container.decode(Bool.self, forKey: .autoStart)
    self.children = try container.decodeIfPresent([Self].self, forKey: .children) ?? []
    self.eventID = try container.decodeIfPresent(UUID.self, forKey: .eventID)
  }

  /// 菜单悬停提示用的一行说明，例如「倒计时 25:00」「秒表 · 含 2 个下级」
  var summary: String {
    let description: String
    switch self.mode {
    case .countdown:
      description = "倒计时 \(TimerLogic.durationDisplayString(seconds: self.duration))"

    case .stopwatch:
      description = "秒表"
    }

    let eventTail = self.eventID != nil ? " · 显示事件倒计时" : ""
    let descendants = self.flattenedDescendants.count
    if descendants > 0 {
      return "\(description) · 含 \(descendants) 个下级\(eventTail)"
    }
    return description + eventTail
  }

  /// 先序遍历出所有下级（含下级的下级），顺序与编辑面板里的行一致
  var flattenedDescendants: [Self] {
    self.children.flatMap { [$0] + $0.flattenedDescendants }
  }

  /// 把编辑面板里改好的名字 / 起跑设置按先序写回树里；名字留空则保持原样
  mutating func applyEdits(_ edits: [(name: String, autoStart: Bool)]) {
    var index = 0
    Self.write(edits, into: &self.children, index: &index)
  }

  private static func write(
    _ edits: [(name: String, autoStart: Bool)],
    into children: inout [Self],
    index: inout Int
  ) {
    for position in children.indices {
      guard index < edits.count else { return }

      let edit = edits[index]
      if !edit.name.isEmpty {
        children[position].name = edit.name
      }
      children[position].autoStart = edit.autoStart
      index += 1

      Self.write(edits, into: &children[position].children, index: &index)
    }
  }
}

/// 模板存在 UserDefaults 里，按名字去重（同名覆盖，避免菜单越堆越长）
enum MVTemplateStore {
  static func load(from defaults: UserDefaults = .standard) -> [ChildClockTemplate] {
    guard let data = defaults.data(forKey: MVUserDefaultsKeys.childClockTemplates),
      let templates = try? JSONDecoder().decode([ChildClockTemplate].self, from: data)
    else { return [] }
    return templates
  }

  static func save(_ templates: [ChildClockTemplate], to defaults: UserDefaults = .standard) {
    guard let data = try? JSONEncoder().encode(templates) else { return }
    defaults.set(data, forKey: MVUserDefaultsKeys.childClockTemplates)
  }

  /// 同名模板覆盖，只留一份
  static func upsert(_ template: ChildClockTemplate, to defaults: UserDefaults = .standard) {
    var templates = Self.load(from: defaults)
    if let index = templates.firstIndex(where: { $0.name == template.name }) {
      templates[index] = template
    } else {
      templates.append(template)
    }
    Self.save(templates, to: defaults)
  }

  /// 按 id 覆盖（管理窗口里改名、改内容都用它，改名也只留一份）
  static func update(_ template: ChildClockTemplate, to defaults: UserDefaults = .standard) {
    var templates = Self.load(from: defaults)
    if let index = templates.firstIndex(where: { $0.id == template.id }) {
      templates[index] = template
    } else {
      templates.append(template)
    }
    Self.save(templates, to: defaults)
  }

  /// 删掉一个模板（名字写错了时用）
  static func remove(id: UUID, from defaults: UserDefaults = .standard) {
    Self.save(Self.load(from: defaults).filter { $0.id != id }, to: defaults)
  }
}
