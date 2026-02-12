import AppKit
import SwiftUI

/// A view modifier that styles the hosting NSWindow to match the Rosé Pine theme.
/// Makes the titlebar transparent and sets the window background color.
struct RosePineWindowStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(WindowAccessor { window in
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.backgroundColor = RosePine.nsBase
        window.titleVisibility = .visible
        // Use full-size content view so sidebar + detail fill behind titlebar
        window.styleMask.insert(.fullSizeContentView)

        // Apply JetBrains Mono to the window title
        applyTitleFont(to: window)
      })
  }

  private func applyTitleFont(to window: NSWindow) {
    guard let titleFont = NSFont(name: "JetBrainsMonoNF-Medium", size: 13) else { return }
    // The title text field lives in the titlebar container view
    if let titlebarView = window.standardWindowButton(.closeButton)?.superview?.superview {
      applyFont(titleFont, in: titlebarView)
    }
  }

  private func applyFont(_ font: NSFont, in view: NSView) {
    if let textField = view as? NSTextField {
      textField.font = font
    }
    for subview in view.subviews {
      applyFont(font, in: subview)
    }
  }
}

extension View {
  func rosePineWindow() -> some View {
    modifier(RosePineWindowStyle())
  }
}

// MARK: - WindowAccessor

/// An NSViewRepresentable that finds and exposes the hosting NSWindow.
private struct WindowAccessor: NSViewRepresentable {
  let callback: (NSWindow?) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    // Defer to next run loop so the view is in the window hierarchy
    DispatchQueue.main.async {
      self.callback(view.window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      self.callback(nsView.window)
    }
  }
}
