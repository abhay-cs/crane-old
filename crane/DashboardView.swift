//
//  DashboardView.swift
//  crane
//
//  The menu-bar popover. Shows at-a-glance stats (total, today, streak),
//  a 14-day activity sparkline, a thoughts-vs-links breakdown, and the
//  most recent drops. Footer carries the keyboard shortcuts that used
//  to live in the system menu.
//
//  Hosted via `MenuBarExtra(.window)` in craneApp.swift. Macos already
//  renders that popover with vibrancy, so this view doesn't need its
//  own outer glass surface — only the inner cards do.
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    // Single source of truth for every panel on this view. `@Query`
    // re-renders the whole dashboard whenever a write happens anywhere
    // (capture pill submits, history deletes), so totals, streaks, the
    // sparkline, and the recent list stay in lockstep automatically.
    @Query(sort: \Drop.timestamp, order: .reverse)
    private var drops: [Drop]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            statCards

            activitySection

            TopTagsSection(drops: drops) { tag in
                openOverlayHistory(search: tag)
            }

            recentSection

            Spacer(minLength: 0)

            footer
        }
        .padding(16)
        .frame(width: 360, height: 480, alignment: .topLeading)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("Crane")
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.2)

            Spacer()

            Menu {
                Button("Open History") { openOverlayHistory(focusing: nil) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    // MARK: Stat cards

    private var statCards: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(drops.count)",       label: "TOTAL")
            StatCard(value: "\(drops.todayCount)",  label: "TODAY")
            StatCard(value: "\(drops.streakDays)d", label: "STREAK")
        }
        .frame(height: 76)
    }

    // MARK: Activity

    private var activitySection: some View {
        let breakdown = drops.typeBreakdown
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Activity", trailing: "14 days")
            ActivityChart(points: drops.dailyCounts(days: 14))
                .frame(height: 56)
            TypeBreakdownBar(thoughts: breakdown.thoughts, links: breakdown.links)
                .frame(height: 6)
            HStack(spacing: 10) {
                LegendChip(color: Color.accentColor,
                           label: "thoughts",
                           count: breakdown.thoughts)
                LegendChip(color: Color.secondary,
                           label: "links",
                           count: breakdown.links)
                Spacer()
            }
        }
    }

    // MARK: Recent

    private var recentSection: some View {
        // `drops` is already newest-first thanks to `@Query(sort:order:)`,
        // so taking the prefix gives the same result the old
        // `store.recent(3)` did.
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Recent")
            let items = Array(drops.prefix(3))
            if items.isEmpty {
                EmptyStateView(
                    message: "No drops yet. Capture a thought or link to see it here.",
                    primaryAction: { AppDelegate.shared?.showOverlay() }
                )
            } else {
                VStack(spacing: 2) {
                    ForEach(items) { drop in
                        DropRow(drop: drop, onDelete: { delete(drop) })
                            .contentShape(Rectangle())
                            .onTapGesture { openOverlayHistory(focusing: drop.id) }
                    }
                }
            }
        }
    }

    private func delete(_ drop: Drop) {
        withAnimation(.easeOut(duration: 0.15)) {
            modelContext.delete(drop)
            do {
                try modelContext.save()
            } catch {
                CraneAlert.presentSaveFailed(error)
            }
        }
    }

    // MARK: Footer

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
    }

    // MARK: Helpers

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

    private func openOverlayHistory(focusing dropID: UUID? = nil, search: String? = nil) {
        AppDelegate.shared?.showOverlayHistory(focusing: dropID, search: search)
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.06))
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                }
        }
        .specularBorder(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

// MARK: - ActivityChart

private struct ActivityChart: View {
    let points: [(date: Date, count: Int)]

    var body: some View {
        Chart {
            ForEach(points, id: \.date) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Count", point.count)
                )
                .foregroundStyle(Color.accentColor.opacity(0.85))
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

// MARK: - TypeBreakdownBar

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
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: proxy.size.width * (CGFloat(thoughts) / total))
                Capsule()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: max(0, proxy.size.width * (CGFloat(links) / total) - 2))
            }
        }
        .clipShape(Capsule())
        .background(Capsule().fill(.quaternary.opacity(0.4)))
    }
}

// MARK: - LegendChip

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
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - FooterButton

private struct FooterButton: View {
    let shortcut: String
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        .quaternary.opacity(0.6),
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(hovering ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.craneSnappy, value: hovering)
    }
}

// MARK: - Preview

#Preview("Dashboard") {
    DashboardView()
        .modelContainer(for: Drop.self, inMemory: true)
}
