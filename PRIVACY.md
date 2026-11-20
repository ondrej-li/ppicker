# Privacy Policy — Profile Picker

**Effective date:** 20 November 2026

Profile Picker is a macOS app that opens links in the browser and browser profile you choose. It is
designed to work without an account and without sending anything anywhere.

## What Profile Picker collects

**Nothing.** Profile Picker does not collect, transmit, sell or share any personal data.

- No analytics, telemetry, advertising or crash-reporting SDKs.
- No network connections are made by the app.
- No account, sign-in, email address or device identifier is requested.

## What is stored on your Mac

- **Your settings and rules** are stored in
  `~/Library/Containers/cz.ondralinek.ppicker/Data/Library/Application Support/config.json`, inside
  the app's sandbox container. They never leave your Mac and are removed when you delete the app.
- **Links** are written to the macOS system log with their address redacted, so you can diagnose
  routing if you choose to. macOS keeps and rotates that log; Profile Picker does not send it
  anywhere.
- **Browser profiles** are read only when you have installed the optional helper script. The helper
  extracts the list of profile names from the browser's own `Local State` file and writes it to a
  temporary file in the app's container, which the app deletes after reading it.

## The optional helper script

The helper is a short shell script that ships inside the app and is also published in the
[open-source repository](https://github.com/ondrej-li/ppicker/blob/main/ProfilePicker/Core/Helper.swift).
You install it yourself from Profile Picker's settings, into Profile Picker's own Application
Scripts folder. It has two commands:

1. `profiles` — copies the browser's list of profile names.
2. `open` — asks the browser to open a link with a given profile.

The script does not access the network and does not read or write anything else. Deleting it is
always safe.

## Children

Profile Picker does not collect data from anyone, including children.

## Changes

If this policy changes, the new version will be published at this address with a new effective date.

## Contact

Questions about this policy: open an issue at <https://github.com/ondrej-li/ppicker/issues>.
