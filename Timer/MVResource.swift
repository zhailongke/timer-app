import AppKit

/// 资源访问层：优先从 asset catalog 取（Xcode 构建），
/// 取不到时回退到 bundle 里的散装 PNG / mvcolors.json（Script/build.sh 构建）。
enum MVResource {
  private struct ColorEntry: Decodable, Sendable {
    let space: String?
    let light: [Double]
    let dark: [Double]

    func resolve(_ appearance: NSAppearance) -> NSColor {
      let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      return self.color(isDark ? self.dark : self.light)
    }

    private func color(_ components: [Double]) -> NSColor {
      guard components.count == 4 else { return .labelColor }
      let (red, green, blue, alpha) = (components[0], components[1], components[2], components[3])
      if self.space == "display-p3" {
        return NSColor(displayP3Red: red, green: green, blue: blue, alpha: alpha)
      }
      return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
  }

  private static let colorTable: [String: ColorEntry] = {
    guard let url = Bundle.main.url(forResource: "mvcolors", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let table = try? JSONDecoder().decode([String: ColorEntry].self, from: data)
    else {
      return [:]
    }
    return table
  }()

  /// 图片名使用 asset catalog 里的名字，例如 "clock-unfocus"、"icon-pause"
  static func image(_ name: String) -> NSImage {
    guard let image = NSImage(named: NSImage.Name(name)) else {
      NSLog("MVResource: image not found %@", name)
      return NSImage()
    }
    return image
  }

  /// 颜色名使用 Xcode 生成的符号名（camelCase），例如 "timerTime"、"backgroundTop"
  static func color(_ name: String) -> NSColor {
    let hyphenated = Self.hyphenated(name)
    for candidate in [name, hyphenated, hyphenated + "-color"] {
      if let color = NSColor(named: NSColor.Name(candidate)) {
        return color
      }
    }

    guard let entry = Self.colorTable[name] ?? Self.colorTable[hyphenated] else {
      NSLog("MVResource: color not found %@", name)
      return .labelColor
    }
    return NSColor(name: NSColor.Name(name)) { appearance in
      entry.resolve(appearance)
    }
  }

  private static func hyphenated(_ name: String) -> String {
    var result = ""
    for character in name {
      if character.isUppercase {
        result += "-" + character.lowercased()
      } else {
        result.append(character)
      }
    }
    return result
  }
}
