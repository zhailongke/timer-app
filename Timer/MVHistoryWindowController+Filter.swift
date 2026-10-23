import AppKit

// MARK: - 日期筛选与排序

/// 窗口顶部的日期筛选条、月历弹层、以及列头排序。
/// 单独拆一个文件，主文件只管列表本身；这里的成员因此不加 private
extension MVHistoryWindowController {
  /// 顶部第二行：当前区间按钮（点开是月历）+ 一键预设；
  /// 「共 N 条 · 合计 …」放在路径标签那一行右侧
  func buildFilterBar(in content: NSView) {
    self.statsLabel.frame = NSRect(x: 330, y: 446, width: 336, height: 18)
    self.statsLabel.font = NSFont.systemFont(ofSize: 12)
    self.statsLabel.textColor = .secondaryLabelColor
    self.statsLabel.alignment = .right
    self.statsLabel.autoresizingMask = [.width, .minXMargin, .minYMargin]
    content.addSubview(self.statsLabel)

    self.rangeButton.frame = NSRect(x: 14, y: 414, width: 180, height: 28)
    self.rangeButton.bezelStyle = .rounded
    self.rangeButton.target = self
    self.rangeButton.action = #selector(self.showCalendar(_:))
    self.rangeButton.autoresizingMask = [.minYMargin]
    content.addSubview(self.rangeButton)

    self.presetControl.frame = NSRect(x: 202, y: 414, width: 310, height: 26)
    self.presetControl.target = self
    self.presetControl.action = #selector(self.applyPreset(_:))
    self.presetControl.autoresizingMask = [.minYMargin]
    content.addSubview(self.presetControl)
  }

  /// 当前层有多少条、合计多长时间（正在跑的那条每秒跟着长）
  func statsText(for records: [ClockRecord]) -> String {
    guard !records.isEmpty else { return "共 0 条" }

    let total = records.reduce(0) { $0 + $1.duration }
    return "共 \(records.count) 条 · 合计 \(TimerLogic.stopwatchDisplayString(seconds: CGFloat(total)))"
  }

  // MARK: - 日期区间

  func applyFilter(_ filter: MVHistoryDateFilter?) {
    self.filter = filter
    MVHistoryFilterStore.save(filter)
    self.updateRangeControls()
    self.reload()
  }

  func updateRangeControls() {
    self.rangeButton.title = self.filter?.displayText ?? "全部记录"
  }

  @objc func applyPreset(_ sender: NSSegmentedControl) {
    switch sender.selectedSegment {
    case 0:
      self.applyFilter(.today())

    case 1:
      self.applyFilter(.yesterday())

    case 2:
      self.applyFilter(.lastDays(7))

    case 3:
      self.applyFilter(.lastDays(30))

    default:
      self.applyFilter(nil)
    }
  }

  /// 点范围按钮：弹月历，点起止两天定区间
  @objc func showCalendar(_: Any?) {
    self.calendarPopover?.close()

    let popover = NSPopover()
    popover.behavior = .semitransient
    popover.delegate = self

    let calendarView = MVCalendarView(
      month: self.filter?.start ?? Date(),
      startDate: self.filter?.start,
      endDate: self.filter?.lastDay
    )
    calendarView.onSelectionChanged = { [weak self] start, end in
      self?.applyFilter(MVHistoryDateFilter(startDay: start, endDay: end))
      self?.calendarPopover?.close()
    }

    let controller = NSViewController()
    controller.view = NSView(frame: NSRect(origin: .zero, size: MVCalendarView.size))
    controller.view.addSubview(calendarView)
    popover.contentViewController = controller
    popover.contentSize = MVCalendarView.size

    self.calendarPopover = popover
    popover.show(relativeTo: self.rangeButton.bounds, of: self.rangeButton, preferredEdge: .maxY)
  }

  // MARK: - 排序

  func updateSortIndicators() {
    let symbol = self.sort.ascending ? "chevron.up" : "chevron.down"
    for column in self.tableView.tableColumns {
      let isActive = column.identifier.rawValue == self.sort.key.rawValue
      self.tableView.setIndicatorImage(
        isActive ? NSImage(systemSymbolName: symbol, accessibilityDescription: nil) : nil,
        in: column
      )
    }
  }

  /// 点列头排序：点同一列换方向，换一列就按那列的默认方向来
  func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
    guard let descriptor = tableView.sortDescriptors.first,
      let key = MVHistorySortKey(columnIdentifier: descriptor.key ?? "")
    else { return }

    if self.sort.key == key {
      self.sort.ascending.toggle()
    } else {
      self.sort = MVHistorySort(key: key, ascending: MVHistorySort.preferredAscending(for: key))
    }
    self.updateSortIndicators()
    self.reload()
  }
}

extension MVHistoryWindowController: NSPopoverDelegate {
  func popoverDidClose(_: Notification) {
    self.calendarPopover = nil
  }
}
