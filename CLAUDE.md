# CLAUDE.md — ppicker

The app lives in `ProfilePicker/`, the site in `Website/` (served at
ppicker.ondralinek.cz by the deploy account from git).

## Writing HTML and CSS

Before writing or changing HTML, CSS or client-side JavaScript here, use the
`modern-web-guidance` skill (installed for this account): search for the
capability, retrieve the guides it names, apply them. The platform usually has
the answer the library was added for — `<dialog>` and the popover API instead of
div overlays, container queries instead of media-query rewrites, View
Transitions and `@starting-style` instead of JS entrance animations, native
validation and `:user-invalid` instead of a validation library.

Browser support policy: Baseline Widely available as-is; Newly available only
with feature detection and a fallback of 20 lines or fewer, no dependencies, no
polyfills.
