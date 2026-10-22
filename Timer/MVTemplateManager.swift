import AppKit

/// 模板管理窗口：列出存过的模板，可以修改内容或删掉。
/// 「子时钟 ▸ 管理模板…」打开，改完右键菜单里的列表下次打开菜单就是新的
@MainActor
final class MVTemplateManager: NSWindowController {
  static let shared = MVTemplateManager()

  private var templates: [ChildClockTemplate] = []

  private let tableView = NSTableView(frame: .zero)
  private let editButton = NSButton(title: "修改…", target: nil, action: nil)
  private let deleteButton = NSButton(title: "删除", target: nil, action: nil)
  private let hintLabel = NSTextField(labelWithString: "")

  private init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "模板管理"
    // 关掉后还能再开
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 400, height: 240)
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

    let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    nameColumn.title = "名字"
    nameColumn.width = 170
    nameColumn.minWidth = 110
    nameColumn.resizingMask = .userResizingMask

    let detailColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("detail"))
    detailColumn.title = "内容"
    detailColumn.width = 260
    detailColumn.minWidth = 150
    detailColumn.resizingMask = .userResizingMask

    self.tableView.addTableColumn(nameColumn)
    self.tableView.addTableColumn(detailColumn)
    self.tableView.dataSource = self
    self.tableView.delegate = self
    self.tableView.rowHeight = 22
    self.tableView.usesAlternatingRowBackgroundColors = true
    self.tableView.doubleAction = #selector(self.editSelected)
    self.tableView.target = self

    let scrollView = NSScrollView(frame: NSRect(x: 12, y: 46, width: 456, height: 282))
    scrollView.borderType = .bezelBorder
    scrollView.hasVerticalScroller = true
    scrollView.autoresizingMask = [.width, .height]
    scrollView.documentView = self.tableView
    content.addSubview(scrollView)

    self.hintLabel.frame = NSRect(x: 14, y: 14, width: 300, height: 16)
    self.hintLabel.textColor = .secondaryLabelColor
    self.hintLabel.autoresizingMask = [.maxXMargin, .maxYMargin]
    content.addSubview(self.hintLabel)

    self.editButton.target = self
    self.editButton.action = #selector(self.editSelected)
    self.editButton.bezelStyle = .rounded
    self.editButton.frame = NSRect(x: 280, y: 8, width: 88, height: 28)
    self.editButton.autoresizingMask = [.minXMargin, .maxYMargin]
    content.addSubview(self.editButton)

    self.deleteButton.target = self
    self.deleteButton.action = #selector(self.deleteSelected)
    self.deleteButton.bezelStyle = .rounded
    self.deleteButton.frame = NSRect(x: 372, y: 8, width: 88, height: 28)
    self.deleteButton.autoresizingMask = [.minXMargin, .maxYMargin]
    content.addSubview(self.deleteButton)
  }

  @objc private func editSelected() {
    guard let index = self.selectedIndex() else { return }
    let template = self.templates[index]

    guard let updated = MVTemplateEditor.edit(template) else { return }
    MVTemplateStore.update(updated) // 按 id 覆盖，改名也只留一份
    self.reload(selecting: index)
  }

  @objc private func deleteSelected() {
    guard let index = self.selectedIndex() else { return }
    let template = self.templates[index]

    let alert = NSAlert()
    alert.messageText = "删除模板「\(template.name)」？"
    alert.informativeText = "删除后无法恢复，已经建好的子时钟不受影响。"
    alert.addButton(withTitle: "删除")
    alert.addButton(withTitle: "取消")

    guard alert.runModal() == .alertFirstButtonReturn else { return }

    MVTemplateStore.remove(id: template.id)
    self.reload(selecting: min(index, self.templates.count - 1))
  }

  private func selectedIndex() -> Int? {
    let row = self.tableView.selectedRow
    return self.templates.indices.contains(row) ? row : nil
  }

  private func reload(selecting row: Int? = nil) {
    self.templates = MVTemplateStore.load()
    self.tableView.reloadData()

    if let row, self.templates.indices.contains(row) {
      self.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    let hasSelection = self.selectedIndex() != nil
    self.editButton.isEnabled = hasSelection
    self.deleteButton.isEnabled = hasSelection
    self.hintLabel.stringValue = self.templates.isEmpty
      ? "还没有模板：在子时钟上右键选「保存为模板…」"
      : "双击一行可以修改模板"
  }
}

extension MVTemplateManager: NSTableViewDataSource, NSTableViewDelegate {
  func numberOfRows(in _: NSTableView) -> Int {
    self.templates.count
  }

  func tableView(_: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
    guard self.templates.indices.contains(row) else { return nil }
    let template = self.templates[row]

    guard let identifier = column?.identifier.rawValue else { return nil }
    return identifier == "name" ? template.name : template.summary
  }

  func tableViewSelectionDidChange(_: Notification) {
    let hasSelection = self.selectedIndex() != nil
    self.editButton.isEnabled = hasSelection
    self.deleteButton.isEnabled = hasSelection
  }
}
