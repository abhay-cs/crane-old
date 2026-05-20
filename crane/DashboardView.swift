//
//  DashboardView.swift
//  crane
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var drops: [Drop]

    init() {
        var descriptor = FetchDescriptor<Drop>(
            sortBy: [SortDescriptor(\Drop.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = Persistence.maxFetchedDrops
        _drops = Query(descriptor)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignMetrics.md) {
                header
                statCards
                activitySection
                TopTagsSection(drops: drops) { tag in
                    openOverlayHistory(search: tag)
                }
                recentSection
                footer
            }
            .padding(DesignMetrics.md)
        }
        .frame(width: 380, height: 520, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("MenuBarIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(CraneColor.accent)
                .accessibilityHidden(true)
            Text("crane")
                .font(CraneFont.display(18))
                .tracking(-0.2)
                .foregroundStyle(Color.craneInk)

            Spacer()

            Menu {
                Button("Open History") { openOverlayHistory(focusing: nil) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.craneInkTertiary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var statCards: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(drops.count)", label: "TOTAL")
            StatCard(value: "\(drops.todayCount)", label: "TODAY")
            StatCard(
                value: "\(drops.streakDays)d",
                label: "STREAK",
                subtitle: drops.hasDropToday ? nil : "last active day"
            )
        }
        .frame(height: 80)
    }

    private var activitySection: some View {
        let breakdown = drops.typeBreakdown
        return VStack(alignment: .leading, spacing: 8) {
            CraneSectionHeader(title: "Activity", trailing: "14 days")
            ActivityChart(points: drops.dailyCounts(days: 14))
                .frame(height: 56)
            TypeBreakdownBar(thoughts: breakdown.thoughts, links: breakdown.links)
                .frame(height: 6)
            HStack(spacing: 10) {
                LegendChip(color: Color.craneThought, label: "thoughts", count: breakdown.thoughts)
                LegendChip(color: Color.craneLink, label: "links", count: breakdown.links)
                Spacer()
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            CraneSectionHeader(
                title: "Recent",
                trailingActionTitle: drops.isEmpty ? nil : "Open all",
                trailingAction: drops.isEmpty ? nil : { openOverlayHistory(focusing: nil) }
            )
            let items = Array(drops.prefix(3))
            if items.isEmpty {
                EmptyStateView(
                    symbol: "tray",
                    message: "No drops yet. Capture a thought or link to see it here.",
                    primaryAction: { AppDelegate.shared?.showOverlay() }
                )
            } else {
                VStack(spacing: 2) {
                    ForEach(items) { drop in
                        DropRow(drop: drop, style: .compact, onDelete: { delete(drop) })
                            .contentShape(Rectangle())
                            .onTapGesture { openOverlayHistory(focusing: drop.id) }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            FooterButton(shortcut: "⌘⇧Space", label: "New Drop") {
                AppDelegate.shared?.showOverlay()
            }
            Spacer()
            FooterButton(shortcut: "⌘Q", label: "Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(.top, 4)
    }

    private func delete(_ drop: Drop) {
        withAnimation(.easeOut(duration: 0.15)) {
            modelContext.deleteDrop(drop)
        }
    }

    private func openOverlayHistory(focusing dropID: UUID? = nil, search: String? = nil) {
        AppDelegate.shared?.showOverlayHistory(focusing: dropID, search: search)
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(CraneFont.display(32))
                .foregroundStyle(Color.craneInk)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(CraneFont.ui(10, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(Color.craneInkTertiary)
            if let subtitle {
                Text(subtitle)
                    .font(CraneFont.ui(9, weight: .medium))
                    .foregroundStyle(Color.craneInkTertiary.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .craneCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let subtitle {
            return "\(label), \(value), \(subtitle)"
        }
        return "\(label), \(value)"
    }
}

private struct ActivityChart: View {
    let points: [(date: Date, count: Int)]

    var body: some View {
        Chart {
            ForEach(points, id: \.date) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Count", point.count)
                )
                .foregroundStyle(CraneColor.accent.opacity(0.85))
                .cornerRadius(2)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
    }
}

private struct TypeBreakdownBar: View {
    let thoughts: Int
    let links: Int

    private var total: CGFloat {
        let sum = CGFloat(thoughts + links)
        return sum == 0 ? 1 : sum
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                Capsule()
                    .fill(Color.craneThought.opacity(0.85))
                    .frame(width: proxy.size.width * (CGFloat(thoughts) / total))
                Capsule()
                    .fill(Color.craneLink.opacity(0.85))
                    .frame(width: max(0, proxy.size.width * (CGFloat(links) / total) - 2))
            }
        }
        .clipShape(Capsule())
        .background(Capsule().fill(Color.craneInk.opacity(0.06)))
    }
}

private struct LegendChip: View {
    let color: Color
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(CraneFont.ui(11))
                .foregroundStyle(Color.craneInkSecondary)
            Text("\(count)")
                .font(CraneFont.ui(11, weight: .semibold))
                .foregroundStyle(Color.craneInk)
        }
    }
}

private struct FooterButton: View {
    let shortcut: String
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(shortcut)
                    .font(CraneFont.mono(10, weight: .medium))
                    .foregroundStyle(Color.craneInkSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .craneInputRecess(cornerRadius: DesignMetrics.xs + 2)
                Text(label)
                    .font(CraneFont.ui(11))
                    .foregroundStyle(hovering ? Color.craneInk : Color.craneInkSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.craneSnappy, value: hovering)
    }
}

#Preview("Dashboard") {
    DashboardView()
        .modelContainer(for: Drop.self, inMemory: true)
}
