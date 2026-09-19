# Contributing to Echofloat

Thanks for helping improve Echofloat.

## Prerequisites

- macOS 13 or later.
- Swift 6.1 or later.
- Apple Command Line Tools.

## Local checks

Run these from the repository root:

```bash
swift test
swift build
bash Tests/PackagingChecks.sh
bash Tests/InstallerChecks.sh
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

## Notes

Echofloat is a local macOS app. If you change install, uninstall, or Launch at Login behavior, verify the relevant setup and removal paths before opening a pull request.
