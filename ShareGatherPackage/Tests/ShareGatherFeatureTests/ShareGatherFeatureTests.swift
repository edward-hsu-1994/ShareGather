import Testing
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
