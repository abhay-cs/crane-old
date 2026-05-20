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
    }
}
