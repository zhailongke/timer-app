import AppKit

/// 自绘月历：点一下选开始日，再点一下选结束日，区间内高亮；可以翻月，跨月选也行。
/// 系统自带的 NSDatePicker 图形日历选不了区间，所以自己画一个
final class MVCalendarView: NSView {
  /// 选完整一段才回调（起止都含，已经排好先后）
  var onSelectionChanged: ((Date, Date) -> Void)?

  static let size = NSSize(width: 272, height: 256)

  private static let inset: CGFloat = 10
  private static let headerHeight: CGFloat = 30
  private static let weekdayHeight: CGFloat = 18
  private static let cellHeight: CGFloat = 28
  private static let cellWidth: CGFloat = 36
  private static let hintHeight: CGFloat = 18
  private static let columnCount = 7
  private static let rowCount = 6
  private static let weekdayTitles = ["日", "一", "二", "三", "四", "五", "六"]

  private let titleLabel: NSTextField = {
    let label = NSTextField(labelWithString: "")
    label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    label.alignment = .center
    return label
  }()

  private let previousButton = MVCalendarView.arrowButton(symbol: "chevron.left")
  private let nextButton = MVCalendarView.arrowButton(symbol: "chevron.right")

  private let hintLabel: NSTextField = {
    let label = NSTextField(labelWithString: "点一下选开始日，再点一下选结束日")
    label.font = NSFont.systemFont(ofSize: 11)
    label.textColor = .secondaryLabelColor
    label.alignment = .center
    return label
  }()

  /// 当前显示的月份（固定为该月 1 号 00:00）
  private var monthStart: Date
  /// 选中区间的两端（都含）；只点了第一下时 end 为 nil
  private var selectionStart: Date?
  private var selectionEnd: Date?

