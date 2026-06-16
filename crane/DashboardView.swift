//
//  DashboardView.swift
//  crane
//

import SwiftUI
import SwiftData
// import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    /// Newest drops for recent list and row actions (capped).
    @Query private var recentDrops: [Drop]

    @State private var stats: DropStatistics = .empty
    @State private var dashboardHovering = false
    @State private var pendingResetConfirmation = false
    @State private var resetDeleteHovering = false

    init() {
        var descriptor = FetchDescriptor<Drop>(
            sortBy: [SortDescriptor(\Drop.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = Persistence.maxFetchedDrops
        _recentDrops = Query(descriptor)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: dashboardHovering) {
                VStack(alignment: .leading, spacing: DesignMetrics.dashboardSectionSpacing) {
                    header
                    if stats.totalCount > 0 {
                        journalMetaLine
                    }
                    recentSection
                    TopTagsSection(
                        topTags: stats.topTags,
                        hasAnyDrops: stats.totalCount > 0,
                        untaggedInSample: recentDrops.untaggedCount
                    ) { tag in
                        openOverlayHistory(search: tag)
                    }
                    // Charts disabled for now.
                    // if stats.totalCount > 0 {
                    //     rhythmSection
                    // }
                }
                .padding(DesignMetrics.dashboardContentInset)
            }
            .frame(height: DesignMetrics.dashboardScrollHeight)
            .onHover { dashboardHovering = $0 }

            footer
        }
        .frame(
            width: DesignMetrics.dashboardWidth,
            height: DesignMetrics.dashboardHeight
        )
        .padding(DesignMetrics.glassShadowMargin)
        .frame(
            width: DesignMetrics.dashboardWindowWidth,
            height: DesignMetrics.dashboardWindowHeight,
            alignment: .topLeading
        )
        .fixedSize(horizontal: true, vertical: true)
        .craneDashboardBackground()
        .presentationBackground(.clear)
        .containerBackground(.clear, for: .window)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
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
                .foregroundStyle(Color.craneInkSecondary)
                .accessibilityHidden(true)

            Text("crane")
                .craneText(.title)

            Spacer()

            CraneIconButton(
                systemName: "clock",
                help: "Open history",
                accessibilityLabel: "Open history"
            ) {
                openOverlayHistory(focusing: nil)
            }
        }
    }

    // MARK: - Journal meta

    private var journalMetaLine: some View {
        Text(journalMetaSummary)
            .craneText(.meta)
            .accessibilityLabel(journalMetaSummary)
    }

    private var journalMetaSummary: String {
        var parts: [String] = []
        let entryWord = stats.totalCount == 1 ? "entry" : "entries"
        parts.append("\(stats.totalCount) \(entryWord)")
        if stats.todayCount > 0 {
            parts.append("\(stats.todayCount) today")
        }
        if stats.streakDays >= 2 {
            parts.append("\(stats.streakDays) days in a row")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Rhythm

#if false // Charts disabled for now.
    private var rhythmSection: some View {
        let breakdown = stats.typeBreakdown
        let hasTypeData = breakdown.thoughts + breakdown.links > 0
        let showActivityChart = stats.totalCount > 0

        return VStack(alignment: .leading, spacing: DesignMetrics.sm) {
            CraneSectionHeader(title: "Rhythm", style: .journal, trailing: "14 days")

            Group {
                if showActivityChart {
                    ActivityChart(points: stats.dailyCounts)
                } else {
                    RhythmEmptyState()
                        .clipped()
                }
            }
            .frame(height: DesignMetrics.dashboardActivityChartHeight)

            typeBreakdownSlot(hasTypeData: hasTypeData, breakdown: breakdown)
        }
        .opacity(0.92)
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
#endif

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: DesignMetrics.sm) {
            CraneSectionHeader(
                title: "Recent",
                style: .journal,
                trailingActionTitle: recentDrops.isEmpty ? nil : "See everything",
                trailingAction: recentDrops.isEmpty ? nil : { openOverlayHistory(focusing: nil) }
            )

            let items = Array(recentDrops.prefix(DesignMetrics.dashboardRecentLimit))
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

            if pendingResetConfirmation {
                resetConfirmationFooter
            } else {
                defaultFooter
            }
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
                    Text("Write")
                    Text("⌘⇧Space")
                        .font(CraneFont.mono(10, weight: .medium))
                        .foregroundStyle(CraneColor.cream.opacity(0.85))
                        .padding(.horizontal, DesignMetrics.xs + 1)
                        .padding(.vertical, DesignMetrics.xs / 2)
                        .background {
                            RoundedRectangle(cornerRadius: DesignMetrics.xs, style: .continuous)
                                .fill(Color.craneInk.opacity(0.18))
                        }
                }
            }

            Spacer()

            if stats.totalCount > 0 {
                CraneTertiaryButton {
                    pendingResetConfirmation = true
                } label: {
                    Text("Reset")
                }
            }

            CraneTertiaryButton {
                NSApp.terminate(nil)
            } label: {
                Text("Quit")
            }
        }
        .padding(.horizontal, DesignMetrics.dashboardContentInset)
        .padding(.vertical, DesignMetrics.sm)
    }

    private var resetConfirmationFooter: some View {
        HStack(spacing: DesignMetrics.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Delete all entries?")
                    .font(CraneFont.ui(13, weight: .semibold))
                    .foregroundStyle(Color.craneInk)
                Text("This can’t be undone.")
                    .font(CraneFont.ui(10))
                    .foregroundStyle(Color.craneInkTertiary)
            }

            Spacer(minLength: DesignMetrics.xs)

            CraneSecondaryButton {
                pendingResetConfirmation = false
            } label: {
                Text("Cancel")
            }

            Button("Delete All", role: .destructive) {
                pendingResetConfirmation = false
                resetAllData()
            }
            .buttonStyle(.plain)
            .font(CraneFont.ui(13, weight: .semibold))
            .foregroundStyle(Color.craneWarning)
            .padding(.horizontal, DesignMetrics.sm)
            .padding(.vertical, DesignMetrics.xs)
            .background {
                if resetDeleteHovering {
                    RoundedRectangle(cornerRadius: DesignMetrics.rowCornerRadius, style: .continuous)
                        .fill(Color.craneWarning.opacity(0.12))
                }
            }
            .onHover { resetDeleteHovering = $0 }
            .animation(.craneSnappy, value: resetDeleteHovering)
        }
        .padding(.horizontal, DesignMetrics.dashboardContentInset)
        .padding(.vertical, DesignMetrics.sm)
        .animation(.craneSnappy, value: pendingResetConfirmation)
    }

    // MARK: - Actions

    private func delete(_ drop: Drop) {
        withAnimation(.craneSpring) {
            modelContext.deleteDrop(drop)
        }
        refreshStatistics()
    }

    private func resetAllData() {
        withAnimation(.craneSpring) {
            AppDelegate.shared?.resetAllData()
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

#if false // Charts disabled for now.

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
        .animation(.craneChartHover, value: hoveredDay)
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
            // Keyed by day so content swaps cleanly while position springs between bars.
            ChartDayTooltip(date: hoveredDay, count: count)
                .id(hoveredDay)
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
                .position(anchor)
                .animation(.craneChartHover, value: anchor)
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
                .transition(.opacity)
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
            return CraneColor.accent.opacity(0.85)
        }
        return CraneColor.accent.opacity(0.35)
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
    }
}

