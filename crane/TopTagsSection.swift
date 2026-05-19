//
//  TopTagsSection.swift
//  crane
//
//  Dashboard slot for FM-extracted tag chips and availability messaging.
//

import SwiftUI

struct TopTagsSection: View {
    let drops: [Drop]
    let onTagSelected: (String) -> Void

    private var queue: AIJobQueue { AIJobQueue.shared }

    private var availability: AIAvailability {
        FoundationModelsService.shared.tagAvailability
    }

    private var topTags: [(tag: String, count: Int)] {
        drops.topTags(limit: 8)
    }

    private var isTagging: Bool {
        queue.isActive || drops.untaggedCount > 0
    }

    var body: some View {
        if !drops.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(
                    "Top Tags",
                    trailing: isTagging && topTags.isEmpty ? "Tagging…" : nil
                )

                if !topTags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(topTags, id: \.tag) { item in
                            TagChip(label: item.tag, style: .dashboard) {
                                onTagSelected(item.tag)
                            }
                        }
                    }
                } else if case .unavailable(let message) = availability {
                    AIUnavailableBanner(message: message)
                } else if isTagging {
                    TagSkeletonRow()
                } else {
                    Text("Tags appear on your thoughts after capture.")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, trailing: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Skeleton chips

private struct TagSkeletonRow: View {
    private let widths: [CGFloat] = [52, 44, 60, 48]

    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(pulsing ? 0.08 : 0.04))
                    .frame(width: width, height: 24)
            }
        }
        .accessibilityLabel("Tagging in progress")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Unavailable banner

private struct AIUnavailableBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 1)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

// MARK: - Flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
