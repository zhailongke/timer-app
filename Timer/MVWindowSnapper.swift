import AppKit

/// 窗口拼接的几何计算：算出被拖动的窗口该贴到哪儿。
///
/// 只是把两个窗口贴在一起（缝归零、不重叠、对齐），不合并、也不记组关系——
/// 拖近就拼、拖走就散，所以这里没有状态，每次都只看当前这一帧的位置。
enum MVWindowSnapper {
  /// 离目标位置多近才算「想拼上」（横向 + 纵向的曼哈顿距离，单位点）
  static let snapDistance: CGFloat = 16

  struct Target {
    let origin: NSPoint
    let distance: CGFloat
  }

  /// 最合适的拼接位置；够不上就返回 nil，保持拖动原样
  /// - Parameters:
  ///   - frame: 被拖动窗口当前的位置（系统按鼠标算出来的那个，不是上一次吸附的结果）
  ///   - others: 参与拼接的其它窗口位置
  ///   - visibleFrame: 窗口所在屏幕的可见区域，防止把窗口吸出屏幕
  static func snapTarget(for frame: NSRect, among others: [NSRect], visibleFrame: NSRect?) -> NSPoint? {
    var candidates: [Target] = []

    for other in others {
      for target in Self.candidates(attaching: frame, to: other) {
        guard target.distance <= Self.snapDistance else { continue }

        let snapped = NSRect(origin: target.origin, size: frame.size)
        // 拼上去不能压住别的窗口
        guard !others.contains(where: { $0.intersects(snapped) }) else { continue }
        // 也不能把窗口吸出屏幕：拼接后露出来的面积不能比现在少
        if let visibleFrame {
          let before = Self.visibleArea(of: frame, in: visibleFrame)
          let after = Self.visibleArea(of: snapped, in: visibleFrame)
          guard after >= before - 0.5 else { continue }
        }

        candidates.append(target)
      }
    }

    return candidates.min { $0.distance < $1.distance }?.origin
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
