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

- **⌘⇧Space, anywhere.** A 620×88pt panel (64pt capture pill + padding) drops in at the upper third of the active screen. The text field is already focused.
- **Type → Enter.** The drop is persisted. Pill dismisses with a quick checkmark blip.
- **⌘L toggles "link" mode.** A `LINK` badge appears; the URL is parsed and rendered as a clickable link in history.
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
| History | ⌫ on a row's × button | Delete that drop (with confirmation) |
| History | Esc | Back to capture pill (Esc again dismisses) |
| Menu-bar window | ⌘Q | Quit |

The global combo is registered via Carbon's `RegisterEventHotKey`, which works inside the App Sandbox without extra entitlements — see `crane/GlobalHotkey.swift`.

---

## Architecture

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

The capture pill and history list live inside the **same** borderless `NSPanel`, not separate windows. Switching between views animates the panel's frame downward from 620×88 (pill) to 620×480 (history) while the SwiftUI hierarchy cross-fades. That's why `OverlayController.applySize(for:animated:)` anchors to the top edge — so the pill stays put as the panel grows down into the list.

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
| `Design.swift` | All shared design tokens: motion, corner radius, specular border. |
| `CraneAlert.swift` | AppKit alerts for save failures, bad links, ephemeral store, hotkey registration. |
| `Drop+Link.swift` | Link normalization (`https://` prefix) and validation helpers. |
| `CraneSchema.swift` | SwiftData `CraneSchemaV1` + `CraneMigrationPlan` for forward-compatible migrations. |
| `SingleInstance.swift` | Prevents two crane processes from sharing one store. |

---

## Design system

crane is built to feel like *one* coordinated surface, not a bag of views. Three shared tokens carry that: one motion language, one corner radius, one edge highlight. All three live in `Design.swift`.

### Motion

| Token | Curve | When |
|---|---|---|
| `Animation.craneSpring` | `spring(response: 0.35, dampingFraction: 0.82)` | Big transitions: input ⇄ history, panel resize. |
| `Animation.craneSnappy` | `spring(response: 0.22, dampingFraction: 0.86)` | Hover, press, link-mode badge, save checkmark — fast and confident. |
| `Animation.craneSubtle` | `easeInOut(duration: 0.18)` | Plain opacity fades. |

Two springs, not five. Anything bigger than a hover uses `craneSpring`; anything smaller uses `craneSnappy`. If a third spring is ever tempting, it's probably the wrong scale somewhere else.

### Surfaces

| Surface | Material | Rationale |
|---|---|---|
| Capture pill (`DropInputBar`) | `.regularMaterial` in a `RoundedRectangle(cornerRadius: 22)` | Hosts a focused `TextField`. macOS 26 Liquid Glass paints a soft focus halo around any `.glassEffect()` surface containing a focused descendant in the key window, and there is no public API to opt out. We trade the dynamic Liquid Glass for `NSVisualEffectView`'s `.regularMaterial`, which looks 95% the same and never haloes. |
| History card (`HistoryView`) | `.regularMaterial` in a `RoundedRectangle(cornerRadius: 22)` | Same reason — hosts the focused search field. |
| Search field (inner) | `.regularMaterial` + a 6%-tinted overlay | Subtle visual recess, no halo. |
| Dashboard `StatCard` | `.glassEffect(.regular.tint(accent at 6%))` in `RoundedRectangle(cornerRadius: 16)` | No focused descendant — Liquid Glass is safe here, and the dynamic ambient sampling looks great over the dashboard's blurred backdrop. |
| `DropRow` (hover) | `.glassEffect(.regular.tint(accent at 8%))` in `RoundedRectangle(cornerRadius: 8)` | Tiny lit-up feel on hover; transient, never focused. |

**Corner radius:** `DesignMetrics.surfaceCornerRadius = 22` for primary surfaces (pill, history card). 16 for stat cards, 10 for the inner search pill, 8 for row hover, 4 for hint chips and the LINK badge. Always `.continuous` — never `.circular` — because continuous corners look right at every scale.

