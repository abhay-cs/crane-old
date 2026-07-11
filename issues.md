# crane — issue tracker

Living document for MVP / v1. Update status as work lands.

**Status legend**

| Status | Meaning |
|--------|---------|
| ✅ Fixed | Shipped in codebase |
| 🔄 In progress | Actively being worked |
| ⏳ Open | Not started |
| 🚫 Won't fix (v1) | Explicitly deferred |
| 📋 Accepted | Known limitation, documented |

**Last updated:** 2026-07-10

---

## Changelog (tracker)

| Date | Change |
|------|--------|
| 2026-05-18 | Initial tracker created from code audits |
| 2026-05-18 | First hardening pass: save errors, links, alerts, delete confirm, streak, icons, `.gitignore`, README/landing |
| 2026-05-18 | **Must-fix pass:** `sourceApp` capture on open, post-save dismiss coalescing, single-instance guard, New Drop → `show()`, Esc in history → pill, `CraneSchemaV1` + migration plan, panel `visibleFrame` clamp |
| 2026-05-20 | **Production polish pass:** ephemeral JSON safety, store archive recovery, idempotent JSON merge, wired `CraneMigrationPlan`, flock lock, wake hotkey re-register, AI queue/UX, capture limits, delete rollback, fetch caps, combined launch alert, CI, privacy manifest |
| 2026-05-20 | **Re-audit fixes:** `DropStatistics` store-wide aggregates, `AITaggingCoordinator`, lock retry + alert, wake hotkey loss alert, history cap messaging, CI SDK gate |
| 2026-07-10 | **First-run onboarding (P2-21):** event-driven coach card tour in `crane/Onboarding/`, overlay show/hide + drop-saved notifications, Capture → Welcome Tour replay, `CRANE_VERIFY_ONBOARDING` runtime checks + `scripts/test-onboarding.sh` |

---

## P0 — Ship blockers

| ID | Issue | Status | Notes |
|----|--------|--------|-------|
| P0-01 | `sourceApp` recorded crane instead of host app | ✅ Fixed | Snapshot in `OverlayController.captureSourceApp()` before panel is key; used on submit |
| P0-02 | Post-save `asyncAfter` could dismiss a newly opened overlay | ✅ Fixed | `saveDismissGeneration` in `OverlayController.scheduleAfterSaveDismiss` / `cancelAfterSaveDismiss` |
| P0-03 | Two processes can corrupt shared `crane.store` | ✅ Fixed | `SingleInstance.shouldTerminateAsDuplicate()` in `applicationWillFinishLaunching` |
| P0-04 | macOS 26.4-only deployment | 📋 Accepted | Intentional for Tahoe / Liquid Glass stack; limits v1 audience |
| P0-05 | No SwiftData schema versioning | ✅ Fixed | `CraneMigrationPlan` wired in `Persistence.openDiskContainer`; add V2 + stage before model changes |

---

## P1 — High (fix before wide beta)

| ID | Issue | Status | Notes |
|----|--------|--------|-------|
| P1-01 | “New Drop” toggled hide when overlay already open | ✅ Fixed | Footer calls `showOverlay()` not `toggleOverlay()` |
| P1-02 | Esc in history inconsistently dismissed whole overlay | ✅ Fixed | `handleCancelKey()`: history → input; input → hide |
| P1-03 | Panel not clamped to `visibleFrame` | ✅ Fixed | `clampFrame(_:to:)` in `OverlayController` |
| P1-04 | Double-submit on rapid Enter | ✅ Fixed | Guard `saving` / `justSaved` until dismiss |
| P1-05 | Silent `try? modelContext.save()` | ✅ Fixed | `CraneAlert.presentSaveFailed` on failure |
| P1-06 | Corrupt store → in-memory with no warning | ✅ Fixed | `Persistence.isEphemeralStore` + launch alert |
| P1-07 | Hotkey registration failure invisible | ✅ Fixed | Alert on failed `RegisterEventHotKey` |
| P1-08 | Ephemeral store skips `drops.json` import | ✅ Fixed | Session import without renaming JSON; disk store merges on next good launch |
| P1-09 | Partial JSON migration can strand data | ✅ Fixed | Idempotent merge by UUID; JSON renamed only when all rows present on disk |
| P1-10 | Hotkey dies after sleep / wake | ✅ Fixed | Re-register on `NSWorkspace.didWakeNotification` in `AppDelegate` |
| P1-11 | Blocking modal alerts at launch | ✅ Fixed | `CraneAlert.presentLaunchWarnings` combines hotkey + ephemeral |
| P1-12 | `@Query` loads all drops in dashboard + history | ✅ Fixed | Lists capped at 5000; stats via `DropStatistics` + `fetchCount`; history shows cap notice |
| P1-13 | No maximum capture text length | ✅ Fixed | `Persistence.maxDropTextLength` (8192) enforced in `DropInputBar` |
| P1-14 | Delete fails after `modelContext.delete` | ✅ Fixed | `ModelContext.deleteDrop` rolls back on save failure |
| P1-15 | ⌘⇧Space still toggles (can hide while capturing) | 📋 Accepted | By design for global shortcut; “New Drop” uses `show()` only |

