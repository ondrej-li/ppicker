# Profile Picker

<p align="center"><img src="AppStore/AppIcon-1024.png" width="128" alt="Profile Picker icon"></p>

<p align="center"><a href="https://github.com/ondrej-li/ppicker/actions/workflows/ci.yml"><img src="https://github.com/ondrej-li/ppicker/actions/workflows/ci.yml/badge.svg" alt="CI"></a></p>

Open every link in the right browser **profile**.

Profile Picker is a small macOS app that you set as your default browser. When you click a link in any app, Profile Picker either opens it straight away according to your rules ("links from Slack open in Brave, *Work* profile") or shows a picker next to the mouse so you can choose a browser and profile.

- Works with Chromium browsers' profiles (Chrome, Brave, Edge, Vivaldi, Chromium) and with any other browser (Safari, Firefox, …) as a whole.
- Rules match on the **app the link was clicked in**, the **host**, or the **whole URL**, using `*` wildcards.
- When no rule matches: show the picker, open a specific profile, or open the link the way that browser normally would.
- The picker is keyboard friendly: `1`–`9` to choose, arrows and Return, `⌘C` to copy the link, Esc to cancel. Hold **⌥ Option** while clicking a link to always get the picker.
- "Always for github.com" (and similar) in the picker creates a rule for you.
- Native SwiftUI + AppKit, Liquid Glass, macOS 26 or later. No network access, no analytics.

The App Store listing name is **Profile Picker**. Bundle ID `cz.ondralinek.ppicker`, team `B592D69P29`.

## How browser profiles work (and why there's a helper script)

Chromium browsers open a link in a given profile when launched with `--profile-directory="Profile 1"`. Mac App Store apps must run in the App Sandbox, and the sandbox **strips command-line arguments** from apps it launches and **blocks reading** other apps' data (such as the browser's list of profiles).

macOS's sanctioned way out is a script in the app's own *Application Scripts* folder (`~/Library/Application Scripts/<bundle id>/`). Such scripts run outside the sandbox via `NSUserUnixTask`, but only the user can put them there. Profile Picker's settings (Browsers ▸ *Install Helper…*) open that folder in a standard dialog; clicking *Install Helper* writes [`profile-picker-helper.sh`](ProfilePicker/Core/Helper.swift) into it. The script can do exactly two things:

| Command | What it does |
|---|---|
| `profiles <data dir> <output>` | Copies the `profile.info_cache` part of the browser's `Local State` file (profile folder names, display names, colors) using `plutil`. Nothing else is read. |
| `open <app> <profile> <url>` | Runs `open -n -a <app> --args --profile-directory=<profile> <url>`. |

Without the helper Profile Picker still works, but it can only choose between browsers, not profiles. Deleting the script is always safe.

## Building

Requirements: macOS 26, Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate              # creates ProfilePicker.xcodeproj from project.yml
open ProfilePicker.xcodeproj
```

`project.yml` already carries the bundle ID and team. A normal Debug run signs with your
development identity.

Command line (ad-hoc, no team needed):

```sh
xcodebuild -scheme ProfilePicker -derivedDataPath build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
xcodebuild -scheme ProfilePicker -derivedDataPath build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test
open "build/Build/Products/Debug/Profile Picker.app"
```

To try it without changing your default browser: `open -a "build/Build/Products/Debug/Profile Picker.app" https://example.com`

## Releasing

```sh
scripts/release.sh               # archive + export to build/export/Profile Picker.pkg
scripts/release.sh --upload      # also upload to App Store Connect with the Xcode account
```

Bump `CURRENT_PROJECT_VERSION` in [`project.yml`](project.yml) before each upload. The archive is
signed with the Apple Distribution certificate and the *Mac Team Store* provisioning profile for
`cz.ondralinek.ppicker`; the exported package is what TestFlight receives.

`APPSTORE.md` has the App Store fields, privacy answers, screenshots, review notes and the steps to
create the app record (required before the first upload).

### CI

- [`.github/workflows/ci.yml`](.github/workflows/ci.yml) builds and tests on every push and pull request on a `macos-26` runner.
- [`.github/workflows/testflight.yml`](.github/workflows/testflight.yml) archives, exports and optionally uploads to TestFlight on a `v*` tag or manually. It needs these repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `KEYCHAIN_PASSWORD`.

## Project layout

| Path | |
|---|---|
| `ProfilePicker/App/AppDelegate.swift` | Receives links (`kAEGetURL` Apple Event), works out the source app, routes the link; menu bar item; settings window |
| `ProfilePicker/App/AppState.swift` | Settings (saved as JSON in the app container), default-browser status, launch at login |
| `ProfilePicker/Core/RuleEngine.swift` | Rule matching and wildcards (pure, unit tested) |
| `ProfilePicker/Core/Profiles.swift` | Known Chromium browsers and their data folders; `Local State` parsing |
| `ProfilePicker/Core/BrowserCatalog.swift` | Finds installed browsers and their profiles |
| `ProfilePicker/Core/Helper.swift` | The helper script, its installation, and running it |
| `ProfilePicker/Core/Launcher.swift` | Opens a link in a browser/profile; resolves the app a link came from |
| `ProfilePicker/UI/Picker.swift` | The floating picker panel |
| `ProfilePicker/UI/Settings/` | Settings window: General, Browsers, Rules |
| `ProfilePicker/Assets.xcassets` | App icon and menu bar icon |
| `ProfilePicker/PrivacyInfo.xcprivacy` | Privacy manifest |
| `scripts/make-icon.swift` | Redraws the icon artwork into the asset catalogue and `AppStore/` |
| `scripts/release.sh` | Archive, export and optional TestFlight upload |
| `APPSTORE.md` | App Store Connect copy, review notes and checklist |

### Adding a Chromium browser

Add its bundle identifier and data folder (relative to `~/Library/Application Support`) to `KnownBrowsers.chromiumDataDirectories` in [`Profiles.swift`](ProfilePicker/Core/Profiles.swift). Pull requests welcome.

### Changing the icon

Edit the drawing code in [`scripts/make-icon.swift`](scripts/make-icon.swift), then run:

```sh
xcrun swift scripts/make-icon.swift
```

It rewrites the `AppIcon` and `StatusIcon` asset sets and `AppStore/AppIcon-1024.png`.

## How the source app is detected

The `GetURL` Apple Event carries the sender's process ID. Profile Picker maps it to the app, and maps helper processes (for example `Slack Helper.app`) to the app that contains them. When the sender isn't an app (for example `open https://…` in a terminal), Profile Picker uses the frontmost app.

## Privacy

Profile Picker makes no network requests and collects nothing. Your rules are stored in `~/Library/Containers/cz.ondralinek.ppicker/Data/Library/Application Support/config.json`. Links are logged to the system log only with their URL redacted. See [PRIVACY.md](PRIVACY.md).

## License

MIT, see [LICENSE](LICENSE).
