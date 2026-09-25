# Auto-Update via Sparkle

## Problem

Echofloat has no update mechanism beyond re-running `setup.sh`, which itself
does not fetch new source — a user must know to `git pull` first. There is no
signal that a newer version exists. This blocks the goal of letting anyone
who has already installed Echofloat discover and get the latest release
easily.

`docs/superpowers/specs/2026-09-19-public-packaging-design.md` explicitly
deferred "Automatic updates" and Developer ID signing/notarization, but noted
packaging scripts should be structured so a future notarized workflow can
reuse the generated bundle. This design fills that gap using Sparkle, which
does not require notarization or an Apple Developer Program membership.

## Why Sparkle

- Free, open-source (MIT), the de facto standard for macOS apps distributed
  outside the App Store.
- Security comes from Sparkle's own EdDSA update signing plus HTTPS, not from
  Apple code signing — works for ad-hoc-signed, non-notarized apps like
  Echofloat's current build.
- Users still see a Gatekeeper prompt on first manual install (unchanged from
  today), but Sparkle-delivered updates after that do not require re-clearing
  Gatekeeper each time, since Sparkle verifies its own signature.

## Scope

In scope:
- A signed, versioned release artifact (`.zip` of the built `.app`) produced
  by CI on tag push and attached to a GitHub Release.
- An `appcast.xml` feed (hosted on GitHub Pages) describing available
  versions, download URLs, and EdDSA signatures.
- Sparkle integrated into the app via SwiftPM, with a "Check for Updates…"
  menu bar item and background update checks (default interval, user can
  disable).
- EdDSA key pair generated once; private key stored as a GitHub Actions
  secret, public key embedded in `Info.plist`.

Out of scope (future work, not blocked by this design):
- Apple Developer ID signing and notarization.
- Mac App Store distribution (incompatible with Sparkle).

## Approach

1. **Key generation**: run Sparkle's `generate_keys` tool once locally,
   commit the public key to the repo, store the private key only in GitHub
   Actions secrets (`SPARKLE_PRIVATE_KEY`).
2. **CI release pipeline** (new workflow, triggered on `v*` tag push):
   - Build release binary (reuse existing packaging script from the public
     packaging design).
   - Zip the `.app`, sign it with `sign_update` (Sparkle CLI tool) using the
     private key secret.
   - Create a GitHub Release for the tag, attach the zip.
   - Regenerate `appcast.xml` (via `generate_appcast` or a small script) and
     publish it to a `gh-pages` branch.
3. **App integration**:
   - Add Sparkle as a SwiftPM dependency.
   - Wire `SPUStandardUpdaterController` into the app delegate.
   - Add `SUFeedURL` (points at the GitHub Pages appcast) and
     `SUPublicEDKey` to `Info.plist`.
   - Add "Check for Updates…" to the menu bar item, near existing
     Launch-at-Login controls.
4. **Docs**: replace the README "Update" section's `./setup.sh` instruction
   with "Echofloat checks for updates automatically; use Check for Updates…
   from the menu bar, or re-run `./setup.sh` to build from source."

## Testing

- CI workflow dry-run against a test tag in a fork/branch before using it on
  a real release.
- Manual test: install an old build, publish a newer tagged release, confirm
  the app detects, downloads, verifies, and installs the update.
- Existing `swift test` suite unaffected; add a smoke test only if Sparkle
  wiring introduces app-delegate logic worth covering (e.g., feed URL is set).

## Risks / open questions

- First-run Gatekeeper friction is unchanged — still ad-hoc signed, so a
  brand-new user still must right-click → Open on first install.
- GitHub Pages hosting for the appcast needs `gh-pages` branch + Pages
  enabled on the repo (one-time setup).
- If code signing/notarization is added later, the appcast and CI signing
  step continue to work unchanged (Sparkle signing is independent of Apple's).
