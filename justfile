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
test_sources := "/private/tmp/StepCoTestSources"

default:
    @nix run nixpkgs#just -- --list

generate:
    nix run nixpkgs#xcodegen -- generate

build: build-iphone build-watch

build-iphone:
    xcodebuild build \
      -project "{{project}}" \
      -scheme "{{iphone_scheme}}" \
      -configuration Debug \
      -destination "platform=iOS Simulator,name={{iphone_device}}" \
      -derivedDataPath "{{derived_data}}"

build-watch:
    xcodebuild build \
      -project "{{project}}" \
      -target "{{watch_scheme}}" \
      -sdk watchsimulator \
      SYMROOT="{{build_products}}" \
      OBJROOT="{{build_intermediates}}"

test:
    mkdir -p "{{module_cache}}"
    mkdir -p "{{test_sources}}"
    find StepCo/Shared StepCo/App -name "*.swift" -print | sort > "{{test_sources}}/iphone-app"
    swiftc -typecheck -parse-as-library \
      -module-cache-path "{{module_cache}}" \
      -target arm64-apple-ios17.0 \
      -sdk "{{ios_sdk}}" \
      @"{{test_sources}}/iphone-app"
    find StepCoWidget -name "*.swift" -print | sort > "{{test_sources}}/iphone-widget"
    printf "%s\n" \
      StepCo/Shared/StepModels.swift \
      StepCo/Shared/StepColorStyle.swift \
      StepCo/Shared/StepSnapshotCache.swift \
      StepCo/Shared/StepDemoData.swift >> "{{test_sources}}/iphone-widget"
    swiftc -typecheck \
      -module-cache-path "{{module_cache}}" \
      -target arm64-apple-ios17.0 \
      -sdk "{{ios_sdk}}" \
      @"{{test_sources}}/iphone-widget"
    find StepCo/Shared StepCo/WatchApp -name "*.swift" -print | sort > "{{test_sources}}/watch-app"
    swiftc -typecheck -parse-as-library \
      -module-cache-path "{{module_cache}}" \
      -target arm64-apple-watchos10.0 \
      -sdk "{{watch_sdk}}" \
      @"{{test_sources}}/watch-app"
    find StepCoWatchWidget -name "*.swift" -print | sort > "{{test_sources}}/watch-widget"
    printf "%s\n" \
      StepCo/Shared/StepModels.swift \
      StepCo/Shared/StepColorStyle.swift \
      StepCo/Shared/StepSnapshotCache.swift \
      StepCo/Shared/StepDemoData.swift >> "{{test_sources}}/watch-widget"
    swiftc -typecheck \
      -module-cache-path "{{module_cache}}" \
      -target arm64-apple-watchos10.0 \
      -sdk "{{watch_sdk}}" \
      @"{{test_sources}}/watch-widget"

test-unit:
    xcodebuild test \
      -project "{{project}}" \
      -scheme "{{iphone_scheme}}" \
      -destination "platform=iOS Simulator,name={{iphone_device}}" \
      -derivedDataPath "{{derived_data}}"

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

format:
    nix run nixpkgs#swift-format -- \
      --configuration .swift-format.json \
      --in-place \
      --recursive \
      .

lint:
    nix run nixpkgs#swift-format -- \
      --configuration .swift-format.json \
      --recursive \
      --strict \
      .

run-sim-paired: build-iphone
    xcrun simctl pair "{{iphone_device}}" "{{watch_device}}" > /dev/null || true
    xcrun simctl boot "{{iphone_device}}" || true
    xcrun simctl boot "{{watch_device}}" || true
    xcrun simctl bootstatus "{{iphone_device}}" -b
    xcrun simctl bootstatus "{{watch_device}}" -b
    open -a Simulator
    xcrun simctl install "{{iphone_device}}" "{{derived_data}}/Build/Products/Debug-iphonesimulator/StepCo.app"
    xcrun simctl install "{{watch_device}}" "{{derived_data}}/Build/Products/Debug-watchsimulator/StepCoWatch.app"
    xcrun simctl launch "{{iphone_device}}" com.nixypanda.StepCo
    xcrun simctl launch "{{watch_device}}" com.nixypanda.StepCo.watchkitapp
