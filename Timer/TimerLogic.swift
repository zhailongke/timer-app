import Foundation

enum TimerLogic {
  private static let scaleOriginal: CGFloat = 6
  private static let scaleActual: CGFloat = 3

  // MARK: - Progress Scale Conversion

  static func convertProgressToScale(_ progress: CGFloat, minutes: CGFloat) -> CGFloat {
    if minutes <= 60 {
      if progress <= scaleOriginal / 60 {
        return progress / (scaleOriginal / scaleActual)
      }
      return (progress * 60 - scaleOriginal + scaleActual) / (60 - scaleActual)
    }
    return progress
  }

  static func invertProgressToScale(_ progress: CGFloat, minutes: CGFloat) -> CGFloat {
    if minutes > 60 {
      return progress
    }

    if progress <= scaleActual / 60 {
      return progress * (scaleOriginal / scaleActual)
    }
    return (progress * (60 - scaleActual) - scaleActual + scaleOriginal) / 60
  }

  // MARK: - Display Strings

  static func minutesDisplayString(seconds: CGFloat) -> String {
    if seconds < 60 {
      return "\(Int(seconds))\""
    }
    return "\(Int(floor(seconds / 60)))'"
  }

  static func secondsDisplayString(seconds: CGFloat) -> String {
    if seconds < 60 {
      return ""
    }
    return "\(Int(seconds.truncatingRemainder(dividingBy: 60)))\""
  }

  /// 秒表用「时:分:秒」显示，例如 0:05:30 / 1:05:30
  static func stopwatchDisplayString(seconds: CGFloat) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%d:%02d:%02d", total / 3_600, (total % 3_600) / 60, total % 60)
  }

  /// 时长展示，例如 25:00 / 1:30:00
  static func durationDisplayString(seconds: CGFloat) -> String {
    let total = max(0, Int(seconds))
    if total >= 3_600 {
      return String(format: "%d:%02d:%02d", total / 3_600, (total % 3_600) / 60, total % 60)
    }
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  /// 解析「25」「25:30」「1:05:00」这类输入，返回秒；认不出来返回 nil。
  /// 只写一个数字按分钟算（"25" = 25 分钟），写分:秒才精确到秒
  static func parseDuration(_ text: String) -> CGFloat? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let parts = trimmed.split(separator: ":").compactMap { Double($0) }
    guard !parts.isEmpty, parts.count == trimmed.split(separator: ":").count,
      parts.allSatisfy({ $0 >= 0 })
    else { return nil }

    var seconds = 0.0
    for part in parts {
      seconds = seconds * 60 + part
    }
    if parts.count == 1 {
      seconds *= 60
    }
    return CGFloat(seconds)
  }

  static func badgeString(minutes: Int, seconds: Int) -> String {
    String(format: "%02d:%02d", minutes, seconds)
  }

  // MARK: - Keyboard Input

  struct DigitInputResult: Sendable {
    let seconds: CGFloat
    let accepted: Bool
  }

  static func processDigitInput(
    digit: Int,
    currentSeconds: CGFloat,
    currentMinutes: CGFloat,
    totalSeconds: CGFloat,
    inputSeconds: Bool
  ) -> DigitInputResult {
    var newSeconds: CGFloat

    if inputSeconds {
      if currentSeconds < 6 || currentMinutes == 0 {
        newSeconds = currentMinutes * 60 + currentSeconds * 10 + CGFloat(digit)
      } else {
        newSeconds = totalSeconds
      }
    } else {
      newSeconds = currentMinutes * 600 + currentSeconds + CGFloat(digit) * 60
    }

    if newSeconds < 999 * 60 {
      return DigitInputResult(seconds: newSeconds, accepted: true)
    }
    return DigitInputResult(seconds: totalSeconds, accepted: false)
  }

  static func processBackspace(
    currentSeconds: CGFloat,
    currentMinutes: CGFloat,
    inputSeconds: Bool
  ) -> CGFloat {
    if inputSeconds {
      return currentMinutes * 60 + floor(currentSeconds / 10)
    }
    return floor(currentMinutes / 10) * 60 + currentSeconds
  }

  // MARK: - Accessibility

  static func accessibilityTimeDescription(minutes: Int, seconds: Int) -> String {
    if minutes > 0, seconds > 0 {
      return "\(minutes) 分 \(seconds) 秒"
    }
    if minutes > 0 {
      return "\(minutes) 分"
    }
    return "\(seconds) 秒"
  }

  // MARK: - Sound

  static func soundFilename(forIndex index: Int) -> String? {
    switch index {
    case -1:
      return nil

    case 0:
      return "alert-sound"

    case 1:
      return "alert-sound-2"

    case 2:
      return "alert-sound-3"

    default:
      return "alert-sound"
    }
  }
}
