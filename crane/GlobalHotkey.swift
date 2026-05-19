//
//  GlobalHotkey.swift
//  crane
//
//  Thin Swift wrapper around Carbon's RegisterEventHotKey API for a single
//  app-global hotkey (the "open Crane" combo). This matches the
//  tauri-plugin-global-shortcut behaviour used by the original app.
//
//  Carbon hotkeys work inside the App Sandbox without extra entitlements.
//

import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalHotkey {

    /// FourCharCode 'CRNE' — used as the hotkey signature.
    private static let signature: OSType = 0x43_52_4E_45
    private static var nextID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handler: (() -> Void)?

    /// Whether the most recent `register` call installed a hotkey successfully.
    private(set) var isRegistered = false

    /// Map of opaque ptr → owning instance, so the @convention(c) callback
    /// can dispatch back to the correct Swift object without an unbalanced retain.
    private static var registry: [ObjectIdentifier: GlobalHotkey] = [:]

    deinit {
        // Carbon resources are released in `unregister()`; calling it from
        // deinit isn't safe here because of MainActor isolation, so callers
        // should invoke unregister() explicitly when tearing down.
    }

    /// Register the hotkey. Replaces any previously-registered combo.
    /// `keyCode` uses `kVK_*` constants; `modifiers` uses Carbon flags
    /// (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`).
    @discardableResult
    func register(keyCode: UInt32,
                  modifiers: UInt32,
                  handler: @escaping () -> Void) -> Bool {
        unregister()
        isRegistered = false
        self.handler = handler
        Self.registry[ObjectIdentifier(self)] = self

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            GlobalHotkey.eventHandlerCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        guard installStatus == noErr else {
            self.handler = nil
            Self.registry.removeValue(forKey: ObjectIdentifier(self))
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.nextID)
        Self.nextID &+= 1

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            unregister()
            return false
        }
        isRegistered = true
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let h = eventHandler {
            RemoveEventHandler(h)
            eventHandler = nil
        }
        Self.registry.removeValue(forKey: ObjectIdentifier(self))
        handler = nil
        isRegistered = false
    }

    /// C-callback shim. Carbon dispatches HotKey events on the main thread,
    /// so it is safe to assume MainActor isolation here.
    private static let eventHandlerCallback: EventHandlerUPP = { _, _, userData in
        guard let userData else { return noErr }
        let owner = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
        MainActor.assumeIsolated {
            owner.handler?()
        }
        return noErr
    }
}

extension GlobalHotkey {
    /// Convenience: register Cmd+Shift+Space (the Crane default).
    @discardableResult
    func registerCommandShiftSpace(_ handler: @escaping () -> Void) -> Bool {
        register(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(cmdKey | shiftKey),
            handler: handler
        )
    }
}
