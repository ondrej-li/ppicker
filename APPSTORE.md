# App Store submission — Profile Picker

Everything needed to create the App Store Connect record and submit version 1.0.0.
Values in **bold** are copy-paste ready.

| Field | Value |
|---|---|
| App name | **Profile Picker** |
| Bundle ID | **cz.ondralinek.ppicker** |
| SKU | **PROFILEPICKER1** |
| Apple ID | (created by App Store Connect) |
| Version | **1.0.0** |
| Build | **3** (`CURRENT_PROJECT_VERSION` in `project.yml`) |
| Team ID | **B592D69P29** |
| Primary language | English (U.S.) |
| Category | Utilities (secondary: Productivity) |
| Price | Free, no in-app purchases |
| Age rating | 4+ |
| Copyright | **2026 Ondřej Linek** |
| Support URL | **https://github.com/ondrej-li/ppicker** |
| Marketing URL | **https://github.com/ondrej-li/ppicker** |
| Review contact | **Fill in your name, email and phone under App Review Information** |
| Privacy Policy URL | **https://github.com/ondrej-li/ppicker/blob/main/PRIVACY.md** |
| App icon | `AppStore/AppIcon-1024.png` (also in the asset catalogue) |

## App record

The app record `cz.ondralinek.ppicker` was created on 2026-11-22. **Build 1** was uploaded the same
day, **build 2** on 2026-11-23 (Rules layout and developer-build fixes), and **build 3** on
2026-11-24 (JSON settings export/import). Add the latest processed build to an internal tester group
in TestFlight. The steps below are kept for reference; Apple has no API for creating app records, so
this one step has to happen in the App Store Connect web interface:

1. Open <https://appstoreconnect.apple.com/apps> and click **+ ▸ New App**.
2. Platform **macOS**, name **Profile Picker**, primary language **English (U.S.)**,
   bundle ID **cz.ondralinek.ppicker**, SKU **PROFILEPICKER1**, user access **Full Access**.
3. Click **Create**, then fill in the fields below under **App Information** and the
   **1.0.0 Prepare for Submission** page.
4. Upload a build: `scripts/release.sh --upload`, or Xcode ▸ Product ▸ Archive ▸ Distribute App.

If the name "Profile Picker" is taken, use one of these instead (also check the bundle ID matches):
**Profile Picker — Browser Rules**, **Link Profile Picker**, **ProfileSwitcher for Browsers**.
Update `CFBundleDisplayName` and `CFBundleName` in `project.yml` if you change it.

## App Information

**Name (30 characters max)**

```
Profile Picker
```

**Subtitle (30 characters max)**

```
A profile for every link
```

**Promotional text (170 characters max)**

```
Stop opening work links in your personal profile. Profile Picker is a default browser that sends every link to the right browser and the right profile, automatically.
```

**Keywords (100 characters max, comma separated)**

```
default browser,browser profiles,chrome,brave,edge,vivaldi,link router,rules,menu bar,switcher
```

**Description (4000 characters max)**

