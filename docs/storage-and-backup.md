# Storage and Backup

## Local Storage

All user data lives in the App Group container `group.com.sharegather.app`:

```text
saved-items.json
categories.json
Images/
Thumbnails/
```

`SharedLibraryStore` owns item/category CRUD, category reordering, pin updates, batch operations, clearing content, and backup operations. Normal JSON writes use atomic writes. Existing JSON must remain decodable when storage fields evolve; `isPinned` defaults to `false` when absent and item dates support the current ISO-8601 representation plus the legacy numeric representation.

Deleting an item removes its owned image and thumbnail when present. Clearing all saved content removes item metadata and both media directories; it can optionally retain categories.

## Backup Format v1

An exported backup is a ZIP archive with this root layout:

```text
manifest.json
categories.json
items.json
Images/
Thumbnails/
```

The manifest uses identifier `com.sharegather.backup`, version `1`, creation time, and item/media counts. Backups include categories and order, items, pin state, original content, images, and thumbnails. The app-language preference is not exported.

Export stages a snapshot in temporary storage, creates a ZIP, then opens the iOS system share sheet. Backup archives are not encrypted.

## Restore Flow

Import uses the Files picker. The selected ZIP is copied to temporary storage, extracted, and validated before the user chooses an operation.

Current validation checks the backup identifier and version, decodable metadata, duplicate category/item IDs, category references, and required image/thumbnail files.

- **Merge** retains current UUID-matching categories and items, then adds backup records with nonmatching IDs.
- **Replace** clears current items, categories, images, and thumbnails before restoring the backup.
- Imported image and thumbnail filenames are regenerated to avoid overwriting local media files.

## Current Limits

Do not claim capabilities that are not implemented. Current backups have no encryption, password protection, checksums, archive size limits, path-traversal hardening, transaction journal, or crash-recovery mechanism. Backup sharing is user-directed and is not cloud synchronization.
