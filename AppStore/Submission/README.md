# App Store submission assets

Copy-paste fields and a ready-to-upload screenshot set for **Profile Picker 1.0.0 (build 3)**.

## Copy-paste fields

| Field | File | Limit | Length |
|---|---|---|---|
| Subtitle | [subtitle.txt](subtitle.txt) | 30 | 25 |
| Promotional text | [promotional-text.txt](promotional-text.txt) | 170 | 150 |
| Description | [description.txt](description.txt) | 4000 | 2437 |
| Keywords | [keywords.txt](keywords.txt) | 100 | 94 |
| What’s New | [whats-new.txt](whats-new.txt) | 4000 | 363 |
| App Review Notes | [review-notes.txt](review-notes.txt) | 4000 | 1819 |

All files are UTF-8 plain text. Copy the whole file contents into the matching App Store Connect field.

## Screenshots

Six **2880 × 1800** PNGs, RGB, no alpha — one of the sizes App Store Connect accepts for macOS.
Upload them in this order:

| # | File | Caption |
|---|---|---|
| 1 | [01-picker.png](screenshots/01-picker.png) | Every link in the right profile. |
| 2 | [02-rules.png](screenshots/02-rules.png) | Rules that match how you work. |
| 3 | [03-browsers.png](screenshots/03-browsers.png) | Your browsers. Your profiles. |
| 4 | [04-keyboard.png](screenshots/04-keyboard.png) | One keystroke. Done. |
| 5 | [05-settings-file.png](screenshots/05-settings-file.png) | Take your rules with you. |
| 6 | [06-privacy.png](screenshots/06-privacy.png) | Private by design. |

They are staged marketing images rather than literal captures: the UI is redrawn with generic
profiles (`Personal`, `Work`, `Client`) and generic addresses (`example.com`, `personal@example.com`).
No real profile name, account, email address or browsing data appears in them.

App Previews are optional and are not included; the six screenshots are the visual asset set.

To regenerate the screenshots (requires Pillow):

```sh
python3 scripts/make-appstore-screenshots.py
```

The renderer is [scripts/make-appstore-screenshots.py](../../scripts/make-appstore-screenshots.py).

## Store URLs

| Field | Value |
|---|---|
| Marketing URL | <https://ppicker.ondralinek.cz/> |
| Support URL | <https://ppicker.ondralinek.cz/support.html> |
| Privacy Policy URL | <https://ppicker.ondralinek.cz/privacy.html> |

## Other listing values

- **Name:** Profile Picker
- **Bundle ID:** `cz.ondralinek.ppicker`
- **Version:** 1.0.0 (build 3)
- **Primary language:** English (U.S.)
- **Category:** Utilities; secondary Productivity
- **Price:** Free, no in-app purchases
- **Age rating:** 4+
- **App Privacy:** Data Not Collected

The full submission checklist and review guidance are in [APPSTORE.md](../../APPSTORE.md).
