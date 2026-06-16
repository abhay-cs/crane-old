//
//  CraneGlassHost.swift
//  crane
//
//  AppKit Liquid Glass hosting for the floating overlay panel.
//

import AppKit

enum CraneGlassHost {

    private static let containerIdentifier = NSUserInterfaceItemIdentifier("crane.glass.container")

    /// Wrap `contentView` in a clear container with an inset `NSGlassEffectView`.
    @discardableResult
    static func wrap(
        contentView: NSView,
        containerSize: NSSize,
        margin: CGFloat = DesignMetrics.glassShadowMargin
    ) -> NSView {
        prepareHost(contentView)

        let glass = makeGlass(contentView: contentView)
        let container = makeContainer(size: containerSize, margin: margin, glass: glass)
        container.identifier = containerIdentifier
        return container
    }

    // MARK: - Private

    private static func prepareHost(_ host: NSView) {
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.layer?.isOpaque = false
        host.layer?.shadowOpacity = 0
        host.layer?.shadowRadius = 0
        host.layer?.shadowOffset = .zero
    }

    private static func makeGlass(contentView: NSView) -> NSGlassEffectView {
        let glass = NSGlassEffectView()
        // AppKit exposes `.regular` / `.clear` only; SwiftUI `.interactive()` is
        // unavailable here — overlay depth comes from NSGlassEffectView + specular border.
        glass.style = .regular
        glass.cornerRadius = DesignMetrics.surfaceCornerRadius
        glass.clipsToBounds = true
        glass.contentView = contentView
        return glass
    }

    private static func makeContainer(
        size: NSSize,
        margin: CGFloat,
        glass: NSGlassEffectView
    ) -> NSView {
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.autoresizesSubviews = true
        glass.frame = container.bounds.insetBy(dx: margin, dy: margin)
        glass.autoresizingMask = [.width, .height]
        container.addSubview(glass)
        return container
    }

}
