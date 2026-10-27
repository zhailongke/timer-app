import AppKit

/// 事件进度窗口：加 / 改 / 删事件。
/// 右键「事件进度…」打开；改完表盘上的倒计时立刻跟着变
@MainActor
final class MVEventManager: NSWindowController {
  static let shared = MVEventManager()

  private var events: [TimerEvent] = []

  private let tableView = NSTableView(frame: .zero)
  private let addButton = NSButton(title: "添加…", target: nil, action: nil)
  private let editButton = NSButton(title: "修改…", target: nil, action: nil)
  private let deleteButton = NSButton(title: "删除", target: nil, action: nil)
  private let hintLabel = NSTextField(labelWithString: "")
  /// 总小时数按一天多少小时折算：默认 24，改成别的表盘上的总小时数立刻跟着变
  private let hoursPerDayField = NSTextField(frame: .zero)
  /// 轮播：表盘每隔几秒自动切到下一个事件
  private let rotateCheckbox = NSButton(checkboxWithTitle: "轮播显示", target: nil, action: nil)

  private init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 580, height: 348),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "事件进度"
    // 关掉后还能再开
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 380, height: 260)
    super.init(window: window)
    // 直接点关闭按钮时输入框的 action 不一定发得出来，关之前再存一次
    window.delegate = self

    self.buildContent()
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    self.reload()
    self.window?.center()
    self.showWindow(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  private func buildContent() {
    guard let content = self.window?.contentView else { return }

    let scrollView = self.buildTable()
    content.addSubview(scrollView)
    self.buildHoursPerDayRow(in: content)
    self.buildFooter(in: content)
  }

  /// 表盘（单选）/ 名字 / 每日时长 / 日期（勾了时刻的带时分）/ 还有，五列
  private func buildTable() -> NSScrollView {
    let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
    nameColumn.title = "名字"
    nameColumn.width = 140
    nameColumn.minWidth = 100
    nameColumn.resizingMask = .userResizingMask

    let hoursColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("hours"))
    hoursColumn.title = "每日时长"
    hoursColumn.width = 72
    hoursColumn.resizingMask = .userResizingMask

    let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
    dateColumn.title = "日期"
    dateColumn.width = 168
    dateColumn.minWidth = 130
    dateColumn.resizingMask = .userResizingMask

    let daysColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("days"))
    daysColumn.title = "还有"
    daysColumn.width = 88
    daysColumn.minWidth = 76
    daysColumn.resizingMask = .userResizingMask

    let displayColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("display"))
    displayColumn.title = "表盘"
    displayColumn.width = 44
    displayColumn.resizingMask = .userResizingMask
    // 单选风格的勾选框：点哪行，表盘就显示哪个事件
    let radioCell = NSButtonCell()
    radioCell.setButtonType(.radio)
    radioCell.title = ""
    displayColumn.dataCell = radioCell

    for column in [displayColumn, nameColumn, hoursColumn, dateColumn, daysColumn] {
      self.tableView.addTableColumn(column)
    }
    self.tableView.dataSource = self
    self.tableView.delegate = self
    self.tableView.rowHeight = 22
    self.tableView.usesAlternatingRowBackgroundColors = true
    self.tableView.doubleAction = #selector(self.editSelected)
    self.tableView.target = self

    let scrollView = NSScrollView(frame: NSRect(x: 12, y: 74, width: 556, height: 262))
    scrollView.borderType = .bezelBorder
    scrollView.hasVerticalScroller = true
    scrollView.autoresizingMask = [.width, .height]
    scrollView.documentView = self.tableView
    return scrollView
  }

  /// 底部一行：提示文字 + 添加 / 修改 / 删除
  private func buildFooter(in content: NSView) {
    self.hintLabel.frame = NSRect(x: 14, y: 14, width: 240, height: 16)
    self.hintLabel.textColor = .secondaryLabelColor
    self.hintLabel.autoresizingMask = [.maxXMargin, .maxYMargin]
    content.addSubview(self.hintLabel)

    self.addButton.target = self
    self.addButton.action = #selector(self.addTimerEvent)
    self.addButton.bezelStyle = .rounded
    self.addButton.frame = NSRect(x: 246, y: 8, width: 64, height: 28)
    self.addButton.autoresizingMask = [.minXMargin, .maxYMargin]
    content.addSubview(self.addButton)

    self.editButton.target = self
    self.editButton.action = #selector(self.editSelected)
    self.editButton.bezelStyle = .rounded
    self.editButton.frame = NSRect(x: 316, y: 8, width: 64, height: 28)
    self.editButton.autoresizingMask = [.minXMargin, .maxYMargin]
    content.addSubview(self.editButton)

    self.deleteButton.target = self
    self.deleteButton.action = #selector(self.deleteSelected)
    self.deleteButton.bezelStyle = .rounded
    self.deleteButton.frame = NSRect(x: 386, y: 8, width: 62, height: 28)
    self.deleteButton.autoresizingMask = [.minXMargin, .maxYMargin]
    content.addSubview(self.deleteButton)
  }

  /// 「总小时数按一天 [__] 小时算」：留空就按 24 小时
  private func buildHoursPerDayRow(in content: NSView) {
    let leadLabel = NSTextField(labelWithString: "总小时数按一天")
    leadLabel.font = NSFont.systemFont(ofSize: 11)
    leadLabel.textColor = .secondaryLabelColor
    leadLabel.frame = NSRect(x: 14, y: 46, width: 82, height: 16)
    leadLabel.autoresizingMask = [.maxXMargin, .minYMargin]
    content.addSubview(leadLabel)

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimum = 1
    formatter.maximum = 24
    formatter.allowsFloats = true

    self.hoursPerDayField.formatter = formatter
    self.hoursPerDayField.isBezeled = true
    self.hoursPerDayField.bezelStyle = .roundedBezel
    self.hoursPerDayField.drawsBackground = true
    self.hoursPerDayField.alignment = .center
    self.hoursPerDayField.placeholderString = "24"
    self.hoursPerDayField.target = self
    self.hoursPerDayField.action = #selector(self.hoursPerDayChanged)
    self.hoursPerDayField.delegate = self
    self.hoursPerDayField.frame = NSRect(x: 100, y: 44, width: 48, height: 20)
    self.hoursPerDayField.autoresizingMask = [.maxXMargin, .minYMargin]
    content.addSubview(self.hoursPerDayField)

    let trailLabel = NSTextField(labelWithString: "小时算（1–24，留空按 24）")
    trailLabel.font = NSFont.systemFont(ofSize: 11)
    trailLabel.textColor = .secondaryLabelColor
    trailLabel.frame = NSRect(x: 154, y: 46, width: 170, height: 16)
    trailLabel.autoresizingMask = [.maxXMargin, .minYMargin]
    content.addSubview(trailLabel)

    // 轮播：开了之后表盘不再只盯选中那条，每隔几秒换一个事件
    self.rotateCheckbox.target = self
    self.rotateCheckbox.action = #selector(self.toggleRotate)
    self.rotateCheckbox.font = NSFont.systemFont(ofSize: 11)
    self.rotateCheckbox.frame = NSRect(x: 330, y: 44, width: 220, height: 20)
    self.rotateCheckbox.autoresizingMask = [.minXMargin, .minYMargin]
    content.addSubview(self.rotateCheckbox)
  }

  @objc private func toggleRotate() {
    MVEventSettings.save(isRotating: self.rotateCheckbox.state == .on)
  }

  @objc private func hoursPerDayChanged() {
    self.applyHoursPerDay()
  }

  /// 存进 UserDefaults 并广播一声：所有时钟窗口收到后自己重画蓝条和总小时数。
  /// 这是全局设置，不用再去点「添加…」让它生效
  private func applyHoursPerDay() {
    let text = self.hoursPerDayField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    MVEventSettings.save(hoursPerDay: Double(text))
  }

  @objc private func addTimerEvent() {
    let draft = TimerEvent(title: "", date: Date())
    guard let result = MVEventEditor.edit(
      draft,
      title: "添加事件",
      message: "勾上「生成子时钟模板」，就能从「子时钟 ▸ 从模板选择」一键建出这个事件的子时钟"
    ) else { return }

    if let template = result.template {
      MVTemplateStore.upsert(template)
    }
    MVEventStore.add(result.event)
    self.reload(selecting: self.events.count)
  }

  @objc private func editSelected() {
    guard let index = self.selectedIndex() else { return }
    let draft = self.events[index]

    guard let result = MVEventEditor.edit(
      draft,
      title: "修改事件",
      message: "表盘下方显示选中的那条；总小时数按这一条自己的每日时长折算"
    ) else { return }

    if let template = result.template {
      MVTemplateStore.update(template)
    } else if let oldTemplateID = draft.templateID {
      // 取消了「生成子时钟模板」：那份模板也一并删掉，免得留个关联不上的
      MVTemplateStore.remove(id: oldTemplateID)
    }
    MVEventStore.update(result.event)
    self.reload(selecting: index)
  }

  @objc private func deleteSelected() {
    guard let index = self.selectedIndex() else { return }
    let event = self.events[index]

    let alert = NSAlert()
    alert.messageText = "删除「\(event.title)」？"
    alert.informativeText = "删除后无法恢复。"
    alert.addButton(withTitle: "删除")
    alert.addButton(withTitle: "取消")

    guard alert.runModal() == .alertFirstButtonReturn else { return }

    MVEventStore.remove(id: event.id)
    self.reload(selecting: min(index, self.events.count - 1))
  }

  private func selectedIndex() -> Int? {
    let row = self.tableView.selectedRow
    return self.events.indices.contains(row) ? row : nil
  }

  private func reload(selecting row: Int? = nil) {
    self.hoursPerDayField.doubleValue = MVEventSettings.hoursPerDay()
    self.rotateCheckbox.state = MVEventSettings.isRotating() ? .on : .off

    // 表里按日期先后排，跟表盘上「先显示最近那条」是同一套顺序
    self.events = MVEventStore.load().sorted { $0.date < $1.date }
    self.tableView.reloadData()

    if let row, self.events.indices.contains(row) {
      self.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    let hasSelection = self.selectedIndex() != nil
    self.editButton.isEnabled = hasSelection
    self.deleteButton.isEnabled = hasSelection
    self.hintLabel.stringValue = self.events.isEmpty
      ? "还没有事件：点「添加…」加一个"
      : "双击一行可以修改"
  }
}

