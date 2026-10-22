import AppKit

/// 历史记录窗口：根一层是每次主时钟的记录，点进去是那一次记录下的子时钟记录，
/// 再往下一层层点。选中一行可以改名、删除、看它的下级
@MainActor
final class MVHistoryWindowController: NSWindowController {
  static let shared = MVHistoryWindowController()

  private var records: [ClockRecord] = []
  /// 一层层点进来的记录 id；空就是根层（每次主时钟）
  private var path: [UUID] = []

  private let tableView = NSTableView(frame: .zero)
  private let pathLabel = NSTextField(labelWithString: "历史记录")
  private let backButton = NSButton(title: "返回", target: nil, action: nil)
  private let openButton = NSButton(title: "查看下级…", target: nil, action: nil)
  private let renameButton = NSButton(title: "改名…", target: nil, action: nil)
  private let deleteButton = NSButton(title: "删除", target: nil, action: nil)
  private let hintLabel = NSTextField(labelWithString: "")

  private init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 680, height: 440),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "历史记录"
    // 关掉还能再开
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 560, height: 300)
    super.init(window: window)
    self.buildContent()
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    self.records = MVHistoryStore.load()
    self.path = []
    self.reload()
    self.window?.center()
    self.showWindow(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  private func buildContent() {
    guard let content = self.window?.contentView else { return }

    self.pathLabel.frame = NSRect(x: 14, y: 404, width: 380, height: 18)
    self.pathLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
    self.pathLabel.lineBreakMode = .byTruncatingMiddle
    self.pathLabel.autoresizingMask = [.width, .minYMargin]
    content.addSubview(self.pathLabel)

    for (identifier, title, width) in [
      ("name", "名字", 150),
      ("title", "时钟", 90),
      ("start", "起始时间", 120),
      ("duration", "时长", 90),
      ("end", "结束时间", 140)
    ] {
      let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
      column.title = title
      column.width = CGFloat(width)
      column.minWidth = 70
      column.resizingMask = .userResizingMask
      self.tableView.addTableColumn(column)
    }

    self.tableView.dataSource = self
    self.tableView.delegate = self
    self.tableView.rowHeight = 22
    self.tableView.usesAlternatingRowBackgroundColors = true
    self.tableView.doubleAction = #selector(self.openSelected)
    self.tableView.target = self

    let scrollView = NSScrollView(frame: NSRect(x: 12, y: 46, width: 656, height: 350))
    scrollView.borderType = .bezelBorder
    scrollView.hasVerticalScroller = true
    scrollView.autoresizingMask = [.width, .height]
    scrollView.documentView = self.tableView
    content.addSubview(scrollView)

    self.hintLabel.frame = NSRect(x: 14, y: 14, width: 320, height: 16)
    self.hintLabel.textColor = .secondaryLabelColor
    self.hintLabel.autoresizingMask = [.maxXMargin, .maxYMargin]
    content.addSubview(self.hintLabel)

    // 从右往左排：删除 / 改名 / 查看下级 / 返回
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

  private var currentRecords: [ClockRecord] {
    self.records.records(at: self.path)
  }

  private var selectedRecord: ClockRecord? {
    let row = self.tableView.selectedRow
    let records = self.currentRecords
    return records.indices.contains(row) ? records[row] : nil
  }

  private var pathText: String {
    var titles = ["历史记录"]
    var level = self.records
    for id in self.path {
      guard let index = level.firstIndex(where: { $0.id == id }) else { break }
      titles.append(level[index].name)
      level = level[index].children
    }
    return titles.joined(separator: " › ")
  }

  private func reload() {
    self.tableView.reloadData()

    self.pathLabel.stringValue = self.pathText
    self.backButton.isEnabled = !self.path.isEmpty

    let record = self.selectedRecord
    self.openButton.isEnabled = record?.children.isEmpty == false
    self.renameButton.isEnabled = record != nil
    self.deleteButton.isEnabled = record != nil

    self.hintLabel.stringValue = self.currentRecords.isEmpty
      ? "还没有记录：关掉一个时钟就记一条，或右键选「记入历史」"
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
    let id = record.id
    let path = self.path
    MVHistoryStore.update { records in
      records.mutate(at: path) { level in
        for index in level.indices where level[index].id == id {
          level[index].name = name.isEmpty ? ClockRecord.defaultName(for: level[index].startDate) : name
        }
      }
    }
    self.records = MVHistoryStore.load()
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

    let id = record.id
    let path = self.path
    MVHistoryStore.update { records in
      records.mutate(at: path) { level in
        level.remove(id: id)
      }
    }
    self.records = MVHistoryStore.load()
    self.reload()
  }
}

extension MVHistoryWindowController: NSTableViewDataSource, NSTableViewDelegate {
  func numberOfRows(in _: NSTableView) -> Int {
    self.currentRecords.count
  }

  func tableView(_: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
    let records = self.currentRecords
    guard records.indices.contains(row) else { return nil }
    let record = records[row]

    switch column?.identifier.rawValue {
    case "name":
      return record.name

    case "title":
      return record.title.isEmpty ? "—" : record.title

    case "start":
      return record.startDateDisplay

    case "duration":
      return record.durationDisplay

    case "end":
      return record.endDateDisplay

    default:
      return nil
    }
  }

  func tableViewSelectionDidChange(_: Notification) {
    let record = self.selectedRecord
    self.openButton.isEnabled = record?.children.isEmpty == false
    self.renameButton.isEnabled = record != nil
    self.deleteButton.isEnabled = record != nil
  }
}
