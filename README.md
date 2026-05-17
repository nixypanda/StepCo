# StepCo

Simple step tracking for iPhone and Apple Watch.

## What is here

- iOS app with Dashboard, Calendar, and Settings.
- HealthKit-backed step count and walking/running distance.
- Distance is displayed in kilometers only.
- Historical target-step settings.
- iOS WidgetKit widget using the latest cached step snapshot.
- watchOS app and accessory circular WidgetKit complication.

## Generate the Xcode project

This repository includes an XcodeGen manifest:

```sh
xcodegen generate
```

After generating, open `StepCo.xcodeproj`, set your development team, and enable these capabilities for the matching bundle identifiers:

- HealthKit for `StepCo` and `StepCoWatch`
- App Groups using `group.com.nixypanda.StepCo` for all targets

The current folder did not have an Xcode project or project generator installed, so the source tree and manifest are checked in directly.
