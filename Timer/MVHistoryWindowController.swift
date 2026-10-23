import AppKit

/// 历史记录窗口：根一层是每次主时钟的记录（正在跑的那条也在，时长会自己长），
/// 点进去是那一次记录下的子时钟记录，再往下一层层点。
/// 选中一行可以改名、删除、看它的下级
@MainActor
final class MVHistoryWindowController: NSWindowController {
  static let shared = MVHistoryWindowController()

  /// 一层层点进来的记录 id；空就是根层（每次主时钟）
  private var path: [UUID] = []

  /// 日期区间筛选：只按最外层那条记录的起始时间筛
  var filter: MVHistoryDateFilter?
  /// 列表排序；默认起始时间倒序，最新的在最上面
  var sort = MVHistorySort()

  let tableView = NSTableView(frame: .zero)
  private let pathLabel = NSTextField(labelWithString: "历史记录")
  /// 当前层级「共 N 条 · 合计 …」；筛选条那边要用，不加 private
  let statsLabel = NSTextField(labelWithString: "")
  let rangeButton = NSButton(title: "全部记录", target: nil, action: nil)
  let presetControl = NSSegmentedControl(
    labels: ["今天", "昨天", "近 7 天", "近 30 天", "全部"],
    trackingMode: .momentary,
    target: nil,
    action: nil
  )
  var calendarPopover: NSPopover?
  private let backButton = NSButton(title: "返回", target: nil, action: nil)
  private let openButton = NSButton(title: "查看下级…", target: nil, action: nil)
  private let renameButton = NSButton(title: "改名…", target: nil, action: nil)
  private let deleteButton = NSButton(title: "删除", target: nil, action: nil)
  private let hintLabel = NSTextField(labelWithString: "")

