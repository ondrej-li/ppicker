# PPicker handover

Status as of 2026-11-20. Read the [README](README.md) first for what PPicker does and how to build it; this document covers the state of the work, the decisions behind it, and what is left.

## Status

Version 1.0.0 is complete and runs locally, but nobody has used it day to day yet and it has not been submitted to the App Store.

| Area | State | How it was checked |
|---|---|---|
| Debug and Release builds | ✅ No warnings in app code | `xcodebuild` |
| Unit tests | ✅ 14 tests pass | Rule engine, wildcards, profile parsing, config decoding |
| Release entitlements | ✅ Only `app-sandbox` and `files.user-selected.read-write` | `codesign -d --entitlements -` on the Release build |
| Profile discovery through the helper | ✅ Works | Found 2 Brave and 3 Chrome profiles on a real machine |
| Picker panel | ✅ Renders with Liquid Glass and no window frame | Screenshot of the panel window |
| Source app detection | ✅ Works for apps that send the link themselves | A test app sent a link; the log showed its bundle ID |
| Passing `--profile-directory` through the helper | ⚠️ Arguments arrive intact | Verified with a test app that records its arguments, **not with a real browser** |
| "Make Default Browser" button | ❌ Not tested | |
| "Install Helper…" dialog | ❌ Not tested | The script was installed by hand instead |
| Keyboard control of the picker | ❌ Not tested | |
| Opening `.html` files from Finder | ❌ Not tested | |
| Open at login, hiding the menu bar icon | ❌ Not tested | |
| App icon | ❌ Missing | Required for the App Store |
| Bundle ID and team | ❌ Placeholders | `com.example.ppicker` in `project.yml` |

## Decisions and why

### Sandboxed, with a user-installed helper script

The App Store requires the App Sandbox, and two things profiles depend on don't work inside it. Both were tested with small throwaway apps before writing PPicker:

| Test from a sandboxed app | Result |
|---|---|
| Launch an app with `NSWorkspace.OpenConfiguration.arguments` | Launched, but with **no arguments** |
| Run `/usr/bin/open -n -a … --args …` with `Process` | Launched, but with **no arguments** |
| Read `~/Library/Application Support/BraveSoftware/Brave-Browser/Local State` | **Denied** |
| Run a script in `~/Library/Application Scripts/<bundle id>/` with `NSUserUnixTask` | **Arguments passed through**, and the script could read `Local State` |
| `NSWorkspace.urlsForApplications(toOpen:)`, `Bundle(url:)` on apps in `/Applications` | Works |

