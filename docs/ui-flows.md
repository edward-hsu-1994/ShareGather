# UI Flows

## Home

The home screen presents categories, Uncategorized items, recent items, and a privacy banner. The Share Sheet instruction card appears only when the library has no saved items.

Category and Uncategorized lists sort pinned items first, then sort both pinned and unpinned items by creation time from newest to oldest. The home screen's recent-items section ignores pin state and sorts only by creation time from newest to oldest. Pinned status is only managed in category item views; an item moved to Uncategorized retains its persisted pin value for ordering compatibility.

## Search

The home screen search field matches the whole library locally: titles, descriptions, URL and text values, the original shared value and its source text, and category names. Matching is case-insensitive and ignores surrounding whitespace in the query.

An empty or whitespace-only query keeps the normal home presentation. A non-empty query replaces the home content with the matching items from every category plus Uncategorized, each labeled with its category name or `Uncategorized`, ordered with pinned items first and then newest to oldest. Search results reuse the standard item interactions: open the item detail, share, move, and delete. A query with no matches shows a localized no-results message. Search never fetches anything from the network.

## Categories and Items

Categories can be created, renamed, reordered, and deleted. Deleting a nonempty category prompts the user to either delete its items or move them to Uncategorized.

Category item views support pinning, selection, drag selection, batch move, and batch delete. Uncategorized supports selection, drag selection, batch move, and batch delete, but does not expose a pin action. Batch action bars remain fixed at the bottom while the item list scrolls.

Long-press item menus expose the actions relevant to the item: pin/unpin when available, move, share, and delete. Item detail views provide delete, share, and open-link actions.

## Settings

Settings is organized into Preferences, Danger Zone, and App Information.

- Preferences contains language selection.
- Danger Zone clears all saved content and lets the user choose whether categories are retained.
- App Information exposes backup export/import, the Privacy Policy sheet, the GitHub repository, and the official website.

Import displays a result dialog for both successful and failed restore attempts. Exported backup names use `ShareGather Backup yyyy-MM-dd.zip`.

## Sharing

The Share Extension accepts URL, text, and image attachments and offers Uncategorized plus available categories as destinations. URL metadata loading is optional and must never block saving the original shared payload.
