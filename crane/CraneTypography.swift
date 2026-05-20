//
//  CraneTypography.swift
//  crane
//
//  Instrument Serif (display) + Geist (UI) + Geist Mono (shortcuts).
//

import SwiftUI

enum CraneFontName {
    static let displayRegular = "InstrumentSerif-Regular"
    static let displayItalic = "InstrumentSerif-Italic"
    static let uiRegular = "Geist-Regular"
    static let uiMedium = "Geist-Medium"
    static let uiSemibold = "Geist-SemiBold"
    static let monoRegular = "GeistMono-Regular"
    static let monoMedium = "GeistMono-Medium"
}

enum CraneFont {
    static func display(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? CraneFontName.displayItalic : CraneFontName.displayRegular, size: size)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy, .black:
            name = CraneFontName.uiSemibold
        case .medium:
            name = CraneFontName.uiMedium
        default:
            name = CraneFontName.uiRegular
        }
        return .custom(name, size: size)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = weight == .medium ? CraneFontName.monoMedium : CraneFontName.monoRegular
        return .custom(name, size: size)
    }
}

enum CraneTextStyle {
    case capture
    case title
    case section
    case body
    case meta
    case caps

    var font: Font {
        switch self {
        case .capture: CraneFont.display(26)
        case .title: CraneFont.display(20)
        case .section: CraneFont.ui(11, weight: .semibold)
        case .body: CraneFont.ui(13)
        case .meta: CraneFont.ui(12)
        case .caps: CraneFont.ui(10, weight: .medium)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .capture, .title: -0.2
        case .section: 0.4
        case .caps: 0.6
        default: 0
        }
    }

    var foreground: Color {
        switch self {
        case .capture, .body: .craneInk
        case .title, .section: .craneInkSecondary
        case .meta, .caps: .craneInkTertiary
        }
    }
}

struct CraneTextModifier: ViewModifier {
    let style: CraneTextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(style.foreground)
    }
}

extension View {
    func craneText(_ style: CraneTextStyle) -> some View {
        modifier(CraneTextModifier(style: style))
    }
}