```
Profile Picker is the default browser that respects your profiles.

If you use Chrome, Brave, Edge or Vivaldi, you probably have more than one profile: work and personal, a client's account, a test account. Every link you click opens in whichever profile that browser used last — often not the one you wanted.

Profile Picker sits between your apps and your browsers. Set it as your default web browser and it sends each link where it belongs:

• Links from Slack open in the Brave profile you use for work.
• Links from your personal mail open in Chrome's personal profile.
• Links to your company wiki open in Edge, without asking.
• Everything else shows a small picker next to the mouse, so you can choose a browser or a profile in one keystroke.

RULES THAT MATCH HOW YOU WORK
Build rules from the app a link was clicked in, the site's host, or the whole URL, with * wildcards. Rules are checked from top to bottom and the first match wins. A built-in tester shows where a link will open before you save the rule.

A PICKER THAT STAYS OUT OF THE WAY
The picker appears next to the pointer, takes no focus from the app you were using, and closes with Esc. Choose with 1–9, the arrow keys or a click; ⌘C copies the link. Hold ⌥ Option while clicking any link to force the picker. "Always for this site" and "Always for links from this app" turn a one-off choice into a rule.

YOUR BROWSERS, YOUR PROFILES
Profile names and colours are read from the browser's own profile list, so they look the way you named them. Choose which browsers and profiles appear in the picker, or hide the menu bar icon and forget it is there. Export your rules and settings as a JSON file to keep a backup or move them to another Mac.

PRIVATE BY DESIGN
No account. No analytics. No network requests. Your rules live in a JSON file inside the app's sandbox container on your Mac. Links are written to the system log only with the address redacted.

A NOTE ON BROWSER PROFILES
macOS does not let sandboxed Mac App Store apps pass command-line arguments to other apps or read other apps' data, and choosing a Chromium profile needs both. Profile Picker therefore offers an optional helper: a short, readable shell script that ships inside the app and is published in the open-source repository. You install it yourself from Settings with a standard macOS dialog, into Profile Picker's own Application Scripts folder. It does two things: it copies the browser's list of profile names, and it asks the browser to open a link with a given profile. Without it, Profile Picker still routes links between browsers; only profile selection needs the helper.

Profile Picker requires macOS 26 or later.
```

## What's New (version 1.0.0)

```
First release.

• Route links by app, host or URL with wildcard rules.
• Send each link to a specific Chrome, Brave, Edge or Vivaldi profile.
• A keyboard-first picker with "always for this site" rules.
• Export and import rules and settings as JSON.
• Optional helper for browser profiles; the app works without it.
• No network access, no analytics, no account.
```

## App Privacy

At **App Privacy** choose **Data Not Collected**. Nothing needs to be declared.

- No tracking, no tracking domains, no third-party SDKs.
- `ProfilePicker/PrivacyInfo.xcprivacy` declares no collected data and no required-reason APIs.
- No account, advertising, analytics or crash-reporting service is used.

## Age rating

Answer **None** to every content question (cartoon violence, realistic violence, profanity,
mature themes, horror, medical information, gambling, contests, unrestricted web access). The result is **4+**.

> Note: Profile Picker is a browser *router*. It does not display web content, so the
> "unrestricted web access" question should be answered **No**.

## Export compliance

`ITSAppUsesNonExemptEncryption` is set to `false` in `Info.plist`: the app uses no encryption of
its own and makes no network connections. No export-compliance documents are needed.

## Screenshots

Mac screenshots must be 16:10 and at least one is required. Upload 1–10 images at one of these
sizes (PNG or JPEG, no transparency):

| Size | Typical use |
|---|---|
| 1280 × 800 | smallest accepted |
| 1440 × 900 | most common MacBook |
| 2560 × 1600 | Retina, recommended |
| 2880 × 1800 | Retina, largest |

A ready-to-upload set is in [AppStore/Submission/README.md](AppStore/Submission/README.md): six
2880 × 1800 PNGs plus the copy-paste description, promotional text, keywords and review notes.

Suggested shots and captions:

1. The picker next to a link, with the header showing the source app — **"One keystroke to the right profile"**.
2. Settings ▸ Rules with two or three rules and the "Test a link" box — **"Rules for apps, sites and URLs"**.
3. Settings ▸ Browsers with browser icons and profile rows — **"Your browsers, your profiles"**.
4. Settings ▸ General with "Profile Picker is your default browser" in green — **"Set it once, forget it"**.

Capture them on a Mac with a real desktop (not the Xcode simulator), using ⇧⌘4 or
`screencapture -i`, and crop to a 16:10 size above. Do not include other people's names, email
addresses or private URLs; use a demo profile and example.com links.

## App Review notes

Paste this into **App Review Information ▸ Notes**:

