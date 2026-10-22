import Foundation

/// `Notification` 不是 `Sendable`，Swift 6 严格并发下无法直接
/// `for await` `NotificationCenter` 的异步序列（结果要跨隔离边界）。
/// 这里把通知剥成一份 `@unchecked Sendable` 的值再送出。
struct MVNotification: @unchecked Sendable {
  let name: Notification.Name
  let object: Any?

  init(_ notification: Notification) {
    self.name = notification.name
    self.object = notification.object
  }
}

extension NotificationCenter {
  /// 按通知名（可选按发送对象）订阅，产出 Sendable 安全的通知值。
  func mvNotifications(
    named name: Notification.Name,
    object: AnyObject? = nil
  ) -> AsyncCompactMapSequence<NotificationCenter.Notifications, MVNotification> {
    // 直接用 object 参数会让编译器报 AnyObject 非 Sendable，改用对象标识来过滤
    let targetID = object.map { ObjectIdentifier($0) }
    return self.notifications(named: name).compactMap { notification in
      guard let targetID else { return MVNotification(notification) }
      guard let sender = notification.object as? AnyObject,
        ObjectIdentifier(sender) == targetID
      else { return nil }
      return MVNotification(notification)
    }
  }
}