  private init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "历史记录"
    // 关掉还能再开
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 560, height: 360)
    super.init(window: window)
    window.delegate = self
    self.buildContent()
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    self.path = []
    // 沿用上次关掉时的区间；排序每次从「最新在上」开始
    self.filter = MVHistoryFilterStore.load()
    self.sort = MVHistorySort()
    self.updateRangeControls()
    self.updateSortIndicators()
    self.reload()
    self.window?.center()
    self.showWindow(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)

    // 计时中的记录每秒都在长，开着窗口就跟着刷
    MVHistoryTracker.shared.onChange = { [weak self] in self?.refreshPreservingSelection() }
  }

  private func buildContent() {
    guard let content = self.window?.contentView else { return }

    self.pathLabel.frame = NSRect(x: 14, y: 446, width: 300, height: 18)
    self.pathLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
    self.pathLabel.lineBreakMode = .byTruncatingMiddle
    self.pathLabel.autoresizingMask = [.width, .minYMargin]
    content.addSubview(self.pathLabel)

    self.buildFilterBar(in: content)

    // 列的 identifier 与排序键同名，点列头就能对上
    for (identifier, title, width) in [
      ("name", "名字", 150),
      ("title", "时钟", 90),
      ("startDate", "起始时间", 120),
      ("duration", "时长", 90),
      ("endDate", "结束时间", 140)
    ] {
      let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
      column.title = title
      column.width = CGFloat(width)
      column.minWidth = 70
      column.resizingMask = .userResizingMask
      column.sortDescriptorPrototype = NSSortDescriptor(key: identifier, ascending: true)
      self.tableView.addTableColumn(column)
    }

    self.tableView.dataSource = self
    self.tableView.delegate = self
    self.tableView.rowHeight = 22
    self.tableView.usesAlternatingRowBackgroundColors = true
    self.tableView.doubleAction = #selector(self.openSelected)
    self.tableView.target = self

    let scrollView = NSScrollView(frame: NSRect(x: 12, y: 46, width: 656, height: 360))
    scrollView.borderType = .bezelBorder
    scrollView.hasVerticalScroller = true
    scrollView.autoresizingMask = [.width, .height]
    scrollView.documentView = self.tableView
    content.addSubview(scrollView)

    self.hintLabel.frame = NSRect(x: 14, y: 14, width: 320, height: 16)
    self.hintLabel.textColor = .secondaryLabelColor
    self.hintLabel.autoresizingMask = [.maxXMargin, .maxYMargin]
    content.addSubview(self.hintLabel)

    self.buildActionButtons(in: content)
    self.updateSortIndicators()
  }

  /// 底部一排按钮，从右往左：删除 / 改名 / 查看下级 / 返回
  private func buildActionButtons(in content: NSView) {
    var buttonX: CGFloat = 568
    for button in [self.deleteButton, self.renameButton, self.openButton, self.backButton] {
      button.bezelStyle = .rounded
      button.frame = NSRect(x: buttonX, y: 8, width: 100, height: 28)
      button.autoresizingMask = [.minXMargin, .maxYMargin]
      button.target = self
      content.addSubview(button)
      buttonX -= 108
    }
    self.deleteButton.action = #selector(self.deleteSelected)
    self.renameButton.action = #selector(self.renameSelected)
    self.openButton.action = #selector(self.openSelected)
    self.backButton.action = #selector(self.goBack)
  }

  // MARK: - 当前层级

  /// 真正显示出来的记录：根层先按日期区间筛，再按当前排序排好
  private var displayedRecords: [ClockRecord] {
    let level = MVHistoryTracker.shared.records.records(at: self.path)
    // 筛选只认最外层：点进某条之后，它下面的子时钟记录整段都在
    let visible = self.path.isEmpty
      ? level.filter { self.filter?.contains($0.startDate) ?? true }
      : level
    return visible.sorted(by: self.sort)
  }

  private var selectedRecord: ClockRecord? {
    let row = self.tableView.selectedRow
    let records = self.displayedRecords
    return records.indices.contains(row) ? records[row] : nil
  }

  private var pathText: String {
    var titles = ["历史记录"]
    var level = MVHistoryTracker.shared.records
    for id in self.path {
      guard let index = level.firstIndex(where: { $0.id == id }) else { break }
      titles.append(level[index].name)
      level = level[index].children
    }
    return titles.joined(separator: " › ")
  }

  /// 计时中的记录每秒刷新；只重画，不动选中行与层级
  private func refreshPreservingSelection() {
    let selectedID = self.selectedRecord?.id
    self.tableView.reloadData()

    if let selectedID, let row = self.displayedRecords.firstIndex(where: { $0.id == selectedID }) {
      self.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
    self.updateControls()
  }

  func reload() {
    self.tableView.reloadData()
    self.updateControls()
  }

  private func updateControls() {
    self.pathLabel.stringValue = self.pathText
    self.backButton.isEnabled = !self.path.isEmpty

    let record = self.selectedRecord
    self.openButton.isEnabled = record?.children.isEmpty == false
    self.renameButton.isEnabled = record != nil
    self.deleteButton.isEnabled = record != nil

    let records = self.displayedRecords
    self.statsLabel.stringValue = self.statsText(for: records)

    // 进了下级之后筛选控件就用不上了（筛选只认最外层记录），关掉免得点了个空
    let filtering = self.path.isEmpty
    self.rangeButton.isEnabled = filtering
    self.presetControl.isEnabled = filtering

    self.hintLabel.stringValue = records.isEmpty
      ? (filtering && self.filter != nil ? "这段时间没有记录" : "还没有记录：一点开始计时就有")
      : "双击一行可以看下级记录"
  }

  // MARK: - 操作

  @objc private func openSelected() {
    guard let record = self.selectedRecord, !record.children.isEmpty else { return }
    self.path.append(record.id)
    self.reload()
  }

  @objc private func goBack() {
    guard !self.path.isEmpty else { return }
    self.path.removeLast()
    self.reload()
  }

  @objc private func renameSelected() {
    guard let record = self.selectedRecord else { return }

    let alert = NSAlert()
    alert.messageText = "重命名记录"
    alert.informativeText = record.summary

    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
    field.stringValue = record.name
    field.placeholderString = ClockRecord.defaultName(for: record.startDate)

    alert.accessoryView = field
    alert.addButton(withTitle: "好")
    alert.addButton(withTitle: "取消")
    alert.window.initialFirstResponder = field

    guard alert.runModal() == .alertFirstButtonReturn else { return }

    let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let recordID = record.id
    let path = self.path

    MVHistoryTracker.shared.mutate { records in
      records.mutate(at: path) { level in
        level.update(id: recordID) { target in
          target.name = name.isEmpty ? ClockRecord.defaultName(for: target.startDate) : name
        }
      }
    }
    self.reload()
  }

  @objc private func deleteSelected() {
    guard let record = self.selectedRecord else { return }

    let alert = NSAlert()
    alert.messageText = "删除记录「\(record.name)」？"
    alert.informativeText = record.children.isEmpty
      ? "删除后无法恢复。"
      : "它下面的 \(record.children.count) 条子时钟记录会一起删掉，无法恢复。"
    alert.addButton(withTitle: "删除")
    alert.addButton(withTitle: "取消")

    guard alert.runModal() == .alertFirstButtonReturn else { return }

    let recordID = record.id
    let path = self.path

    MVHistoryTracker.shared.mutate { records in
      records.mutate(at: path) { level in
        level.remove(id: recordID)
      }
    }
    self.reload()
  }
}

extension MVHistoryWindowController: NSWindowDelegate {
  func windowWillClose(_: Notification) {
    MVHistoryTracker.shared.onChange = nil
  }
}

extension MVHistoryWindowController: NSTableViewDataSource, NSTableViewDelegate {
  func numberOfRows(in _: NSTableView) -> Int {
    self.displayedRecords.count
  }

  func tableView(_: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
    let records = self.displayedRecords
    guard records.indices.contains(row) else { return nil }
    let record = records[row]

    switch column?.identifier.rawValue {
    case "name":
      return record.name

    case "title":
      return record.title.isEmpty ? "—" : record.title

    case "startDate":
      return record.startDateDisplay

    case "duration":
      return record.durationDisplay

    case "endDate":
      return record.endDateDisplay

    default:
      return nil
    }
  }

  func tableViewSelectionDidChange(_: Notification) {
    self.updateControls()
  }
}