```
Profile Picker is a default web browser that does not render web pages. It receives http/https links through the standard kAEGetURL Apple Event and opens them in the browser and, for Chromium browsers, the profile the user chooses. It is comparable to other link routers on the App Store.

How to test:
1. Open Profile Picker. Settings open on first launch.
2. Click "Make Default Browser" and confirm the macOS prompt.
3. Needed only for profile selection: Settings ▸ Browsers ▸ "Install Helper…". The open panel is already pointed at Profile Picker's Application Scripts folder; click "Install Helper". (This row appears only when Chrome, Brave, Edge or Vivaldi is installed; Safari alone is enough to test link routing.)
4. Click a link in another app (Mail, Notes or Safari). The picker appears; choose a browser or profile.

The optional helper and the App Sandbox
Opening a link in a specific Chromium profile requires launching the browser with --profile-directory, which the App Sandbox does not allow a sandboxed app to pass. Reading another app's profile list is blocked as well. macOS's sanctioned route is a script in the app's own Application Scripts folder (~/Library/Application Scripts/cz.ondralinek.ppicker/), which runs outside the sandbox via NSUserUnixTask. Only the user can put files there, which is why the app asks the user to confirm the folder in a standard open panel. The script ships inside the app bundle as a string and is also published at https://github.com/ondrej-li/ppicker (ProfilePicker/Core/Helper.swift). It cannot be changed or downloaded remotely. It has exactly two commands: "profiles" (extract profile.info_cache from the browser's Local State file with plutil) and "open" (open -n -a <browser> --args --profile-directory=<profile> <url>). Without it, every feature except profile selection still works.

The app makes no network requests, collects no data and has no account. App Privacy: Data Not Collected. The app is open source under the MIT license.
```

Optional: attach a 30-second screen recording of the two flows (picker, rules) if the reviewer asks.

## TestFlight

**Beta App Description**

```
Profile Picker is a default browser that opens every link in the right browser and profile. Choose it as your default browser, click a link in any app, and pick where it should open. Please try rules, the picker keyboard shortcuts, and the optional helper for Chromium profiles.
```

**What to Test**

```
1. Make Profile Picker the default browser (Settings ▸ General).
2. Click links from different apps: does the picker show the right source app?
3. Create rules for an app, a host and a full URL, and use "Test a link".
4. Install the helper (Settings ▸ Browsers) and open a link in two different profiles.
5. Try 1–9, arrow keys, Return, Esc and ⌘C in the picker; try holding ⌥ Option when clicking a link.
6. Open a local .html file from Finder, and hide the menu bar icon.
```

Testers need a Mac running macOS 26 or later. The build is uploaded to the **macOS** platform
section of App Store Connect; add the build to the internal tester group after processing.

## Submission checklist

- [x] App record created in App Store Connect (2026-11-22).
- [ ] Name, subtitle, description, keywords, URLs and category filled in.
- [x] Build 3 uploaded (2026-11-24); add it to a tester group and test on TestFlight.
- [ ] App Privacy: Data Not Collected.
- [ ] Age rating: 4+.
- [ ] Screenshots uploaded from `AppStore/Submission/screenshots/` (2880 × 1800).
- [ ] Review notes pasted.
- [ ] Build selected on the 1.0.0 page, then **Add for Review**.

## What is in the repository for this

| File | |
|---|---|
| `project.yml` | Bundle ID, team, version, entitlements, plist keys |
| `ProfilePicker/PrivacyInfo.xcprivacy` | Privacy manifest (no data collected) |
| `ProfilePicker/Assets.xcassets` | App icon and menu bar icon |
| `scripts/make-icon.swift` | Redraws the icon artwork |
| `AppStore/AppIcon-1024.png` | 1024 px icon for the store listing |
| `AppStore/Submission/` | Copy-paste listing text and six 2880 × 1800 screenshots |
| `scripts/make-appstore-screenshots.py` | Renders the screenshot set |
| `scripts/release.sh` | Archive, export and optionally upload |
| `scripts/ExportOptions.plist` | App Store Connect export options |
| `.github/workflows/ci.yml` | Build and test on every push |
| `.github/workflows/testflight.yml` | Tag-driven archive and TestFlight upload |
