import AppKit

// MARK: - 子时钟模板

extension MVTimerController {
  /// 右键「子时钟 ▸ 保存为模板…」：弹窗确认名字与是否立即开始，然后存起来
  @objc func saveAsTemplate(_: Any?) {
    let draft = self.templateDraft()
    guard let confirmed = Self.promptForTemplate(draft) else { return }
    MVTemplateStore.upsert(confirmed)
  }

  /// 右键「子时钟 ▸ 从模板选择 ▸ 数学」：照模板建一个子时钟
  @objc func addChildClockFromTemplate(_ sender: NSMenuItem) {
    guard let template = sender.representedObject as? ChildClockTemplate else { return }
    self.makeChildClock()?.applyTemplate(template)
  }

  /// 把模板套到这个（刚建好的）子时钟上：名字、模式、时长、是否起跑
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
  }

  /// 按当前状态生成一份待确认的模板：倒计时记时长，秒表记「建好就跑」
  private func templateDraft() -> ChildClockTemplate {
    let clockView = self.clockView
    let duration = clockView.countdownDuration > 0 ? clockView.countdownDuration : clockView.seconds

    return ChildClockTemplate(
      id: UUID(),
      name: clockView.clockTitle.isEmpty ? "子时钟" : clockView.clockTitle,
      mode: clockView.mode,
      duration: clockView.mode == .stopwatch ? 0 : duration,
      autoStart: clockView.mode == .stopwatch || clockView.timerTask != nil
    )
  }

  /// 弹窗展示模板内容，只让改名字（和是否立即开始）
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

    let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 92))
    accessory.addSubview(nameLabel)
    accessory.addSubview(nameField)
    accessory.addSubview(summaryLabel)
    accessory.addSubview(startButton)

    alert.accessoryView = accessory
    alert.addButton(withTitle: "保存")
    alert.addButton(withTitle: "取消")
    alert.window.initialFirstResponder = nameField

    guard alert.runModal() == .alertFirstButtonReturn else { return nil }

    var result = draft
    let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    result.name = name.isEmpty ? draft.name : name
    result.autoStart = startButton.state == .on
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
}
