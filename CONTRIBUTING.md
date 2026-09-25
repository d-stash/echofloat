# Contributing to Echofloat

Thanks for helping improve Echofloat.

## Prerequisites

- macOS 13 or later.
- Apple Command Line Tools with Swift 5.9 or later for app builds.
- Swift 6.1 or later for the full Swift Testing suite.

## Local checks

Run these from the repository root:

```bash
swift build
bash Tests/PackagingChecks.sh
bash Tests/InstallerChecks.sh
bash Tests/ReleaseScriptChecks.sh
```

With Swift 6.1 or newer, also run:

```bash
swift test --no-parallel
bash Tests/ToolchainCompatibilityChecks.sh
```

## Coding expectations

- Keep changes focused and easy to review.
- Add tests for behavior changes.
- Avoid private Apple frameworks.
- Do not commit secrets.
- Do not add borrowed artwork or copied media.
- Update documentation when setup, privacy, permissions, or user-visible behavior changes.

## Pull-request checklist

- Tests pass.
- Documentation reflects the change.
- Privacy or permission changes are called out clearly.
- Screenshots are included only when the change is visual and repository-owned images already exist; do not add placeholders, borrowed art, or broken image links.
- No unrelated files are modified.

## Cutting a release

1. Bump `VERSION` (semantic version, e.g. `0.2.0`) and commit.
2. Tag and push: `git tag v0.2.0 && git push origin v0.2.0`.
3. The `Release` GitHub Actions workflow builds, signs, and publishes the release automatically — see `.github/workflows/release.yml`.
4. Confirm the new version appears at the `SUFeedURL` in `Resources/Info.plist` before announcing.

## Notes

Echofloat is a local macOS app. If you change install, uninstall, or Launch at Login behavior, verify the relevant setup and removal paths before opening a pull request.
