import AppKit

/// 事件编辑弹窗：名字 + 日期 +（可选）时刻 +（可选）自己的每日时长 +（可选）生成子时钟模板。
/// 新增和「修改…」都走这里，返回 nil 表示取消
@MainActor
enum MVEventEditor {
  /// 弹窗期间持有复选框的 target（弱引用，得留在静态变量里跑完弹窗）
  private static var timeToggleHandler: TimeToggleHandler?
  private static var templateOptionsHandler: TemplateOptionsHandler?

  /// 编辑结果：事件本身，以及要不要顺手生成 / 更新一个子时钟模板
  struct Result {
    var event: TimerEvent
    var template: ChildClockTemplate?
  }

  static func edit(
    _ draft: TimerEvent,
    title: String,
    message: String
  ) -> Result? {
    let calendar = Calendar.current
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message

    let fields = Self.buildFields(draft)
    alert.accessoryView = Self.formStack(fields: fields)
    alert.addButton(withTitle: "好")
    alert.addButton(withTitle: "取消")
    alert.window.initialFirstResponder = fields.name

    let confirmed = alert.runModal() == .alertFirstButtonReturn
    Self.timeToggleHandler = nil
    Self.templateOptionsHandler = nil
    guard confirmed else { return nil }

    return Self.makeResult(draft: draft, fields: fields, calendar: calendar)
  }

  /// 弹窗里的控件一箩筐：挂联动的 target 要持着它们，收结果时也要读它们
  private struct Fields {
    let name: NSTextField
    let date: NSDatePicker
    let time: NSDatePicker
    let timeToggle: NSButton
    let hours: NSTextField
    let makeTemplate: NSButton
    let mode: NSSegmentedControl
    let duration: NSTextField
  }

  private static func buildFields(_ draft: TimerEvent) -> Fields {
    let name = Self.nameField(draft)
    let date = Self.datePicker(draft, calendar: .current)
    let time = Self.timePicker(draft, calendar: .current)
    let timeToggle = Self.timeToggle(draft) { isOn in
      time.isEnabled = isOn
    }
    let hours = Self.hoursPerDayField(draft)

    // 之前生成过模板的，修改时默认还生成着：模式时长从那份模板里带出来
    let existing = MVTemplateStore.load().first { $0.id == draft.templateID }
    let makeTemplate = NSButton(checkboxWithTitle: "生成子时钟模板", target: nil, action: nil)
    makeTemplate.state = draft.templateID != nil ? .on : .off

    let mode = NSSegmentedControl(
      labels: ["倒计时", "秒表"], trackingMode: .selectOne, target: nil, action: nil
    )
    mode.selectedSegment = existing?.mode == .stopwatch ? 1 : 0

    let duration = Self.templateDurationField(existing)
    let handler = TemplateOptionsHandler(toggle: makeTemplate, segment: mode, durationField: duration)
    makeTemplate.target = handler
    makeTemplate.action = #selector(TemplateOptionsHandler.toggle(_:))
    mode.target = handler
    mode.action = #selector(TemplateOptionsHandler.pickMode(_:))
    handler.refresh()
    Self.templateOptionsHandler = handler

    return Fields(
      name: name, date: date, time: time, timeToggle: timeToggle,
      hours: hours, makeTemplate: makeTemplate, mode: mode, duration: duration
    )
  }

  private static func formStack(fields: Fields) -> NSStackView {
    let stack = NSStackView(views: [
      Self.row("名字", fields.name),
      Self.row("日期", fields.date),
      Self.row("时刻", Self.timeRow(fields.timeToggle, fields.time)),
      Self.row("每日时长", Self.hoursRow(fields.hours, fields.makeTemplate)),
      Self.row("模板", Self.templateRow(fields.mode, fields.duration))
    ])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    stack.frame = NSRect(x: 0, y: 0, width: 330, height: 145)
    return stack
  }

