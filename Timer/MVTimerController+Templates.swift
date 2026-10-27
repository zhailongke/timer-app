import AppKit

// MARK: - 子时钟模板

extension MVTimerController {
  /// 右键「子时钟 ▸ 保存为模板…」：弹窗确认名字 / 模式 / 时长，然后存起来
  @objc func saveAsTemplate(_: Any?) {
    let draft = self.templateDraft()
    guard let confirmed = MVTemplateEditor.edit(
      draft,
      title: "保存为模板",
      message: "保存后可从「子时钟 ▸ 从模板选择」一键新建同样的子时钟"
    ) else { return }
    MVTemplateStore.upsert(confirmed)
  }

  /// 右键「子时钟 ▸ 从模板选择 ▸ 数学」：照模板建一个子时钟（含模板里记下的下级）
  @objc func addChildClockFromTemplate(_ sender: NSMenuItem) {
    guard let template = sender.representedObject as? ChildClockTemplate else { return }
    self.makeChildClock()?.applyTemplate(template)
  }

  /// 把模板套到这个（刚建好的）子时钟上：名字、模式、时长、是否起跑，再把下级一个个建出来。
  /// 模板带了事件的，表盘下方显示那个事件的倒计时
  func applyTemplate(_ template: ChildClockTemplate) {
    self.clockView.clockTitle = template.name
    self.clockView.eventID = template.eventID
    self.clockView.updateCountdownLabels(force: true)
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
}
