//
//  OnboardingView.swift
//  crane
//
//  Coach card content for the first-run tour. Rendered inside the glass
//  panel that `OnboardingController` owns; steps advance from real app
//  events (overlay shown, drop saved), so this view only presents state.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(OnboardingController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DesignMetrics.md) {
            header

            stepBody
                .frame(maxHeight: .infinity, alignment: .leading)

            footer
        }
        .padding(DesignMetrics.overlayContentInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .craneOverlayShell()
        .animation(CraneMotion.adaptive(.craneSpring, reduceMotion: reduceMotion), value: controller.step)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignMetrics.sm) {
            Text("Welcome to crane")
                .craneText(.title)

            Spacer()

            Text("\(controller.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                .craneText(.meta)
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepBody: some View {
        switch controller.step {
        case .capture:
            stepRow {
                HStack(spacing: 4) {
                    Keycap("⌘")
                    Keycap("⇧")
                    Keycap("space")
                }
            } text: {
                Text("Press the shortcut to open the capture bar — it works from inside any app.")
            }
            .transition(stepTransition)

        case .save:
            stepRow {
                Keycap("↵")
            } text: {
                Text("Type a thought, press Return. crane saves it and gets out of your way.")
            }
            .transition(stepTransition)

        case .review:
            stepRow {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .foregroundStyle(Color.craneInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .craneInputRecess(cornerRadius: DesignMetrics.rowCornerRadius)
            } text: {
                Text("Saved. Your drops live behind this icon in the menu bar — recents, tags, and stats.")
            }
            .transition(stepTransition)
        }
    }

    private func stepRow(
        @ViewBuilder glyph: () -> some View,
        @ViewBuilder text: () -> Text
    ) -> some View {
        HStack(alignment: .center, spacing: DesignMetrics.md) {
            glyph()
                .fixedSize()

            text()
                .craneText(.body)
                .foregroundStyle(Color.craneInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 6)),
            removal: .opacity
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: DesignMetrics.sm) {
            progressDots

            Spacer()

            switch controller.step {
            case .capture:
                CraneTertiaryButton {
                    controller.skip()
                } label: {
                    Text("Skip tour")
                }
                CraneSecondaryButton {
                    AppDelegate.shared?.showOverlay()
                } label: {
                    Text("Open it for me")
                }
            case .save:
                CraneTertiaryButton {
                    controller.skip()
                } label: {
                    Text("Skip tour")
                }
            case .review:
                CranePrimaryButton {
                    controller.finish()
                } label: {
                    Text("Done")
                }
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(
                        step == controller.step
                            ? Color.craneInk
                            : Color.craneInkTertiary.opacity(0.4)
                    )
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityLabel("Step \(controller.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
    }
}

// MARK: - Keycap

/// Larger sibling of the capture pill's hint keys, sized for the tour card.
private struct Keycap: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(CraneFont.mono(13, weight: .medium))
            .foregroundStyle(Color.craneInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .craneInputRecess(cornerRadius: DesignMetrics.rowCornerRadius)
    }
}

#Preview("Onboarding card") {
    OnboardingView()
        .environment(OnboardingController())
        .frame(
            width: OnboardingController.cardSize.width,
            height: OnboardingController.cardSize.height
        )
        .background(Color.gray.opacity(0.3))
}