  /// 读弹窗里的值，拼出事件，以及要不要一份子时钟模板
  private static func makeResult(
    draft: TimerEvent,
    fields: Fields,
    calendar: Calendar
  ) -> Result {
    let text = fields.name.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let finalTitle = text.isEmpty ? (draft.title.isEmpty ? "事件" : draft.title) : text

    // 每日时长：留空 / 乱填都当作「用全局的」
    let hoursText = fields.hours.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    var hoursPerDay: Double?
    if let value = Double(hoursText), value >= 1, value <= 24 {
      hoursPerDay = value
    }

    var event = TimerEvent(
      title: finalTitle,
      date: Self.combined(date: fields.date.dateValue, time: fields.time.dateValue, calendar: calendar),
      id: draft.id,
      hasTime: fields.timeToggle.state == .on,
      hoursPerDay: hoursPerDay,
      templateID: nil,
      calendar: calendar
    )

    // 勾了「生成子时钟模板」：模板名就是事件名，从模板建出来的子时钟表盘显示这个事件的倒计时
    guard fields.makeTemplate.state == .on else { return Result(event: event, template: nil) }

    let templateID = draft.templateID ?? UUID()
    let templateMode: TimerMode = fields.mode.selectedSegment == 1 ? .stopwatch : .countdown
    let minutes = Swift.max(1, fields.duration.doubleValue)
    let template = ChildClockTemplate(
      id: templateID,
      name: finalTitle,
      mode: templateMode,
      duration: templateMode == .countdown ? minutes * 60 : 0,
      autoStart: true,
      eventID: event.id
    )
    event.templateID = templateID

    return Result(event: event, template: template)
  }

  // MARK: - 控件

  private static func nameField(_ draft: TimerEvent) -> NSTextField {
    let field = NSTextField(frame: .zero)
    field.stringValue = draft.title
    field.placeholderString = "例如：考研"
    field.translatesAutoresizingMaskIntoConstraints = false
    field.widthAnchor.constraint(equalToConstant: 200).isActive = true
    return field
  }

  private static func hoursPerDayField(_ draft: TimerEvent) -> NSTextField {
    let field = NSTextField(frame: .zero)
    field.placeholderString = "全局"
    field.formatter = Self.numberFormatter()
    field.translatesAutoresizingMaskIntoConstraints = false
    field.widthAnchor.constraint(equalToConstant: 56).isActive = true
    if let hoursPerDay = draft.hoursPerDay {
      field.doubleValue = hoursPerDay
    }
    return field
  }

  private static func templateDurationField(_ template: ChildClockTemplate?) -> NSTextField {
    let field = NSTextField(frame: .zero)
    field.placeholderString = "25"
    field.formatter = Self.numberFormatter()
    field.translatesAutoresizingMaskIntoConstraints = false
    field.widthAnchor.constraint(equalToConstant: 56).isActive = true
    // 模板记的是秒，这里按分钟显示
    if let template, template.mode == .countdown, template.duration > 0 {
      field.doubleValue = template.duration / 60
    }
    return field
  }

