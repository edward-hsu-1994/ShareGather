# ShareGather

ShareGather is a privacy-first iPhone app that receives content from the iOS Share Sheet and keeps it available for later review.

It is designed for moments when something is interesting but there is no time to read it immediately. ShareGather stores the saved content locally, without accounts, sign-in, or a server-side service.

## Features

- Receive URLs, text, and images from other apps through the Share Sheet.
- Save content locally in an App Group shared by the main app and Share Extension.
- Organize saved items into user-created categories or leave them Uncategorized.
- Create, rename, and delete categories.
- Delete a saved item with confirmation.
- Move an item between categories, including back to Uncategorized.
- Show URL metadata when available, including a title, description/source, and thumbnail.
- Keep the original shared content alongside display metadata for later re-sharing.
- Open or share an item again from its detail page.
- Show recent saved items on the home screen.
- Work without an account or cloud backend. URL metadata enrichment is best-effort; saving does not depend on it succeeding.

## Localization

The app supports:

- English (`en`)
- Traditional Chinese (`zh-Hant`)
- Simplified Chinese (`zh-Hans`)

`System Default` follows the device language. If the device language is not supported, the app falls back to English. The selected language is shared with the Share Extension through the App Group preferences.

The shared localization implementation is in `ShareGatherStorage`:

- English and Traditional Chinese resources are maintained in `Resources/Localizable.xcstrings`.
- Simplified Chinese strings are provided by `Localization.swift`.
- User-facing strings should use localization keys rather than language conditionals or ternary expressions.

## Architecture

- `ShareGather/` contains the SwiftUI app entry point.
- `ShareGatherPackage/Sources/ShareGatherFeature/` contains the main app UI and interaction flows.
- `ShareGatherPackage/Sources/ShareGatherStorage/` contains local persistence models, the App Group store, and shared localization.
- `ShareGatherPackage/Sources/ShareGatherStorage/Resources/` contains the String Catalog.
- `ShareGatherShareExtension/` contains the Share Extension that reads incoming URL, text, and image attachments, prepares metadata, and saves items.
- `ShareGatherPackage/Tests/` contains Swift Package tests.
- `ShareGatherUITests/` contains Xcode UI test scaffolding.
- `Config/` contains shared entitlements and build configuration.

The primary shared models are `SharedItem`, `SharedCategory`, and `SharedOriginalContent`. Saved items include display metadata, category assignment, creation date, and the original shared payload when available. Images and URL thumbnails are stored in the local App Group container; item metadata is serialized locally.

## Requirements

- macOS with Xcode
- iOS 17 or later
- An Apple Developer account for physical-device testing
- A registered, paired iPhone with Developer Mode enabled for physical-device testing

## Build and Run

Open `ShareGather.xcworkspace` in Xcode and select the `ShareGather` scheme.

For simulator verification, the repository uses XcodeBuildMCP:

```sh
xcodebuildmcp simulator build-and-run \
  --workspace-path ./ShareGather.xcworkspace \
  --scheme ShareGather \
  --simulator-name 'iPhone 17'
```

For a physical device, configure an Apple Developer account in Xcode, enable Developer Mode on the iPhone, register the device with the team, and select the Development Team for both `ShareGather` and `ShareGatherShareExtension`. Then run:

```sh
xcodebuildmcp device list
xcodebuildmcp device build-and-run \
  --workspace-path ./ShareGather.xcworkspace \
  --scheme ShareGather \
  --device-id <device-udid> \
  --extra-args=-allowProvisioningUpdates
```

The Share Extension requires valid signing and provisioning for physical-device installation. Simulator builds do not require device provisioning.

## Testing

Run the relevant test target from Xcode or use XcodeBuildMCP for project-specific test workflows. At minimum, verify:

- The app builds for the simulator.
- The app builds and launches on a signed physical device when device testing is in scope.
- URLs, text, and images can be received through the Share Sheet.
- Items remain available after relaunch and can be categorized, moved, shared, and deleted.
- English, Traditional Chinese, Simplified Chinese, and System Default language selection update the app and Share Extension.

## Privacy and Product Constraints

ShareGather is intentionally local-first:

- No account or sign-in flow.
- No required server or cloud storage.
- Saved content belongs to the user and stays in the local App Group container.
- New functionality should preserve offline use unless the product requirements explicitly change.
