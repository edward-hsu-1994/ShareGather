import Foundation
import Testing
import ZIPFoundation
@testable import ShareGatherFeature
import ShareGatherStorage

@Test func reorderingCategoriesPersistsWithoutChangingItemAssignments() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = try SharedLibraryStore(baseDirectory: directory)
    let first = try store.createCategory(named: "First")
    let second = try store.createCategory(named: "Second")
    let third = try store.createCategory(named: "Third")
    let item = try store.saveItem(kind: .text, value: "Saved text", categoryID: second.id)

    try store.reorderCategories(ids: [third.id, first.id, second.id])

    #expect(try store.loadCategories().map(\.id) == [third.id, first.id, second.id])
    #expect(try store.loadItems().first?.id == item.id)
    #expect(try store.loadItems().first?.categoryID == second.id)
}

@Test func clearingAllItemsPreservesCategoriesAndRemovesMedia() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = try SharedLibraryStore(baseDirectory: directory)
    let first = try store.createCategory(named: "First")
    let second = try store.createCategory(named: "Second")
    try store.reorderCategories(ids: [second.id, first.id])

    let imageItem = try store.saveItem(
        kind: .image,
        value: "image",
        categoryID: first.id,
        imageData: Data([1, 2, 3]),
        thumbnailData: Data([4, 5, 6])
    )
    let linkItem = try store.saveItem(
        kind: .url,
        value: "https://example.com",
        categoryID: second.id,
        thumbnailData: Data([7, 8, 9])
    )

    #expect(try store.clearAllSavedContent(keepingCategories: true) == 2)
    #expect(try store.loadItems().isEmpty)
    #expect(try store.loadCategories().map(\.id) == [second.id, first.id])
    #expect(store.imageData(for: imageItem) == nil)
    #expect(store.thumbnailData(for: imageItem) == nil)
    #expect(store.thumbnailData(for: linkItem) == nil)
    #expect(try store.clearAllSavedContent(keepingCategories: true) == 0)

    _ = try store.saveItem(kind: .text, value: "Another saved item", categoryID: first.id)
    #expect(try store.clearAllSavedContent(keepingCategories: false) == 1)
    #expect(try store.loadCategories().isEmpty)
}

@Test func pinningAnItemPersistsAndSurvivesRecategorization() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = try SharedLibraryStore(baseDirectory: directory)
    let first = try store.createCategory(named: "First")
    let second = try store.createCategory(named: "Second")
    let item = try store.saveItem(kind: .text, value: "Saved text", categoryID: first.id)

    #expect(item.isPinned == false)
    #expect(try store.updateItemPin(id: item.id, isPinned: true).isPinned)
    #expect(try store.loadItems().first?.isPinned == true)
    #expect(try store.updateItemCategory(id: item.id, categoryID: second.id).isPinned == true)
    #expect(try store.updateItemPin(id: item.id, isPinned: false).isPinned == false)
}

@Test func backupReplaceRestoresPreparedLibraryAndMedia() throws {
    let sourceDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    let destinationDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).zip")
    defer {
        try? FileManager.default.removeItem(at: sourceDirectory)
        try? FileManager.default.removeItem(at: destinationDirectory)
        try? FileManager.default.removeItem(at: backupURL)
    }

    let source = try SharedLibraryStore(baseDirectory: sourceDirectory)
    let category = try source.createCategory(named: "Imported")
    let image = try source.saveItem(
        kind: .image,
        value: "image",
        categoryID: category.id,
        imageData: Data([1, 2, 3]),
        thumbnailData: Data([4, 5, 6])
    )
    _ = try source.exportBackup(to: backupURL)

    let destination = try SharedLibraryStore(baseDirectory: destinationDirectory)
    _ = try destination.saveItem(kind: .text, value: "Existing", categoryID: nil)
    _ = try destination.importBackup(at: backupURL, mode: .replace)

    #expect(try destination.loadCategories().map(\.id) == [category.id])
    #expect(try destination.loadItems().map(\.id) == [image.id])
    let restoredImage = try #require(try destination.loadItems().first)
    #expect(destination.imageData(for: restoredImage) == Data([1, 2, 3]))
}

