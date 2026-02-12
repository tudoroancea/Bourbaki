import AppKit
import SwiftUI

/// Rosé Pine color palette for app chrome.
/// Automatically switches between Rosé Pine (dark) and Rosé Pine Dawn (light)
/// based on the system color scheme.
/// Reference: https://rosepinetheme.com/palette
enum RosePine {
  // MARK: - Dark variant (Rosé Pine)

  enum Dark {
    static let base = Color(hex: "#191724")
    static let surface = Color(hex: "#1f1d2e")
    static let overlay = Color(hex: "#26233a")
    static let muted = Color(hex: "#6e6a86")
    static let subtle = Color(hex: "#908caa")
    static let text = Color(hex: "#e0def4")
    static let highlightLow = Color(hex: "#21202e")
    static let highlightMed = Color(hex: "#403d52")
    static let highlightHigh = Color(hex: "#524f67")
    static let love = Color(hex: "#eb6f92")
    static let gold = Color(hex: "#f6c177")
    static let rose = Color(hex: "#ebbcba")
    static let pine = Color(hex: "#31748f")
    static let foam = Color(hex: "#9ccfd8")
    static let iris = Color(hex: "#c4a7e7")
  }

  // MARK: - Light variant (Rosé Pine Dawn)

  enum Dawn {
    static let base = Color(hex: "#faf4ed")
    static let surface = Color(hex: "#fffaf3")
    static let overlay = Color(hex: "#f2e9e1")
    static let muted = Color(hex: "#9893a5")
    static let subtle = Color(hex: "#797593")
    static let text = Color(hex: "#575279")
    static let highlightLow = Color(hex: "#f4ede8")
    static let highlightMed = Color(hex: "#dfdad9")
    static let highlightHigh = Color(hex: "#cecacd")
    static let love = Color(hex: "#b4637a")
    static let gold = Color(hex: "#ea9d34")
    static let rose = Color(hex: "#d7827e")
    static let pine = Color(hex: "#286983")
    static let foam = Color(hex: "#56949f")
    static let iris = Color(hex: "#907aa9")
  }

  // MARK: - Adaptive colors (switch on colorScheme)

  /// Main background
  static let base = adaptive(dark: Dark.base, light: Dawn.base)
  /// Raised surface (sidebar, tab bar)
  static let surface = adaptive(dark: Dark.surface, light: Dawn.surface)
  /// Overlay panels (context menus, popovers)
  static let overlay = adaptive(dark: Dark.overlay, light: Dawn.overlay)
  /// Muted foreground (disabled, placeholders)
  static let muted = adaptive(dark: Dark.muted, light: Dawn.muted)
  /// Subtle foreground (secondary text)
  static let subtle = adaptive(dark: Dark.subtle, light: Dawn.subtle)
  /// Primary text
  static let text = adaptive(dark: Dark.text, light: Dawn.text)

  /// Low-emphasis highlight (selected row background)
  static let highlightLow = adaptive(dark: Dark.highlightLow, light: Dawn.highlightLow)
  /// Medium-emphasis highlight (hover)
  static let highlightMed = adaptive(dark: Dark.highlightMed, light: Dawn.highlightMed)
  /// High-emphasis highlight (active selection)
  static let highlightHigh = adaptive(dark: Dark.highlightHigh, light: Dawn.highlightHigh)

  /// Red — errors, destructive
  static let love = adaptive(dark: Dark.love, light: Dawn.love)
  /// Yellow/amber — warnings, idle status
  static let gold = adaptive(dark: Dark.gold, light: Dawn.gold)
  /// Pink — primary accent
  static let rose = adaptive(dark: Dark.rose, light: Dawn.rose)
  /// Teal/blue — info, active status
  static let pine = adaptive(dark: Dark.pine, light: Dawn.pine)
  /// Cyan — links, added lines, notification badges
  static let foam = adaptive(dark: Dark.foam, light: Dawn.foam)
  /// Purple — highlight, selection accent
  static let iris = adaptive(dark: Dark.iris, light: Dawn.iris)

  // MARK: - Semantic Aliases

  static let statusRunning = foam
  static let statusIdle = gold
  static let statusTerminal = subtle
  static let statusStopped = muted

  static let diffAdded = foam
  static let diffRemoved = love

  static let notificationBadge = iris

  static let tabSelected = highlightMed
  static let tabHover = highlightLow

  static let sidebarSelected = adaptive(
    dark: Dark.iris.opacity(0.2),
    light: Dawn.iris.opacity(0.2)
  )

  static let separator = highlightHigh

  // MARK: - NSColor variants (for window chrome)

  /// NSColor for the window/titlebar background
  static let nsBase = NSColor(name: nil) { appearance in
    appearance.isDark
      ? NSColor(red: 0x19/255.0, green: 0x17/255.0, blue: 0x24/255.0, alpha: 1)
      : NSColor(red: 0xfa/255.0, green: 0xf4/255.0, blue: 0xed/255.0, alpha: 1)
  }

  static let nsSurface = NSColor(name: nil) { appearance in
    appearance.isDark
      ? NSColor(red: 0x1f/255.0, green: 0x1d/255.0, blue: 0x2e/255.0, alpha: 1)
      : NSColor(red: 0xff/255.0, green: 0xfa/255.0, blue: 0xf3/255.0, alpha: 1)
  }

  // MARK: - Helpers

  private static func adaptive(dark: Color, light: Color) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      appearance.isDark ? NSColor(dark) : NSColor(light)
    })
  }
}

// MARK: - NSAppearance helper

extension NSAppearance {
  var isDark: Bool {
    bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
  }
}

// MARK: - Color hex initializer

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    let scanner = Scanner(string: hex)
    var rgb: UInt64 = 0
    scanner.scanHexInt64(&rgb)

    let r = Double((rgb >> 16) & 0xFF) / 255.0
    let g = Double((rgb >> 8) & 0xFF) / 255.0
    let b = Double(rgb & 0xFF) / 255.0

    self.init(red: r, green: g, blue: b)
  }
}
