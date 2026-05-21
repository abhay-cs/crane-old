//
//  DashboardView.swift
//  crane
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    /// Newest drops for recent list and row actions (capped).
    @Query private var recentDrops: [Drop]

    @State private var stats: DropStatistics = .empty
    @State private var headerHovering = false

    init() {
        var descriptor = FetchDescriptor<Drop>(
            sortBy: [SortDescriptor(\Drop.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = Persistence.maxFetchedDrops
        _recentDrops = Query(descriptor)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DesignMetrics.dashboardSectionSpacing) {
                    header
                    statCards
                    activitySection
                    TopTagsSection(
                        topTags: stats.topTags,
                        hasAnyDrops: stats.totalCount > 0,
                        untaggedInSample: recentDrops.untaggedCount
                    ) { tag in
                        openOverlayHistory(search: tag)
                    }
                    recentSection
                }
                .padding(DesignMetrics.md)
            }
            .frame(height: DesignMetrics.dashboardScrollHeight)

            footer
        }
        .frame(
            width: DesignMetrics.dashboardWidth,
            height: DesignMetrics.dashboardHeight,
            alignment: .topLeading
        )
        .fixedSize(horizontal: true, vertical: true)
        .clipped()
        .craneDashboardBackground()
        .onAppear(perform: refreshStatistics)
        .onChange(of: recentDrops.count) { _, _ in refreshStatistics() }
    }

    // MARK: - Data

    private func refreshStatistics() {
        stats = DropStatistics.compute(in: modelContext)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignMetrics.sm) {
            Image("MenuBarIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(CraneColor.accent)
                .shadow(
                    color: headerHovering ? CraneColor.accentGlow(for: colorScheme) : .clear,
                    radius: headerHovering ? 8 : 0,
                    y: 1
                )
                .accessibilityHidden(true)

            Text("crane")
                .font(CraneFont.display(18))
                .tracking(-0.2)
                .foregroundStyle(Color.craneInk)

            Spacer()

            CraneIconButton(
                systemName: "clock",
                help: "Open history",
                accessibilityLabel: "Open history"
            ) {
                openOverlayHistory(focusing: nil)
            }
        }
        .onHover { headerHovering = $0 }
        .animation(.craneSnappy, value: headerHovering)
    }

    // MARK: - Stat cards

    private var statCards: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(stats.totalCount)", label: "TOTAL")
            StatCard(
                value: "\(stats.todayCount)",
                label: "TODAY",
                usesAccent: stats.todayCount > 0
            )
            StatCard(
                value: "\(stats.streakDays)d",
                label: "STREAK",
                subtitle: stats.hasDropToday ? nil : "last active day",
                usesAccent: stats.streakDays >= 3
            )
        }
        .frame(height: 84)
    }

    // MARK: - Activity

    private var activitySection: some View {
        let breakdown = stats.typeBreakdown
        let hasTypeData = breakdown.thoughts + breakdown.links > 0
        let hasActivityData = stats.totalCount > 0
            && stats.dailyCounts.contains { $0.count > 0 }

        return VStack(alignment: .leading, spacing: DesignMetrics.sm) {
            CraneSectionHeader(caps: "Activity", capsEmphasis: .neutral, trailing: "14 days")

            Group {
                if hasActivityData {
                    ActivityChart(points: stats.dailyCounts)
                } else {
                    ActivityEmptyState {
                        DispatchQueue.main.async {
                            AppDelegate.shared?.showOverlay()
                        }
                    }
                }
            }
            .frame(height: 72)

            typeBreakdownSlot(hasTypeData: hasTypeData, breakdown: breakdown)
        }
    }

    @ViewBuilder
    private func typeBreakdownSlot(
        hasTypeData: Bool,
        breakdown: (thoughts: Int, links: Int)
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if hasTypeData {
                TypeBreakdownBar(thoughts: breakdown.thoughts, links: breakdown.links)
                    .frame(height: 6)
                HStack(spacing: 10) {
                    LegendChip(
                        color: CraneColor.accent.opacity(0.85),
                        label: "thoughts",
                        count: breakdown.thoughts
                    )
                    LegendChip(
                        color: CraneColor.accent.opacity(0.45),
                        label: "links",
                        count: breakdown.links
                    )
                    Spacer()
                }
            }
        }
        .frame(height: 28, alignment: .topLeading)
        .opacity(hasTypeData ? 1 : 0)
        .accessibilityHidden(!hasTypeData)
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: DesignMetrics.xs) {
            CraneSectionHeader(
                caps: "Recent",
                capsEmphasis: .accent,
                trailingActionTitle: recentDrops.isEmpty ? nil : "Open all",
                trailingAction: recentDrops.isEmpty ? nil : { openOverlayHistory(focusing: nil) }
            )

            let items = Array(recentDrops.prefix(2))
            if items.isEmpty {
                RecentEmptyState {
                    DispatchQueue.main.async {
                        AppDelegate.shared?.showOverlay()
                    }
                }
            } else {
                VStack(spacing: DesignMetrics.xs) {
                    ForEach(items) { drop in
                        DropRow(
                            drop: drop,
                            style: .compact,
                            inlineDeleteConfirmation: true,
                            onActivate: { openOverlayHistory(focusing: drop.id) },
                            onDelete: { delete(drop) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(CraneColor.creamLine)
                .frame(height: 0.5)

            HStack(spacing: DesignMetrics.sm) {
            CranePrimaryButton {
                DispatchQueue.main.async {
                    AppDelegate.shared?.showOverlay()
                }
            } label: {
                    HStack(spacing: 6) {
                        Text("New Drop")
                        Text("⌘⇧Space")
                            .font(CraneFont.mono(10, weight: .medium))
                            .foregroundStyle(CraneColor.cream.opacity(0.85))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background {
                                RoundedRectangle(cornerRadius: DesignMetrics.xs + 2, style: .continuous)
                                    .fill(Color.craneInk.opacity(0.18))
                            }
                    }
                }

                Spacer()

                CraneTertiaryButton {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit")
                }
            }
            .padding(.horizontal, DesignMetrics.md)
            .padding(.vertical, DesignMetrics.sm)
        }
    }

    // MARK: - Actions

    private func delete(_ drop: Drop) {
        withAnimation(.easeOut(duration: 0.15)) {
            modelContext.deleteDrop(drop)
        }
        refreshStatistics()
    }

    private func openOverlayHistory(focusing dropID: UUID? = nil, search: String? = nil) {
        // Defer until after MenuBarExtra finishes its open/close layout pass.
        DispatchQueue.main.async {
            AppDelegate.shared?.showOverlayHistory(focusing: dropID, search: search)
        }
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let value: String
    let label: String
    var subtitle: String?
    var usesAccent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignMetrics.xs) {
            Text(value)
                .font(CraneFont.display(32))
                .monospacedDigit()
                .foregroundStyle(usesAccent ? CraneColor.accent : Color.craneInk)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(CraneFont.ui(12, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(usesAccent ? CraneColor.accent : Color.craneInkTertiary)
            if let subtitle {
                Text(subtitle)
                    .font(CraneFont.ui(11, weight: .medium))
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

// MARK: - Activity chart

private struct ActivityChart: View {
    let points: [(date: Date, count: Int)]

    @State private var selectedDate: Date?
    @State private var hoveredDate: Date?

    private var calendar: Calendar { Calendar.current }
    private var today: Date { calendar.startOfDay(for: Date()) }

    private var activeDate: Date? {
        hoveredDate ?? selectedDate
    }

    var body: some View {
        Chart {
            ForEach(points, id: \.date) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Count", point.count)
                )
                .foregroundStyle(barColor(for: point))
                .cornerRadius(2)
                .opacity(barOpacity(for: point))
            }

            if let activeDate, let point = point(matching: activeDate), point.count > 0 {
                PointMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Count", point.count)
                )
                .symbolSize(0)
                .annotation(position: .top, spacing: 4) {
                    ChartDayTooltip(date: point.date, count: point.count)
                }
            } else if hoveredDate == nil, let todayPoint = point(matching: today), todayPoint.count > 0 {
                PointMark(
                    x: .value("Day", todayPoint.date, unit: .day),
                    y: .value("Count", todayPoint.count)
                )
                .symbolSize(0)
                .annotation(position: .top, spacing: 4) {
                    Text("\(todayPoint.count)")
                        .font(CraneFont.mono(10, weight: .medium))
                        .foregroundStyle(CraneColor.accent)
                        .monospacedDigit()
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                if let date = value.as(Date.self) {
                    if calendar.isDate(date, inSameDayAs: today) {
                        AxisValueLabel {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(CraneColor.accent)
                                    .frame(width: 4, height: 4)
                                Text("Today")
                                    .font(CraneFont.ui(9, weight: .medium))
                                    .foregroundStyle(CraneColor.accent)
                            }
                        }
                    } else if isWeekStart(date) {
                        AxisValueLabel {
                            Text(weekdayLabel(for: date))
                                .font(CraneFont.ui(9))
                                .foregroundStyle(Color.craneInkTertiary)
                        }
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXSelection(value: $selectedDate)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let origin = geometry[proxy.plotAreaFrame].origin
                            let x = location.x - origin.x
                            hoveredDate = proxy.value(atX: x, as: Date.self)
                        case .ended:
                            hoveredDate = nil
                        }
                    }
            }
        }
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .animation(.craneSnappy, value: hoveredDate)
        .animation(.craneSnappy, value: selectedDate)
    }

    private var axisDates: [Date] {
        points.map(\.date)
    }

    private func point(matching date: Date) -> (date: Date, count: Int)? {
        points.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func isWeekStart(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == calendar.firstWeekday
    }

    private func weekdayLabel(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func isToday(_ point: (date: Date, count: Int)) -> Bool {
        calendar.isDate(point.date, inSameDayAs: today)
    }

    private func barColor(for point: (date: Date, count: Int)) -> Color {
        if isToday(point) {
            return CraneColor.accent
        }
        return CraneColor.accent.opacity(0.55)
    }

    private func barOpacity(for point: (date: Date, count: Int)) -> Double {
        guard let activeDate else { return 1 }
        if calendar.isDate(point.date, inSameDayAs: activeDate) { return 1 }
        return 0.35
    }
}

private struct ChartDayTooltip: View {
    let date: Date
    let count: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                .font(CraneFont.ui(10, weight: .medium))
                .foregroundStyle(Color.craneInkSecondary)
            Text("\(count)")
                .font(CraneFont.mono(11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.craneInk)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                .fill(CraneColor.cardWash(for: colorScheme))
                .background {
                    RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                }
        }
        .specularBorder(cornerRadius: DesignMetrics.rowCornerRadius)
    }
}

private struct ActivityEmptyState: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(CraneColor.accentSoft(for: colorScheme))
                    .frame(width: 44, height: 44)
                Image(systemName: "chart.bar")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Color.craneInkSecondary)
                    .symbolRenderingMode(.hierarchical)
            }

            Text("No activity yet")
                .font(CraneFont.display(16))
                .tracking(-0.15)
                .foregroundStyle(Color.craneInk)

            CranePrimaryButton(action: action) {
                Text("Capture drop")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RecentEmptyState: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(CraneColor.accentSoft(for: colorScheme))
                    .frame(width: 44, height: 44)
                Image(systemName: "tray")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Color.craneInkSecondary)
                    .symbolRenderingMode(.hierarchical)
            }

            Text("Nothing held yet.")
                .font(CraneFont.display(16))
                .tracking(-0.15)
                .foregroundStyle(Color.craneInk)

            CranePrimaryButton(action: action) {
                Text("Capture drop")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nothing held yet. Capture a drop to get started.")
    }
}

// MARK: - Type breakdown

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
                    .fill(CraneColor.accent.opacity(0.85))
                    .frame(width: proxy.size.width * (CGFloat(thoughts) / total))
                Capsule()
                    .fill(CraneColor.accent.opacity(0.45))
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
                .font(CraneFont.ui(14))
                .foregroundStyle(Color.craneInkSecondary)
            Text("\(count)")
                .font(CraneFont.ui(14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.craneInk)
        }
    }
}

#Preview("Dashboard") {
    DashboardView()
        .modelContainer(for: Drop.self, inMemory: true)
}