**Specular border:** every primary surface gets `.specularBorder(...)`, a 0.5pt linear-gradient stroke from white-at-22% in the top-leading corner to white-at-4% bottom-trailing. It gives the surface a felt edge without an outline — the trick is that the gradient is dimmer than the material itself almost everywhere, so it reads as a *highlight* on the lit side of glass rather than a *border*.

**No drop shadows.** We tried `.shadow(radius: 30, y: 16)` and it got clipped at the panel boundary, leaving a visible rounded rectangle around the pill. The material + specular border carry the depth on their own.

### Typography

A single SF system stack, six scale steps, three weights. Tracking is set on the larger sizes only.

| Role | Size / weight | Tracking | Where |
|---|---|---|---|
| Capture input | 24 regular | −0.2 | The pill itself (`DropInputBar` `TextField`). |
| Pill icon | 20 medium | — | `square.and.pencil` / `link` / checkmark. |
| Section title | 15 semibold | −0.2 | "Your Drops", "Crane" header. |
| Pill icon (back) | 13 medium | — | History back arrow. |
| Body | 13 regular | — | `DropRow` text, search field. |
| Search icon / row icon | 12 medium | — | Magnifying glass, link/thought leading icons in rows. |
| Inline meta | 11 medium | — | Drop count badge, relative time. |
| Inline meta (regular) | 11 regular | — | Hint chip labels ("save", "dismiss", "history"). |
| Inline meta (semibold) | 11 semibold | 0.4 | Section headers ("Activity", "Recent"). |
| Stat number | 28 semibold (`.rounded`) | — | Dashboard TOTAL / TODAY / STREAK. |
| Caps label | 10 medium | 0.6 | "TOTAL" / "TODAY" / "STREAK", LINK badge, footer shortcuts. |

Three principles fall out of the table:

1. **Tighten tracking as size grows.** Anything 15pt or larger gets `−0.2` to feel intentional. Anything 10pt with an all-caps label gets `+0.6` because tiny letterforms need air.
2. **Weight, not color, carries hierarchy on text.** Most labels stay at `regular` or `medium`; `semibold` is reserved for headings and stat numbers; `bold` is unused.
3. **The pill's 24pt input is the only place anything gets large.** It's the single moment of "this is where you type" — every other surface stays quiet.

Foreground style follows SwiftUI's semantic ladder: `.primary` for the input and stat numbers, `.secondary` for headings and chip text, `.tertiary` for relative time, hint labels, and empty-state copy. `.accentColor` shows up only on the LINK badge, the save checkmark, the sparkline bars, and the thoughts color of the type-breakdown bar.

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

- **AI-extracted tags + daily digest.** `DashboardView` has a documented empty slot between the type-breakdown and the recent list, sized for a tag-chip row and a digest card. The plan is to extract tags from drops with an LLM (locally, ideally) and surface them so the holding pen becomes self-organising over time.
- **Voice capture.** Push-to-talk via the same global combo, dictation into the same pill.
- **Source app attribution in history.** `Drop.sourceApp` is recorded at capture time; richer “captured from Figma” UI in rows is still TBD.
- **Per-drop tagging UI.** Once tags exist, a chip-row inside `DropRow` for filtering history.
- **iCloud sync** via SwiftData's CloudKit integration — currently off, intentionally; crane is single-device on purpose for now.

---

## Acknowledgements / design ancestors

The pill resting position (upper third), the keyboard-first ethos, and the "open, capture, dismiss" flow all come from Spotlight and Raycast. The "tiny menu-bar dashboard with one stat-card row" pattern comes from the better members of the menu-bar app genre (Stats, Bartender, Itsycal). The capture-as-holding-pen idea — separating the moment of *catching* a thought from the moment of *acting on* it — is the same instinct behind apps like Drafts and Things' Inbox; crane's contribution is to lean further into "the capture surface dismisses itself" so the cost of a capture rounds to zero.

If you build on top of crane or want a different tradeoff in the design system (denser pill, brighter material, larger corner radii), the tokens are all in `Design.swift` and the surface layouts each fit on one screen — start there.
