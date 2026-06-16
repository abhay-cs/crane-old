//
//  ContentView.swift
//  crane
//
//  Root of the floating overlay. Switches between the capture pill and history.
//

import AppKit
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(OverlayController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch controller.currentView {
            case .input:
                DropInputBar()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                    ))
            case .history:
                HistoryView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(
            CraneMotion.adaptive(.craneSpring, reduceMotion: reduceMotion),
            value: controller.currentView
        )
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

private struct DropInputBar: View {
    @Environment(OverlayController.self) private var controller
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var text: String = ""
    @State private var linkMode: Bool = false
    @State private var saving: Bool = false
    @State private var justSaved: Bool = false
    @State private var linkError: String?
    @State private var saveFlash = false
    @State private var shellAppeared = false
    @FocusState private var captureFocused: Bool

    private var shellOpacity: Double {
        if saving { return 0.85 }
        return shellAppeared ? 1 : 0
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Group {
                        if justSaved {
                            Image(systemName: "checkmark")
                                .font(CraneFont.symbol(18, weight: .medium))
                                .foregroundStyle(Color.craneInk)
                        } else {
                            CraneDropGlyph(
                                dropType: linkMode ? .link : .thought,
                                context: .capture,
                                size: 18
                            )
                        }
                    }
                    .shadow(
                        color: justSaved ? CraneColor.sage.opacity(0.25) : .clear,
                        radius: justSaved ? 10 : 0
                    )
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 22)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: justSaved)

                    CaptureMirrorField(
                        text: $text,
                        placeholder: linkMode ? "Paste a link…" : "Drop your thought…",
                        isEnabled: !saving && !justSaved,
                        isFocused: $captureFocused,
                        onSubmit: submit
                    )
                    .frame(maxWidth: .infinity, minHeight: DesignMetrics.inputRowHeight)

                    CaptureModeSegment(linkMode: $linkMode)
                }
                .frame(height: DesignMetrics.inputRowHeight)

                Group {
                    if justSaved {
                        SavedHint()
                    } else if let linkError {
                        LinkValidationHint(message: linkError)
                    } else {
                        HintChips(linkMode: linkMode)
                    }
                }
                .frame(minHeight: DesignMetrics.hintRowHeight, maxHeight: DesignMetrics.hintRowMaxHeight, alignment: .leading)
            }
            .padding(.horizontal, DesignMetrics.inputPillHorizontalPadding)
            .padding(.vertical, DesignMetrics.inputPillVerticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .craneOverlayShell()
            .craneAccentFocusRing(isFocused: captureFocused && !justSaved)
            .overlay {
                RoundedRectangle(cornerRadius: DesignMetrics.surfaceCornerRadius, style: .continuous)
                    .fill(Color.craneCream.opacity(saveFlash ? 0.12 : 0))
                    .allowsHitTesting(false)
            }
            .opacity(shellOpacity)

            shortcutButtons
        }
        .onAppear {
            withAnimation(CraneMotion.adaptive(.craneSpring, reduceMotion: reduceMotion)) {
                shellAppeared = true
            }
            focusCaptureField()
        }
        .onChange(of: controller.currentView) { _, newValue in
            if newValue == .input { focusCaptureField() }
        }
        .onChange(of: controller.inputResetToken) { _, _ in
            resetDraft()
        }
        .animation(CraneMotion.adaptive(.craneSnappy, reduceMotion: reduceMotion), value: linkMode)
        .animation(CraneMotion.adaptive(.craneSnappy, reduceMotion: reduceMotion), value: justSaved)
        .animation(CraneMotion.adaptive(.craneSnappy, reduceMotion: reduceMotion), value: linkError != nil)
        .onChange(of: text) { _, _ in linkError = nil }
        .onChange(of: linkMode) { _, _ in linkError = nil }
    }

    @ViewBuilder
    private var shortcutButtons: some View {
        Group {
            Button("Toggle link mode") { linkMode.toggle() }
                .keyboardShortcut("l", modifiers: .command)
            Button("Open history") {
                controller.currentView = .history
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
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

        if trimmed.count > Persistence.maxDropTextLength {
            linkError = "Keep it under \(Persistence.maxDropTextLength) characters."
            return
        }

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

        saving = false
        justSaved = true
        withAnimation(CraneMotion.adaptive(.craneSubtle, reduceMotion: reduceMotion)) {
            saveFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(CraneMotion.adaptive(.craneSubtle, reduceMotion: reduceMotion)) {
                saveFlash = false
            }
        }
        controller.scheduleAfterSaveDismiss { hideAndReset() }
    }

    /// Focus after the panel is key; immediate `@FocusState` often misses on overlay open.
    private func focusCaptureField() {
        DispatchQueue.main.async { captureFocused = true }
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
        saveFlash = false
        shellAppeared = true
    }
}

// MARK: - Capture field (mirror text)

/// Invisible `TextField` captures keys; a SwiftUI `Text` overlay shows ink
/// reliably (AppKit text in our transparent panel does not paint glyphs).
private struct CaptureMirrorField: View {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool
    @FocusState.Binding var isFocused: Bool
    var onSubmit: () -> Void

    var body: some View {
        CraneMirrorTextField(
            text: $text,
            placeholder: placeholder,
            font: CraneTextStyle.capture.font,
            tracking: CraneTextStyle.capture.tracking,
            height: DesignMetrics.inputRowHeight,
            verticalNudge: 2,
            focusedLeadingPadding: 3,
            isEnabled: isEnabled,
            accessibilityLabel: placeholder,
            isFocused: $isFocused,
            onSubmit: onSubmit
        )
    }
}

// MARK: - Mode segment

private struct CaptureModeSegment: View {
    @Binding var linkMode: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var segmentNamespace

    var body: some View {
        HStack(spacing: 2) {
            segment("Thought", selected: !linkMode) { linkMode = false }
            segment("Link", selected: linkMode) { linkMode = true }
        }
        .padding(3)
        .background(Color.craneInk.opacity(0.05), in: Capsule(style: .continuous))
        .fixedSize()
    }

    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(CraneFont.ui(13, weight: .medium))
                .foregroundStyle(selected ? Color.craneInk : Color.craneInkTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    if selected {
                        Capsule(style: .continuous)
                            .fill(CraneColor.recessFill(for: colorScheme))
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(CraneColor.creamLine, lineWidth: 0.5)
                            }
                            .matchedGeometryEffect(id: "selectedSegment", in: segmentNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(.craneSnappy, value: linkMode)
    }
}

// MARK: - Inline link validation

private struct LinkValidationHint: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(CraneFont.symbol(12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text(message)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(CraneFont.ui(13, weight: .medium))
        .foregroundStyle(Color.craneWarning)
        .accessibilityLabel(message)
    }
}

// MARK: - Saved hint

private struct SavedHint: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(CraneFont.symbol(11, weight: .semibold))
            Text("Saved")
        }
        .font(CraneFont.ui(14, weight: .medium))
        .foregroundStyle(Color.craneInkSecondary)
    }
}

// MARK: - Hint chips

private struct HintChips: View {
    let linkMode: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                HintKey("↵")
                Text("save")
                HintKey("⌘L")
                Text(linkMode ? "thought" : "link")
                HintKey("esc")
                Text("dismiss")
                HintKey("⌘⇧H")
                Text("history")
            }
            .font(CraneFont.mono(13))
            .foregroundStyle(Color.craneInkTertiary)
        }
    }
}

private struct HintKey: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(CraneFont.mono(12, weight: .medium))
            .foregroundStyle(Color.craneInkSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .craneInputRecess(cornerRadius: DesignMetrics.xs + 2)
    }
}

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