---

## P2 — Medium (polish & trust)

| ID | Issue | Status | Notes |
|----|--------|--------|-------|
| P2-01 | Link mode saved invalid / scheme-less URLs | ✅ Fixed | `Drop+Link.swift` normalize + validate |
| P2-02 | Legacy link rows may not render as clickable | ✅ Fixed | `Drop.linkURL(for:)` normalizes + validates on read |
| P2-03 | No delete confirmation | ✅ Fixed | `confirmationDialog` on `DropRow` |
| P2-04 | Dashboard delete had no animation | ✅ Fixed | `withAnimation` on delete |
| P2-05 | Dashboard recent tap didn’t focus drop | ✅ Fixed | `scrollToDropID` + `ScrollViewReader` |
| P2-06 | Streak reset harshly when no drop today | ✅ Fixed | Count from last active day; label still ambiguous |
| P2-07 | Streak label doesn’t explain “as of” date | ✅ Fixed | “last active day” subtitle when today has no drop |
| P2-08 | Hint chips may clip on capture pill | ✅ Fixed | Horizontal `ScrollView` for hint row |
| P2-09 | `confirmationDialog` from menu-bar window | ⏳ Open | Test sheet placement on hardware |
| P2-10 | Same `scrollToDropID` doesn’t re-scroll | ✅ Fixed | `scrollToken` bumped on each `openHistory` |
| P2-11 | History search ignores `sourceApp` | ✅ Fixed | Filter includes `sourceApp` |
| P2-12 | README / marketing dimension drift | ✅ Fixed | 620×88 documented |
| P2-13 | Empty `AppIcon.appiconset` | ✅ Fixed | PNGs generated from `AppIcon.svg` |
| P2-14 | No `.gitignore` | ✅ Fixed | Root `.gitignore` |
| P2-15 | Landing “Download” without artifact | ✅ Fixed | CTAs → GitHub build instructions |
| P2-16 | No ⌘Q from overlay | ✅ Fixed | Hidden shortcut in `ContentView` |
| P2-17 | Display layout change while open | ✅ Fixed | `didChangeScreenParametersNotification` |
| P2-18 | Draft text survived panel-level Esc | ✅ Fixed | `inputResetToken` on hide |
| P2-19 | Invalid link / save errors use blocking `NSAlert` | ⏳ Open | Prefer inline pill error for flow |
| P2-20 | No launch at login | ⏳ Open | Expected for menu-bar MVP |
| P2-21 | No first-run onboarding | ✅ Fixed | First-launch coach card tour (`crane/Onboarding/`); advances as user performs each step; replay via Capture → Welcome Tour |
| P2-22 | `REGISTER_APP_GROUPS` without group | ✅ Fixed | Set to `NO` in project |
| P2-23 | Empty copyright in Info.plist | ✅ Fixed | Set in `project.pbxproj` |
| P2-24 | Menu bar icon uses template SVG | 📋 Accepted | Verify light menu bar + increased contrast |

---

## P3 — Low / v1.1+

