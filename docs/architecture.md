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
- `ShareGatherPackage/Sources/ShareGatherReminders/` owns the optional EventKit adapter for creating reading reminders.
- `ShareGatherShareExtension/ShareViewController.swift` receives shared URLs, text, and images; it lets the user choose a category before saving.
- `ShareGather/SaveToShareGatherIntent.swift` provides the Action-list shortcut for URL and text capture.

## Data Flow

The Share Extension and App Intent write through `SharedLibraryStore`. URL metadata enrichment uses Link Presentation when available, but saving the original content does not depend on enrichment succeeding. After a Share Extension save, a user can explicitly opt in to an EventKit reading reminder; an EventKit failure never rolls back the saved item. The main app reloads from the shared store when it becomes active.

The selected language and the preference for asking about a reading reminder after saving are stored in App Group preferences so the main app and Share Extension use the same settings. These preferences are not included in backups.

## Core Models

- `SharedItem`: URL, text, or image record with display metadata, category assignment, creation date, thumbnail reference, original payload, and pin state.
- `SharedCategory`: ID, name, and creation date. The stored array order is the category display order.
- `SharedOriginalContent`: original value, kind, optional source text, and optional image asset reference.
- `SharedItemKind`: `url`, `text`, or `image`.

Images and thumbnails are referenced by filenames. A persisted item must retain valid references to its media files when that media is present.

## Dependency Boundary

ZIPFoundation is used only by `SharedLibraryStore` for ZIP backup creation and extraction. It does not add a network service, account flow, or synchronization behavior.

EventKit is used only after a user explicitly chooses to create a reminder. `SharedItemDeepLink` creates `sharegather://bookmark/<UUID>` links that the main app resolves to a saved-item detail page. Each reminder stores that link in EventKit's URL field and appends the raw link to its notes because the Reminders UI does not guarantee a visible URL control. Reminder identifiers are not persisted or included in backups.
