# crane

A floating capture bar for the thoughts you get *while* you're trying to focus on something else.

```
                    ⌘⇧Space
                       │
                       ▼
           ┌──────────────────────────────────────┐
           │  ✎  Drop your thought…       ↵ save  │
           └──────────────────────────────────────┘
                       │
                       │  Enter
                       ▼
                  (back to work)
```

---

## Why

You're three layers deep in a Figma file, or rereading a paragraph of a paper, or untangling a function that almost compiles, and your brain does the thing it always does:

> *"I should email Maya about Friday."*
> *"What was that link Jay sent me?"*
> *"Add a tag system to crane."*

Three options, all bad:

1. **Hold the thought.** Now you're juggling two things, and the original task is degraded.
2. **Switch apps to write it down properly** (Notes, Linear, a journal). The switch costs you the flow you were protecting in the first place. By the time the window is open, you've forgotten why you opened it.
3. **Let it go.** It comes back at 11pm, in the shower, three days later — the wrong moment, every time.

crane is the fourth option. A global ⌘⇧Space anywhere, a one-line capture pill in the upper third of your screen, hit Enter, the pill dismisses, you're back in your editor. Total elapsed time: roughly 2 seconds. The thought is yours to come back to on your own terms, on your own schedule — not the brain's.

The aim is **friction so low your "real" task barely notices the interruption.** No naming files, no choosing folders, no waiting for an Electron window to come up — just open, type, enter.

This is not a notes app. It's a *holding pen* between flow and proper capture. The history is meant to be skimmed at the end of a session and either acted on or discarded.

---

## What it does

- **⌘⇧Space, anywhere.** A 620×116pt panel (two-row capture pill + padding) drops in at the upper third of the active screen. The text field is already focused.
- **Type → Enter.** The drop is persisted. Pill dismisses with a quick checkmark blip.
- **⌘L toggles "link" mode.** A Thought / Link segment control appears; the URL is parsed and rendered as a clickable link in history.
- **⌘H opens history.** The same panel grows downward into a searchable list of every drop, newest-first, with per-row delete on hover.
- **Esc** dismisses the capture pill; in history, Esc returns to the pill (⌘⇧Space toggles the panel from anywhere).
- **Menu-bar dashboard** (the drop-shaped tray icon) gives you a glance at how the holding pen is doing: TOTAL / TODAY / STREAK cards, a 14-day activity sparkline, a thoughts-vs-links bar, and the three most recent drops.

No Dock icon. No Cmd-Tab entry. crane lives in your menu bar and behind a global keystroke.

---

## Install / Run

Requires macOS 26.4 (Tahoe) and Xcode 26 — we lean on `@Model` / `@Query` (SwiftData), Liquid Glass tokens, and `MenuBarExtra` features that landed in this era.

```bash
git clone https://github.com/abhay-cs/crane.git
cd crane
open crane.xcodeproj
# ⌘R in Xcode
```

There's no release artifact yet; building from source is the supported path.

**Issue tracker:** [issues.md](issues.md) — prioritized open/fixed items for MVP and v1.

---

## Keyboard

| Where | Combo | Action |
|---|---|---|
| Anywhere | ⌘⇧Space | Toggle the capture pill |
| Capture pill | ↵ | Save the drop, dismiss |
| Capture pill | ⌘L | Toggle link mode |
| Capture pill | ⌘H | Switch to history view |
| Capture pill | Esc | Dismiss |
| Capture pill or history | ⌘Q | Quit |
| History | ⌘F | Focus search |
| History | ⌫ on a row's × button | Delete that drop (with confirmation) |
| History | Esc | Back to capture pill (Esc again dismisses) |
| Menu-bar window | ⌘Q | Quit |

The global combo is registered via Carbon's `RegisterEventHotKey`, which works inside the App Sandbox without extra entitlements — see `crane/GlobalHotkey.swift`.

---

## Architecture

Full diagrams (context, layers, data flow, AI pipeline, module map): **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

New to the codebase? Story-style walkthrough with diagrams: **[docs/ONBOARDING.md](docs/ONBOARDING.md)**.

```
craneApp (SwiftUI scene + MenuBarExtra)
    │
    ├── AppDelegate ──── GlobalHotkey (⌘⇧Space)
    │       │
    │       └── OverlayController ──── NSPanel (borderless, .floating)
    │                                       │
    │                                       └── NSHostingView<ContentView>
    │                                               ├── DropInputBar
    │                                               └── HistoryView
    │
    └── DashboardView (menu-bar popover)
```

