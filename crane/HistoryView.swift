//
//  HistoryView.swift
//  crane
//
//  Searchable list of saved drops with per-row delete. Mirrors the React
//  HistoryView.tsx, including:
//
//   - text/type search filter
//   - relative-time formatting ("just now", "Nm ago", …)
//   - "back" button + Esc to return to the input bar
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(OverlayController.self) private var controller
    @Environment(\.modelContext) private var modelContext

    // SwiftData fetches the list sorted newest-first so we don't need to
    // reverse manually; the view re-renders automatically when the
    // dashboard or the input bar mutate the store.
    @Query(sort: \Drop.timestamp, order: .reverse)
    private var drops: [Drop]

    @State private var search: String = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [Drop] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return drops }
        return drops.filter { drop in
            drop.text.lowercased().contains(q)
                || drop.dropType.rawValue.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider().opacity(0.4)
            listContent
        }
        // See `DropInputBar` for why we use `.regularMaterial` instead of
        // `.glassEffect`: Liquid Glass renders a focus halo around any
        // glass surface that contains a focused text input in the key
        // window, and there's no API to opt out.
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: DesignMetrics.surfaceCornerRadius, style: .continuous)
        )
        .specularBorder(cornerRadius: DesignMetrics.surfaceCornerRadius)
        .clipShape(RoundedRectangle(cornerRadius: DesignMetrics.surfaceCornerRadius, style: .continuous))
        .padding(12)
        .background(
            // Hidden cancel-action button so Esc returns to the input view
            // without depending on the panel-level cancelOperation handler.
            Button("Back") { goBack() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
        .onAppear { searchFocused = true }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: goBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(.quaternary.opacity(0.5),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Back (esc)")

            Text("Your Drops")
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.2)

            Text("\(drops.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .background(.quaternary.opacity(0.5),
                            in: Capsule(style: .continuous))

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 12, weight: .medium))
            TextField("Search drops…", text: $search)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .font(.system(size: 13))
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // Match the card material; using `.regularMaterial` avoids the
        // Liquid Glass focus halo around the focused search field.
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    // MARK: List

    @ViewBuilder
    private var listContent: some View {
        let items = filtered
        if items.isEmpty {
            VStack {
                Spacer()
                Text(drops.isEmpty
                     ? "No drops yet. Press ⌘⇧Space to capture your first thought!"
                     : "No drops match your search.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 13))
                    .padding(.horizontal, 36)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(items) { drop in
                            DropRow(drop: drop, onDelete: { delete(drop) })
                                .id(drop.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onAppear { scrollToFocusedDrop(in: items, proxy: proxy) }
                .onChange(of: controller.scrollToDropID) { _, _ in
                    scrollToFocusedDrop(in: items, proxy: proxy)
                }
                .onChange(of: items.count) { _, _ in
                    scrollToFocusedDrop(in: items, proxy: proxy)
                }
            }
        }
    }

    // MARK: Actions

    private func goBack() {
        controller.currentView = .input
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

// MARK: - Preview

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
