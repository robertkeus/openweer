# OpenWeer iOS

Native iPhone app for [openweer.nl](https://openweer.nl). SwiftUI, iOS 17+, MapLibre Native.

## Status

Milestone 1 — scaffold. Real implementations land in milestones 2–11 (see `~/.claude/plans/make-a-plan-to-stateless-abelson.md`).

## Build

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd ios
xcodegen generate
open OpenWeer.xcodeproj
```

Then in Xcode: pick a simulator (iPhone 15 Pro), ⌘R.

## Layout

```
ios/
  project.yml                    # XcodeGen config (do not edit OpenWeer.xcodeproj by hand)
  OpenWeer/
    App/                         # @main, AppDelegate, RootView
    Onboarding/                  # 3-screen flow
    Main/                        # Map, timeline, rain sheet, weather, forecast, chat, search, controls
    Core/                        # Network, Models, Location, Push, Theme, State
    Resources/                   # Asset catalog, Localizable.xcstrings, fonts
  OpenWeerTests/                 # XCTest target
```

## API base URL

`OPENWEER_API_BASE` is set per build configuration in [project.yml](project.yml) and substituted into `Info.plist` at build time:

| Configuration | URL                       |
|---------------|---------------------------|
| Debug         | `http://localhost:8000`   |
| Release       | `https://openweer.nl`     |

Verify the baked URL after a build:

```sh
plutil -extract OPENWEER_API_BASE raw \
  ./build/Build/Products/Release-iphonesimulator/OpenWeer.app/Info.plist
# → https://openweer.nl
```

ATS is `NSAllowsArbitraryLoads = false` in both configs. `NSAllowsLocalNetworking = true` permits HTTP to `localhost`/`*.local` (used by the Debug build) but cannot be used for arbitrary internet hosts.

## Fonts

Inter font files (`Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, `Inter-Bold.ttf`) belong in `OpenWeer/Resources/`. They are not committed; download from [rsms/inter](https://github.com/rsms/inter/releases) and drop the four ttfs into the Resources folder before generating the Xcode project. The system font is used as a fallback if a face is missing.

## Push notifications

Configured against the `nl.openweer.app` bundle ID. Push backend lives in `/api` (see milestone 8). To enable in development, sign with a team that has the **Push Notifications** capability enabled.

## Tests

```sh
xcodebuild -project OpenWeer.xcodeproj \
  -scheme OpenWeer \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

## License

MIT (code). KNMI weather data: CC-BY-4.0 — attribution required.
