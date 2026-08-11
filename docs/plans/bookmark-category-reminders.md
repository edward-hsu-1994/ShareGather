# Bookmark Category Reminders

## Objective

After a shared item is saved and the user confirms its category, ShareGather should optionally create an Apple Reminders entry. The reminder must link back to the exact saved-item detail page in ShareGather.

The saved item remains the source of truth. A reminder is an optional external integration and must never be required for saving or cause a saved item to be rolled back.

## Recommended first release

The Share Extension keeps its existing category and Uncategorized chooser. After the item is durably written to the App Group, it asks whether the user wants to set a reminder.

If the user chooses to continue, a reminder form provides:

- An editable title, initially derived from the saved item's display title.
- An optional note containing concise ShareGather and category context.
- A date and time for the reminder notification.
- The user's default Reminders list.

The first release does not include recurrence, priority, custom list selection, or synchronization of reminder edits and completion state.

## Deep-link contract

Use one stable URL format:

```text
sharegather://bookmark/<SharedItem UUID>
```

Add a shared `SharedItemDeepLink` helper for URL generation and parsing. Register the `sharegather` URL scheme on the main app and route valid URLs to the matching saved-item detail view on both cold and warm launches.

Malformed URLs, unknown UUIDs, and links to deleted items must fail safely by returning to the library and showing localized feedback. The existing `SharedItem.id` is sufficient; no reminder identifier needs to be added to the persisted model or backup format.

## EventKit integration

Use a dedicated `ShareGatherReminders` module rather than placing EventKit code in the storage implementation. The service owns one `EKEventStore` for the duration of an operation and exposes a testable value-type draft and typed errors.

The reminder is populated with the draft title and notes, the ShareGather deep link as its URL, and `defaultCalendarForNewReminders()` as its calendar. Scheduled reminders set both start and due date components and add an alarm. The iOS deployment target requires the modern full Reminders access API and purpose string.

Permission is requested only after the user explicitly confirms that they want a reminder. Denied access, a missing default list, or an EventKit save error leaves the saved item intact and provides a retry or dismiss path.

## Share Extension feasibility gate

The direct Share Extension flow should first be validated on a physical device, including the permission prompt and reminder save. The extension should use its own UIKit form and EventKit APIs rather than relying on an unsupported way to launch the containing app.

If permission or EventKit persistence is unreliable in the extension lifecycle, keep the item saved immediately and write a pending reminder request to the App Group. The main app can present the reminder form at its next activation, with the saved-item detail view also providing a manual “Set reminder” action.

## Persistence and privacy

Do not store EventKit reminder identifiers in `SharedItem` in the first release, and do not delete external reminders when a ShareGather item is deleted. A reminder pointing to a deleted item should open the library and show an unavailable-item state.

Creating a reminder explicitly writes the selected title, notes, and ShareGather URL to the user's Reminders database. That data may sync through the accounts configured by the user, but this does not introduce a ShareGather server, account, analytics, or cloud-synchronization service. The privacy policy and user-facing copy must explain this boundary.

## Implementation phases

1. Add and test the deep-link generator/parser, URL scheme registration, and main-app routing.
2. Add the EventKit reminder module, authorization/error handling, modern Reminders usage descriptions, and unit-testable draft generation.
3. Update the Share Extension save sequence and add the localized reminder question and UIKit form.
4. If needed, add the App Group pending-request fallback and a manual reminder action from the saved-item detail view.
5. Update architecture, UI-flow, development, README, and privacy documentation.

## Verification

Test the no-reminder, first-time allow, deny, previously denied, missing default list, successful save, duplicate-tap, and EventKit failure paths. Verify URL, text, and image saves still work and that reminder links open the correct detail page from cold and warm launches, including deleted or restored items.

Build both the app and Share Extension, validate generated Info.plist purpose strings, and verify English, Traditional Chinese, Simplified Chinese, and System Default behavior on a physical device. Run the package tests and `git diff --check` before publishing.

## Scope decisions

- The initial implementation covers the Share Extension flow; the App Intent and Action Extension remain unchanged.
- A reminder means a scheduled alert in the first release, so a date and time are collected explicitly.
- The default Reminders list is used initially; list selection and synchronization are future work.
