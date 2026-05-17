set shell := ["zsh", "-cu"]

project := "StepCo.xcodeproj"
iphone_scheme := "StepCo"
watch_scheme := "StepCoWatch"
derived_data := ".build/DerivedData"
build_products := ".build/XcodeProducts"
build_intermediates := ".build/XcodeIntermediates"
iphone_device := "iPhone 16"
watch_device := "Apple Watch Series 10 (46mm)"
ios_sdk := "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
watch_sdk := "/Applications/Xcode.app/Contents/Developer/Platforms/WatchOS.platform/Developer/SDKs/WatchOS.sdk"
module_cache := "/private/tmp/StepCoModuleCache"

default:
    @nix run nixpkgs#just -- --list

generate:
    nix run nixpkgs#xcodegen -- generate

build: build-iphone build-watch

build-iphone:
    xcodebuild build \
      -project "{{project}}" \
      -scheme "{{iphone_scheme}}" \
      -destination "platform=iOS Simulator,name={{iphone_device}}" \
      -derivedDataPath "{{derived_data}}"

build-watch:
    xcodebuild build \
      -project "{{project}}" \
      -target "{{watch_scheme}}" \
      -sdk watchsimulator \
      SYMROOT="{{build_products}}" \
      OBJROOT="{{build_intermediates}}"

test: test-iphone test-watch

test-iphone:
    mkdir -p "{{module_cache}}"
    swiftc -typecheck -parse-as-library \
      -module-cache-path "{{module_cache}}" \
      -target arm64-apple-ios17.0 \
      -sdk "{{ios_sdk}}" \
      StepCo/Shared/StepModels.swift \
      StepCo/Shared/StepSettingsStore.swift \
      StepCo/Shared/StepColorStyle.swift \
      StepCo/Shared/HealthKitStepStore.swift \
      StepCo/Shared/StepSnapshotCache.swift \
      StepCo/Shared/StepRepository.swift \
      StepCo/App/StepCoApp.swift \
      StepCo/App/ContentView.swift \
      StepCo/App/DashboardView.swift \
      StepCo/App/CalendarView.swift \
      StepCo/App/SettingsView.swift
    swiftc -typecheck \
      -module-cache-path "{{module_cache}}" \
      -target arm64-apple-ios17.0 \
      -sdk "{{ios_sdk}}" \
      StepCo/Shared/StepModels.swift \
      StepCo/Shared/StepColorStyle.swift \
      StepCo/Shared/StepSnapshotCache.swift \
      StepCoWidget/StepCoWidget.swift

test-watch:
    mkdir -p "{{module_cache}}"
    swiftc -typecheck -parse-as-library \
      -module-cache-path "{{module_cache}}" \
      -target arm64-apple-watchos10.0 \
      -sdk "{{watch_sdk}}" \
      StepCo/Shared/StepModels.swift \
      StepCo/Shared/StepSettingsStore.swift \
      StepCo/Shared/StepColorStyle.swift \
      StepCo/Shared/HealthKitStepStore.swift \
      StepCo/Shared/StepSnapshotCache.swift \
      StepCo/Shared/StepRepository.swift \
      StepCo/WatchApp/StepCoWatchApp.swift \
      StepCo/WatchApp/WatchDashboardView.swift
    swiftc -typecheck \
      -module-cache-path "{{module_cache}}" \
      -target arm64-apple-watchos10.0 \
      -sdk "{{watch_sdk}}" \
      StepCo/Shared/StepModels.swift \
      StepCo/Shared/StepColorStyle.swift \
      StepCo/Shared/StepSnapshotCache.swift \
      StepCoWatchWidget/StepCoWatchWidget.swift

run-sim: run-sim-iphone

run-sim-iphone: build-iphone
    xcrun simctl boot "{{iphone_device}}" || true
    open -a Simulator
    xcrun simctl install "{{iphone_device}}" "{{derived_data}}/Build/Products/Debug-iphonesimulator/StepCo.app"
    xcrun simctl launch "{{iphone_device}}" com.nixypanda.StepCo

run-sim-watch: build-watch
    if ! xcrun simctl list devices available | grep -q "{{watch_device}}"; then echo "No available watchOS simulator named {{watch_device}}"; exit 1; fi
    xcrun simctl boot "{{watch_device}}" || true
    open -a Simulator
    xcrun simctl install "{{watch_device}}" "{{build_products}}/Debug-watchsimulator/StepCoWatch.app"
    xcrun simctl launch "{{watch_device}}" com.nixypanda.StepCo.watchkitapp
