enum MVUserDefaultsKeys {
  static let staysOnTop = "staysOnTop"
  static let soundIndex = "soundIndex"
  static let childClockTemplates = "childClockTemplates"
  static let historyRecords = "historyRecords"
  /// 历史记录窗口上次用的日期区间（nil 表示「全部记录」）
  static let historyDateFilter = "historyDateFilter"
  /// 事件（名字 + 日期 + 每日时长），表盘上显示倒计时。
  /// 字符串还是老的 keyDates：改名前存进去的事件不能丢
  static let events = "keyDates"
  /// 总小时数按一天多少小时折算；没存就是一天 24 小时。字符串也是老的
  static let eventsHoursPerDay = "keyDatesHoursPerDay"
  /// 表盘下方显示哪个事件的倒计时（存 UUID 字符串），没存 = 自动选最近的
  static let eventDisplaySelected = "eventDisplaySelected"
  /// 轮播模式：表盘每隔几秒自动切到下一个事件
  static let eventDisplayRotate = "eventDisplayRotate"
}
