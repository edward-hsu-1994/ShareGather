# ShareGather

<p align="center">
  <img src="docs/assets/SG_ICON_120.png" alt="ShareGather logo" width="120">
</p>

ShareGather is a local-first iPhone app for saving URLs, text, and images from the iOS Share Sheet. It is built for collecting something now and reviewing it later—without an account, sign-in, or ShareGather cloud service.

## Features

- Save URLs, text, and images through the iOS Share Sheet.
- Save URLs and text from the Share Sheet Action list with **Save to ShareGather**.
- Keep saved content offline in the shared App Group container used by the app and Share Extension.
- Organize items into categories or leave them Uncategorized.
- Create, rename, reorder, and delete categories.
- Pin items within a category; pinned items appear at the top of that category.
- Sort category and Uncategorized lists with pinned items first, then by saved time from newest to oldest; Recent saved items always use saved time only.
- Move or delete individual items, including moving them back to Uncategorized.
- Select multiple items in category and Uncategorized views to move or delete them.
- Long-press a saved item to pin it when available, move it, share it, or delete it.
- Show recent saved items on the home screen.
- Preserve original shared content while optionally enriching URLs with a title, description/source, and thumbnail.
- Open, share, or delete a saved item from its detail view.
- Read the in-app privacy policy and open the project repository from Settings.

## Backup and Restore

ShareGather can export all saved content as a portable ZIP backup and share it through the iOS system share sheet. This lets you save the backup in Files, a cloud-drive app, or another app that accepts files.

The exported filename uses this format:

```text
ShareGather Backup yyyy-MM-dd.zip
```

Each backup contains:

```text
manifest.json
categories.json
items.json
Images/
Thumbnails/
```

Backups include categories and their order, item metadata, category assignments, pin state, original shared content, images, and URL thumbnails. The selected app language is not included.

To restore a backup, choose **Import Backup** in Settings and select a ZIP file in the Files picker. ShareGather validates the backup identifier, supported format version, metadata structure, duplicate IDs, category references, and required media files before offering these choices:

- **Merge with Existing Items** keeps existing UUID-matching categories and items, then adds nonmatching backup data.
- **Replace Existing Items** removes current items, categories, images, and thumbnails before restoring the backup.

Backups are not encrypted. Sharing or uploading a ZIP gives the receiving app or service access to its contents, subject to that provider's privacy policy. Backup is user-directed file transfer, not automatic cloud synchronization.

## Privacy

ShareGather is intentionally local-first:

- No account or sign-in.
- No required server or cloud storage.
- No analytics, advertising, or tracking integrations.
- Saved content belongs to the user and stays in the local App Group container.

For shared URLs, iOS Link Presentation may optionally request preview metadata such as a title or thumbnail. This can contact the linked website, but saving the original URL does not depend on metadata loading.

Read the full policy in [PRIVACY.md](PRIVACY.md).

## Localization

The app supports:

- English (`en`)
- Traditional Chinese (`zh-Hant`)
- Simplified Chinese (`zh-Hans`)

`System Default` follows the device language and falls back to English for unsupported languages. The selected language is synchronized with the Share Extension through App Group preferences.

English and Traditional Chinese are maintained in `ShareGatherPackage/Sources/ShareGatherStorage/Resources/Localizable.xcstrings`. Simplified Chinese is maintained in `ShareGatherPackage/Sources/ShareGatherStorage/Localization.swift`. User-facing text uses stable localization keys rather than language-specific view conditionals.

## Architecture and Storage

For component ownership, persistence details, UI interaction rules, and development conventions, see the [design documentation](docs/README.md).

- `ShareGather/` — SwiftUI app entry point and App Intent.
- `ShareGatherPackage/Sources/ShareGatherFeature/` — main UI and interaction flows.
- `ShareGatherPackage/Sources/ShareGatherStorage/` — shared models, local persistence, backup handling, and localization.
- `ShareGatherShareExtension/` — Share Extension for incoming URLs, text, and images.
- `ShareGatherActionExtension/` — Action Extension for saving URLs and text from the Share Sheet Action list.
- `ShareGatherPackage/Tests/` — Swift Package tests.
- `Config/` — shared entitlements and build configuration.

All saved content is stored locally in the App Group container `group.com.sharegather.app`:

- `saved-items.json` stores item metadata.
- `categories.json` stores categories and their order.
- `Images/` stores saved images.
- `Thumbnails/` stores cached URL thumbnails.

The app uses atomic JSON writes for normal metadata updates. ZIP backup creation and extraction use [ZIPFoundation](https://github.com/weichsel/ZIPFoundation).

Deleting and reinstalling the app is not a backup strategy. Export a backup before removing the app if you need to retain data.

## Requirements

- iOS 17 or later.
- macOS with Xcode for development.
- An Apple Developer account, registered device, and Developer Mode for physical-device testing.

## Build and Run

Open `ShareGather.xcworkspace` in Xcode and select the `ShareGather` scheme.

For simulator verification:

```sh
xcodebuildmcp simulator build-and-run \
  --workspace-path ./ShareGather.xcworkspace \
  --scheme ShareGather \
  --simulator-name 'iPhone 17'
```

For a physical device, configure signing for the app and both extension targets, then run:

```sh
xcodebuildmcp device build-and-run \
  --workspace-path ./ShareGather.xcworkspace \
  --scheme ShareGather \
  --device-id <device-udid> \
  --extra-args=-allowProvisioningUpdates
```

## Verification Checklist

- Build and launch on a simulator.
- Build and launch on a signed physical device when device testing is in scope.
- Save URLs, text, and images through both sharing entry points.
- Confirm saved items persist after relaunch and can be categorized, moved, pinned, shared, and deleted.
- Confirm English, Traditional Chinese, Simplified Chinese, and System Default update the app and Share Extension.
- Export a backup to Files or a cloud-drive app, then import it and verify both merge and replace behavior.
- Confirm restored categories remain visible in the Share Extension.
