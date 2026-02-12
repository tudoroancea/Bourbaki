import CoreText
import SwiftUI

enum JetBrainsMono {
  /// Register all bundled JetBrains Mono fonts. Call once at app launch.
  static func registerFonts() {
    let fontNames = [
      "JetBrainsMonoNerdFont-Regular",
      "JetBrainsMonoNerdFont-Medium",
      "JetBrainsMonoNerdFont-SemiBold",
      "JetBrainsMonoNerdFont-Bold",
      "JetBrainsMonoNerdFont-ExtraBold",
      "JetBrainsMonoNerdFont-Light",
    ]
    for name in fontNames {
      guard let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
      else {
        continue
      }
      var error: Unmanaged<CFError>?
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    }
  }
}

extension Font {
  /// JetBrains Mono Nerd Font with the given size and weight.
  static func jetBrainsMono(size: CGFloat, weight: Weight = .regular) -> Font {
    let suffix: String
    switch weight {
    case .ultraLight, .thin, .light:
      suffix = "Light"
    case .regular:
      suffix = "Regular"
    case .medium:
      suffix = "Medium"
    case .semibold:
      suffix = "SemiBold"
    case .bold:
      suffix = "Bold"
    case .heavy, .black:
      suffix = "ExtraBold"
    default:
      suffix = "Regular"
    }
    return .custom("JetBrainsMonoNF-\(suffix)", size: size)
  }
}
