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

  init(
    id: UUID,
    name: String,
    mode: TimerMode,
    duration: CGFloat = 0,
    autoStart: Bool = true
  ) {
    self.id = id
    self.name = name
    self.mode = mode
    self.duration = duration
    self.autoStart = autoStart
  }

  /// 菜单悬停提示用的一行说明，例如「倒计时 25:00」「秒表」
  var summary: String {
    switch self.mode {
    case .countdown:
      return "倒计时 \(TimerLogic.durationDisplayString(seconds: self.duration))"

    case .stopwatch:
      return "秒表"
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
  static func upsert(_ template: ChildClockTemplate) {
    var templates = Self.load()
    if let index = templates.firstIndex(where: { $0.name == template.name }) {
      templates[index] = template
    } else {
      templates.append(template)
    }
    Self.save(templates)
  }

  /// 删掉一个模板（名字写错了时用）
  static func remove(id: UUID) {
    Self.save(Self.load().filter { $0.id != id })
  }
}