Apple documents the first restriction: the arguments launch option is "not available to sandboxed apps" ([NSWorkspace.LaunchConfigurationKey](https://developer.apple.com/documentation/appkit/nsworkspace/launchconfigurationkey)), and Apple engineers on the Developer Forums describe it as a deliberate security restriction.

So PPicker ships the helper script as a string in [Helper.swift](PPicker/Core/Helper.swift). The user installs it from Settings ▸ Browsers: an open panel starts in the Application Scripts folder, and confirming it writes the script there. A sandboxed app can read that folder but not write to it; the open panel grants write access. Velja, which is on the App Store, also uses a helper script installed into its scripts folder (its `open.sh`).

Alternatives that were rejected:
- **Temporary-exception entitlements:** App Review often rejects them.
- **Folder access granted through an open panel:** fixes reading profiles but not passing arguments.
- **Chromium's process-singleton socket:** undocumented and fragile.
- **Distributing outside the App Store:** not what's wanted.

Details of the helper:
- It extracts only `profile.info_cache` with `plutil` (about 2.6 KB) rather than handing over the whole `Local State` file. It rejects `..` in the data folder argument.
- Results come back through a temporary file in the app's container rather than a pipe. This avoids pipe-buffer deadlocks and questions about when the write end of the pipe gets closed.
- `Helper.status` compares the installed file with the bundled script byte for byte. **Any change to the script turns existing installs into "outdated"**, and Settings then offers "Update Helper…". Bump `Helper.version` whenever you change the script.

### AppKit lifecycle, not a SwiftUI `App`

- The `kAEGetURL` handler must be registered in `applicationWillFinishLaunching`, or the link that launched the app is lost. An explicit `@main` `NSApplicationDelegate` makes that ordering obvious.
- The Settings window is an AppKit `NSWindow` hosting SwiftUI, because SwiftUI's `openSettings` can't be reached from the app delegate. That matters when the app is reopened from Finder with the menu bar icon hidden.
- PPicker is a menu bar app (`LSUIElement`). While Settings is open it switches to `.regular` (Dock icon and menu bar) and back to `.accessory` when Settings closes.
- A minimal main menu is built in code so ⌘Q, ⌘W and copy and paste in text fields work.

### Picker panel

- It is a borderless `NSPanel` with `.nonactivatingPanel`. It takes keyboard input without activating PPicker, so the app where you clicked the link stays in front if you press Esc.
- Keys are handled in `PickerPanel.sendEvent`, so SwiftUI focus can't swallow them.
- It closes when it loses key status (`windowDidResignKey`).
- `hasShadow = false`: the window shadow follows the rectangular window bounds and showed as a frame around the rounded glass. The glass draws its own edge, and the 20 pt transparent margin (`PickerView.margin`) keeps that edge from being clipped.

### Rules and targets

- A target stores the **profile folder name** (`Profile 1`), not the display name, so renaming a profile in the browser doesn't break rules.
- All conditions in a rule must match. Within one condition, comma-separated values are alternatives.
- A rule with no conditions never matches. Use the "When no rule matches" setting for a catch-all.
- `*.example.com` in a host condition also matches `example.com`.
- "Always for github.com" in the picker creates a host rule `*.github.com` at the **top** of the list.

### Browser discovery

Browsers are apps that open both `https` links and HTML files. Excluded are apps whose path contains a hidden folder or `Caches`, which removes Puppeteer's "Chrome for Testing" and Sparkle update copies, and anything in `BrowserCatalog.notBrowsers` (iTerm2 registers for both types). Profile support comes from the table in `KnownBrowsers` ([Profiles.swift](PPicker/Core/Profiles.swift)).

The picker lists profiles instead of the plain browser for browsers that have profiles. The plain browser, which opens in its last used profile, is still offered as a target for rules and for "When no rule matches".

### Code conventions

- Swift 6 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Pure model and logic types are marked `nonisolated` so tests and encoders can use them anywhere.
- XcodeGen generates the project. `PPicker.xcodeproj` is not committed.

## How a click flows through the app

1. Launch Services sends `kAEGetURL` to `AppDelegate.handleGetURL`.
2. `SourceAppResolver.resolve` reads the sender's process ID from the event (`'spid'`) and finds the running app. A helper process (such as `Slack Helper.app`) is mapped to the app that contains it. When the sender isn't an app, for example `open` in a terminal, the frontmost app is used.
3. If ⌥ Option is held, the picker is shown. Otherwise `RuleEngine.decide` returns the first matching rule's action, or the "When no rule matches" action.
4. To open a link, `Launcher.open` uses the helper when there's a profile and the helper is installed. Otherwise it calls `NSWorkspace.open(_:withApplicationAt:)`. If the helper fails, it falls back to opening without a profile. If opening fails entirely, the picker is shown.
5. To show the picker, `PickerController.show` is called.

Settings are stored as JSON at `~/Library/Containers/<bundle id>/Data/Library/Application Support/config.json`, saved on every change. Decoding fills in defaults for missing keys, so you can add new fields to `Config` without breaking existing installs.

## Working on it

The README has the build and test commands. Things that aren't obvious:

- **On this Mac, `xcode-select` points at the Command Line Tools.** Prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, or run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` once.
- **After adding or removing source files, run `xcodegen generate`.** Otherwise the build fails with "cannot find X in scope".
- **To try PPicker without changing your default browser:** `open -a build/Build/Products/Debug/PPicker.app https://example.com`. The source app will be the frontmost app.
- **Logs:** `/usr/bin/log show --last 5m --predicate 'subsystem == "PPicker"'`. Use the full path, because in zsh `log` is a shell builtin. Every routed link is logged at `notice` level with the URL redacted. `info` messages are not stored, so use `notice` or higher for anything you need to read afterwards.
- **To install the helper by hand while testing:** copy the script text from `Helper.script` to `~/Library/Application Scripts/<bundle id>/ppicker-helper.sh` and `chmod 755` it. macOS creates that folder on the app's first launch.
- **Unit tests run inside the app.** `applicationDidFinishLaunching` returns early when `XCTestConfigurationFilePath` is set, so no UI appears during tests.
- **Debug builds carry two `temporary-exception` entitlements** that Xcode adds for test injection. Release builds and archives don't. Check the archive before uploading.
- **Don't name a global `log`.** It collides with the C math function `log()`; the logger is called `logger`.
- **The picker closes as soon as it loses focus.** A screenshot taken after you click elsewhere shows an empty header; that is expected.

## Manual test checklist

Do this on a real setup before release, ideally with Brave or Chrome both running and not running.

- [ ] Settings ▸ General ▸ Make Default Browser: macOS asks for confirmation, the status turns green, and System Settings ▸ Desktop & Dock ▸ Default web browser shows PPicker.
- [ ] Settings ▸ Browsers ▸ Install Helper…: the dialog opens in the right folder, the status turns green and profiles appear. Choosing a different folder shows an error.
- [ ] A link clicked in Slack shows the picker with Slack's icon. "Always for links from Slack" creates a rule.
- [ ] A link matched to a profile opens in that profile, with the browser running and not running. Note any extra Dock icon flash from `open -n`.
- [ ] Picker keys: 1–9, arrows, Return, Esc (the source app stays in front), ⌘C. Clicking outside closes the picker.
- [ ] ⌥-click always shows the picker.
- [ ] Each "When no rule matches" option: picker, a profile, a browser without a profile.
- [ ] `open https://…` in Terminal gives Terminal as the source app.
- [ ] Double-clicking an `.html` file in Finder routes it through PPicker.
- [ ] After deleting the helper script, links open in the browser without a profile, and Settings offers to install it again.
- [ ] Rules editor: add, edit, duplicate, delete, reorder, disable; the "Test a link" box.
- [ ] Hide the menu bar icon, then open PPicker from Applications: Settings opens.
- [ ] Open at login.
- [ ] Light mode, multiple displays, and a full-screen app in front.

## Before submitting to the App Store

1. Set `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`, and the test target's bundle ID. Then run `xcodegen generate`.
2. Make an app icon in Icon Composer and add the `.icon` file to the `PPicker` target. There is none yet.
3. Check that the name is available in App Store Connect ("PPicker" is a working name).
4. In App Store Connect:
   - Category: Utilities.
   - App Privacy: "Data Not Collected".
   - Privacy policy URL: the README's Privacy section on GitHub works.
5. Archive (Product ▸ Archive) and check the archive's entitlements before uploading.
6. Paste these notes for App Review (adjust as needed):

   > PPicker lets users choose which browser, and which browser profile, opens each link. The user sets PPicker as the default web browser; links then open according to their rules, or a small picker appears.
   >
   > Opening a link in a specific Chromium browser profile requires launching the browser with the `--profile-directory` argument, which sandboxed apps cannot pass. PPicker therefore offers an **optional** helper script that the user installs themselves, through a standard open panel, into PPicker's own Application Scripts folder, and that PPicker runs with `NSUserUnixTask`. The full script ships inside the app and is published in our open-source repository. It does only two things: it extracts the list of profile names from the browser's `Local State` file, and it runs `open -a <browser> --args --profile-directory=<profile> <url>`. Without the helper, everything works except choosing a profile.
   >
   > To review: open PPicker, click "Make Default Browser", go to Browsers ▸ "Install Helper…", then click any link in another app.

## Ideas for later

- Firefox and Zen profiles (`-P <name>`), and opening Chromium web apps (`--app-id`).
- Unwrapping redirect links before matching: Outlook SafeLinks, Google `url?q=`, Slack redirects, `utm_*` parameters.
- Private windows (`--incognito`), for example with ⌥ held in the picker.
- A history of recent links with "Make a rule from this", which helps users who don't know bundle IDs.
- More Chromium browsers in `KnownBrowsers`, such as Helium, Thorium and Comet. Their data folders are unverified. Arc and Dia don't support `--profile-directory`.
- Rule import and export.
- CI: a GitHub Actions macOS runner running `xcodegen generate` and the tests.
