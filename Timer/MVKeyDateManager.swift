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

  private init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "关键日子"
    // 关掉后还能再开
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 380, height: 220)
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
    self.buildFooter(in: content)
  }

  /// 名字 / 日期 / 还有，三列
  private func buildTable() -> NSScrollView {
    let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
    nameColumn.title = "名字"
    nameColumn.width = 160
    nameColumn.minWidth = 100
    nameColumn.resizingMask = .userResizingMask

    let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
    dateColumn.title = "日期"
    dateColumn.width = 140
    dateColumn.minWidth = 110
    dateColumn.resizingMask = .userResizingMask

    let daysColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("days"))
    daysColumn.title = "还有"
    daysColumn.width = 80
    daysColumn.minWidth = 60
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

    let scrollView = NSScrollView(frame: NSRect(x: 12, y: 46, width: 436, height: 262))
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

  @objc private func addKeyDate() {
    let draft = KeyDate(title: "", date: Date())
    guard let result = MVKeyDateEditor.edit(
      draft,
      title: "添加关键日子",
      message: "加好之后表盘下方就会显示还有多少天"
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
      message: "表盘上最多显示最近的三条，按「还有几天」从小到大排"
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
    let days = MVKeyDateCountdown.days(to: keyDate.date)

    switch column?.identifier.rawValue {
    case "title":
      return keyDate.title

    case "date":
      return Self.dateFormatter.string(from: keyDate.date)

    default:
      return MVKeyDateCountdown.daysText(days)
    }
  }

  func tableViewSelectionDidChange(_: Notification) {
    let hasSelection = self.selectedIndex() != nil
    self.editButton.isEnabled = hasSelection
    self.deleteButton.isEnabled = hasSelection
  }
}

extension MVKeyDateManager {
  /// 表里的日期：年份不同就带上年份，同年只写月日
  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy年M月d日"
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter
  }()
}
