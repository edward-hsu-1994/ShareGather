import Foundation
import Testing
import ShareGatherStorage

private func makeTextItem(
    value: String,
    title: String? = nil,
    description: String? = nil,
    originalContent: SharedOriginalContent? = nil,
    categoryID: UUID? = nil,
    createdAt: Date = Date()
) -> SharedItem {
    SharedItem(
        kind: .text,
        value: value,
        title: title,
        description: description,
        originalContent: originalContent,
        createdAt: createdAt,
        categoryID: categoryID
    )
}

@Test func searchMatchesSavedTitle() {
    let item = makeTextItem(value: "https://example.com", title: "Swift Concurrency Notes")

    #expect(LibrarySearch.matches(item, query: "Concurrency Notes"))
    #expect(!LibrarySearch.matches(item, query: "UIKit"))
}

@Test func searchMatchesItemDescription() {
    let item = makeTextItem(
        value: "https://example.com/actors",
        title: "Actors",
        description: "Isolation and Sendable rules"
    )

    #expect(LibrarySearch.matches(item, query: "Sendable rules"))
}

@Test func searchMatchesURLValue() {
    let item = makeTextItem(value: "https://swift.org/documentation/concurrency")

    #expect(LibrarySearch.matches(item, query: "swift.org/documentation"))
}

@Test func searchMatchesTextValue() {
    let item = makeTextItem(value: "Groceries for the weekend")

    #expect(LibrarySearch.matches(item, query: "Groceries"))
}

@Test func searchMatchesOriginalSharedValue() {
    let item = makeTextItem(
        value: "https://example.com/rewritten",
        title: "Example",
        originalContent: SharedOriginalContent(kind: .url, value: "https://example.org/original")
    )

    #expect(LibrarySearch.matches(item, query: "example.org/original"))
}

@Test func searchMatchesOriginalSourceText() {
    let item = makeTextItem(
        value: "https://example.com/article",
        originalContent: SharedOriginalContent(
            kind: .url,
            value: "https://example.com/article",
            sourceText: "Shared from my favourite reading list"
        )
    )

    #expect(LibrarySearch.matches(item, query: "favourite reading"))
}

@Test func searchMatchesCategoryName() {
    let categoryID = UUID()
    let item = makeTextItem(value: "https://example.com/notes", categoryID: categoryID)

    #expect(LibrarySearch.matches(item, query: "Recipes", categoryName: "Recipes"))
    #expect(!LibrarySearch.matches(item, query: "Travel", categoryName: "Recipes"))
}

@Test func searchIgnoresMissingCategoryName() {
    let item = makeTextItem(value: "https://example.com/notes", categoryID: UUID())

    #expect(!LibrarySearch.matches(item, query: "Recipes"))
}

@Test func searchMatchesImageItemsThroughReadableFieldsOnly() {
    let image = SharedItem(
        kind: .image,
        value: "6C0F2E8A-0000-4000-8000-000000000001.image",
        title: "Receipt",
        originalContent: SharedOriginalContent(
            kind: .image,
            value: "Lighthouse photo",
            sourceText: "Shared from Photos"
        ),
        categoryID: nil
    )

    #expect(LibrarySearch.matches(image, query: "Receipt"))
    #expect(LibrarySearch.matches(image, query: "Lighthouse photo"))
    #expect(LibrarySearch.matches(image, query: "Shared from Photos"))
    #expect(LibrarySearch.matches(image, query: "Weekend", categoryName: "Weekend"))
    // The stored asset filename is not user-visible content.
    #expect(!LibrarySearch.matches(image, query: "6C0F2E8A"))
    #expect(!LibrarySearch.matches(image, query: ".image"))
}

@Test func searchIsCaseInsensitive() {
    let item = makeTextItem(
        value: "https://example.com/Seafood",
        title: "Weekend Recipe"
    )

    #expect(LibrarySearch.matches(item, query: "weekend recipe"))
    #expect(LibrarySearch.matches(item, query: "WEEKEND RECIPE"))
    #expect(LibrarySearch.matches(item, query: "Seafood"))
    #expect(LibrarySearch.matches(item, query: "SEAFOOD"))
}

