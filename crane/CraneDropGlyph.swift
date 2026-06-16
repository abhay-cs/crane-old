//
//  CraneDropGlyph.swift
//  crane
//
//  Drop-type icons aligned with landing demo: pencil / arrow.up.forward (lists),
//  pencil / link (capture).
//

import SwiftUI

enum CraneDropGlyphContext {
    case list
    case capture
}

struct CraneDropGlyph: View {
    let dropType: DropType
    var context: CraneDropGlyphContext = .list
    var size: CGFloat = 12

    private var symbolName: String {
        switch (dropType, context) {
        case (.thought, _):
            return "pencil"
        case (.link, .list):
            return "arrow.up.forward"
        case (.link, .capture):
            return "link"
        }
    }

    private var foregroundColor: Color {
        switch context {
        case .list:
            return dropType == .link ? CraneColor.link : CraneColor.thought
        case .capture:
            return dropType == .link ? CraneColor.link : CraneColor.thought
        }
    }

    var body: some View {
        Image(systemName: symbolName)
            .font(CraneFont.symbol(size, weight: .medium))
            .foregroundStyle(foregroundColor)
            .frame(
                width: context == .capture ? 22 : DesignMetrics.iconColumnWidth,
                alignment: .center
            )
    }
}