  init(month: Date, startDate: Date?, endDate: Date?) {
    let calendar = Calendar.current
    let parts = calendar.dateComponents([.year, .month], from: month)
    self.monthStart = calendar.date(from: parts) ?? calendar.startOfDay(for: month)
    self.selectionStart = startDate.map { calendar.startOfDay(for: $0) }
    self.selectionEnd = endDate.map { calendar.startOfDay(for: $0) }
    super.init(frame: NSRect(origin: .zero, size: Self.size))

    self.previousButton.target = self
    self.previousButton.action = #selector(self.showPreviousMonth)
    self.nextButton.target = self
    self.nextButton.action = #selector(self.showNextMonth)

    self.addSubview(self.titleLabel)
    self.addSubview(self.previousButton)
    self.addSubview(self.nextButton)
    self.addSubview(self.hintLabel)
    self.updateTitle()
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private static func arrowButton(symbol: String) -> NSButton {
    let button = NSButton(frame: .zero)
    button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    button.imagePosition = .imageOnly
    button.isBordered = false
    return button
  }

  // MARK: - 布局

  override func layout() {
    super.layout()

    let top = self.bounds.height - Self.inset - Self.headerHeight
    self.previousButton.frame = NSRect(x: Self.inset, y: top + 2, width: 26, height: 26)
    self.nextButton.frame = NSRect(x: self.bounds.width - Self.inset - 26, y: top + 2, width: 26, height: 26)
    self.titleLabel.frame = NSRect(
      x: Self.inset + 28,
      y: top + 4,
      width: self.bounds.width - Self.inset * 2 - 56,
      height: 20
    )
    self.hintLabel.frame = NSRect(
      x: Self.inset,
      y: 4,
      width: self.bounds.width - Self.inset * 2,
      height: Self.hintHeight
    )
  }

  private var weekdayFrame: NSRect {
    NSRect(
      x: Self.inset,
      y: self.bounds.height - Self.inset - Self.headerHeight - Self.weekdayHeight,
      width: Self.cellWidth * CGFloat(Self.columnCount),
      height: Self.weekdayHeight
    )
  }

  private func cellFrame(row: Int, column: Int) -> NSRect {
    NSRect(
      x: Self.inset + CGFloat(column) * Self.cellWidth,
      y: self.weekdayFrame.minY - CGFloat(row + 1) * Self.cellHeight,
      width: Self.cellWidth,
      height: Self.cellHeight
    )
  }

  /// 左上角那格对应的日期（可能是上个月的尾巴）
  private var gridStartDate: Date {
    let calendar = Calendar.current
    let offset = calendar.component(.weekday, from: self.monthStart) - 1
    return calendar.date(byAdding: .day, value: -offset, to: self.monthStart) ?? self.monthStart
  }

  private func date(atRow row: Int, column: Int) -> Date? {
    Calendar.current.date(byAdding: .day, value: row * Self.columnCount + column, to: self.gridStartDate)
  }

  // MARK: - 绘制

  override func draw(_: NSRect) {
    self.drawWeekdayTitles()

    for row in 0..<Self.rowCount {
      for column in 0..<Self.columnCount {
        guard let date = self.date(atRow: row, column: column) else { continue }
        self.draw(day: date, in: self.cellFrame(row: row, column: column))
      }
    }
  }

  private func drawWeekdayTitles() {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 11, weight: .medium),
      .foregroundColor: NSColor.secondaryLabelColor
    ]
    for (index, title) in Self.weekdayTitles.enumerated() {
      let columnFrame = NSRect(
        x: Self.inset + CGFloat(index) * Self.cellWidth,
        y: self.weekdayFrame.minY + 2,
        width: Self.cellWidth,
        height: 14
      )
      Self.drawCentered(title, in: columnFrame, attributes: attributes)
    }
  }

  private func draw(day: Date, in frame: NSRect) {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: day)

    let isFirst = self.selectionStart.map { calendar.isDate(dayStart, inSameDayAs: $0) } ?? false
    let isLast = self.selectionEnd.map { calendar.isDate(dayStart, inSameDayAs: $0) } ?? false
    let inRange = self.isSelected(dayStart)
    let isEndpoint = isFirst || isLast

    if inRange {
      // 首尾画圆点，中间的铺满整格连成一条
      let path = isEndpoint
        ? NSBezierPath(ovalIn: frame.insetBy(dx: 4, dy: 3))
        : NSBezierPath(rect: frame.insetBy(dx: 0, dy: 3))
      (isEndpoint ? NSColor.systemBlue : NSColor.systemBlue.withAlphaComponent(0.22)).setFill()
      path.fill()
    } else if calendar.isDateInToday(dayStart) {
      NSColor.systemBlue.setStroke()
      NSBezierPath(ovalIn: frame.insetBy(dx: 4, dy: 3)).stroke()
    }

    let inCurrentMonth = calendar.isDate(dayStart, equalTo: self.monthStart, toGranularity: .month)
    let color: NSColor
    if isEndpoint {
      color = .white
    } else if inCurrentMonth {
      color = .labelColor
    } else {
      color = .tertiaryLabelColor
    }

    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12, weight: inCurrentMonth ? .regular : .light),
      .foregroundColor: color
    ]
    Self.drawCentered("\(calendar.component(.day, from: dayStart))", in: frame, attributes: attributes)
  }

  private static func drawCentered(_ text: String, in frame: NSRect, attributes: [NSAttributedString.Key: Any]) {
    let measured = (text as NSString).size(withAttributes: attributes)
    let rect = NSRect(
      x: frame.midX - measured.width / 2,
      y: frame.midY - measured.height / 2,
      width: measured.width,
      height: measured.height
    )
    (text as NSString).draw(in: rect, withAttributes: attributes)
  }

  private func isSelected(_ dayStart: Date) -> Bool {
    guard let start = self.selectionStart else { return false }
    let end = self.selectionEnd ?? start
    return dayStart >= start && dayStart <= end
  }

  // MARK: - 交互

  override func mouseUp(with event: NSEvent) {
    let point = self.convert(event.locationInWindow, from: nil)
    guard let day = self.day(at: point) else { return }

    // 第一下：定开始日；第二下：补齐结束日并回调
    if let start = self.selectionStart, self.selectionEnd == nil {
      let ordered = day < start ? (day, start) : (start, day)
      self.selectionStart = ordered.0
      self.selectionEnd = ordered.1
      self.needsDisplay = true
      self.onSelectionChanged?(ordered.0, ordered.1)
      return
    }

    self.selectionStart = day
    self.selectionEnd = nil
    self.needsDisplay = true
  }

  private func day(at point: NSPoint) -> Date? {
    for row in 0..<Self.rowCount {
      for column in 0..<Self.columnCount where self.cellFrame(row: row, column: column).contains(point) {
        return self.date(atRow: row, column: column)
      }
    }
    return nil
  }

  @objc private func showPreviousMonth() {
    self.shiftMonth(by: -1)
  }

  @objc private func showNextMonth() {
    self.shiftMonth(by: 1)
  }

  private func shiftMonth(by value: Int) {
    let calendar = Calendar.current
    guard let month = calendar.date(byAdding: .month, value: value, to: self.monthStart) else { return }
    self.monthStart = month
    self.updateTitle()
    self.needsDisplay = true
  }

  private func updateTitle() {
    let parts = Calendar.current.dateComponents([.year, .month], from: self.monthStart)
    self.titleLabel.stringValue = "\(parts.year ?? 0)年\(parts.month ?? 0)月"
  }

  // MARK: - Accessibility

  override func isAccessibilityElement() -> Bool { true }
  override func accessibilityRole() -> NSAccessibility.Role? { .group }
  override func accessibilityLabel() -> String? { "日历" }
}
