# Architecture

## Components

```text
Main App ──────────────┐
App Intent ────────────┼── ShareGatherStorage ── App Group container
Share Extension ───────┤
Action Extension ──────┘
```

- `ShareGather/ShareGatherApp.swift` starts the SwiftUI app and hosts `ContentView`.
- `ShareGatherPackage/Sources/ShareGatherFeature/ContentView.swift` owns main-app UI state and feature flows.
- `ShareGatherPackage/Sources/ShareGatherStorage/` owns shared persistence models, App Group storage, backup handling, and localization support.
- `ShareGatherShareExtension/ShareViewController.swift` receives shared URLs, text, and images; it lets the user choose a category before saving.
- `ShareGather/SaveToShareGatherIntent.swift` provides the Action-list shortcut for URL and text capture.

## Data Flow

The Share Extension and App Intent write through `SharedLibraryStore`. URL metadata enrichment uses Link Presentation when available, but saving the original content does not depend on enrichment succeeding. The main app reloads from the shared store when it becomes active.

The selected language is stored in the App Group preference so the main app and Share Extension use the same language selection.

## Core Models

- `SharedItem`: URL, text, or image record with display metadata, category assignment, creation date, thumbnail reference, original payload, and pin state.
- `SharedCategory`: ID, name, and creation date. The stored array order is the category display order.
- `SharedOriginalContent`: original value, kind, optional source text, and optional image asset reference.
- `SharedItemKind`: `url`, `text`, or `image`.

Images and thumbnails are referenced by filenames. A persisted item must retain valid references to its media files when that media is present.

## Dependency Boundary

ZIPFoundation is used only by `SharedLibraryStore` for ZIP backup creation and extraction. It does not add a network service, account flow, or synchronization behavior.
