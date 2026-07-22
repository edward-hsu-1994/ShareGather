# AGENTS.md

## Project Overview

ShareGather is a local-first iPhone app and Share Extension. It receives URLs, text, and images from other apps through the iOS Share Sheet and stores them locally for later review.

## Product Constraints

- The app must work without an account, sign-in, or required server.
- Saved content must remain available offline after it has been received.
- User data belongs to the user and must stay in the local App Group container.
- Metadata enrichment, such as Link Presentation title, description, or thumbnail loading, is optional and must not prevent saving the original shared content.
- Preserve the original shared payload when adding or changing display metadata.
- Avoid introducing cloud synchronization, analytics, or remote dependencies unless the product requirements explicitly change.

## Current Product Behavior

- The main screen shows categories, Uncategorized items, recent saved items, and the Share Sheet usage card at the bottom.
- Categories can be created, renamed, deleted, and selected during sharing.
- Deleting a category checks whether it contains items and lets the user delete those items or move them to Uncategorized.
- Items can be opened, shared, deleted with confirmation, or moved to another category.
- URL items can show a title, description/source, thumbnail, URL, and creation date.
- The detail page places Delete on the left and Share/Open Link actions on the right.
- The Share Extension supports URL, text, and image attachments and includes an Uncategorized destination.

## Localization Rules

- Documentation, code comments, identifiers, and resource keys use English.
- User-facing text must be localized; do not add language-specific ternary expressions in views or the Share Extension.
- Supported locales are English (`en`), Traditional Chinese (`zh-Hant`), and Simplified Chinese (`zh-Hans`).
- System Default follows the device language and falls back to English when the language is unsupported.
- Keep the main app and Share Extension on the same localization source and synchronize the selected language through the App Group preference.
- Add new strings using stable localization keys and update all supported languages.

## Architecture and Storage

- The app shell is in `ShareGather/`.
- Feature UI is in `ShareGatherPackage/Sources/ShareGatherFeature/`.
- Persistence and shared models are in `ShareGatherPackage/Sources/ShareGatherStorage/`.
- The Share Extension is in `ShareGatherShareExtension/`.
- The shared App Group identifier is `group.com.sharegather.app`.
- `SharedItem` stores display metadata, category assignment, and `SharedOriginalContent` when available.
- Image files and URL thumbnails are stored in the App Group container; item metadata is persisted locally.
- Keep storage changes backward-compatible with existing JSON data. Add migration logic when changing serialized fields or formats.

## Development Practices

- Open and build `ShareGather.xcworkspace`; use the `ShareGather` scheme.
- Use XcodeBuildMCP workflows for simulator and physical-device build/run verification.
- Run `git diff --check` before committing.
- Run an appropriate build or test after code changes, especially for Share Extension, persistence, signing, and localization changes.
- Physical-device testing requires an Apple Developer account, a registered device, valid provisioning for both app targets, and Developer Mode enabled on the iPhone.
- Do not commit generated DerivedData or local signing artifacts.
- Preserve unrelated user changes in a dirty worktree.

## Documentation

- Keep `README.md` accurate to implemented behavior and supported workflows.
- Update this file when product constraints, architecture, localization, signing, or verification conventions change.
- Keep documentation in English unless a future project requirement explicitly says otherwise.
