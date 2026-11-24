# Profile Picker 1.0.0

Open every link in the right browser **profile**.

Profile Picker is a small macOS app that you set as your default browser. Links open straight away
according to your rules — “links from Slack open in Brave, *Work* profile” — or a picker appears next
to the mouse so you can choose a browser and profile.

## Install

1. Download **ProfilePicker-1.0.0.dmg** (or the `.zip`) below.
2. Open it and drag **Profile Picker** onto the **Applications** folder.
3. Open Profile Picker from Applications, then click **Make Default Browser**.

Requires **macOS 26** or later. The app is signed with a Developer ID certificate and notarized by
Apple.

## Highlights

- Rules for the app a link was clicked in, the host, or the whole URL, with `*` wildcards.
- Chrome, Brave, Edge and Vivaldi profiles, with the names and colours from the browser itself.
- Keyboard-first picker: `1`–`9`, arrows, Return, Esc, `⌘C`; hold **⌥** when clicking a link to force it.
- “Always for this site” and “Always for links from this app” turn a choice into a rule.
- Export and import rules and settings as JSON, to move them between Macs or keep a backup.
- Menu bar app with no Dock icon; optional open at login.

## About this build

This is the **direct-download** build. It runs outside the App Sandbox, so it reads browser profiles
and opens them directly — no helper script is needed. The App Store build is sandboxed and asks for
an optional helper script for profile selection.

No account, no analytics, no network access. Your rules stay on your Mac.

## Checksums

See `ProfilePicker-1.0.0-SHA256SUMS.txt` in the release assets.
