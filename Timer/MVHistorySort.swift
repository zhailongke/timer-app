import Foundation

/// 历史记录列表按哪一列排；列的 identifier 与排序键同名，点列头就能对上
enum MVHistorySortKey: String, CaseIterable, Sendable {
  case duration
  case endDate
  case name
  case startDate
  case title

  init?(columnIdentifier: String) {
    self.init(rawValue: columnIdentifier)
  }
}

struct MVHistorySort: Equatable, Sendable {
  var key: MVHistorySortKey
  var ascending: Bool

  /// 默认看最新的：起始时间倒序，正在跑的那条排最上面
  init(key: MVHistorySortKey = .startDate, ascending: Bool = false) {
    self.key = key
    self.ascending = ascending
  }

  /// 换一列时的初始方向：文字从小到大，时间与时长从大到小
  static func preferredAscending(for key: MVHistorySortKey) -> Bool {
    switch key {
    case .name, .title:
      return true

    case .startDate, .endDate, .duration:
      return false
    }
  }

  static func compare(_ lhs: ClockRecord, _ rhs: ClockRecord, key: MVHistorySortKey) -> Int {
    switch key {
    case .name:
      return Self.textOrder(lhs.name, rhs.name)

    case .title:
      return Self.textOrder(lhs.title, rhs.title)

    case .startDate:
      return Self.valueOrder(lhs.startDate, rhs.startDate)

    case .endDate:
      return Self.valueOrder(lhs.endDate, rhs.endDate)

    case .duration:
      return Self.valueOrder(lhs.duration, rhs.duration)
    }
  }

  private static func textOrder(_ lhs: String, _ rhs: String) -> Int {
    switch lhs.localizedStandardCompare(rhs) {
    case .orderedAscending:
      return -1

    case .orderedDescending:
      return 1

    case .orderedSame:
      return 0
    }
  }

  private static func valueOrder<T: Comparable>(_ lhs: T, _ rhs: T) -> Int {
    if lhs < rhs { return -1 }
    return lhs > rhs ? 1 : 0
  }
}

extension Array where Element == ClockRecord {
  /// 按排序键排序；值相同的按起始时间、再按 id 兜底，避免每秒刷新时行乱跳
  func sorted(by sort: MVHistorySort) -> [ClockRecord] {
    self.sorted { lhs, rhs in
      let directed = sort.ascending
        ? MVHistorySort.compare(lhs, rhs, key: sort.key)
        : -MVHistorySort.compare(lhs, rhs, key: sort.key)
      if directed != 0 {
        return directed < 0
      }
      if lhs.startDate != rhs.startDate {
        return sort.ascending ? lhs.startDate < rhs.startDate : lhs.startDate > rhs.startDate
      }
      return lhs.id.uuidString < rhs.id.uuidString
    }
  }
}
