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
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var confirmDelete = false
    @FocusState private var isFocused: Bool

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var bodyLineLimit: Int { style == .compact ? 2 : 4 }
    private var verticalPadding: CGFloat { style == .compact ? 6 : 10 }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: drop.dropType == .link ? "link" : "square.and.pencil")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(drop.dropType == .link ? Color.craneLink : Color.craneThought)
                .frame(width: 14)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                textBody
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
                            .font(.system(size: 10, weight: .medium))
                        Text("Tags unavailable")
                            .font(CraneFont.ui(10, weight: .medium))
                    }
                    .foregroundStyle(Color.craneInkTertiary)
                    .padding(.top, 2)
                    .accessibilityLabel("Automatic tags could not be generated")
                }
                HStack(spacing: 6) {
                    Text(relativeTime(drop.timestamp))
                    if let app = drop.sourceApp, !app.isEmpty {
                        Text("·")
                        Text(app)
                    }
                }
                .font(CraneFont.ui(12))
                .foregroundStyle(Color.craneInkTertiary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                confirmDelete = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.craneInkTertiary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hovering || isFocused ? 1 : 0.45)
            .help("Delete drop")
            .accessibilityLabel("Delete drop")
            .confirmationDialog(
                "Delete this drop?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: onDelete)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can’t be undone.")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, verticalPadding)
        .craneRowHighlight(isHighlighted: hovering)
        .contentShape(Rectangle())
        .focusable()
        .focused($isFocused)
        .onHover { hovering = $0 }
        .animation(.craneSnappy, value: hovering)
    }

    @ViewBuilder
    private var textBody: some View {
        if drop.dropType == .link, let url = Drop.linkURL(for: drop.text) {
            Link(drop.text, destination: url)
                .font(CraneFont.ui(13))
                .foregroundStyle(Color.craneLink)
                .lineLimit(bodyLineLimit)
                .truncationMode(.tail)
        } else {
            Text(drop.text)
                .font(CraneFont.ui(13))
                .foregroundStyle(Color.craneInk)
                .textSelection(.enabled)
                .lineLimit(bodyLineLimit)
                .truncationMode(.tail)
        }
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