  private static func numberFormatter() -> NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimum = 1
    formatter.maximum = 600
    formatter.allowsFloats = false
    return formatter
  }

  private static func datePicker(_ draft: TimerEvent, calendar: Calendar) -> NSDatePicker {
    let picker = NSDatePicker(frame: .zero)
    picker.datePickerStyle = .textFieldAndStepper
    picker.datePickerElements = .yearMonthDay
    picker.dateValue = draft.date
    picker.calendar = calendar
    picker.locale = Locale.current
    picker.translatesAutoresizingMaskIntoConstraints = false
    picker.widthAnchor.constraint(equalToConstant: 130).isActive = true
    return picker
  }

  private static func timePicker(_ draft: TimerEvent, calendar: Calendar) -> NSDatePicker {
    let picker = NSDatePicker(frame: .zero)
    picker.datePickerStyle = .textFieldAndStepper
    picker.datePickerElements = .hourMinute
    // 没指定时刻的给个默认值：考研这类都是上午开考
    picker.dateValue = draft.hasTime ? draft.date : Self.defaultTime(calendar: calendar)
    picker.calendar = calendar
    picker.locale = Locale.current
    picker.translatesAutoresizingMaskIntoConstraints = false
    picker.widthAnchor.constraint(equalToConstant: 100).isActive = true
    picker.isEnabled = draft.hasTime
    return picker
  }

  private static func timeToggle(
    _ draft: TimerEvent,
    onChange: @escaping (Bool) -> Void
  ) -> NSButton {
    let toggle = NSButton(checkboxWithTitle: "指定时刻", target: nil, action: nil)
    toggle.state = draft.hasTime ? .on : .off

    let handler = TimeToggleHandler(onChange: onChange)
    Self.timeToggleHandler = handler
    toggle.target = handler
    toggle.action = #selector(TimeToggleHandler.toggle(_:))
    return toggle
  }

  /// 日期取年月日，时刻取时分，拼成一个完整时刻
  private static func combined(date: Date, time: Date, calendar: Calendar) -> Date {
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
    components.hour = timeComponents.hour
    components.minute = timeComponents.minute
    components.second = 0
    return calendar.date(from: components) ?? date
  }

  private static func defaultTime(calendar: Calendar) -> Date {
    calendar.date(bySettingHour: 8, minute: 30, second: 0, of: Date()) ?? Date()
  }

  private static func row(_ title: String, _ control: NSView) -> NSView {
    let label = NSTextField(labelWithString: title)
    label.alignment = .right
    label.translatesAutoresizingMaskIntoConstraints = false
    label.widthAnchor.constraint(equalToConstant: 56).isActive = true

    let stack = NSStackView(views: [label, control])
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 8
    return stack
  }

  private static func timeRow(_ toggle: NSView, _ picker: NSView) -> NSView {
    let stack = NSStackView(views: [toggle, picker])
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 10
    return stack
  }

  /// 「[__] 小时（留空用全局）  ☑生成子时钟模板」
  private static func hoursRow(_ field: NSView, _ toggle: NSView) -> NSView {
    let unit = NSTextField(labelWithString: "小时")
    let stack = NSStackView(views: [field, unit, toggle])
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 8
    return stack
  }

  /// 「(倒计时|秒表)  时长 [__] 分钟」
  private static func templateRow(_ segment: NSView, _ field: NSView) -> NSView {
    let lead = NSTextField(labelWithString: "模式")
    let duration = NSTextField(labelWithString: "时长")
    let unit = NSTextField(labelWithString: "分钟")
    let stack = NSStackView(views: [lead, segment, duration, field, unit])
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 8
    return stack
  }
}

/// 复选框的 target：把「勾没勾」传出去，顺手开关时刻输入框
@MainActor
private final class TimeToggleHandler: NSObject {
  private let onChange: (Bool) -> Void

  init(onChange: @escaping (Bool) -> Void) {
    self.onChange = onChange
    super.init()
  }

  @objc func toggle(_ sender: NSButton) {
    self.onChange(sender.state == .on)
  }
}

/// 模板那行的联动：勾了「生成子时钟模板」才能选模式；模式是秒表时不用填时长
@MainActor
private final class TemplateOptionsHandler: NSObject {
  private let toggle: NSButton
  private let segment: NSSegmentedControl
  private let durationField: NSTextField

  init(
    toggle: NSButton,
    segment: NSSegmentedControl,
    durationField: NSTextField
  ) {
    self.toggle = toggle
    self.segment = segment
    self.durationField = durationField
    super.init()
  }

  @objc func toggle(_ sender: NSButton) {
    _ = sender
    self.refresh()
  }

  @objc func pickMode(_ sender: NSSegmentedControl) {
    _ = sender
    self.refresh()
  }

  func refresh() {
    let enabled = self.toggle.state == .on
    self.segment.isEnabled = enabled
    self.durationField.isEnabled = enabled && self.segment.selectedSegment == 0
  }
}
