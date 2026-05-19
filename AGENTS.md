# StepCo Agent Notes

## Project Shape

This repo uses XcodeGen as the source of truth for the Xcode project.

- Edit `project.yml` for targets, schemes, Info.plist keys, capabilities, and build settings.
- Regenerate `StepCo.xcodeproj` with `nix run nixpkgs#just -- generate`.
- Do not hand-edit generated project files unless explicitly asked.

Targets:

- `StepCo`: iOS app
- `StepCoTests`: iOS XCTest unit-test bundle
- `StepCoWidget`: iOS WidgetKit extension
- `StepCoWatch`: watchOS app
- `StepCoWatchWidget`: watchOS WidgetKit complication/widget

Source layout:

- `StepCo/App`: iOS SwiftUI app views and app entry point
- `StepCo/WatchApp`: watchOS SwiftUI app views and app entry point
- `StepCo/Shared`: shared app/watch/widget model, HealthKit, pedometer, settings, tint, and cache code
- `StepCoWidget`: iOS WidgetKit widget
- `StepCoWatchWidget`: watchOS WidgetKit widget/complication
- `StepCoTests`: XCTest coverage for shared behavior

## Commands

Use `just` through Nix in this repo:

```sh
nix run nixpkgs#just -- --list
nix run nixpkgs#just -- generate
nix run nixpkgs#just -- test
nix run nixpkgs#just -- test-unit
nix run nixpkgs#just -- build
nix run nixpkgs#just -- run-sim
nix run nixpkgs#just -- run-sim-watch
nix run nixpkgs#just -- run-sim-paired
```

Recipes defined in the current `justfile`:

- `default`
- `generate`
- `test`
- `test-unit`
- `build`
- `build-iphone`
- `build-watch`
- `run-sim`
- `run-sim-iphone`
- `run-sim-watch`
- `run-sim-paired`

`run-sim-watch` expects a simulator named `Apple Watch Series 10 (46mm)`.
`run-sim-iphone` expects a simulator named `iPhone 16`.
`run-sim-paired` pairs/boots both named simulators and installs both the iOS app and watch app.

## Build Notes

The iOS build uses the generated `StepCo` scheme and builds into `.build/DerivedData`.

The watch build intentionally uses:

```sh
xcodebuild build -project StepCo.xcodeproj -target StepCoWatch -sdk watchsimulator SYMROOT=.build/XcodeProducts OBJROOT=.build/XcodeIntermediates
```

This avoids flaky destination resolution for watchOS simulator builds. Keep `run-sim-watch` aligned with `.build/XcodeProducts/Debug-watchsimulator/StepCoWatch.app`.

`run-sim-paired` installs the watch app from `.build/DerivedData/Build/Products/Debug-watchsimulator/StepCoWatch.app`, so keep that recipe aligned with the iOS scheme build output.

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

Core Motion live pedometer updates are used while the app is open to update today's step and distance totals on top of the HealthKit baseline.

On simulator, `StepRepository` uses `StepDemoData` instead of HealthKit.

Settings are historical. Changing target steps applies from today forward; past days use the settings snapshot active on that day.

Widgets read the latest cached `CachedStepSnapshot` from app group `group.com.nixypanda.StepCo`.
Widget reloads are throttled during live updates with a 60-second interval unless a refresh forces a reload.

## Known Caveats

`just test` runs platform-specific `swiftc -typecheck` checks for:

- iOS app
- iOS widget
- watch app
- watch widget

`just test-unit` runs the `StepCoTests` XCTest bundle through `xcodebuild test` on the `StepCo` scheme.

App group and HealthKit capabilities are declared in entitlements, but a real device/App Store build will still need the proper Apple developer team/capability setup.
