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
    #if DEBUG
    @State private var pendingSeedConfirmation = false
    @State private var seedingSampleData = false
    @State private var seedReplaceHovering = false
    #endif

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
        let showActivityChart = stats.totalCount > 0

        return VStack(alignment: .leading, spacing: DesignMetrics.sm) {
            CraneSectionHeader(caps: "Activity", capsEmphasis: .neutral, trailing: "14 days")

            Group {
                if showActivityChart {
                    ActivityChart(points: stats.dailyCounts)
                } else {
                    ActivityEmptyState()
                        .clipped()
                }
            }
            .frame(height: DesignMetrics.dashboardActivityChartHeight)

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
                RecentEmptyState()
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

            #if DEBUG
            if pendingSeedConfirmation {
                seedConfirmationFooter
            } else {
                defaultFooter
            }
            #else
            defaultFooter
            #endif
        }
    }

    private var defaultFooter: some View {
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

            #if DEBUG
            CraneTertiaryButton {
                pendingSeedConfirmation = true
            } label: {
                Text(seedingSampleData ? "Seeding…" : "Seed week")
            }
            .disabled(seedingSampleData)
            #endif

            CraneTertiaryButton {
                NSApp.terminate(nil)
            } label: {
                Text("Quit")
            }
        }
        .padding(.horizontal, DesignMetrics.md)
        .padding(.vertical, DesignMetrics.sm)
    }

    #if DEBUG
    private var seedConfirmationFooter: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Load sample week?")
                    .font(CraneFont.ui(13, weight: .semibold))
                    .foregroundStyle(Color.craneInk)
                Text("7 days · 10–15/day")
                    .font(CraneFont.ui(10))
                    .foregroundStyle(Color.craneInkTertiary)
            }

            Spacer(minLength: 4)

            CraneSecondaryButton {
                pendingSeedConfirmation = false
            } label: {
                Text("Cancel")
            }

            CraneTertiaryButton {
                loadSampleWeek(clearFirst: false)
                pendingSeedConfirmation = false
            } label: {
                Text("Append")
            }
            .disabled(seedingSampleData)

            Button("Replace") {
                loadSampleWeek(clearFirst: true)
                pendingSeedConfirmation = false
            }
            .buttonStyle(.plain)
            .font(CraneFont.ui(13, weight: .semibold))
            .foregroundStyle(Color.craneWarning)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if seedReplaceHovering {
                    RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                        .fill(Color.craneWarning.opacity(0.12))
                }
            }
            .onHover { seedReplaceHovering = $0 }
            .animation(.craneSnappy, value: seedReplaceHovering)
            .disabled(seedingSampleData)
        }
        .padding(.horizontal, DesignMetrics.md)
        .padding(.vertical, DesignMetrics.sm)
        .animation(.craneSnappy, value: pendingSeedConfirmation)
    }
    #endif

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

    #if DEBUG
    private func loadSampleWeek(clearFirst: Bool) {
        seedingSampleData = true
        do {
            let count = try DummyDataSeeder.seedWeekOfUsage(in: modelContext, clearFirst: clearFirst)
            refreshStatistics()
            print("crane: seeded \(count) sample drops")
        } catch {
            print("crane: sample seed failed: \(error)")
        }
        seedingSampleData = false
    }
    #endif
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

private enum ActivityChartMetrics {
    static let tooltipHeight: CGFloat = 38
    static let tooltipGap: CGFloat = 6
    static let plotInset: CGFloat = 2
}

private struct ActivityChart: View {
    let points: [(date: Date, count: Int)]

    @State private var hoveredDay: Date?