The capture pill and history list live inside the **same** borderless `NSPanel`, not separate windows. Switching between views animates the panel's frame downward from 620×116 (pill) to 620×480 (history) while the SwiftUI hierarchy cross-fades. That's why `OverlayController.applySize(for:animated:)` anchors to the top edge — so the pill stays put as the panel grows down into the list.

The menu-bar dashboard and the overlay panel point to **the same shared `ModelContainer`** (`Persistence.container`). That single source of truth is why a drop captured via ⌘⇧Space lights up the dashboard's TOTAL/TODAY/STREAK numbers and the recent list **live** — both surfaces consume drops via `@Query`.

### File map

| File | Responsibility |
|---|---|
| `craneApp.swift` | `@main` scene, `MenuBarExtra`, attaches the shared `ModelContainer`. |
| `AppDelegate.swift` | Hides the Dock icon (`.accessory`), owns the overlay panel, registers the global hotkey. |
| `GlobalHotkey.swift` | Carbon `RegisterEventHotKey` wrapper. Single combo, replaces previous. |
| `OverlayController.swift` | Owns the `NSPanel`, positions it on the active screen's upper third, resizes between input and history. |
| `OverlayPanel.swift` | Subclass of `NSPanel` that can become key, joins all spaces, has no chrome and no shadow. |
| `ContentView.swift` | Switches between `DropInputBar` and `HistoryView`; the capture pill itself. |
| `HistoryView.swift` | Search + scrollable list of drops. |
| `DashboardView.swift` | Menu-bar popover (stats, sparkline, type breakdown, recents). |
| `DropRow.swift` | Single-row presentation used by both `HistoryView` and `DashboardView`. |
| `Drop.swift` | `@Model final class Drop` — id (UUID), text, dropType, timestamp, sourceApp. |
| `Persistence.swift` | Single shared `ModelContainer` + one-time JSON-store migration. |
| `DropStats.swift` | `[Drop]` extension powering the dashboard's `todayCount`, `streakDays`, `dailyCounts(days:)`, `typeBreakdown`. |
| `Design.swift` | Motion, spacing, surface modifiers, specular border. |
| `CraneColors.swift` | Brand color tokens (`CraneInk`, `CraneCream`, `CraneThought`, `CraneLink`, …). |
| `CraneTypography.swift` | Instrument Serif + Geist + Geist Mono text styles. |
| `CraneButtonStyles.swift` | Primary / secondary button styles. |
| `CraneSectionHeader.swift` | Shared dashboard / history section headers. |
| `Fonts/` | Bundled Instrument Serif and Geist font files. |
| `CraneAlert.swift` | AppKit alerts for save failures, bad links, ephemeral store, hotkey registration. |
| `Drop+Link.swift` | Link normalization (`https://` prefix) and validation helpers. |
| `CraneSchema.swift` | SwiftData `CraneSchemaV1` + `CraneMigrationPlan` for forward-compatible migrations. |
| `SingleInstance.swift` | Prevents two crane processes from sharing one store. |

---

## Design system

crane shares the landing page brand: **electric blue** (`#2400FF`), **cream** (`#F7E6C8`), and an ink ladder that adapts to light/dark. Tokens live in `Design.swift`, `CraneColors.swift`, `CraneTypography.swift`, and `Assets.xcassets`.

### Color (adaptive)

| Asset | Light | Dark | Use |
|---|---|---|---|
| `CraneInk` | Near-black | Warm off-white | Body text, capture field |
| `CraneInkSecondary` | Muted gray | ~62% cream | Section labels, footer |
| `CraneInkTertiary` | Lighter gray | ~36% cream | Hints, meta, empty states |
| `CraneCream` | `#F7E6C8` | same | Specular edges, tag fills |
| `CraneSurface` | Elevated white | `#0E0E18` | Tint under `.regularMaterial` |
| `CraneThought` | Purple-gray | Lavender | Thought icons, chart segment |
| `CraneLink` | Blue | Sky blue | Links, chart segment |
| `AccentColor` | `#2400FF` | same | Actions, chart bars, mode segment |

Semantic colors replace the old `.primary` / `.secondary` ladder on branded surfaces. `Color.accentColor` remains the system accent hook.

### Motion

