# crane — system architecture

macOS menu-bar capture app: **⌘⇧Space** → type a thought or link → **Enter** → back to work. Drops live in SwiftData; the dashboard and overlay share one store.

---

## 1. System context

```mermaid
flowchart TB
    subgraph User["User"]
        KB[Keyboard / mouse]
    end

    subgraph macOS["macOS"]
        MB[Menu bar]
        FS[Frontmost app e.g. Xcode]
        AI[Apple Intelligence / Foundation Models]
    end

    subgraph Crane["crane.app"]
        APP[crane process]
    end

    subgraph Disk["~/Library/Application Support/com.abhaycs.crane/"]
        STORE[(crane.store)]
        LEGACY[(drops.json — migrated once)]
    end

    KB -->|⌘⇧Space| APP
    KB --> FS
    APP --> MB
    APP --> FS
    APP -->|read/write| STORE
    APP -->|one-time import| LEGACY
    APP -->|on-device tagging| AI
```

| Boundary | Notes |
|----------|--------|
| **Activation** | `.accessory` — no Dock icon, no Cmd-Tab |
| **Sandbox** | App Sandbox; global hotkey via Carbon `RegisterEventHotKey` |
| **Single instance** | `SingleInstance` exits duplicate processes |
| **Persistence** | SwiftData `ModelContainer` at `crane.store` |

---

## 2. Layered architecture

```mermaid
flowchart TB
    subgraph Presentation["Presentation (SwiftUI + AppKit)"]
        MBE[MenuBarExtra / DashboardView]
        OVL[Overlay NSPanel / ContentView]
    end

    subgraph Application["Application / coordination"]
        AD[AppDelegate]
        OC[OverlayController]
        GH[GlobalHotkey]
    end

    subgraph Domain["Domain & UI helpers"]
        DR[Drop / DropType]
        DS[DropStats / DropHistoryGrouping]
        DL[Drop+Link validation]
        DSYS[Design / CraneColors / CraneTypography]
    end

    subgraph Infrastructure["Infrastructure"]
        PER[Persistence]
        SCH[CraneSchema / migrations]
        AL[CraneAlert]
        SI[SingleInstance]
    end

    subgraph AI["AI (async, non-blocking)"]
        Q[AIJobQueue]
        FM[FoundationModelsService]
        TE[TagExtractor]
    end

    MBE --> PER
    OVL --> OC
    OVL --> PER
    AD --> OC
    AD --> GH
    AD --> Q
    OVL -->|save drop| PER
    OVL -->|enqueue| Q
    Q --> FM
    FM --> TE
    PER --> DR
    SCH --> PER
```

---

## 3. Runtime component graph

```mermaid
flowchart LR
    subgraph Entry["@main"]
        CA[craneApp]
    end

    subgraph Delegate["AppKit bridge"]
        AD[AppDelegate]
        HK[GlobalHotkey]
    end

    subgraph OverlayStack["Floating overlay"]
        OC[OverlayController]
        OP[OverlayPanel]
        CV[ContentView]
        DIB[DropInputBar]
        HV[HistoryView]
    end

    subgraph MenuBar["Menu bar window"]
        DV[DashboardView]
        TTS[TopTagsSection]
    end

    subgraph Shared["Shared"]
        PC[(Persistence.container)]
        ENV[OverlayController @Environment]
    end

    CA --> AD
    CA --> DV
    CA --> PC
    AD --> HK
    AD --> OC
    OC --> OP
    OC --> CV
    CV --> DIB
    CV --> HV
    DV --> PC
    OC -->|attach + .modelContainer| PC
    DIB --> ENV
    HV --> ENV
    DV -->|Footer / chips| AD
```

**Two UI trees, one database:** `MenuBarExtra` and `NSHostingView<ContentView>` both use `Persistence.container`, so `@Query` updates propagate instantly across surfaces.

---

## 4. Overlay UI state machine

```mermaid
stateDiagram-v2
    [*] --> Hidden: launch
    Hidden --> Input: show() / ⌘⇧Space
    Input --> Hidden: Esc / dismiss after save
    Input --> History: ⌘H
    History --> Input: Esc
    History --> Hidden: Esc from input-equivalent / toggle
    Input --> Input: save flash then dismiss
```

| State | Panel size | SwiftUI root |
|-------|------------|--------------|
| **Input** | 620×116 | `DropInputBar` |
| **History** | 620×480 | `HistoryView` |

`OverlayController.applySize` anchors the **top** of the panel so growth is downward. `inputResetToken` clears the capture field on dismiss.

---

## 5. Data model & persistence

```mermaid
erDiagram
    Drop {
        UUID id PK
        string text
        DropType dropType
        Date timestamp
        string sourceApp "optional"
        string-array tags
        Date aiProcessedAt "optional"
    }
```

```mermaid
flowchart LR
    subgraph WritePath["Write path"]
        CAP[DropInputBar.submit]
        CTX[ModelContext.insert]
        SAVE[modelContext.save]
    end

    subgraph ReadPath["Read path"]
        Q["@Query Drop"]
        DASH[DashboardView]
        HIST[HistoryView]
    end

    CAP --> CTX --> SAVE
    SAVE --> STORE[(crane.store)]
    STORE --> Q
    Q --> DASH
    Q --> HIST
```

