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

    var body: some View {
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

private struct DropInputBar: View {
    @Environment(OverlayController.self) private var controller
    @Environment(\.modelContext) private var modelContext

    @State private var text: String = ""
    @State private var linkMode: Bool = false
    @State private var saving: Bool = false
    @State private var justSaved: Bool = false
    @State private var linkError: String?
    @State private var saveFlash = false
    @FocusState private var captureFocused: Bool

    private var leadingSymbol: String {
        if justSaved { return "checkmark" }
        return linkMode ? "link" : "square.and.pencil"
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: leadingSymbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            justSaved
                                ? AnyShapeStyle(CraneColor.accent)
                                : AnyShapeStyle(linkMode ? CraneColor.link : Color.craneInkSecondary)
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
                    if let linkError {
                        LinkValidationHint(message: linkError)
                    } else {
                        HintChips(linkMode: linkMode)
                    }
                }
                .frame(height: DesignMetrics.hintRowHeight, alignment: .leading)
            }
            .padding(.horizontal, DesignMetrics.inputPillHorizontalPadding)
            .padding(.vertical, DesignMetrics.inputPillVerticalPadding)
            .craneOverlayShell()
            .overlay {
                RoundedRectangle(cornerRadius: DesignMetrics.surfaceCornerRadius, style: .continuous)
                    .fill(Color.craneCream.opacity(saveFlash ? 0.12 : 0))
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            shortcutButtons
        }
        .onAppear { focusCaptureField() }
        .onChange(of: controller.currentView) { _, newValue in
            if newValue == .input { focusCaptureField() }
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
        withAnimation(.craneSubtle) { saveFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.craneSubtle) { saveFlash = false }
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
    @Environment(\.colorScheme) private var colorScheme

    private static let captureFontSize: CGFloat = 22
    private static let captureTracking: CGFloat = -0.15

    var body: some View {
        let caretColor = CraneColor.caret(for: colorScheme)
        ZStack(alignment: .leading) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(CraneFont.display(Self.captureFontSize))
                .tracking(Self.captureTracking)
                .foregroundStyle(Color.clear)
                .tint(caretColor)
                .focused($isFocused)
                .disabled(!isEnabled)
                .onSubmit(onSubmit)
                .accessibilityLabel(placeholder)

            if text.isEmpty {
                Text(placeholder)
                    .font(CraneFont.display(Self.captureFontSize))
                    .tracking(Self.captureTracking)
                    .foregroundStyle(Color.craneInkTertiary)
                    // Nudge right while focused so the system caret isn’t buried under the label.
                    .padding(.leading, isFocused ? 3 : 0)
                    .offset(y: 2)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
            } else {
                Text(text)
                    .font(CraneFont.display(Self.captureFontSize))
                    .tracking(Self.captureTracking)
                    .foregroundStyle(Color.craneInk)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .offset(y: 2)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: DesignMetrics.inputRowHeight)
    }
}

// MARK: - Mode segment

private struct CaptureModeSegment: View {
    @Binding var linkMode: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            segment("Thought", selected: !linkMode) { linkMode = false }
            segment("Link", selected: linkMode) { linkMode = true }
        }
        .padding(3)
        .background(Color.craneCream.opacity(0.12), in: Capsule(style: .continuous))
        .fixedSize()
    }

    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(CraneFont.ui(10, weight: .medium))
                .tracking(0.3)
                .foregroundStyle(selected ? CraneColor.cream : Color.craneInkTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    if selected {
                        Capsule(style: .continuous)
                            .fill(CraneColor.accentFill(for: colorScheme))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
        .font(CraneFont.ui(11, weight: .medium))
        .foregroundStyle(Color.craneWarning)
        .accessibilityLabel(message)
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
                HintKey("⌘H")
                Text("history")
            }
            .font(CraneFont.mono(11))
            .foregroundStyle(Color.craneInkTertiary)
        }
    }
}

private struct HintKey: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(CraneFont.mono(10, weight: .medium))
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
