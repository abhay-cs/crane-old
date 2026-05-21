//
//  TopTagsSection.swift
//  crane
//

import SwiftUI

struct TopTagsSection: View {
    let topTags: [(tag: String, count: Int)]
    let hasAnyDrops: Bool
    let untaggedInSample: Int
    let onTagSelected: (String) -> Void

    private var queue: AIJobQueue { AIJobQueue.shared }

    private var availability: AIAvailability {
        FoundationModelsService.shared.tagAvailability
    }

    private var isTagging: Bool {
        if case .available = availability {
            return queue.isActive || untaggedInSample > 0
        }
        return false
    }

    var body: some View {
        if hasAnyDrops {
            VStack(alignment: .leading, spacing: 8) {
                CraneSectionHeader(
                    caps: "TOP TAGS",
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
                        .font(CraneFont.ui(14))
                        .foregroundStyle(Color.craneInkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct TagSkeletonRow: View {
    private let widths: [CGFloat] = [52, 44, 60, 48]
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                Capsule(style: .continuous)
                    .fill(Color.craneInk.opacity(pulsing ? 0.08 : 0.04))
                    .frame(width: width, height: 24)
            }
        }
        .accessibilityLabel("Tagging in progress")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

private struct AIUnavailableBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.craneInkTertiary)
                .padding(.top, 1)
            Text(message)
                .font(CraneFont.ui(14))
                .foregroundStyle(Color.craneInkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignMetrics.controlCornerRadius, style: .continuous)
                .fill(Color.craneInk.opacity(0.04))
        )
    }
}

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
