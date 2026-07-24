# AGENTS.md

## Project Overview

ShareGather is a local-first iPhone app and Share Extension. It receives URLs, text, and images from other apps through the iOS Share Sheet and stores them locally for later review.

## Product Constraints

- The app must work without an account, sign-in, or required server.
- Saved content must remain available offline after it has been received.
- User data belongs to the user and must stay in the local App Group container.
- Metadata enrichment, such as Link Presentation title, description, or thumbnail loading, is optional and must not prevent saving the original shared content.
- Preserve the original shared payload when adding or changing display metadata.
- Avoid introducing cloud synchronization or analytics unless the product requirements explicitly change. New remote dependencies require explicit user approval.

## Current Product Behavior

- The main screen shows categories, Uncategorized items, recent saved items, and the Share Sheet usage card at the bottom.
- The Share Sheet usage card is shown only when the library has no saved items.
- Categories can be created, renamed, reordered, deleted, and selected during sharing.
- Deleting a category checks whether it contains items and lets the user delete those items or move them to Uncategorized.
- Category items can be pinned; pinned items appear at the top of their category.
- Category and Uncategorized lists sort pinned items first, then sort both pinned and unpinned items by creation time from newest to oldest. The home screen's recent-items section sorts only by creation time from newest to oldest.
- Category and Uncategorized views support multi-selection, drag selection, batch move, and batch delete.
- Items can be opened, shared, deleted with confirmation, or moved to another category. Long-press menus expose the relevant item actions.
- URL items can show a title, description/source, thumbnail, URL, and creation date.
- The detail page places Delete on the left and Share/Open Link actions on the right.
- The Share Extension supports URL, text, and image attachments and includes an Uncategorized destination.
- Settings includes Preferences, App Information, a localized Privacy Policy sheet, and a Danger Zone for clearing saved content.
- Backup export creates a ZIP archive that can be shared through the iOS system share sheet. Backup import validates the archive and supports merging with or replacing existing saved content.

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

## Repository Map

- `ShareGather/`
  - `ShareGatherApp.swift`: Main SwiftUI app entry point that hosts `ContentView`.
  - `SaveToShareGatherIntent.swift`: App Intents Action-list entry point for saving URL and text content.
  - `Assets.xcassets/`: Main-app visual assets.
- `ShareGatherPackage/`
  - `Package.swift`: Local Swift package manifest; declares the iOS 17 minimum, feature/storage products, and ZIPFoundation dependency.
  - `Sources/ShareGatherFeature/ContentView.swift`: Primary app UI and interaction coordinator. Contains the home screen, category management, selection flows, Settings, backup UI, privacy policy, item detail, and share-sheet wrappers.
  - `Sources/ShareGatherStorage/ShareGatherStorage.swift`: Shared App Group persistence and backup implementation used by the app and extensions.
  - `Sources/ShareGatherStorage/Localization.swift`: App Group language preference handling and Simplified Chinese strings.
  - `Sources/ShareGatherStorage/Resources/Localizable.xcstrings`: English and Traditional Chinese string catalog.
  - `Tests/ShareGatherFeatureTests/`: Package-level storage and feature tests.
- `ShareGatherShareExtension/`
  - `ShareViewController.swift`: UIKit Share Extension; receives URL, text, and image attachments, presents category selection, saves content, and optionally enriches URL metadata.
  - `*.lproj/InfoPlist.strings`: Localized extension display names.
- `ShareGatherActionExtension/`: Action Extension target and localized metadata for the **Save to ShareGather** Action-list integration.
- `Config/`: Shared build configuration and App Group entitlement definitions.
- `ShareGather.xcworkspace` / `ShareGather.xcodeproj`: Open the workspace and use the `ShareGather` scheme for builds.
- `ShareGatherUITests/`: Xcode UI-test target.
- `README.md`, `PRIVACY.md`, and `docs/assets/`: Product documentation, canonical English privacy-policy wording, and documentation assets.

## Core Types

