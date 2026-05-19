//
//  ContentView.swift
//  crane
//
//  Created by Abhay Sharma on 2026-05-17.
//
//  Root of the floating overlay. Switches between the compact "drop" input
//  bar (default, ⌘⇧Space) and the history list (⌘H), mirroring the React
//  App.tsx that the original Tauri app used.
//
//  The capture bar is rendered with macOS 26 Liquid Glass.
//

import AppKit
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(OverlayController.self) private var controller

    var body: some View {
        // The underlying NSPanel is fully transparent; whichever subview is
        // shown supplies its own background (a glass pill for the input,
        // a glass card for the history list).
        //
        // Note: we used to wrap this switch in a `GlassEffectContainer` with
        // `glassEffectID`s so the bar and the history card morphed into one
        // another. That rendered a second, larger glass surface behind the
        // input on macOS 26, so we keep the surfaces independent for now.
        Group {
            switch controller.currentView {
            case .input:
                DropInputBar()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity
                    ))
            case .history:
                HistoryView()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.craneSpring, value: controller.currentView)
        .background { overlayShortcuts }
    }

    @ViewBuilder
    private var overlayShortcuts: some View {
        Button("Quit crane") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

// MARK: - DropInputBar

/// Spotlight/Raycast-style capture pill rendered with Liquid Glass.
private struct DropInputBar: View {
    @Environment(OverlayController.self) private var controller
    @Environment(\.modelContext) private var modelContext

    @State private var text: String = ""
    @State private var linkMode: Bool = false
    @State private var saving: Bool = false
    @State private var justSaved: Bool = false
    @State private var linkError: String?
    @FocusState private var inputFocused: Bool

    private var leadingSymbol: String {
        if justSaved { return "checkmark" }
        return linkMode ? "link" : "square.and.pencil"
    }

    var body: some View {
        ZStack {
            HStack(spacing: 14) {
                Image(systemName: leadingSymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(justSaved ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 22)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: justSaved)

                TextField(
                    linkMode ? "Paste a link…" : "Drop your thought…",
                    text: $text
                )
                .focusEffectDisabled()
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .regular, design: .default))
                .tracking(-0.2)
                .foregroundStyle(.primary)
                .focused($inputFocused)
                .disableAutocorrection(true)
                .disabled(saving)
                .focusEffectDisabled()
                .onSubmit(submit)

                if linkMode {
                    Text("LINK")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Color.accentColor.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                        .transition(.scale.combined(with: .opacity))
                }

                if let linkError {
                    LinkValidationHint(message: linkError)
                } else {
                    HintChips(linkMode: linkMode)
                }
            }
            .padding(.horizontal, 22)
            .frame(height: 64)
            // Use the classic translucent material instead of macOS 26's
            // Liquid Glass `.glassEffect(...)`: Liquid Glass paints a soft
            // focus halo around any glass surface that contains a focused
            // text input in the key window (the visible "rectangle behind
            // the input box" symptom), and there's no public API to opt
            // out. The regular material gives a very similar translucent
            // look without that key-state treatment.
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: DesignMetrics.surfaceCornerRadius, style: .continuous)
            )
            .specularBorder(cornerRadius: DesignMetrics.surfaceCornerRadius)
            .focusEffectDisabled()
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // Hidden buttons capture the same Cmd+L / Cmd+H shortcuts that
            // the original DropInput.tsx used while the TextField is focused.
            shortcutButtons
        }
        .onAppear { inputFocused = true }
        .onChange(of: controller.currentView) { _, newValue in
            if newValue == .input { inputFocused = true }
        }
        .onChange(of: controller.inputResetToken) { _, _ in
            resetDraft()
        }
        .animation(.craneSnappy, value: linkMode)
        .animation(.craneSnappy, value: justSaved)
        .animation(.craneSnappy, value: linkError != nil)
        .onChange(of: text) { _, _ in linkError = nil }
        .onChange(of: linkMode) { _, _ in linkError = nil }
    }

    @ViewBuilder
    private var shortcutButtons: some View {
        Group {
            Button("Toggle link mode") { linkMode.toggle() }
                .keyboardShortcut("l", modifiers: .command)
            Button("Open history") {
                inputFocused = false
                controller.currentView = .history
            }
            .keyboardShortcut("h", modifiers: .command)
            Button("Hide") { hideAndReset() }
                .keyboardShortcut(.cancelAction)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !saving, !justSaved else { return }

        let body: String
        if linkMode {
            guard Drop.isValidLinkText(trimmed) else {
                linkError = "Enter a URL like https://example.com, or press ⌘L for thought mode."
                return
            }
            body = Drop.normalizedLinkText(trimmed)
        } else {
            body = trimmed
        }

        saving = true
        let drop = Drop(
            text: body,
            dropType: linkMode ? .link : .thought,
            sourceApp: controller.capturedSourceApp
        )
        modelContext.insert(drop)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(drop)
            saving = false
            CraneAlert.presentSaveFailed(error)
            return
        }

        AIJobQueue.shared.enqueue(dropID: drop.id)

        // Brief checkmark blip in the leading-icon slot, then hide. The
        // 250 ms delay lets the symbol replace + bounce play before the
        // panel disappears.
        justSaved = true
        controller.scheduleAfterSaveDismiss { hideAndReset() }
    }

    private func hideAndReset() {
        resetDraft()
        controller.hide()
    }

    private func resetDraft() {
        text = ""
        linkMode = false
        saving = false
        justSaved = false
        linkError = nil
    }
}

// MARK: - Inline link validation

private struct LinkValidationHint: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text(message)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.orange)
        .frame(maxWidth: 200, alignment: .leading)
        .accessibilityLabel(message)
    }
}

// MARK: - Hint chips ("↵ save · esc dismiss · ⌘H history")

private struct HintChips: View {
    let linkMode: Bool

    var body: some View {
        HStack(spacing: 6) {
            HintKey("↵")
            Text("save")
                .foregroundStyle(.tertiary)

            if linkMode {
                HintKey("⌘L")
                Text("thought")
                    .foregroundStyle(.tertiary)
            } else {
                HintKey("⌘L")
                Text("link")
                    .foregroundStyle(.tertiary)
            }

            HintKey("esc")
            Text("dismiss")
                .foregroundStyle(.tertiary)

            HintKey("⌘H")
            Text("history")
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 12, weight: .regular))
        .lineLimit(1)
        .fixedSize()
    }
}

private struct HintKey: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
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
    }
}

// MARK: - Preview

#Preview("Input bar") {
    let controller = OverlayController()
    return ContentView()
        .environment(controller)
        .modelContainer(for: Drop.self, inMemory: true)
        .frame(
            width: OverlayController.inputSize.width,
            height: OverlayController.inputSize.height
        )
        .background(Color.gray.opacity(0.3))
}
