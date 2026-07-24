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
