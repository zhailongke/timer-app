import AppKit

/// 关键日子编辑弹窗：名字 + 日期 +（可选）具体时刻。新增和「修改…」都走这里，返回 nil 表示取消
@MainActor
enum MVKeyDateEditor {
  /// 弹窗期间持有复选框的 target
  private static var toggleHandler: TimeToggleHandler?

  static func edit(
    _ draft: KeyDate,
    title: String,
    message: String
  ) -> KeyDate? {
    let calendar = Calendar.current
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message

    let nameField = Self.nameField(draft)
    let datePicker = Self.datePicker(draft, calendar: calendar)
    let timePicker = Self.timePicker(draft, calendar: calendar)
    let toggle = Self.timeToggle(draft) { isOn in
      timePicker.isEnabled = isOn
    }

    let stack = NSStackView(views: [
      Self.row("名字", nameField),
      Self.row("日期", datePicker),
      Self.row("时刻", Self.timeRow(toggle, timePicker))
    ])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    stack.frame = NSRect(x: 0, y: 0, width: 300, height: 90)

    alert.accessoryView = stack
    alert.addButton(withTitle: "好")
    alert.addButton(withTitle: "取消")
    alert.window.initialFirstResponder = nameField

    let confirmed = alert.runModal() == .alertFirstButtonReturn
    Self.toggleHandler = nil
    guard confirmed else { return nil }

    let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return KeyDate(
      title: name.isEmpty ? (draft.title.isEmpty ? "关键日子" : draft.title) : name,
      date: Self.combined(date: datePicker.dateValue, time: timePicker.dateValue, calendar: calendar),
      id: draft.id,
      hasTime: toggle.state == .on,
      calendar: calendar
    )
  }

  private static func nameField(_ draft: KeyDate) -> NSTextField {
    let field = NSTextField(frame: .zero)
    field.stringValue = draft.title
    field.placeholderString = "例如：考研"
    field.translatesAutoresizingMaskIntoConstraints = false
    field.widthAnchor.constraint(equalToConstant: 200).isActive = true
    return field
  }

  private static func datePicker(_ draft: KeyDate, calendar: Calendar) -> NSDatePicker {
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

  private static func timePicker(_ draft: KeyDate, calendar: Calendar) -> NSDatePicker {
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
    _ draft: KeyDate,
    onChange: @escaping (Bool) -> Void
  ) -> NSButton {
    let toggle = NSButton(checkboxWithTitle: "指定时刻", target: nil, action: nil)
    toggle.state = draft.hasTime ? .on : .off

    // 复选框的 target 是弱引用，用静态变量把它留到弹窗关掉
    let handler = TimeToggleHandler(onChange: onChange)
    Self.toggleHandler = handler
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
    label.widthAnchor.constraint(equalToConstant: 48).isActive = true

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
