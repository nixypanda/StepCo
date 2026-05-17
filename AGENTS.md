# StepCo Agent Notes

## Project Shape

This repo uses XcodeGen as the source of truth for the Xcode project.

- Edit `project.yml` for targets, schemes, Info.plist keys, capabilities, and build settings.
- Regenerate `StepCo.xcodeproj` with `nix run nixpkgs#just -- generate`.
- Do not hand-edit generated project files unless explicitly asked.

Targets:

- `StepCo`: iOS app
- `StepCoWidget`: iOS WidgetKit extension
- `StepCoWatch`: watchOS app
- `StepCoWatchWidget`: watchOS WidgetKit complication/widget

Shared app/watch/widget model code lives in `StepCo/Shared`.

## Commands

Use `just` through Nix in this repo:

```sh
nix run nixpkgs#just -- --list
nix run nixpkgs#just -- generate
nix run nixpkgs#just -- test
nix run nixpkgs#just -- build
nix run nixpkgs#just -- run-sim
nix run nixpkgs#just -- run-sim-watch
```

Verified working as of the last handoff:

- `default`
- `generate`
- `test`
- `test-iphone`
- `test-watch`
- `build`
- `build-iphone`
- `build-watch`
- `run-sim`
- `run-sim-iphone`
- `run-sim-watch`

`run-sim-watch` expects a simulator named `Apple Watch Series 10 (46mm)`.
`run-sim-iphone` expects a simulator named `iPhone 16`.

## Build Notes

The iOS build uses the generated `StepCo` scheme and builds into `.build/DerivedData`.

The watch build intentionally uses:

```sh
xcodebuild build -project StepCo.xcodeproj -target StepCoWatch -sdk watchsimulator SYMROOT=.build/XcodeProducts OBJROOT=.build/XcodeIntermediates
```

This avoids flaky destination resolution for watchOS simulator builds. Keep `run-sim-watch` aligned with `.build/XcodeProducts/Debug-watchsimulator/StepCoWatch.app`.

## Important Plist/Manifest Details

XcodeGen regenerates Info.plists. Required keys must live in `project.yml`, not only in the plist files.

Watch app install requires:

- `WKApplication: true`
- `WKCompanionAppBundleIdentifier: com.nixypanda.StepCo`

Widget install requires:

- `NSExtension.NSExtensionPointIdentifier: com.apple.widgetkit-extension`

HealthKit usage strings also live in `project.yml`.

## Product Decisions

- Dashboard uses a horizontal `ProgressView`, not the large circular mockup ring.
- UI should stay close to native SwiftUI defaults: `TabView`, `NavigationStack`, `Form`, `ScrollView`, `ProgressView`, `Gauge`, system colors/icons.
- Distance is kilometers only.
- Color logic:
  - `< half goal`: red
  - `>= half goal && < goal`: orange
  - `>= goal`: green

## Current Data Model

HealthKit is used for:

- `stepCount`
- `distanceWalkingRunning`

Settings are historical. Changing target steps or leeway applies from today forward; past days use the settings snapshot active on that day.

Widgets read the latest cached `CachedStepSnapshot` from app group `group.com.nixypanda.StepCo`.

## Known Caveats

There are no XCTest targets yet. `just test` currently runs platform-specific `swiftc -typecheck` checks for:

- iOS app
- iOS widget
- watch app
- watch widget

App group and HealthKit capabilities are declared in entitlements, but a real device/App Store build will still need the proper Apple developer team/capability setup.