    private var calendar: Calendar { Calendar.current }
    private var today: Date { calendar.startOfDay(for: Date()) }

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
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let plotFrame = geometry[proxy.plotAreaFrame]

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                updateHover(at: location, plotOrigin: plotFrame.origin, proxy: proxy)
                            case .ended:
                                hoveredDay = nil
                            }
                        }

                    chartTooltip(in: plotFrame, proxy: proxy)
                }
            }
        }
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
    }

    @ViewBuilder
    private func chartTooltip(in plotFrame: CGRect, proxy: ChartProxy) -> some View {
        if let hoveredDay, let count = count(on: hoveredDay), count > 0,
           let anchor = tooltipPosition(
               in: plotFrame,
               day: hoveredDay,
               count: count,
               proxy: proxy,
               labelHeight: ActivityChartMetrics.tooltipHeight
           ) {
            ChartDayTooltip(date: hoveredDay, count: count)
                .position(anchor)
        } else if hoveredDay == nil, let todayCount = count(on: today), todayCount > 0,
                  let anchor = tooltipPosition(
                      in: plotFrame,
                      day: today,
                      count: todayCount,
                      proxy: proxy,
                      labelHeight: 16
                  ) {
            Text("\(todayCount)")
                .font(CraneFont.mono(10, weight: .medium))
                .foregroundStyle(CraneColor.accent)
                .monospacedDigit()
                .position(x: anchor.x, y: anchor.y)
        }
    }

    private func updateHover(at location: CGPoint, plotOrigin: CGPoint, proxy: ChartProxy) {
        let x = location.x - plotOrigin.x
        guard let date = proxy.value(atX: x, as: Date.self) else { return }
        let day = calendar.startOfDay(for: date)
        if let hoveredDay, calendar.isDate(hoveredDay, inSameDayAs: day) { return }
        hoveredDay = day
    }

    /// Positions a hover label fully inside the plot area, centered above the bar when possible.
    private func tooltipPosition(
        in plotFrame: CGRect,
        day: Date,
        count: Int,
        proxy: ChartProxy,
        labelHeight: CGFloat
    ) -> CGPoint? {
        guard let x = proxy.position(forX: day),
              let barTopY = proxy.position(forY: count) else { return nil }

        let absoluteX = plotFrame.origin.x + x
        let barTopAbsoluteY = plotFrame.origin.y + barTopY
        let halfLabel = labelHeight / 2
        let inset = ActivityChartMetrics.plotInset

        let idealCenterY = barTopAbsoluteY
            - ActivityChartMetrics.tooltipGap
            - halfLabel
        let minCenterY = plotFrame.minY + halfLabel + inset
        let maxCenterY = plotFrame.maxY - halfLabel - inset
        let centerY = min(max(idealCenterY, minCenterY), maxCenterY)

        return CGPoint(x: absoluteX, y: centerY)
    }

    private func count(on day: Date) -> Int? {
        points.first { calendar.isDate($0.date, inSameDayAs: day) }?.count
    }

    private var axisDates: [Date] {
        points.map(\.date)
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
        guard let hoveredDay else { return 1 }
        if calendar.isDate(point.date, inSameDayAs: hoveredDay) { return 1 }
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
        }
        .specularBorder(cornerRadius: DesignMetrics.rowCornerRadius)
    }
}

private struct ActivityEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(CraneColor.accentSoft(for: colorScheme))
                    .frame(width: 36, height: 36)
                Image(systemName: "chart.bar")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.craneInkSecondary)
                    .symbolRenderingMode(.hierarchical)
            }

            Text("No activity yet")
                .font(CraneFont.ui(13, weight: .medium))
                .foregroundStyle(Color.craneInkTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No activity yet. Use New Drop in the footer to capture.")
    }
}

private struct RecentEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(CraneColor.accentSoft(for: colorScheme))
                    .frame(width: 36, height: 36)
                Image(systemName: "tray")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.craneInkSecondary)
                    .symbolRenderingMode(.hierarchical)
            }

            Text("Nothing held yet.")
                .font(CraneFont.ui(13, weight: .medium))
                .foregroundStyle(Color.craneInkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nothing held yet. Use New Drop in the footer to capture.")
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
