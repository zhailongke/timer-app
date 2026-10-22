import AppKit

// MARK: - 子时钟模板

extension MVTimerController {
  /// 右键「子时钟 ▸ 保存为模板…」：弹窗确认名字与是否立即开始，然后存起来
  @objc func saveAsTemplate(_: Any?) {
    let draft = self.templateDraft()
    guard let confirmed = Self.promptForTemplate(draft) else { return }
    MVTemplateStore.upsert(confirmed)
  }

  /// 右键「子时钟 ▸ 从模板选择 ▸ 数学」：照模板建一个子时钟（含模板里记下的下级）
  @objc func addChildClockFromTemplate(_ sender: NSMenuItem) {
    guard let template = sender.representedObject as? ChildClockTemplate else { return }
    self.makeChildClock()?.applyTemplate(template)
  }

  /// 把模板套到这个（刚建好的）子时钟上：名字、模式、时长、是否起跑，再把下级一个个建出来
  func applyTemplate(_ template: ChildClockTemplate) {
    self.clockView.clockTitle = template.name
    self.setMode(template.mode)

    if template.mode == .countdown {
      self.clockView.setCountdownSeconds(template.duration)
      self.clockView.updateTimerTime()
    }

    if template.autoStart {
      self.clockView.start()
    }

    // 先设好自己的时长，下级才按这个上限截断
    for childTemplate in template.children {
      self.makeChildClock()?.applyTemplate(childTemplate)
    }
  }

  /// 按当前状态生成一份待确认的模板：倒计时记时长，秒表记「建好就跑」，下级照抄一份
  private func templateDraft() -> ChildClockTemplate {
    let clockView = self.clockView
    let duration = clockView.countdownDuration > 0 ? clockView.countdownDuration : clockView.seconds

    return ChildClockTemplate(
      id: UUID(),
      name: clockView.clockTitle.isEmpty ? "子时钟" : clockView.clockTitle,
      mode: clockView.mode,
      duration: clockView.mode == .stopwatch ? 0 : duration,
      autoStart: clockView.mode == .stopwatch || clockView.timerTask != nil,
      children: self.childControllers.map { $0.templateDraft() }
    )
  }

  /// 弹窗展示模板内容，只让改名字（和是否立即开始、是否记录下级）
  private static func promptForTemplate(_ draft: ChildClockTemplate) -> ChildClockTemplate? {
    let alert = NSAlert()
    alert.messageText = "保存为模板"
    alert.informativeText = "保存后可从「子时钟 ▸ 从模板选择」一键新建同样的子时钟"

    let nameField = NSTextField(frame: NSRect(x: 0, y: 48, width: 260, height: 22))
    nameField.stringValue = draft.name
    nameField.placeholderString = "模板名字"

    let nameLabel = NSTextField(labelWithString: "名字")
    nameLabel.frame = NSRect(x: 0, y: 74, width: 260, height: 16)
    nameLabel.textColor = .secondaryLabelColor

    let summaryLabel = NSTextField(labelWithString: Self.summary(for: draft))
    summaryLabel.frame = NSRect(x: 0, y: 26, width: 260, height: 16)

    let startButton = NSButton(checkboxWithTitle: "新建后立即开始", target: nil, action: nil)
    startButton.frame = NSRect(x: 0, y: 2, width: 260, height: 18)
    startButton.state = draft.autoStart ? .on : .off

    let descendantsButton = NSButton(
      checkboxWithTitle: Self.descendantsTitle(for: draft),
      target: nil,
      action: nil
    )
    descendantsButton.frame = NSRect(x: 0, y: -20, width: 260, height: 18)
    descendantsButton.state = draft.children.isEmpty ? .off : .on
    descendantsButton.isEnabled = !draft.children.isEmpty

    let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 112))
    accessory.addSubview(nameLabel)
    accessory.addSubview(nameField)
    accessory.addSubview(summaryLabel)
    accessory.addSubview(startButton)
    accessory.addSubview(descendantsButton)

    alert.accessoryView = accessory
    alert.addButton(withTitle: "保存")
    alert.addButton(withTitle: "取消")
    alert.window.initialFirstResponder = nameField

    guard alert.runModal() == .alertFirstButtonReturn else { return nil }

    var result = draft
    let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    result.name = name.isEmpty ? draft.name : name
    result.autoStart = startButton.state == .on

    guard descendantsButton.state == .on, !result.children.isEmpty else {
      result.children = []
      return result
    }

    // 勾了「记录下级」就再弹一页，让每个下级的名字也能改
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
    alert.addButton(withTitle: "保存")
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

  private static func summary(for template: ChildClockTemplate) -> String {
    switch template.mode {
    case .countdown:
      return "模式：倒计时 · 时长 \(TimerLogic.durationDisplayString(seconds: template.duration))"

    case .stopwatch:
      return "模式：秒表"
    }
  }

  private static func descendantsTitle(for template: ChildClockTemplate) -> String {
    let count = template.flattenedDescendants.count
    return count > 0 ? "记录下级子时钟（\(count) 个）" : "记录下级子时钟（没有下级）"
  }
}
