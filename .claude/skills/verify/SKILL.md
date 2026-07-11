---
name: verify
description: Build, launch, and observe crane (macOS menu-bar app) to verify changes at runtime.
---

# Verifying crane changes

## Build & launch

```bash
xcodebuild -project crane.xcodeproj -scheme crane -configuration Release -destination 'platform=macOS' build
# Run the binary directly (NOT `open`) so NSLog/stderr is capturable:
pkill -x crane; <DerivedData>/Build/Products/Release/crane.app/Contents/MacOS/crane 2>&1 &
```

`crane` is single-instance — always `pkill -x crane` before launching, or the
new process exits as a duplicate.

## Observing (headless-ish: no screen-recording / accessibility permission)

- `screencapture` and System Events UI scripting are **permission-blocked**
  for shell sessions. Don't burn time on them.
- Window geometry needs no permission — CGWindowList via a scratch Swift
  script filtering `kCGWindowOwnerName == "crane"` shows layer/bounds of the
  overlay (656×154 input, 656×516 history), onboarding card (520×236), and
  dashboard. Wrong sizes here catch Auto Layout ballooning (NSHostingView
  constraints drive panel frames).
- Unified log (`log show --predicate 'process == "crane"'`) shows nothing
  for this app; use direct-binary stderr instead.

## In-app runtime verifiers (the repo's sanctioned drive mechanism)

Env-gated modes in `AppDelegate` run real UI flows and exit with JSON results
— use these to drive behavior you can't reach without input synthesis:

```bash
scripts/test-overlay-glass.sh   # CRANE_VERIFY_OVERLAY_GLASS=1 — glass hosts
scripts/test-onboarding.sh      # CRANE_VERIFY_ONBOARDING=1 — first-run tour
```

Results JSON lands in the sandbox container:
`~/Library/Containers/com.abhaycs.crane/Data/Library/Application Support/com.abhaycs.crane/`.

New feature that can't be driven externally → add another env-gated verifier
following `OverlayGlassVerifier` / `OnboardingVerifier` + a `scripts/test-*.sh`.

## State

- Preferences live in the container plist:
  `defaults read ~/Library/Containers/com.abhaycs.crane/Data/Library/Preferences/com.abhaycs.crane`
  (e.g. `craneHasCompletedOnboarding`). Restore what you mutate.
- Drops store: `.../Application Support/com.abhaycs.crane/crane.store`.

## Gotchas

- Panels host SwiftUI via `NSHostingView` inside `CraneGlassHost` — a fully
  flexible SwiftUI root resizes the whole panel via Auto Layout; pin the root
  with an explicit `.frame(width:height:)`.
- Verification runs on the user's real display: panels flash on screen. Keep
  runs short.
