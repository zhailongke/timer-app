import AppKit

/// 关键日子编辑弹窗：名字 + 日期。新增和「修改…」都走这里，返回 nil 表示取消
@MainActor
enum MVKeyDateEditor {
  static func edit(
    _ draft: KeyDate,
    title: String,
    message: String
  ) -> KeyDate? {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message

    let nameField = NSTextField(frame: .zero)
    nameField.stringValue = draft.title
    nameField.placeholderString = "例如：考研"
    nameField.translatesAutoresizingMaskIntoConstraints = false
    nameField.widthAnchor.constraint(equalToConstant: 200).isActive = true

    let datePicker = NSDatePicker(frame: .zero)
    datePicker.datePickerStyle = .textFieldAndStepper
    datePicker.datePickerElements = .yearMonthDay
    datePicker.dateValue = draft.date
    datePicker.calendar = Calendar.current
    datePicker.locale = Locale.current
    datePicker.translatesAutoresizingMaskIntoConstraints = false
    datePicker.widthAnchor.constraint(equalToConstant: 200).isActive = true

    let stack = NSStackView(views: [
      Self.row("名字", nameField),
      Self.row("日期", datePicker)
    ])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    stack.frame = NSRect(x: 0, y: 0, width: 300, height: 60)

    alert.accessoryView = stack
    alert.addButton(withTitle: "好")
    alert.addButton(withTitle: "取消")
    alert.window.initialFirstResponder = nameField

    guard alert.runModal() == .alertFirstButtonReturn else { return nil }

    let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return KeyDate(
      title: name.isEmpty ? (draft.title.isEmpty ? "关键日子" : draft.title) : name,
      date: datePicker.dateValue,
      id: draft.id
    )
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
}