| Module | Role |
|--------|------|
| `Drop.swift` | `@Model` entity |
| `CraneSchema.swift` | `CraneSchemaV1`, `CraneMigrationPlan` |
| `Persistence.swift` | Container factory, JSON migration, recovery / ephemeral fallback |
| `DropStats.swift` | `todayCount`, `streakDays`, `dailyCounts`, `typeBreakdown`, `topTags` |
| `DropHistoryGrouping.swift` | Today / Yesterday / date sections for history |

---

## 6. Capture flow (sequence)

```mermaid
sequenceDiagram
    participant U as User
    participant HK as GlobalHotkey
    participant AD as AppDelegate
    participant OC as OverlayController
    participant UI as DropInputBar
    participant SD as SwiftData
    participant Q as AIJobQueue

    U->>HK: ⌘⇧Space
    HK->>AD: toggleOverlay()
    AD->>OC: show()
    OC->>OC: captureSourceApp() before key
    OC->>UI: focus capture field

    U->>UI: type + Enter
    UI->>SD: insert Drop
    UI->>Q: enqueue(dropID)
    UI->>OC: dismiss after save flash
    Note over Q: serial FM tagging, later
    Q->>SD: update tags + aiProcessedAt
```

**Link mode:** `Drop+Link` normalizes URLs; invalid input shows `LinkValidationHint` without saving.

**Mirror field:** `CaptureMirrorField` uses a clear `TextField` + visible `Text` overlay (AppKit glyphs unreliable in transparent panel).

---

## 7. AI tagging pipeline

```mermaid
flowchart LR
    subgraph Trigger["Triggers"]
        SAVE[New drop saved]
        BF[Backfill on launch +8s]
    end

    subgraph Queue["AIJobQueue @MainActor"]
        ENQ[pending UUIDs]
        DRAIN[serial drain]
        CD[cooldown on provider crash]
    end

    subgraph Service["FoundationModelsService"]
        AVAIL[tagAvailability]
        FM[SystemLanguageModel contentTagging]
        GEN[@Generable DropTagsResult]
    end

    SAVE --> ENQ
    BF --> ENQ
    ENQ --> DRAIN
    DRAIN --> FM
    FM --> GEN
    GEN -->|tags on Drop| SD[(SwiftData)]
```

| File | Responsibility |
|------|----------------|
| `AIService.swift` | Protocol + `AIAvailability` |
| `FoundationModelsService.swift` | Apple Intelligence adapter |
| `TagExtractor.swift` | Prompt / post-processing |
| `AIJobQueue.swift` | Queue, rate limit, crash cooldown |
| `TopTagsSection.swift` | Dashboard “Top Tags” + skeleton / unavailable UI |

Tagging **never blocks** capture; failures set `aiProcessedAt` with empty tags.

---

## 8. Design system (cross-cutting)

```mermaid
flowchart TB
    subgraph Assets["Assets.xcassets"]
        COL[CraneInk / Cream / Thought / Link / Surface / Accent]
        ICO[AppIcon + MenuBarIcon]
    end

    subgraph Code["Swift modules"]
        CC[CraneColors]
        TY[CraneTypography + Fonts/]
        DS[Design.swift modifiers]
        BS[CraneButtonStyles]
    end

    subgraph Surfaces["Surface modifiers"]
        OS[craneOverlayShell]
        CD[craneCard]
        IR[craneInputRecess]
        RH[craneRowHighlight]
    end

    COL --> CC
    TY --> Views
    CC --> Views
    DS --> OS & CD & IR & RH
    BS --> Views
```

---

## 9. Repository layout

```
crane/                          # Xcode target (Swift app)
├── craneApp.swift              # @main MenuBarExtra
├── AppDelegate.swift           # Hotkey, overlay, lifecycle
├── GlobalHotkey.swift          # Carbon hotkey
├── SingleInstance.swift        # Duplicate guard
├── OverlayController.swift     # Panel logic + state
├── OverlayPanel.swift          # NSPanel subclass
├── ContentView.swift           # Input ↔ history switch + capture pill
├── HistoryView.swift           # Searchable drop list
├── DashboardView.swift         # Menu-bar dashboard
├── Drop.swift / Drop+Link.swift
├── DropRow.swift / DropStats.swift / DropHistoryGrouping.swift
├── Persistence.swift / CraneSchema.swift
├── CraneAlert.swift
├── Design.swift / CraneColors.swift / CraneTypography.swift
├── CraneButtonStyles.swift / CraneSectionHeader.swift
├── EmptyStateView.swift / TagChip.swift / TopTagsSection.swift
├── AI/                         # On-device tagging
├── Assets.xcassets/            # Colors + icons
└── Fonts/                      # Instrument Serif, Geist

landing/                        # Marketing site (static HTML/CSS/JS)
icons/                          # Logo explorations (wingspan = production)
docs/                           # This document
issues.md                       # Prioritized tracker
```

---

## 10. External dependencies

| Framework | Use |
|-----------|-----|
| **SwiftUI** | All UI |
| **SwiftData** | Persistence, `@Query`, `@Model` |
| **AppKit** | `NSPanel`, `NSApplication`, alerts, activation |
| **Charts** | Dashboard activity sparkline |
| **FoundationModels** | Apple Intelligence tagging |
| **Carbon** | `RegisterEventHotKey` |
| **os** | Logging |

---

## 11. Related docs

- [README.md](../README.md) — product overview, keyboard map, design tokens
- [issues.md](../issues.md) — open bugs and QA checklist
