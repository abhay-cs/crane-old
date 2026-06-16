//
//  craneApp.swift
//  crane
//
//  Created by Abhay Sharma on 2026-05-17.
//
//  Menu-bar-only entry. The actual capture UI lives inside the floating
//  overlay panel that AppDelegate owns; clicking the tray icon opens a
//  small dashboard window with stats, recent drops, and the New Drop /
//  Quit actions in its footer.
//

import SwiftUI
import SwiftData

@main
struct craneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
        } label: {
            // Wingspan mark (MenuBarIcon.imageset). Template-tinted for the menu bar.
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)
        // Single shared container; the overlay panel also installs this
        // exact instance in `OverlayController.attach(rootView:)` so the
        // dashboard sees writes made from the capture pill live.
        .modelContainer(Persistence.container)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Write…") {
                    AppDelegate.shared?.showOverlay()
                }
                .keyboardShortcut(" ", modifiers: [.command, .shift])
            }

            CommandMenu("Capture") {
                Button("Open History") {
                    AppDelegate.shared?.showOverlayHistory()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Focus Search") {
                    AppDelegate.shared?.showOverlayHistory()
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                Button("Reset All Data…") {
                    AppDelegate.shared?.confirmAndResetAllData()
                }
            }

            CommandGroup(replacing: .appTermination) {
                Button("Quit crane") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
