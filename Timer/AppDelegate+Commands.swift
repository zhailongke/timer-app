import AppKit

// MARK: - timer:// 与命令行指令解析

extension AppDelegate {
  func handleTimerCommand(_ input: String, window: Int? = nil) {
    if input.lowercased() == "new" {
      self.newDocument(nil)
      return
    }

    let index = (window ?? 1) - 1
    guard self.controllers.indices.contains(index) else { return }
    let controller = self.controllers[index]
    let clockView = controller.clockView

    switch input.lowercased() {
    case "stop":
      clockView.paused = false
      clockView.stop()

    case "reset":
      clockView.paused = false
      clockView.stop()
      clockView.seconds = 0
      clockView.updateTimerTime()
      clockView.inputSeconds = false

    case "pause":
      if clockView.timerTask != nil {
        clockView.paused = true
        clockView.stop()
      } else if clockView.paused, clockView.seconds > 0 {
        clockView.updateTimerTime()
        clockView.start()
      }

    default:
      guard let seconds = self.parseTimeInput(input), seconds > 0 else { return }
      // 显式时长就是倒计时，只把这个时钟切过去（startTimer 自己会切模式）
      clockView.startTimer(seconds: seconds)
    }

    controller.window?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  static func parseLaunchArguments(_ args: [String]) -> (command: String?, window: Int?) {
    // args[0] is the executable path; skip it
    var command: String?
    var window: Int?
    var skip = false
    for idx in 1..<args.count {
      if skip { skip = false; continue }
      if args[idx] == "--window" {
        if idx + 1 < args.count, let value = Int(args[idx + 1]) {
          window = value
          skip = true
        }
      } else {
        command = args[idx]
      }
    }
    return (command, window)
  }

  private static let maxTimerSeconds: CGFloat = 24 * 60 * 60 // 24 hours

  private func parseTimeInput(_ input: String) -> CGFloat? {
    let seconds: CGFloat

    // "2:50" → 2 minutes 50 seconds (colon = literal minutes:seconds)
    if input.contains(":") {
      let parts = input.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
      guard parts.count == 2, let minutes = Double(parts[0]), let secs = Double(parts[1]) else { return nil }
      seconds = CGFloat(minutes * 60 + secs)
    } else if let value = Double(input) {
      // "2.5" → 2.5 minutes = 2m30s (dot = fractional minutes)
      seconds = CGFloat(value * 60)
    } else {
      return nil
    }

    guard seconds.isFinite, seconds <= Self.maxTimerSeconds else { return nil }
    return seconds
  }
}