@Test func searchTrimsSurroundingQueryWhitespace() {
    let item = makeTextItem(value: "https://example.com/recipes", title: "Ramen")

    #expect(LibrarySearch.matches(item, query: "   ramen   "))
    #expect(LibrarySearch.matches(item, query: "\n\tram en\t") == false)
    #expect(LibrarySearch.items(in: [item], matching: "  ramen  ").map(\.id) == [item.id])
    #expect(LibrarySearch.normalizedQuery("\n\t ramen \t\n") == "ramen")
}

@Test func emptyAndWhitespaceOnlyQueriesPreserveEveryItemInOrder() {
    let items = [
        makeTextItem(value: "https://example.com/b"),
        makeTextItem(value: "https://example.com/a"),
        makeTextItem(value: "https://example.com/c")
    ]

    #expect(LibrarySearch.items(in: items, matching: "") == items)
    #expect(LibrarySearch.items(in: items, matching: "   ") == items)
    #expect(LibrarySearch.items(in: items, matching: "\n\t ") == items)
    #expect(LibrarySearch.normalizedQuery("  recipe  ") == "recipe")
    #expect(items.allSatisfy { LibrarySearch.matches($0, query: "   ") })
}

@Test func searchResultsPreserveInputOrder() {
    let categoryID = UUID()
    let first = makeTextItem(value: "https://example.com/1", title: "Match one", categoryID: categoryID)
    let skipped = makeTextItem(value: "https://example.com/2", title: "Unrelated")
    let third = makeTextItem(value: "https://example.com/3", title: "Match three", categoryID: categoryID)

    let matches = LibrarySearch.items(
        in: [first, skipped, third],
        matching: "match",
        categoryNames: [categoryID: "Matched category"]
    )

    #expect(matches.map(\.id) == [first.id, third.id])
}

@Test func searchWithNoMatchesReturnsNoItems() {
    let items = [
        makeTextItem(value: "https://example.com/1", title: "First"),
        makeTextItem(value: "https://example.com/2", title: "Second")
    ]

    #expect(LibrarySearch.items(in: items, matching: "nonexistent query").isEmpty)
    #expect(LibrarySearch.items(in: [], matching: "anything").isEmpty)
}

@Test func searchingPersistedLibraryMatchesSavedFieldsAndCategoryNames() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = try SharedLibraryStore(baseDirectory: directory)
    let recipes = try store.createCategory(named: "Recipes")
    let matchingItem = try store.saveItem(
        kind: .url,
        value: "https://example.com/roast-carrots",
        categoryID: recipes.id,
        title: "Roasted Carrots",
        description: "Oven roasted with cumin",
        originalContent: SharedOriginalContent(
            kind: .url,
            value: "https://example.org/roast-carrots",
            sourceText: "Shared from Cooking Notes"
        )
    )
    let uncategorizedItem = try store.saveItem(kind: .text, value: "Pack sunscreen", categoryID: nil)

    let items = try store.loadItems()
    let categoryNames = Dictionary(
        uniqueKeysWithValues: try store.loadCategories().map { ($0.id, $0.name) }
    )

    #expect(LibrarySearch.items(in: items, matching: "carrots", categoryNames: categoryNames).map(\.id) == [matchingItem.id])
    #expect(LibrarySearch.items(in: items, matching: "CUMIN", categoryNames: categoryNames).map(\.id) == [matchingItem.id])
    #expect(LibrarySearch.items(in: items, matching: " example.org ", categoryNames: categoryNames).map(\.id) == [matchingItem.id])
    #expect(LibrarySearch.items(in: items, matching: "Cooking Notes", categoryNames: categoryNames).map(\.id) == [matchingItem.id])
    #expect(LibrarySearch.items(in: items, matching: "recipes", categoryNames: categoryNames).map(\.id) == [matchingItem.id])
    #expect(LibrarySearch.items(in: items, matching: "sunscreen", categoryNames: categoryNames).map(\.id) == [uncategorizedItem.id])
    #expect(LibrarySearch.items(in: items, matching: "  ", categoryNames: categoryNames).count == items.count)
    #expect(LibrarySearch.items(in: items, matching: "helicopter", categoryNames: categoryNames).isEmpty)
}