extension MVEventManager: NSWindowDelegate, NSTextFieldDelegate {
  /// 每敲一下就存：输入框的 action 要等回车或失焦才发，填完直接看表盘时还没存上，
  /// 表现就是「改了但进度条没反应」
  func controlTextDidChange(_: Notification) {
    self.applyHoursPerDay()
  }

  func windowWillClose(_: Notification) {
    self.applyHoursPerDay()
  }
}

extension MVEventManager: NSTableViewDataSource, NSTableViewDelegate {
  func numberOfRows(in _: NSTableView) -> Int {
    self.events.count
  }

  func tableView(_: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
    guard self.events.indices.contains(row) else { return nil }
    let event = self.events[row]

    switch column?.identifier.rawValue {
    case "display":
      // 选中了哪行，哪行的圆点就亮；没选过（nil）时全不亮，表盘自动显示最近的那条
      return MVEventSettings.selectedEventID() == event.id ? 1 : 0

    case "title":
      return event.title

    case "hours":
      return event.hoursPerDay.map { "\(Int($0)) 小时" } ?? "全局"

    case "date":
      let formatter = event.hasTime ? Self.dateTimeFormatter : Self.dateFormatter
      return formatter.string(from: event.date)

    default:
      let item = MVEventCountdownItem(
        event: event,
        remaining: event.remaining()
      )
      return MVEventCountdown.text(item)
    }
  }

  /// 点了「表盘」那一列的圆点：把显示的事件换成这一行
  func tableView(
    _ tableView: NSTableView,
    setObjectValue object: Any?,
    for column: NSTableColumn?,
    row: Int
  ) {
    guard column?.identifier.rawValue == "display",
          self.events.indices.contains(row),
          let state = object as? Int, state == 1
    else { return }

    MVEventSettings.save(selectedEventID: self.events[row].id)
    // 单选：别行的圆点要灭掉
    tableView.reloadData()
  }

  func tableViewSelectionDidChange(_: Notification) {
    let hasSelection = self.selectedIndex() != nil
    self.editButton.isEnabled = hasSelection
    self.deleteButton.isEnabled = hasSelection
  }
}

extension MVEventManager {
  /// 表里的日期：只算到天的写成「2026年12月19日」
  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy年M月d日"
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter
  }()

  /// 指定了时刻的再带上时分：「2026年12月19日 08:30」
  static let dateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy年M月d日 HH:mm"
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter
  }()
}