@Test func backupImportRejectsUnexpectedArchiveFilesWithoutChangingLibrary() throws {
    let sourceDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    let destinationDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).zip")
    defer {
        try? FileManager.default.removeItem(at: sourceDirectory)
        try? FileManager.default.removeItem(at: destinationDirectory)
        try? FileManager.default.removeItem(at: backupURL)
    }

    let source = try SharedLibraryStore(baseDirectory: sourceDirectory)
    _ = try source.saveItem(kind: .text, value: "Imported", categoryID: nil)
    _ = try source.exportBackup(to: backupURL)
    let archive = try #require(Archive(url: backupURL, accessMode: .update))
    let unexpected = Data("unexpected".utf8)
    try archive.addEntry(
        with: "unexpected.txt",
        type: .file,
        uncompressedSize: Int64(unexpected.count),
        compressionMethod: .none
    ) { position, size in
        unexpected.subdata(in: Int(position)..<(Int(position) + size))
    }

    let destination = try SharedLibraryStore(baseDirectory: destinationDirectory)
    let existing = try destination.saveItem(kind: .text, value: "Existing", categoryID: nil)
    #expect(throws: SharedLibraryBackupError.self) {
        try destination.importBackup(at: backupURL, mode: .replace)
    }
    #expect(try destination.loadItems().map(\.id) == [existing.id])
}

@Test func legacyItemsWithoutReadStatusDecodeAsUnread() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let itemID = UUID()
    let legacyJSON = """
    [
      {
        "id": "\(itemID.uuidString)",
        "kind": "text",
        "value": "Legacy saved text",
        "isPinned": true,
        "createdAt": "2026-01-02T03:04:05Z"
      }
    ]
    """
    let decoded = try JSONDecoder().decode([SharedItem].self, from: Data(legacyJSON.utf8))
    #expect(decoded.first?.isRead == false)

    let store = try SharedLibraryStore(baseDirectory: directory)
    try Data(legacyJSON.utf8).write(
        to: directory.appendingPathComponent("saved-items.json"),
        options: .atomic
    )
    let legacyItem = try #require(try store.loadItems().first)
    #expect(legacyItem.id == itemID)
    #expect(legacyItem.isPinned)
    #expect(legacyItem.isRead == false)
}

@Test func updatingReadStatusPersistsAndPreservesOtherItemFields() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = try SharedLibraryStore(baseDirectory: directory)
    let category = try store.createCategory(named: "Reading")
    let item = try store.saveItem(
        kind: .url,
        value: "https://example.com/article",
        categoryID: category.id,
        title: "Article",
        description: "A saved article",
        thumbnailData: Data([1, 2, 3]),
        originalContent: SharedOriginalContent(
            kind: .url,
            value: "https://example.com/article",
            sourceText: "Shared from Safari"
        )
    )

    #expect(item.isRead == false)

    let readItem = try store.updateItemReadStatus(id: item.id, isRead: true)
    #expect(readItem.isRead)
    #expect(readItem.id == item.id)
    #expect(readItem.kind == .url)
    #expect(readItem.value == item.value)
    #expect(readItem.title == "Article")
    #expect(readItem.description == "A saved article")
    #expect(readItem.thumbnailFilename == item.thumbnailFilename)
    #expect(readItem.originalContent == item.originalContent)
    #expect(readItem.categoryID == category.id)
    #expect(readItem.isPinned == false)
    #expect(store.thumbnailData(for: readItem) == Data([1, 2, 3]))

    let reloadedItem = try #require(try store.loadItems().first)
    #expect(reloadedItem.id == readItem.id)
    #expect(reloadedItem.isRead)
    #expect(reloadedItem.isPinned == false)
    #expect(reloadedItem.categoryID == category.id)
    #expect(reloadedItem.originalContent == item.originalContent)
    #expect(abs(reloadedItem.createdAt.timeIntervalSince(item.createdAt)) < 1)

    let reopened = try SharedLibraryStore(baseDirectory: directory)
    let reopenedItem = try #require(try reopened.loadItems().first)
    #expect(reopenedItem.isRead)

    #expect(try store.updateItemReadStatus(id: item.id, isRead: false).isRead == false)
    let rereadItem = try #require(try store.loadItems().first)
    #expect(rereadItem.isRead == false)
    #expect(throws: SharedLibraryError.itemNotFound) {
        try store.updateItemReadStatus(id: UUID(), isRead: true)
    }
}

