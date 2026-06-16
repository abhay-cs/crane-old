//
//  DropRow.swift
//  crane
//

import SwiftUI

struct DropRow: View {
    enum Style {
        case standard
        case compact
    }

    let drop: Drop
    var style: Style = .standard
    /// Menu-bar dashboard: inline confirm avoids SwiftUI alerts closing `MenuBarExtra`.
    var inlineDeleteConfirmation: Bool = false
    var isEmphasized: Bool = false
    var onActivate: (() -> Void)? = nil
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var deleteHovering = false
    @State private var deleteWarningHovering = false
    @State private var confirmDelete = false
    @State private var pendingInlineDelete = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var bodyLineLimit: Int { style == .compact ? 2 : 4 }
    private var verticalPadding: CGFloat { style == .compact ? 8 : 10 }
    /// Dashboard scroll provides `dashboardContentInset`; overlay rows carry their own inset.
    private var horizontalPadding: CGFloat {
        style == .compact ? 0 : DesignMetrics.overlayContentInset
    }

    private var rowActionsVisible: Bool {
        hovering || isFocused || pendingInlineDelete || deleteHovering
    }

    var body: some View {
        Group {
            if pendingInlineDelete && inlineDeleteConfirmation {
                inlineDeleteRow
            } else {
                normalRow
            }
        }
        .animation(.craneSnappy, value: pendingInlineDelete)
    }

    private var normalRow: some View {
        HStack(alignment: .top, spacing: 10) {
            activateButton
            rowTrailingActions
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .craneRowHighlight(
            isHighlighted: hovering && !pendingInlineDelete && !isEmphasized,
            isEmphasized: isEmphasized && !pendingInlineDelete
        )
        .focusable(style == .standard)
        .focused($isFocused)
        .onHover { hovering = $0 }
        .animation(.craneSnappy, value: hovering)
        .animation(.craneSnappy, value: isEmphasized)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint(onActivate != nil ? "Opens in history" : "")
        .alert("Delete this drop?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can’t be undone.")
        }
    }

    private var rowTrailingActions: some View {
        HStack(spacing: 2) {
            if onActivate != nil {
                Image(systemName: "chevron.right")
                    .font(CraneFont.symbol(10, weight: .semibold))
                    .foregroundStyle(Color.craneInkSecondary)
                    .frame(width: DesignMetrics.navigateColumnWidth, height: 28)
                    .opacity(rowActionsVisible ? 0.55 : 0)
                    .accessibilityHidden(true)
            }
            deleteButton
        }
        .frame(
            width: onActivate != nil
                ? DesignMetrics.navigateColumnWidth + DesignMetrics.actionColumnWidth
                : DesignMetrics.actionColumnWidth,
            alignment: .trailing
        )
        .opacity(rowActionsVisible ? 1 : 0)
        .animation(.craneSnappy, value: rowActionsVisible)
    }