- `SharedLibraryStore`: App Group-backed JSON and media store. Owns item/category CRUD, ordering, pin updates, batch operations, clear-all behavior, ZIP backup export/import, and backup validation.
- `SharedItem`: Persisted URL, text, or image record; includes display metadata, original payload, category assignment, creation date, thumbnail reference, and `isPinned`.
- `SharedCategory`: Persisted category ID, name, and creation date. Its stored array order is the display order.
- `SharedOriginalContent`: Preserves the original shared payload separately from enriched display metadata.
- `SharedItemKind`: URL, text, or image discriminator.
- `BackupImportMode`, `BackupSummary`, and `SharedLibraryBackupError`: ZIP backup import/export contract and results.
- `ContentView`: Main app state owner; reloads the library and bridges UI actions to `SharedLibraryStore`.
- `SettingsView`: Language, destructive clearing, backup export/import, and privacy-policy entry points.
- `CategoryItemsView` and `UncategorizedItemsSection`: Item-list selection, batch move/delete, and category-only pin behavior.
- `CategorySelectionSheet`: Reusable destination chooser; callers control whether Uncategorized or the current category is available.
- `ShareViewController`: Extension-side receiver for shared content and category selection.

## Backup and Restore

- Backups are user-directed local file transfers, not cloud synchronization.
- The backup format includes categories and order, saved-item metadata, pin state, original content, images, and thumbnails. It does not include the selected app language.
- Backup files are not encrypted. User-facing backup flows and documentation must state that recipients of a shared backup may access its contents.
- Import must validate the backup identifier, supported format version, metadata structure, category references, and required media before changing the live library.
- Preserve backward compatibility for published backup formats. Any format change requires a versioning and migration strategy.
- For import behavior, clearly distinguish merge from replace. Merge behavior is UUID-based unless the product requirements explicitly define another deduplication policy.

## Dependency Policy

- New third-party dependencies require explicit user approval.
- Prefer Apple frameworks first. Use a maintained dependency only when it materially improves correctness or interoperability.
- Commit the relevant Swift Package lockfiles whenever dependencies change.

## Development Practices

- Open and build `ShareGather.xcworkspace`; use the `ShareGather` scheme.
- Use XcodeBuildMCP workflows for simulator and physical-device build/run verification.
- Run `git diff --check` before committing.
- Run an appropriate build or test after code changes, especially for Share Extension, persistence, signing, and localization changes.
- After a user-visible iPhone UI change, build, install, and launch on the connected iPhone unless the user says not to.
- For storage, import, export, or backup changes, add or update round-trip tests before committing.
- For any change that affects an on-screen UI or other user-visible copy, account for English, Traditional Chinese, and Simplified Chinese from the start, including labels, dialogs, errors, accessibility text, and Share Extension copy where applicable.
- Verify English, Traditional Chinese, and Simplified Chinese whenever new user-facing strings are added.
- Verify both the app and Share Extension after changing shared storage or language preferences.
- Physical-device testing requires an Apple Developer account, a registered device, valid provisioning for both app targets, and Developer Mode enabled on the iPhone.
- Do not commit generated DerivedData or local signing artifacts.
- Preserve unrelated user changes in a dirty worktree.
- Keep commits focused on one completed user-facing change. When unrelated work is already uncommitted, stage only the files belonging to the requested commit.

## Documentation

- Keep `README.md` accurate to implemented behavior and supported workflows.
- Update this file when product constraints, architecture, localization, signing, or verification conventions change.
- Keep documentation in English unless a future project requirement explicitly says otherwise.
- Keep documentation assets under `docs/assets/`. README files should reference documentation assets instead of app-target assets when an appropriate documentation asset exists.

## Design Documentation

- Read `docs/README.md` before nontrivial feature, storage, sharing, backup, localization, or extension work, then read the relevant linked design document.
- `docs/` contains the detailed architecture and behavior contract; README is the concise product and developer overview.
- Update the relevant `docs/` file in the same change when behavior, persistence format, backup semantics, UI interaction rules, target ownership, localization flow, dependency policy, or verification procedure changes.
- If code and documentation disagree, treat current code as the source of truth, correct the documentation in the same change, and do not preserve unsupported claims.
- Document only implemented and verified behavior. Clearly label known limitations rather than implying guarantees such as encryption, transactional restore, or security validation that the code does not provide.
