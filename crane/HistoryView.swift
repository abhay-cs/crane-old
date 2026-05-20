//
//  HistoryView.swift
//  crane
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(OverlayController.self) private var controller
    @Environment(\.modelContext) private var modelContext

    @Query private var drops: [Drop]

    @State private var search: String = ""
    @State private var debouncedSearch: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

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
        }
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
            Button(action: goBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.craneInkSecondary)
                    .frame(width: 28, height: 28)
                    .craneInputRecess(cornerRadius: DesignMetrics.rowCornerRadius)
            }
            .buttonStyle(.plain)
            .help("Back (esc)")

            Text("Your Drops")
                .font(CraneFont.display(20))
                .tracking(-0.2)
                .foregroundStyle(Color.craneInk)

            Text("\(drops.count)")
                .font(CraneFont.ui(11, weight: .medium))
                .foregroundStyle(Color.craneInkSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .craneCard(cornerRadius: DesignMetrics.chipCornerRadius)

            Spacer()
        }
        .padding(.horizontal, DesignMetrics.md + 2)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Search drops")
                .font(CraneFont.ui(11, weight: .medium))
                .foregroundStyle(Color.craneInkSecondary)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.craneInkTertiary)
                    .font(.system(size: 12, weight: .medium))
                TextField("Filter by text, type, or tags…", text: $search)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .font(CraneFont.ui(13))
                    .foregroundStyle(Color.craneInk)
                    .tint(CraneColor.accent)
                    .disableAutocorrection(true)
                    .accessibilityLabel("Search drops")
                    .accessibilityHint("Filters by text, type, tags, or source app")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .craneInputRecess()
        }
        .padding(.horizontal, DesignMetrics.md + 2)
        .padding(.bottom, 12)
        .background {
            Button("Focus search") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
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
                        message: "No drops yet. Capture a thought or link to get started.",
                        primaryAction: { AppDelegate.shared?.showOverlay() }
                    )
                    .padding(.horizontal, 24)
                } else {
                    EmptyStateView(
                        symbol: "magnifyingglass",
                        message: "No drops match your search.",
                        primaryTitle: "Clear search",
                        primaryAction: {
                            searchDebounceTask?.cancel()
                            search = ""
                            debouncedSearch = ""
                        }
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
                                DropRow(drop: drop, onDelete: { delete(drop) })
                                    .id(drop.id)
                            }
                        } else {
                            ForEach(items.groupedByDaySection(), id: \.title) { section in
                                Text(section.title)
                                    .font(CraneFont.ui(10, weight: .semibold))
                                    .tracking(0.4)
                                    .foregroundStyle(Color.craneInkTertiary)
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)
                                    .padding(.horizontal, 4)

                                ForEach(section.drops) { drop in
                                    DropRow(drop: drop, onDelete: { delete(drop) })
                                        .id(drop.id)
                                }
                            }
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

    private func goBack() {
        controller.currentView = .input
    }

    private func delete(_ drop: Drop) {
        withAnimation(.easeOut(duration: 0.15)) {
            modelContext.deleteDrop(drop)
        }
    }

    private func scrollToFocusedDrop(in items: [Drop], proxy: ScrollViewProxy) {
        guard let targetID = controller.scrollToDropID,
              items.contains(where: { $0.id == targetID })
        else { return }
        DispatchQueue.main.async {
            withAnimation(.craneSnappy) {
                proxy.scrollTo(targetID, anchor: .center)
            }
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
