//
//  DropRow.swift
//  crane
//
//  Single-row presentation of a Drop. Shared by `HistoryView` (full list)
//  and `DashboardView` (recent drops). Lives at top level so both can
//  consume it without making it `internal` to a single file.
//

import SwiftUI

struct DropRow: View {
    let drop: Drop
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var confirmDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: drop.dropType == .link ? "link" : "square.and.pencil")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 14)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                textBody
                HStack(spacing: 6) {
                    Text(relativeTime(drop.timestamp))
                    if let app = drop.sourceApp, !app.isEmpty {
                        Text("·")
                        Text(app)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                confirmDelete = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
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
        .padding(.vertical, 8)
        .background {
            // Accent-tinted Liquid Glass when hovered; nothing otherwise.
            // Gives the row a gentle, lit feel rather than the flat
            // quaternary fill it used before.
            if hovering {
                Color.clear
                    .glassEffect(
                        .regular.tint(Color.accentColor.opacity(0.08)),
                        in: .rect(cornerRadius: 8, style: .continuous)
                    )
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.craneSnappy, value: hovering)
    }

    @ViewBuilder
    private var textBody: some View {
        if drop.dropType == .link, let url = Drop.linkURL(for: drop.text) {
            Link(drop.text, destination: url)
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
                .lineLimit(3)
                .truncationMode(.tail)
        } else {
            Text(drop.text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(4)
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
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