    @ViewBuilder
    private var activateButton: some View {
        let content = HStack(alignment: .firstTextBaseline, spacing: 10) {
            CraneDropGlyph(dropType: drop.dropType, context: .list, size: 12)
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    dimensions[VerticalAlignment.center]
                }

            VStack(alignment: .leading, spacing: 2) {
                textBody
                tagsRow
                metaRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        if let onActivate {
            Button(action: onActivate) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private var tagsRow: some View {
        if !drop.tags.isEmpty {
            HStack(spacing: 4) {
                ForEach(drop.tags.prefix(3), id: \.self) { tag in
                    TagChip(label: tag, style: .compact)
                }
            }
            .padding(.top, 2)
        } else if drop.aiTaggingFailed {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(CraneFont.symbol(12, weight: .medium))
                Text("Tags unavailable")
                    .font(CraneFont.ui(12, weight: .medium))
            }
            .foregroundStyle(Color.craneInkTertiary)
            .padding(.top, 2)
            .accessibilityLabel("Automatic tags could not be generated")
        }
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(relativeTime(drop.timestamp))
                .monospacedDigit()
            if let app = drop.sourceApp, !app.isEmpty {
                Text("·")
                Text(app)
            }
        }
        .craneText(.meta)
        .lineLimit(1)
    }

    private var deleteButton: some View {
        Button {
            requestDeleteConfirmation()
        } label: {
            Image(systemName: "xmark")
                .font(CraneFont.symbol(11, weight: .medium))
                .foregroundStyle(Color.craneInkTertiary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .overlay {
                    RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                        .strokeBorder(CraneColor.focusLine(for: colorScheme), lineWidth: deleteHovering ? 0.5 : 0)
                }
        }
        .buttonStyle(.plain)
        .opacity(rowDeleteOpacity)
        .allowsHitTesting(rowDeleteOpacity > 0)
        .onHover { deleteHovering = $0 }
        .animation(.craneSnappy, value: deleteHovering)
        .animation(.craneSnappy, value: rowDeleteOpacity)
        .help("Delete drop")
        .accessibilityLabel("Delete drop")
    }

    private var rowDeleteOpacity: Double {
        rowActionsVisible ? 1 : 0
    }

    private var inlineDeleteRow: some View {
        HStack(spacing: 10) {
            Text("Delete this drop?")
                .font(CraneFont.ui(14, weight: .medium))
                .foregroundStyle(Color.craneInkSecondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            CraneSecondaryButton {
                pendingInlineDelete = false
            } label: {
                Text("Cancel")
            }

            Button("Delete", role: .destructive) {
                pendingInlineDelete = false
                onDelete()
            }
            .buttonStyle(.plain)
            .font(CraneFont.ui(13, weight: .semibold))
            .foregroundStyle(Color.craneWarning)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if deleteWarningHovering {
                    RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                        .fill(Color.craneWarning.opacity(0.12))
                }
            }
            .onHover { deleteWarningHovering = $0 }
            .animation(.craneSnappy, value: deleteWarningHovering)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .craneRowHighlight(isHighlighted: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Confirm delete drop")
    }

    private func requestDeleteConfirmation() {
        if inlineDeleteConfirmation {
            pendingInlineDelete = true
        } else {
            confirmDelete = true
        }
    }

    @ViewBuilder
    private var textBody: some View {
        if drop.dropType == .link, let url = Drop.linkURL(for: drop.text) {
            Link(drop.text, destination: url)
                .craneText(entryTextStyle)
                .foregroundStyle(CraneColor.link)
                .underline(true, color: CraneColor.linkLine(for: colorScheme))
                .lineLimit(bodyLineLimit)
                .truncationMode(.tail)
        } else if drop.dropType == .link {
            Text(drop.text)
                .craneText(entryTextStyle)
                .foregroundStyle(CraneColor.link)
                .underline(true, color: CraneColor.linkLine(for: colorScheme))
                .lineLimit(bodyLineLimit)
                .truncationMode(.tail)
        } else {
            Text(drop.text)
                .craneText(entryTextStyle)
                .textSelection(.enabled)
                .lineLimit(bodyLineLimit)
                .truncationMode(.tail)
        }
    }

    /// Serif for journal entries on the dashboard; sans elsewhere.
    private var entryTextStyle: CraneTextStyle {
        style == .compact ? .journalBody : .body
    }

    private var rowAccessibilityLabel: String {
        let kind = drop.dropType == .link ? "Link" : "Thought"
        let time = relativeTime(drop.timestamp)
        if let app = drop.sourceApp, !app.isEmpty {
            return "\(kind), \(drop.text), \(time), from \(app)"
        }
        return "\(kind), \(drop.text), \(time)"
    }

    private func relativeTime(_ date: Date) -> String {
        let now = Date()
        let secs = Int(now.timeIntervalSince(date))
        if secs < 60 { return "just now" }
        let mins = secs / 60
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 7 { return "\(days)d ago" }
        return Self.mediumDateFormatter.string(from: date)
    }
}