@Test func readStatusSurvivesCategoryAndPinUpdates() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = try SharedLibraryStore(baseDirectory: directory)
    let first = try store.createCategory(named: "First")
    let second = try store.createCategory(named: "Second")
    let item = try store.saveItem(kind: .text, value: "Saved text", categoryID: first.id)

    #expect(try store.updateItemReadStatus(id: item.id, isRead: true).isRead)
    #expect(try store.updateItemCategory(id: item.id, categoryID: second.id).isRead)
    #expect(try store.updateItemPin(id: item.id, isPinned: true).isRead)

    let uncategorizedItems = try #require(try store.updateItemsCategory(ids: [item.id], categoryID: nil).first)
    #expect(uncategorizedItems.isRead)
    let reloadedAfterUpdates = try #require(try store.loadItems().first)
    #expect(reloadedAfterUpdates.isRead)

    let unreadItem = try store.saveItem(kind: .text, value: "Another text", categoryID: second.id)
    #expect(unreadItem.isRead == false)

    _ = try store.deleteCategory(id: second.id, itemDisposition: .moveItemsToUncategorized)
    let storedItems = try store.loadItems()
    let readStatusByID = Dictionary(uniqueKeysWithValues: storedItems.map { ($0.id, $0.isRead) })
    #expect(readStatusByID[item.id] == true)
    #expect(readStatusByID[unreadItem.id] == false)
    let movedItem = try #require(storedItems.first { $0.id == item.id })
    #expect(movedItem.categoryID == nil)
}

@Test func backupRoundTripPreservesReadStatus() throws {
    let sourceDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    let destinationDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    let mergeDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).zip")
    defer {
        try? FileManager.default.removeItem(at: sourceDirectory)
        try? FileManager.default.removeItem(at: destinationDirectory)
        try? FileManager.default.removeItem(at: mergeDirectory)
        try? FileManager.default.removeItem(at: backupURL)
    }

    let source = try SharedLibraryStore(baseDirectory: sourceDirectory)
    let category = try source.createCategory(named: "Reading")
    let readItem = try source.saveItem(kind: .text, value: "Read text", categoryID: category.id)
    _ = try source.updateItemReadStatus(id: readItem.id, isRead: true)
    let unreadItem = try source.saveItem(kind: .url, value: "https://example.com", categoryID: category.id)
    _ = try source.exportBackup(to: backupURL)

    let destination = try SharedLibraryStore(baseDirectory: destinationDirectory)
    _ = try destination.saveItem(kind: .text, value: "Existing", categoryID: nil)
    _ = try destination.importBackup(at: backupURL, mode: .replace)

    let restoredReadStatus = Dictionary(
        uniqueKeysWithValues: try destination.loadItems().map { ($0.id, $0.isRead) }
    )
    #expect(restoredReadStatus[readItem.id] == true)
    #expect(restoredReadStatus[unreadItem.id] == false)

    let mergeStore = try SharedLibraryStore(baseDirectory: mergeDirectory)
    let localItem = try mergeStore.saveItem(kind: .text, value: "Local", categoryID: nil)
    _ = try mergeStore.updateItemReadStatus(id: localItem.id, isRead: true)
    _ = try mergeStore.importBackup(at: backupURL, mode: .merge)

    let mergedReadStatus = Dictionary(
        uniqueKeysWithValues: try mergeStore.loadItems().map { ($0.id, $0.isRead) }
    )
    #expect(mergedReadStatus[localItem.id] == true)
    #expect(mergedReadStatus[readItem.id] == true)
    #expect(mergedReadStatus[unreadItem.id] == false)
}