private struct RhythmEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(CraneColor.sageSoft(for: colorScheme))
                    .frame(width: 32, height: 32)
                Image(systemName: "waveform.path")
                    .font(CraneFont.symbol(14, weight: .light))
                    .foregroundStyle(Color.craneInkSecondary)
                    .symbolRenderingMode(.hierarchical)
            }

            Text("Your rhythm will show up here.")
                .font(CraneFont.ui(12))
                .foregroundStyle(Color.craneInkTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your rhythm will show up here. Use Write in the footer to capture.")
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
                .font(CraneFont.ui(12))
                .foregroundStyle(Color.craneInkTertiary)
            Text("\(count)")
                .font(CraneFont.ui(12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.craneInk)
        }
    }
}

#endif

private struct RecentEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(CraneColor.sageSoft(for: colorScheme))
                    .frame(width: 32, height: 32)
                Image(systemName: "text.book.closed")
                    .font(CraneFont.symbol(14, weight: .light))
                    .foregroundStyle(Color.craneInkSecondary)
                    .symbolRenderingMode(.hierarchical)
            }

            Text("Nothing written yet.")
                .craneText(.body)
                .foregroundStyle(Color.craneInkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignMetrics.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nothing written yet. Use Write in the footer to capture.")
    }
}

#Preview("Dashboard") {
    DashboardView()
        .modelContainer(for: Drop.self, inMemory: true)
}
