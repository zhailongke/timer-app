import Foundation

/// 计时模式。`countdown` 是原有倒计时，`stopwatch` 是正向计时（秒表，向上累加无上限）。
enum TimerMode: String, Sendable {
  case countdown
  case stopwatch
}
