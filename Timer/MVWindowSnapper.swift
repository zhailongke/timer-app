import AppKit

/// 窗口拼接的几何计算：算出被拖动的窗口该挪到哪儿。
///
/// 两步走：够得着就贴上去拼成一片（缝归零、边对齐）；够不着但大致对上了，
/// 就把那条边或中线对齐——所以不用描得很准，横着隔多远都能排齐。
/// 不合并、也不记组关系，拖近就拼、拖走就散，这里没有状态，每次只看当前这一帧的位置。
enum MVWindowSnapper {
  /// 离目标位置多近才算「想拼上 / 想对齐」（单位点）
  static let snapDistance: CGFloat = 16

  struct Target {
    let origin: NSPoint
    let distance: CGFloat
  }

  /// 某一个轴上的一条对齐线：线在哪儿 + 离当前位置多远
  private struct Axis {
    let value: CGFloat
    let distance: CGFloat
  }

  /// 该挪到哪儿；够不上就返回 nil，保持拖动原样
  /// - Parameters:
  ///   - frame: 被拖动窗口当前的位置（系统按鼠标算出来的那个，不是上一次吸附的结果）
  ///   - others: 参与拼接的其它窗口位置
  ///   - visibleFrame: 窗口所在屏幕的可见区域，防止把窗口吸出屏幕
  static func snapTarget(for frame: NSRect, among others: [NSRect], visibleFrame: NSRect?) -> NSPoint? {
    if let attached = Self.attachedOrigin(for: frame, among: others, visibleFrame: visibleFrame) {
      return attached
    }
    return Self.alignedOrigin(for: frame, among: others, visibleFrame: visibleFrame)
  }

  // MARK: - 拼接：贴上去，缝归零

  private static func attachedOrigin(
    for frame: NSRect,
    among others: [NSRect],
    visibleFrame: NSRect?
  ) -> NSPoint? {
    var candidates: [Target] = []

    for other in others {
      for target in Self.candidates(attaching: frame, to: other) {
        guard target.distance <= Self.snapDistance else { continue }
        guard Self.isAcceptable(
          NSRect(origin: target.origin, size: frame.size),
          among: others,
          current: frame,
          visibleFrame: visibleFrame
        ) else { continue }

        candidates.append(target)
      }
    }

    return candidates.min { $0.distance < $1.distance }?.origin
  }

  // MARK: - 对齐：大致对上就吸过去，另一个轴不动

  /// 贴不上也能排齐：边或中线只要差得不多就吸到那条线上，横着隔多远都行
  private static func alignedOrigin(
    for frame: NSRect,
    among others: [NSRect],
    visibleFrame: NSRect?
  ) -> NSPoint? {
    var bestX: Axis?
    var bestY: Axis?

    for other in others {
      let verticalLines: [CGFloat] = [
        other.minX,                  // 左边对齐
        other.maxX - frame.width,    // 右边对齐
        other.midX - frame.width / 2 // 居中对齐
      ]
      for value in verticalLines {
        bestX = Self.nearer(bestX, Self.axis(value: value, current: frame.origin.x))
      }

      let horizontalLines: [CGFloat] = [
        other.minY,                   // 底边对齐
        other.maxY - frame.height,    // 顶边对齐
        other.midY - frame.height / 2 // 居中对齐
      ]
      for value in horizontalLines {
        bestY = Self.nearer(bestY, Self.axis(value: value, current: frame.origin.y))
      }
    }

    // 两个轴都能对上就一起吸；一起挪会压住别人或出屏，就退成只吸一个轴
    let origins: [NSPoint] = [
      NSPoint(x: bestX?.value ?? frame.origin.x, y: bestY?.value ?? frame.origin.y),
      NSPoint(x: frame.origin.x, y: bestY?.value ?? frame.origin.y),
      NSPoint(x: bestX?.value ?? frame.origin.x, y: frame.origin.y)
    ]
    for origin in origins {
      guard origin != frame.origin else { continue }
      guard Self.isAcceptable(
        NSRect(origin: origin, size: frame.size),
        among: others,
        current: frame,
        visibleFrame: visibleFrame
      ) else { continue }
      return origin
    }
    return nil
  }

  private static func axis(value: CGFloat, current: CGFloat) -> Axis {
    // 取整：贴在半像素上会把圆环和文字拖模糊
    let rounded = round(value)
    return Axis(value: rounded, distance: abs(current - rounded))
  }

  /// 留更近的那条线；超出阈值的一概不要
  private static func nearer(_ current: Axis?, _ candidate: Axis) -> Axis? {
    guard candidate.distance <= Self.snapDistance else { return current }
    guard let current else { return candidate }
    return candidate.distance < current.distance ? candidate : current
  }

  private static func isAcceptable(
    _ rect: NSRect,
    among others: [NSRect],
    current: NSRect,
    visibleFrame: NSRect?
  ) -> Bool {
    guard !others.contains(where: { $0.intersects(rect) }) else { return false }

    if let visibleFrame {
      let before = Self.visibleArea(of: current, in: visibleFrame)
      let after = Self.visibleArea(of: rect, in: visibleFrame)
      guard after >= before - 0.5 else { return false }
    }
    return true
  }

  /// 四个方向：横向贴在 other 的左右两边，纵向贴在上下两边；
  /// 每个方向再给三种对齐（近端 / 远端 / 居中），最后由距离挑最像用户心意的那一种
  private static func candidates(attaching frame: NSRect, to other: NSRect) -> [Target] {
    var result: [Target] = []

    let horizontalOrigins: [CGFloat] = [
      other.maxX,              // 贴在 other 右边
      other.minX - frame.width // 贴在 other 左边
    ]
    let verticalAlignments: [CGFloat] = [
      other.minY,                   // 顶边对齐
      other.maxY - frame.height,    // 底边对齐
      other.midY - frame.height / 2 // 居中对齐
    ]
    for snapX in horizontalOrigins {
      for snapY in verticalAlignments {
        result.append(Self.target(origin: NSPoint(x: snapX, y: snapY), for: frame))
      }
    }

    let verticalOrigins: [CGFloat] = [
      other.maxY,              // 贴在 other 上边
      other.minY - frame.height // 贴在 other 下边
    ]
    let horizontalAlignments: [CGFloat] = [
      other.minX,                  // 左边对齐
      other.maxX - frame.width,    // 右边对齐
      other.midX - frame.width / 2 // 居中对齐
    ]
    for snapY in verticalOrigins {
      for snapX in horizontalAlignments {
        result.append(Self.target(origin: NSPoint(x: snapX, y: snapY), for: frame))
      }
    }

    return result
  }

  private static func target(origin: NSPoint, for frame: NSRect) -> Target {
    // 取整：贴在半像素上会把圆环和文字拖模糊
    let rounded = NSPoint(x: round(origin.x), y: round(origin.y))
    let distance = abs(frame.origin.x - rounded.x) + abs(frame.origin.y - rounded.y)
    return Target(origin: rounded, distance: distance)
  }

  private static func visibleArea(of frame: NSRect, in visibleFrame: NSRect) -> CGFloat {
    guard frame.intersects(visibleFrame) else { return 0 }
    let intersection = frame.intersection(visibleFrame)
    return intersection.width * intersection.height
  }
}