| Token | Curve | When |
|---|---|---|
| `Animation.craneSpring` | `spring(0.35, 0.82)` | Input ⇄ history, panel resize |
| `Animation.craneSnappy` | `spring(0.22, 0.86)` | Hover, mode segment, save flash |
| `Animation.craneSubtle` | `easeInOut(0.18s)` | Opacity fades |

### Surfaces

| Modifier | Material | Notes |
|---|---|---|
| `.craneOverlayShell()` | `.regularMaterial` + `CraneSurface` tint + specular | Capture pill, history card (hosts focused fields — **no** Liquid Glass) |
| `.craneCard()` | `.regularMaterial` + accent soft fill | Dashboard stat cards, count badges |
| `.craneInputRecess()` | `.regularMaterial` + ink 6% | Search field, shortcut keys |
| `.craneRowHighlight()` | `.regularMaterial` + `CraneThought` 12% | List row hover |

**Corner radii:** 22 (shell), 16 (cards), 10 (controls/chips), 8 (rows). All `.continuous`.

**Specular border:** cream gradient (dark) or ink gradient (light) at 0.5pt — reads as edge light, not outline. **No drop shadows.**

### Typography

| Role | Font | Size | Where |
|---|---|---|---|
| Capture input | Instrument Serif | 26 | `DropInputBar` |
| Display title | Instrument Serif | 18–20 | "crane", "Your Drops" |
| Stat numbers | Instrument Serif | 32 | Dashboard cards |
| UI body | Geist | 11–13 | Rows, search, tags |
| Shortcuts | Geist Mono | 10–11 | Hint row, footer |
| Caps labels | Geist Medium | 10 (+0.6 tracking) | TOTAL / TODAY / STREAK |

Fonts are bundled under `crane/Fonts/` (Instrument Serif, Geist, Geist Mono). Use `CraneFont.display(_:)`, `CraneFont.ui(_:weight:)`, or `.craneText(.body)`.

### Layout

- **Capture pill:** two rows (input + hints), panel **620×116**.
- **Dashboard:** scrollable **380×520** popover.
- **History:** date sections (Today / Yesterday / …) when not searching.

---

## Persistence

SwiftData. Single shared `ModelContainer` in `Persistence.container`, stored at:

```
~/Library/Application Support/com.abhaycs.crane/crane.store
```

(plus the usual `-shm` / `-wal` sidecars). The container is built lazily on first access on the main actor.

### Legacy import

If a `drops.json` from the pre-SwiftData era exists in the same directory, `Persistence.migrateLegacyJSONIfNeeded(...)` decodes it, inserts each row into the SwiftData store (preserving the original UUIDs), and renames the JSON file to `drops.json.migrated` so the import never runs twice. The import is best-effort: if it fails, the JSON is left in place for a future launch.

### Why the dashboard reflects writes from the overlay live

`craneApp.swift` applies `.modelContainer(Persistence.container)` to the `MenuBarExtra` scene, **and** `OverlayController.attach(rootView:)` applies the **same** container instance to the overlay's wrapped root view. One container, two surface trees. Every view that needs drops (`DashboardView`, `HistoryView`) consumes them via `@Query`, so a write from the pill triggers a `@Query` re-fetch in both surface trees automatically.

---

## Roadmap

These are slots the current code intentionally leaves open for, not promises:

- **AI daily digest card.** Tags ship via on-device FM; a digest summary card in the dashboard is still TBD.
- **Voice capture.** Push-to-talk via the same global combo, dictation into the same pill.
- **Source app attribution in history.** `Drop.sourceApp` is recorded at capture time; richer “captured from Figma” UI in rows is still TBD.
- **Per-drop tagging UI.** Once tags exist, a chip-row inside `DropRow` for filtering history.
- **iCloud sync** via SwiftData's CloudKit integration — currently off, intentionally; crane is single-device on purpose for now.

---

## Acknowledgements / design ancestors

The pill resting position (upper third), the keyboard-first ethos, and the "open, capture, dismiss" flow all come from Spotlight and Raycast. The "tiny menu-bar dashboard with one stat-card row" pattern comes from the better members of the menu-bar app genre (Stats, Bartender, Itsycal). The capture-as-holding-pen idea — separating the moment of *catching* a thought from the moment of *acting on* it — is the same instinct behind apps like Drafts and Things' Inbox; crane's contribution is to lean further into "the capture surface dismisses itself" so the cost of a capture rounds to zero.

If you build on top of crane or want a different tradeoff in the design system (denser pill, brighter material, larger corner radii), the tokens are all in `Design.swift` and the surface layouts each fit on one screen — start there.
