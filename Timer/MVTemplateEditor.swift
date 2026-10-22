import AppKit

/// 模板内容编辑弹窗：名字、模式、时长、建好是否立刻跑；有下级时再弹一页逐个改下级名字
@MainActor
enum MVTemplateEditor {
  /// 返回 nil 表示取消。保存为模板、管理窗口里改模板都走这里
  static func edit(
    _ draft: ChildClockTemplate,
    title: String = "修改模板",
    message: String = "改好后从「子时钟 ▸ 从模板选择」新建的就是这个样子"
  ) -> ChildClockTemplate? {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message

    let nameField = Self.textField(width: 220)
    nameField.stringValue = draft.name
    nameField.placeholderString = "模板名字"

    let modePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    modePopup.addItems(withTitles: ["倒计时", "秒表"])
    modePopup.selectItem(at: draft.mode == .countdown ? 0 : 1)
    modePopup.translatesAutoresizingMaskIntoConstraints = false
    modePopup.widthAnchor.constraint(equalToConstant: 120).isActive = true

    let durationField = Self.textField(width: 120)
    durationField.stringValue = TimerLogic.durationDisplayString(seconds: draft.duration)
    durationField.placeholderString = "分:秒"

    let startButton = NSButton(checkboxWithTitle: "新建后立即开始", target: nil, action: nil)
    startButton.state = draft.autoStart ? .on : .off

    let childrenLabel = NSTextField(labelWithString: Self.descendantsTitle(for: draft))
    childrenLabel.textColor = .secondaryLabelColor

    let stack = NSStackView(views: [
      Self.row("名字", nameField),
      Self.row("模式", modePopup),
      Self.row("时长", durationField),
      startButton,
      childrenLabel
    ])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    stack.frame = NSRect(x: 0, y: 0, width: 340, height: 168)

    alert.accessoryView = stack
    alert.addButton(withTitle: "好")
    alert.addButton(withTitle: "取消")
    alert.window.initialFirstResponder = nameField

    guard alert.runModal() == .alertFirstButtonReturn else { return nil }

    var result = draft
    let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    result.name = name.isEmpty ? draft.name : name
    result.mode = modePopup.indexOfSelectedItem == 0 ? .countdown : .stopwatch
    result.autoStart = startButton.state == .on

    if result.mode == .stopwatch {
      result.duration = 0
    } else if let seconds = TimerLogic.parseDuration(durationField.stringValue) {
      result.duration = seconds
    }

    guard !result.children.isEmpty else { return result }
    return Self.promptForDescendants(result)
  }

  /// 第二页：把模板里所有下级列出来，逐个改名字和是否立即开始
  private static func promptForDescendants(_ draft: ChildClockTemplate) -> ChildClockTemplate? {
    let rows = draft.flattenedDescendants
    guard !rows.isEmpty else { return draft }

    let alert = NSAlert()
    alert.messageText = "下级子时钟"
    alert.informativeText = "用这个模板新建时，会一并建出下面这些子时钟"

    let rowHeight: CGFloat = 28
    let height = rowHeight * CGFloat(rows.count)
    let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: height))

    var nameFields: [NSTextField] = []
    var startButtons: [NSButton] = []

    for (index, row) in rows.enumerated() {
      let rowY = height - rowHeight * CGFloat(index + 1)

      let nameField = NSTextField(frame: NSRect(x: 0, y: rowY + 4, width: 150, height: 22))
      nameField.stringValue = row.name

      let summaryLabel = NSTextField(labelWithString: row.summary)
      summaryLabel.frame = NSRect(x: 158, y: rowY + 6, width: 150, height: 16)

      let startButton = NSButton(checkboxWithTitle: "立即开始", target: nil, action: nil)
      startButton.frame = NSRect(x: 316, y: rowY + 4, width: 104, height: 18)
      startButton.state = row.autoStart ? .on : .off

      accessory.addSubview(nameField)
      accessory.addSubview(summaryLabel)
      accessory.addSubview(startButton)
      nameFields.append(nameField)
      startButtons.append(startButton)
    }

    alert.accessoryView = accessory
    alert.addButton(withTitle: "好")
    alert.addButton(withTitle: "取消")
    alert.window.initialFirstResponder = nameFields[0]

    guard alert.runModal() == .alertFirstButtonReturn else { return nil }

    var result = draft
    result.applyEdits(
      zip(nameFields, startButtons).map { field, button in
        (
          name: field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
          autoStart: button.state == .on
        )
      }
    )
    return result
  }

  private static func textField(width: CGFloat) -> NSTextField {
    let field = NSTextField(frame: .zero)
    field.translatesAutoresizingMaskIntoConstraints = false
    field.widthAnchor.constraint(equalToConstant: width).isActive = true
    return field
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

  private static func descendantsTitle(for template: ChildClockTemplate) -> String {
    let count = template.flattenedDescendants.count
    return count > 0 ? "含 \(count) 个下级子时钟" : "没有下级子时钟"
  }
}
