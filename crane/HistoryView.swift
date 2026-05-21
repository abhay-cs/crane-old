//
//  HistoryView.swift
//  crane
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(OverlayController.self) private var controller
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var drops: [Drop]

    @State private var search: String = ""
    @State private var debouncedSearch: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var storeTotalCount = 0
    @FocusState private var searchFocused: Bool

    private var isListCapped: Bool {
        storeTotalCount > Persistence.maxFetchedDrops
    }

    private var isSearching: Bool {
        !debouncedSearch.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var filtered: [Drop] {
        let q = debouncedSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return drops }
        return drops.filter { drop in
            drop.text.lowercased().contains(q)
                || drop.dropType.rawValue.lowercased().contains(q)
                || drop.tags.contains { $0.lowercased().contains(q) }
                || (drop.sourceApp?.lowercased().contains(q) ?? false)
        }
    }

    init() {
        var descriptor = FetchDescriptor<Drop>(
            sortBy: [SortDescriptor(\Drop.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = Persistence.maxFetchedDrops
        _drops = Query(descriptor)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            listContent
        }
        .craneOverlayShell()
        .clipShape(RoundedRectangle(cornerRadius: DesignMetrics.surfaceCornerRadius, style: .continuous))
        .padding(12)
        .background {
            Button("Back") { goBack() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        .onAppear {
            if let seed = controller.historySearchQuery, !seed.isEmpty {
                search = seed
                debouncedSearch = seed
            }
            searchFocused = true
            refreshStoreTotalCount()
        }
        .onChange(of: drops.count) { _, _ in refreshStoreTotalCount() }
        .onChange(of: search) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                debouncedSearch = newValue
            }
        }
        .onDisappear { searchDebounceTask?.cancel() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            CraneIconButton(
                systemName: "arrow.left",
                iconSize: 13,
                usesRecess: true,
                help: "Back (esc)",
                accessibilityLabel: "Back",
                action: goBack
            )

            Text("History")
                .font(CraneFont.display(20))
                .tracking(-0.2)
                .foregroundStyle(Color.craneInk)

            Text("· \(storeTotalCount)")
                .font(CraneFont.ui(13, weight: .medium))
                .foregroundStyle(Color.craneInkSecondary)

            Spacer()
        }
        .padding(.horizontal, DesignMetrics.md + 2)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Search drops")
                    .font(CraneFont.ui(13, weight: .medium))
                    .foregroundStyle(Color.craneInkSecondary)

                Spacer()

                if isSearching {
                    Text(searchResultsLabel)
                        .font(CraneFont.ui(13))
                        .foregroundStyle(Color.craneInkTertiary)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.craneInkTertiary)
                    .font(.system(size: 13, weight: .medium))

                TextField("Filter by text, type, or tags…", text: $search)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .font(CraneFont.ui(14))
                    .foregroundStyle(Color.craneInk)
                    .tint(CraneColor.accent)
                    .disableAutocorrection(true)
                    .accessibilityLabel("Search drops")
                    .accessibilityHint("Filters by text, type, tags, or source app")

                if !search.isEmpty {
                    CraneIconButton(
                        systemName: "xmark.circle.fill",
                        iconSize: 13,
                        help: "Clear search",
                        accessibilityLabel: "Clear search",
                        action: clearSearch
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .craneInputRecess()
            .overlay {
                RoundedRectangle(cornerRadius: DesignMetrics.controlCornerRadius, style: .continuous)
                    .strokeBorder(CraneColor.accentLine(for: colorScheme), lineWidth: searchFocused ? 0.5 : 0)
                    .animation(
                        CraneMotion.adaptive(.craneSnappy, reduceMotion: reduceMotion),
                        value: searchFocused
                    )
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, DesignMetrics.md + 2)
        .padding(.bottom, 12)
        .craneDivider()
        .background {
            Button("Focus search") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }

    private var searchResultsLabel: String {
        let count = filtered.count
        return count == 1 ? "1 match" : "\(count) matches"
    }

    @ViewBuilder
    private var listContent: some View {
        let items = filtered
        if items.isEmpty {
            VStack {
                Spacer()
                if drops.isEmpty {
                    EmptyStateView(
                        symbol: "tray",
                        headline: "Nothing held yet.",
                        message: "Capture a thought or link to get started.",
                        primaryAction: { AppDelegate.shared?.showOverlay() }
                    )
                    .padding(.horizontal, 24)
                } else {
                    EmptyStateView(
                        symbol: "magnifyingglass",
                        headline: "No matches.",
                        message: "Try a different search term.",
                        primaryTitle: "Clear search",
                        primaryAction: clearSearch
                    )
                    .padding(.horizontal, 24)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if isSearching {
                            ForEach(items) { drop in
                                historyRow(for: drop)
                                    .id(drop.id)
                            }
                        } else {
                            ForEach(items.groupedByDaySection(), id: \.title) { section in
                                Text(section.title.uppercased())
                                    .font(CraneFont.ui(12, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundStyle(Color.craneInkTertiary)
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)
                                    .padding(.horizontal, 4)

                                ForEach(section.drops) { drop in
                                    historyRow(for: drop)
                                        .id(drop.id)
                                }
                            }
                        }

                        if isListCapped {
                            Text(cappedListMessage)
                                .font(CraneFont.ui(11))
                                .foregroundStyle(Color.craneInkTertiary)
                                .padding(.top, 8)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onAppear { scrollToFocusedDrop(in: items, proxy: proxy) }
                .onChange(of: controller.scrollToken) { _, _ in
                    scrollToFocusedDrop(in: items, proxy: proxy)
                }
                .onChange(of: items.count) { _, _ in
                    scrollToFocusedDrop(in: items, proxy: proxy)
                }
            }
        }
    }

    private func historyRow(for drop: Drop) -> some View {
        DropRow(
            drop: drop,
            inlineDeleteConfirmation: true,
            isEmphasized: drop.id == controller.scrollToDropID,
            onDelete: { delete(drop) }
        )
    }

    private var cappedListMessage: String {
        let limit = Persistence.maxFetchedDrops
        if isSearching {
            return "Search covers your newest \(limit) drops."
        }
        return "Showing your newest \(limit) drops."
    }

    private func refreshStoreTotalCount() {
        storeTotalCount = (try? modelContext.fetchCount(FetchDescriptor<Drop>())) ?? drops.count
    }

    private func clearSearch() {
        searchDebounceTask?.cancel()
        search = ""
        debouncedSearch = ""
    }

    private func goBack() {
        controller.clearScrollHighlight()
        controller.currentView = .input
    }

    private func delete(_ drop: Drop) {
        withAnimation(CraneMotion.adaptive(.easeOut(duration: 0.15), reduceMotion: reduceMotion)) {
            modelContext.deleteDrop(drop)
            refreshStoreTotalCount()
        }
    }

    private func scrollToFocusedDrop(in items: [Drop], proxy: ScrollViewProxy) {
        guard let targetID = controller.scrollToDropID,
              items.contains(where: { $0.id == targetID })
        else { return }
        DispatchQueue.main.async {
            withAnimation(CraneMotion.adaptive(.craneSnappy, reduceMotion: reduceMotion)) {
                proxy.scrollTo(targetID, anchor: .center)
            }
            controller.scheduleScrollHighlightClear()
        }
    }
}

#Preview("History") {
    let controller = OverlayController()
    return HistoryView()
        .environment(controller)
        .modelContainer(for: Drop.self, inMemory: true)
        .frame(
            width: OverlayController.historySize.width,
            height: OverlayController.historySize.height
        )
}
