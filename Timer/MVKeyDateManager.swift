import AppKit

/// 关键日子窗口：加 / 改 / 删要在表盘上倒计时的日子。
/// 右键「关键日子…」打开；改完表盘上的倒计时立刻跟着变
@MainActor
final class MVKeyDateManager: NSWindowController {
  static let shared = MVKeyDateManager()

  private var keyDates: [KeyDate] = []

  private let tableView = NSTableView(frame: .zero)
  private let addButton = NSButton(title: "添加…", target: nil, action: nil)
  private let editButton = NSButton(title: "修改…", target: nil, action: nil)
  private let deleteButton = NSButton(title: "删除", target: nil, action: nil)
  private let hintLabel = NSTextField(labelWithString: "")
  /// 总小时数按一天多少小时折算：默认 24，改成别的表盘上的总小时数立刻跟着变
  private let hoursPerDayField = NSTextField(frame: .zero)

  private init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 348),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "关键日子"
    // 关掉后还能再开
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 380, height: 260)
    super.init(window: window)

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

  /// 名字 / 日期（勾了时刻的带时分）/ 还有，三列
  private func buildTable() -> NSScrollView {
    let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
    nameColumn.title = "名字"
    nameColumn.width = 160
    nameColumn.minWidth = 100
    nameColumn.resizingMask = .userResizingMask

    let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
    dateColumn.title = "日期"
    dateColumn.width = 168
    dateColumn.minWidth = 130
    dateColumn.resizingMask = .userResizingMask

    let daysColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("days"))
    daysColumn.title = "还有"
    daysColumn.width = 96
    daysColumn.minWidth = 76
    daysColumn.resizingMask = .userResizingMask

    for column in [nameColumn, dateColumn, daysColumn] {
      self.tableView.addTableColumn(column)
    }
    self.tableView.dataSource = self
    self.tableView.delegate = self
    self.tableView.rowHeight = 22
    self.tableView.usesAlternatingRowBackgroundColors = true
    self.tableView.doubleAction = #selector(self.editSelected)
    self.tableView.target = self

    let scrollView = NSScrollView(frame: NSRect(x: 12, y: 74, width: 436, height: 262))
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
    self.addButton.action = #selector(self.addKeyDate)
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
    self.hoursPerDayField.frame = NSRect(x: 100, y: 44, width: 48, height: 20)
    self.hoursPerDayField.autoresizingMask = [.maxXMargin, .minYMargin]
    content.addSubview(self.hoursPerDayField)

    let trailLabel = NSTextField(labelWithString: "小时算（1–24，留空按 24）")
    trailLabel.font = NSFont.systemFont(ofSize: 11)
    trailLabel.textColor = .secondaryLabelColor
    trailLabel.frame = NSRect(x: 154, y: 46, width: 170, height: 16)
    trailLabel.autoresizingMask = [.maxXMargin, .minYMargin]
    content.addSubview(trailLabel)
  }

  @objc private func hoursPerDayChanged() {
    let text = self.hoursPerDayField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    MVKeyDateSettings.save(hoursPerDay: Double(text))
  }

  @objc private func addKeyDate() {
    let draft = KeyDate(title: "", date: Date())
    guard let result = MVKeyDateEditor.edit(
      draft,
      title: "添加关键日子",
      message: "勾上「指定时刻」，倒计时就会精确到还有几小时几分钟"
    ) else { return }

    MVKeyDateStore.add(result)
    self.reload(selecting: self.keyDates.count)
  }

  @objc private func editSelected() {
    guard let index = self.selectedIndex() else { return }
    let draft = self.keyDates[index]

    guard let result = MVKeyDateEditor.edit(
      draft,
      title: "修改关键日子",
      message: "表盘上最多显示最近的三条；勾了「指定时刻」的会精确到小时分钟"
    ) else { return }

    MVKeyDateStore.update(result)
    self.reload(selecting: index)
  }

  @objc private func deleteSelected() {
    guard let index = self.selectedIndex() else { return }
    let keyDate = self.keyDates[index]

    let alert = NSAlert()
    alert.messageText = "删除「\(keyDate.title)」？"
    alert.informativeText = "删除后无法恢复。"
    alert.addButton(withTitle: "删除")
    alert.addButton(withTitle: "取消")

    guard alert.runModal() == .alertFirstButtonReturn else { return }

    MVKeyDateStore.remove(id: keyDate.id)
    self.reload(selecting: min(index, self.keyDates.count - 1))
  }

  private func selectedIndex() -> Int? {
    let row = self.tableView.selectedRow
    return self.keyDates.indices.contains(row) ? row : nil
  }

  private func reload(selecting row: Int? = nil) {
    self.hoursPerDayField.doubleValue = MVKeyDateSettings.hoursPerDay()

    // 表里按日期先后排，跟表盘上「先显示最近那条」是同一套顺序
    self.keyDates = MVKeyDateStore.load().sorted { $0.date < $1.date }
    self.tableView.reloadData()

    if let row, self.keyDates.indices.contains(row) {
      self.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    let hasSelection = self.selectedIndex() != nil
    self.editButton.isEnabled = hasSelection
    self.deleteButton.isEnabled = hasSelection
    self.hintLabel.stringValue = self.keyDates.isEmpty
      ? "还没有关键日子：点「添加…」加一个"
      : "双击一行可以修改"
  }
}

extension MVKeyDateManager: NSTableViewDataSource, NSTableViewDelegate {
  func numberOfRows(in _: NSTableView) -> Int {
    self.keyDates.count
  }

  func tableView(_: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
    guard self.keyDates.indices.contains(row) else { return nil }
    let keyDate = self.keyDates[row]

    switch column?.identifier.rawValue {
    case "title":
      return keyDate.title

    case "date":
      let formatter = keyDate.hasTime ? Self.dateTimeFormatter : Self.dateFormatter
      return formatter.string(from: keyDate.date)

    default:
      let item = MVKeyDateCountdownItem(
        keyDate: keyDate,
        remaining: keyDate.remaining()
      )
      return MVKeyDateCountdown.text(item)
    }
  }

  func tableViewSelectionDidChange(_: Notification) {
    let hasSelection = self.selectedIndex() != nil
    self.editButton.isEnabled = hasSelection
    self.deleteButton.isEnabled = hasSelection
  }
}

extension MVKeyDateManager {
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
