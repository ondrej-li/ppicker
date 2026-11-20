# PPicker

Open every link in the right browser **profile**.

PPicker is a small macOS app that you set as your default browser. When you click a link in any app, PPicker either opens it straight away according to your rules ("links from Slack open in Brave, *Work* profile") or shows a picker next to the mouse so you can choose a browser and profile.

- Works with Chromium browsers' profiles (Chrome, Brave, Edge, Vivaldi, Chromium) and with any other browser (Safari, Firefox, …) as a whole.
- Rules match on the **app the link was clicked in**, the **host**, or the **whole URL**, using `*` wildcards.
- When no rule matches: show the picker, open a specific profile, or open the link the way that browser normally would.
- The picker is keyboard friendly: `1`–`9` to choose, arrows and Return, `⌘C` to copy the link, Esc to cancel. Hold **⌥ Option** while clicking a link to always get the picker.
- "Always for github.com" (and similar) in the picker creates a rule for you.
- Native SwiftUI + AppKit, Liquid Glass, macOS 26 or later. No network access, no analytics.

## How browser profiles work (and why there's a helper script)

Chromium browsers open a link in a given profile when launched with `--profile-directory="Profile 1"`. Mac App Store apps must run in the App Sandbox, and the sandbox **strips command-line arguments** from apps it launches and **blocks reading** other apps' data (such as the browser's list of profiles).

macOS's sanctioned way out is a script in the app's own *Application Scripts* folder (`~/Library/Application Scripts/<bundle id>/`). Such scripts run outside the sandbox via `NSUserUnixTask`, but only the user can put them there. PPicker's settings (Browsers ▸ *Install Helper…*) open that folder in a standard dialog; clicking *Install Helper* writes [`ppicker-helper.sh`](PPicker/Core/Helper.swift) into it. The script can do exactly two things:

| Command | What it does |
|---|---|
| `profiles <data dir> <output>` | Copies the `profile.info_cache` part of the browser's `Local State` file (profile folder names, display names, colors) using `plutil`. Nothing else is read. |
| `open <app> <profile> <url>` | Runs `open -n -a <app> --args --profile-directory=<profile> <url>`. |

Without the helper PPicker still works, but it can only choose between browsers, not profiles. Deleting the script is always safe.

## Building

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate          # creates PPicker.xcodeproj from project.yml
open PPicker.xcodeproj
```

Before running from Xcode, set `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER` in [`project.yml`](project.yml) and generate again.

Command line (signs ad hoc, no team needed):

```sh
xcodebuild -scheme PPicker -derivedDataPath build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
xcodebuild -scheme PPicker -derivedDataPath build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test
open build/Build/Products/Debug/PPicker.app
```

To try it without changing your default browser: `open -a build/Build/Products/Debug/PPicker.app https://example.com`

## Project layout

| Path | |
|---|---|
| `PPicker/App/AppDelegate.swift` | Receives links (`kAEGetURL` Apple Event), works out the source app, routes the link; menu bar item; settings window |
| `PPicker/App/AppState.swift` | Settings (saved as JSON in the app container), default-browser status, launch at login |
| `PPicker/Core/RuleEngine.swift` | Rule matching and wildcards (pure, unit tested) |
| `PPicker/Core/Profiles.swift` | Known Chromium browsers and their data folders; `Local State` parsing |
| `PPicker/Core/BrowserCatalog.swift` | Finds installed browsers and their profiles |
| `PPicker/Core/Helper.swift` | The helper script, its installation, and running it |
| `PPicker/Core/Launcher.swift` | Opens a link in a browser/profile; resolves the app a link came from |
| `PPicker/UI/Picker.swift` | The floating picker panel |
| `PPicker/UI/Settings/` | Settings window: General, Browsers, Rules |

### Adding a Chromium browser

Add its bundle identifier and data folder (relative to `~/Library/Application Support`) to `KnownBrowsers.chromiumDataDirectories` in [`Profiles.swift`](PPicker/Core/Profiles.swift). Pull requests welcome.

## How the source app is detected

The `GetURL` Apple Event carries the sender's process ID. PPicker maps it to the app, and maps helper processes (for example `Slack Helper.app`) to the app that contains them. When the sender isn't an app (for example `open https://…` in a terminal), PPicker uses the frontmost app.

## Privacy

PPicker makes no network requests and collects nothing. Your rules are stored in `~/Library/Containers/<bundle id>/Data/Library/Application Support/config.json`. Links are logged to the system log only with their URL redacted.

## License

MIT, see [LICENSE](LICENSE).