| ID | Issue | Status | Notes |
|----|--------|--------|-------|
| P3-01 | Hotkey remapping UI | 🚫 Won't fix (v1) | User-requested deferral |
| P3-02 | Export / backup | 🚫 Won't fix (v1) | User-requested deferral |
| P3-03 | iCloud sync | 🚫 Won't fix (v1) | Roadmap |
| P3-04 | AI tags / daily digest | ✅ Fixed (tags) / 🚫 (digest) | On-device tagging ships; digest UI deferred |
| P3-05 | Voice capture | 🚫 Won't fix (v1) | Roadmap |
| P3-06 | Per-drop tagging UI | 🚫 Won't fix (v1) | Roadmap |
| P3-07 | Undo delete | ⏳ Open | Confirm dialog only for now |
| P3-08 | Clear all / archive history | ⏳ Open | |
| P3-09 | Automated unit / UI tests | 🔄 In progress | Sources in `craneTests/`; add Xcode unit-test target to run |
| P3-10 | CI pipeline | ✅ Fixed | `.github/workflows/ci.yml` builds on push/PR |
| P3-11 | Crash reporting | ⏳ Open | Privacy-first; optional opt-in later |
| P3-12 | Privacy manifest (`PrivacyInfo.xcprivacy`) | ✅ Fixed | Bundled in app target |
| P3-13 | Localization | ⏳ Open | English only |
| P3-14 | VoiceOver / accessibility pass | ⏳ Open | Hidden shortcuts hurt discoverability |
| P3-15 | `DateFormatter` alloc per row render | ✅ Fixed | Static formatter on `DropRow` |
| P3-16 | Activity chart DST edge cases | ⏳ Open | Rare duplicate-day display |
| P3-17 | Richer `sourceApp` UI in rows | ⏳ Open | Shows name; icon/bundle ID later |
| P3-18 | `ENABLE_PREVIEWS` in Release | ✅ Fixed | `ENABLE_PREVIEWS = NO` in Release config |
| P3-19 | Hardcoded `DEVELOPMENT_TEAM` in Xcode project | 📋 Accepted | Contributors retarget team |
| P3-20 | Notarized / signed release distribution | ⏳ Open | Build from source only today |
| P3-21 | Sparkle / auto-update | ⏳ Open | Post-v1 |
| P3-22 | ⌘⇧Space conflicts with other apps | 📋 Accepted | Document conflict; remap deferred (P3-01) |

---

## Manual QA checklist (v1 sign-off)

- [ ] Capture from Safari → `sourceApp` shows Safari (not crane)
- [ ] Save → ⌘⇧Space within 250ms → overlay stays usable
- [ ] Launch second instance → first activates, second exits
- [ ] Footer “New Drop” while history open → input pill, not hide
- [ ] History → Esc → pill; Esc again → dismiss
- [ ] Small display / external monitor → panel fully visible
- [ ] Sleep → wake → ⌘⇧Space still works
- [ ] 500+ drops → dashboard + history performance *(capped at 5000 fetch)*
- [ ] Corrupt `crane.store` + `drops.json` → recovery path
- [ ] Delete from menu-bar recent → confirm sheet OK *(P2-09)*

---

## File map (fix-related)

| File | Role |
|------|------|
| `crane/SingleInstance.swift` | P0-03 flock + duplicate process guard |
| `crane/CraneSchema.swift` | P0-05 versioned schema v1 |
| `crane/OverlayController.swift` | P0-01/02, P1-01/02/03, P2-10, layout |
| `crane/ContentView.swift` | P0-02, P1-13, capture submit |
| `crane/Persistence.swift` | P0-05, P1-06/08/09, migration |
| `crane/CraneAlert.swift` | P1-05–07/11, P2-19 (save still modal) |
| `crane/ModelContext+DropDeletion.swift` | P1-14 delete rollback |
| `crane/AppDelegate.swift` | P1-10 wake hotkey |
| `crane/AI/AIJobQueue.swift` | AI queue stall + `aiTaggingFailed` |
| `crane/AI/AITaggingCoordinator.swift` | FM availability → backfill on activate |
| `crane/DropStatistics.swift` | Store-wide dashboard stats (uncapped totals) |
| `crane/Drop+Link.swift` | P2-01/02 |
| `crane/DropRow.swift` | P2-03, P3-15, tagging failure UI |
| `crane/PrivacyInfo.xcprivacy` | P3-12 |
| `craneTests/` | P3-09 unit test sources |
| `.github/workflows/ci.yml` | P3-10 |
| `issues.md` | This tracker |

---

## How to update this file

1. Pick an **ID** from the tables above.
2. Implement the fix on a branch.
3. Change status to ✅ Fixed and add a row under **Changelog**.
4. If deferring, use 🚫 or 📋 and note why in **Notes**.
