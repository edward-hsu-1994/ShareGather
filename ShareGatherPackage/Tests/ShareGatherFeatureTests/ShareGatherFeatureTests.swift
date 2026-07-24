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
        unexpected.subdata(in: position..<(position + size))
    }

    let destination = try SharedLibraryStore(baseDirectory: destinationDirectory)
    let existing = try destination.saveItem(kind: .text, value: "Existing", categoryID: nil)
    #expect(throws: SharedLibraryBackupError.self) {
        try destination.importBackup(at: backupURL, mode: .replace)
    }
    #expect(try destination.loadItems().map(\.id) == [existing.id])
}
