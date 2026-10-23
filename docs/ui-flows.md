# UI Flows

## Home

The home screen presents categories, Uncategorized items, recent items, and a privacy banner. The Share Sheet instruction card appears only when the library has no saved items. A Reading List entry with an unread count appears below the privacy banner whenever at least one saved item exists.

Category and Uncategorized lists sort pinned items first, then sort both pinned and unpinned items by creation time from newest to oldest. The home screen's recent-items section ignores pin state and sorts only by creation time from newest to oldest. Pinned status is only managed in category item views; an item moved to Uncategorized retains its persisted pin value for ordering compatibility.

## Categories and Items

Categories can be created, renamed, reordered, and deleted. Deleting a nonempty category prompts the user to either delete its items or move them to Uncategorized.

Category item views support pinning, selection, drag selection, batch move, and batch delete. Uncategorized supports selection, drag selection, batch move, and batch delete, but does not expose a pin action. Batch action bars remain fixed at the bottom while the item list scrolls.

Long-press item menus expose the actions relevant to the item: pin/unpin when available, move, share, and delete. Item detail views provide delete, share, and open-link actions.

## Reading List

The Reading List is reachable from the home screen and lists every saved item regardless of category. A segmented control filters the list by All, Unread, and Read, and each filter provides its own empty state. Items use the same ordering rules as category lists.

Every Reading List row shows a read-status cue: a filled blue dot for unread items and a muted checkmark for read items. The cue carries an accessibility label of Unread or Read.

Read status is changed from the row's long-press menu and from a leading swipe action. Both toggle the current state between Mark as Read and Mark as Unread. Read status is persisted on the device and is not shared, synced, or transmitted. Moving an item to another category, pinning it, or deleting its category does not change its read state.

## Settings

Settings is organized into Preferences, Danger Zone, and App Information.

- Preferences contains language selection.
- Danger Zone clears all saved content and lets the user choose whether categories are retained.
- App Information exposes backup export/import, the Privacy Policy sheet, the GitHub repository, and the official website.

Import displays a result dialog for both successful and failed restore attempts. Exported backup names use `ShareGather Backup yyyy-MM-dd.zip`.

## Sharing

The Share Extension accepts URL, text, and image attachments and offers Uncategorized plus available categories as destinations. URL metadata loading is optional and must never block saving the original shared payload.
