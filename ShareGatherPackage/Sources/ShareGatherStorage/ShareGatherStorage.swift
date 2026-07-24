import Foundation

public enum SharedItemKind: String, Codable, CaseIterable, Sendable {
    case url
    case text
    case image
}

public struct SharedCategory: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public struct SharedOriginalContent: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let kind: SharedItemKind
    public let value: String
    public let sourceText: String?
    public let assetFilename: String?

    public init(
        schemaVersion: Int = 1,
        kind: SharedItemKind,
        value: String,
        sourceText: String? = nil,
        assetFilename: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.value = value
        self.sourceText = sourceText
        self.assetFilename = assetFilename
    }
}

public struct SharedItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let kind: SharedItemKind
    public let value: String
    public let title: String?
    public let description: String?
    public let thumbnailFilename: String?
    public let originalContent: SharedOriginalContent?
    public let createdAt: Date
    public let categoryID: UUID?
    public let isPinned: Bool

    public init(
        id: UUID = UUID(),
        kind: SharedItemKind,
        value: String,
        title: String? = nil,
        description: String? = nil,
        thumbnailFilename: String? = nil,
        originalContent: SharedOriginalContent? = nil,
        createdAt: Date = Date(),
        categoryID: UUID? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.value = value
        self.title = title
        self.description = description
        self.thumbnailFilename = thumbnailFilename
        self.originalContent = originalContent
        self.createdAt = createdAt
        self.categoryID = categoryID
        self.isPinned = isPinned
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, value, title, description, thumbnailFilename, originalContent, createdAt, categoryID, isPinned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(SharedItemKind.self, forKey: .kind)
        value = try container.decode(String.self, forKey: .value)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        thumbnailFilename = try container.decodeIfPresent(String.self, forKey: .thumbnailFilename)
        originalContent = try container.decodeIfPresent(SharedOriginalContent.self, forKey: .originalContent)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        createdAt = try Self.decodeDate(from: container.superDecoder(forKey: .createdAt))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(thumbnailFilename, forKey: .thumbnailFilename)
        try container.encodeIfPresent(originalContent, forKey: .originalContent)
        try container.encode(categoryID, forKey: .categoryID)
        try container.encode(isPinned, forKey: .isPinned)

        let formatter = ISO8601DateFormatter()
		let dateContainer = container.superEncoder(forKey: .createdAt)
        var singleValue = dateContainer.singleValueContainer()
        try singleValue.encode(formatter.string(from: createdAt))
    }

    private static func decodeDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self),
           let date = ISO8601DateFormatter().date(from: string) {
            return date
        }
        if let seconds = try? container.decode(Double.self) {
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date format")
    }
}

public enum CategoryDeletionItemDisposition: Equatable, Sendable {
    case deleteItems
    case moveItemsToUncategorized
}

public enum CategoryOrderError: Error, Equatable, Sendable {
    case invalidCategoryIDs
}

public struct CategoryDeletionResult: Sendable {
    public let deletedCategoryID: UUID
    public let deletedItemIDs: [UUID]
    public let reassignedItemIDs: [UUID]

    public init(
        deletedCategoryID: UUID,
        deletedItemIDs: [UUID],
        reassignedItemIDs: [UUID]
    ) {
        self.deletedCategoryID = deletedCategoryID
        self.deletedItemIDs = deletedItemIDs
        self.reassignedItemIDs = reassignedItemIDs
    }
}

public final class SharedLibraryStore: @unchecked Sendable {
    public static let appGroupIdentifier = "group.com.sharegather.app"

    private let baseDirectory: URL
    private let lock = NSLock()

    public init(baseDirectory: URL? = nil) throws {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else if let groupDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) {
            self.baseDirectory = groupDirectory
        } else {
            throw CocoaError(.fileNoSuchFile)
        }

        try FileManager.default.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true)
    }

    public func loadCategories() throws -> [SharedCategory] {
        try read([SharedCategory].self, from: categoriesURL, missingValue: [])
    }

    @discardableResult
    public func createCategory(named rawName: String) throws -> SharedCategory {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 50 else {
            throw SharedLibraryError.invalidCategoryName
        }

        lock.lock()
        defer { lock.unlock() }

        var categories = try readUnlocked([SharedCategory].self, from: categoriesURL, missingValue: [])
        if let existing = categories.first(where: { normalized($0.name) == normalized(name) }) {
            return existing
        }

        let category = SharedCategory(name: name)
        categories.append(category)
        try writeUnlocked(categories, to: categoriesURL)
        return category
    }

    @discardableResult
    public func renameCategory(id: UUID, named rawName: String) throws -> SharedCategory {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 50 else {
            throw SharedLibraryError.invalidCategoryName
        }

        lock.lock()
        defer { lock.unlock() }

        var categories = try readUnlocked([SharedCategory].self, from: categoriesURL, missingValue: [])
        guard let index = categories.firstIndex(where: { $0.id == id }) else {
            throw SharedLibraryError.categoryNotFound
        }
        if categories.contains(where: { $0.id != id && normalized($0.name) == normalized(name) }) {
            return categories[index]
        }

        let current = categories[index]
        let renamed = SharedCategory(id: current.id, name: name, createdAt: current.createdAt)
        categories[index] = renamed
        try writeUnlocked(categories, to: categoriesURL)
        return renamed
    }

    public func reorderCategories(ids: [UUID]) throws {
        lock.lock()
        defer { lock.unlock() }

        let categories = try readUnlocked([SharedCategory].self, from: categoriesURL, missingValue: [])
        let categoryIDs = Set(categories.map(\.id))
        guard ids.count == categories.count,
              Set(ids).count == ids.count,
              Set(ids) == categoryIDs else {
            throw CategoryOrderError.invalidCategoryIDs
        }

        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let reorderedCategories = ids.compactMap { categoriesByID[$0] }
        try writeUnlocked(reorderedCategories, to: categoriesURL)
    }

    public func loadItems() throws -> [SharedItem] {
        try read([SharedItem].self, from: itemsURL, missingValue: [])
    }

    @discardableResult
    public func clearAllSavedContent(keepingCategories: Bool) throws -> Int {
        lock.lock()
        defer { lock.unlock() }

        let items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
        try writeUnlocked([SharedItem](), to: itemsURL)
        if !keepingCategories {
            try writeUnlocked([SharedCategory](), to: categoriesURL)
        }

        let fileManager = FileManager.default
        try? fileManager.removeItem(at: baseDirectory.appendingPathComponent("Images", isDirectory: true))
        try? fileManager.removeItem(at: baseDirectory.appendingPathComponent("Thumbnails", isDirectory: true))
        return items.count
    }

    public func saveItem(
        kind: SharedItemKind,
        value: String,
        categoryID: UUID?,
        imageData: Data? = nil,
        title: String? = nil,
        description: String? = nil,
        thumbnailData: Data? = nil,
        originalContent: SharedOriginalContent? = nil
    ) throws -> SharedItem {
        lock.lock()
        defer { lock.unlock() }

        var storedValue = value
        var imageURL: URL?
        var thumbnailURL: URL?
        if kind == .image, let imageData {
            let imagesDirectory = baseDirectory.appendingPathComponent("Images", isDirectory: true)
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            let fileName = "\(UUID().uuidString).image"
            imageURL = imagesDirectory.appendingPathComponent(fileName)
            try imageData.write(to: imageURL!, options: .atomic)
            storedValue = fileName
        }

        if let thumbnailData {
            let thumbnailsDirectory = baseDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
            try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
            let fileName = "\(UUID().uuidString).thumbnail"
            thumbnailURL = thumbnailsDirectory.appendingPathComponent(fileName)
            try thumbnailData.write(to: thumbnailURL!, options: .atomic)
        }

        do {
            var items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
            let item = SharedItem(
                kind: kind,
                value: storedValue,
                title: title,
                description: description,
                thumbnailFilename: thumbnailURL?.lastPathComponent,
                originalContent: originalContent.map {
                    SharedOriginalContent(
                        kind: $0.kind,
                        value: $0.value,
                        sourceText: $0.sourceText,
                        assetFilename: imageURL?.lastPathComponent ?? $0.assetFilename
                    )
                },
                categoryID: categoryID
            )
            items.insert(item, at: 0)
            try writeUnlocked(items, to: itemsURL)
            return item
        } catch {
            if let imageURL {
                try? FileManager.default.removeItem(at: imageURL)
            }
            if let thumbnailURL {
                try? FileManager.default.removeItem(at: thumbnailURL)
            }
            throw error
        }
    }

    @discardableResult
    public func updateItemCategory(id: UUID, categoryID: UUID?) throws -> SharedItem {
        lock.lock()
        defer { lock.unlock() }

        if let categoryID {
            let categories = try readUnlocked([SharedCategory].self, from: categoriesURL, missingValue: [])
            guard categories.contains(where: { $0.id == categoryID }) else {
                throw SharedLibraryError.categoryNotFound
            }
        }

        var items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw SharedLibraryError.itemNotFound
        }

        let current = items[index]
        let updated = SharedItem(
            id: current.id,
            kind: current.kind,
            value: current.value,
            title: current.title,
            description: current.description,
            thumbnailFilename: current.thumbnailFilename,
            originalContent: current.originalContent,
            createdAt: current.createdAt,
            categoryID: categoryID,
            isPinned: current.isPinned
        )
        items[index] = updated
        try writeUnlocked(items, to: itemsURL)
        return updated
    }

    @discardableResult
    public func updateItemPin(id: UUID, isPinned: Bool) throws -> SharedItem {
        lock.lock()
        defer { lock.unlock() }

        var items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw SharedLibraryError.itemNotFound
        }

        let current = items[index]
        let updated = SharedItem(
            id: current.id,
            kind: current.kind,
            value: current.value,
            title: current.title,
            description: current.description,
            thumbnailFilename: current.thumbnailFilename,
            originalContent: current.originalContent,
            createdAt: current.createdAt,
            categoryID: current.categoryID,
            isPinned: isPinned
        )
        items[index] = updated
        try writeUnlocked(items, to: itemsURL)
        return updated
    }

    @discardableResult
    public func updateItemsCategory(ids: [UUID], categoryID: UUID?) throws -> [SharedItem] {
        guard !ids.isEmpty else { return [] }
        guard Set(ids).count == ids.count else { throw SharedLibraryError.itemNotFound }

        lock.lock()
        defer { lock.unlock() }

        if let categoryID {
            let categories = try readUnlocked([SharedCategory].self, from: categoriesURL, missingValue: [])
            guard categories.contains(where: { $0.id == categoryID }) else {
                throw SharedLibraryError.categoryNotFound
            }
        }

        var items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
        let requestedIDs = Set(ids)
        guard requestedIDs.isSubset(of: Set(items.map(\.id))) else {
            throw SharedLibraryError.itemNotFound
        }

        var updatedItems: [SharedItem] = []
        items = items.map { item in
            guard requestedIDs.contains(item.id) else { return item }
            let updated = SharedItem(
                id: item.id,
                kind: item.kind,
                value: item.value,
                title: item.title,
                description: item.description,
                thumbnailFilename: item.thumbnailFilename,
                originalContent: item.originalContent,
                createdAt: item.createdAt,
                categoryID: categoryID,
                isPinned: item.isPinned
            )
            updatedItems.append(updated)
            return updated
        }
        try writeUnlocked(items, to: itemsURL)
        return updatedItems
    }

    @discardableResult
    public func deleteItems(ids: [UUID]) throws -> [UUID] {
        guard !ids.isEmpty else { return [] }
        guard Set(ids).count == ids.count else { throw SharedLibraryError.itemNotFound }

        lock.lock()
        defer { lock.unlock() }

        var items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
        let requestedIDs = Set(ids)
        let deletedItems = items.filter { requestedIDs.contains($0.id) }
        guard deletedItems.count == ids.count else { throw SharedLibraryError.itemNotFound }

        items.removeAll { requestedIDs.contains($0.id) }
        try writeUnlocked(items, to: itemsURL)

        let imagesDirectory = baseDirectory.appendingPathComponent("Images", isDirectory: true)
        let thumbnailsDirectory = baseDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        for item in deletedItems where item.kind == .image {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(item.value))
        }
        for item in deletedItems {
            if let thumbnailFilename = item.thumbnailFilename {
                try? FileManager.default.removeItem(at: thumbnailsDirectory.appendingPathComponent(thumbnailFilename))
            }
        }
        return ids
    }

    public func deleteItem(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        let thumbnailsDirectory = baseDirectory.appendingPathComponent("Thumbnails", isDirectory: true)

        var items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw SharedLibraryError.itemNotFound
        }

        let item = items.remove(at: index)
        try writeUnlocked(items, to: itemsURL)

        if item.kind == .image {
            let imageURL = baseDirectory.appendingPathComponent("Images", isDirectory: true)
                .appendingPathComponent(item.value)
            try? FileManager.default.removeItem(at: imageURL)
        }
        if let thumbnailFilename = item.thumbnailFilename {
            try? FileManager.default.removeItem(at: thumbnailsDirectory.appendingPathComponent(thumbnailFilename))
        }
    }

    @discardableResult
    public func deleteCategory(
        id: UUID,
        itemDisposition: CategoryDeletionItemDisposition
    ) throws -> CategoryDeletionResult {
        lock.lock()
        defer { lock.unlock() }

        var categories = try readUnlocked([SharedCategory].self, from: categoriesURL, missingValue: [])
        guard categories.contains(where: { $0.id == id }) else {
            throw SharedLibraryError.categoryNotFound
        }

        var items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
        let matchingItems = items.filter { $0.categoryID == id }
        let deletedItemIDs: [UUID]
        let reassignedItemIDs: [UUID]

        switch itemDisposition {
        case .deleteItems:
            deletedItemIDs = matchingItems.map(\.id)
            reassignedItemIDs = []
            items.removeAll { $0.categoryID == id }
        case .moveItemsToUncategorized:
            deletedItemIDs = []
            reassignedItemIDs = matchingItems.map(\.id)
            items = items.map { item in
                guard item.categoryID == id else { return item }
                return SharedItem(
                    id: item.id,
                    kind: item.kind,
                    value: item.value,
                    title: item.title,
                    description: item.description,
                    thumbnailFilename: item.thumbnailFilename,
                    originalContent: item.originalContent,
                    createdAt: item.createdAt,
                    categoryID: nil,
                    isPinned: item.isPinned
                )
            }
        }

        if !matchingItems.isEmpty {
            try writeUnlocked(items, to: itemsURL)
        }

        categories.removeAll { $0.id == id }
        try writeUnlocked(categories, to: categoriesURL)

        if case .deleteItems = itemDisposition {
            let imagesDirectory = baseDirectory.appendingPathComponent("Images", isDirectory: true)
            let thumbnailsDirectory = baseDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
            for item in matchingItems where item.kind == .image {
                let imageURL = imagesDirectory.appendingPathComponent(item.value)
                try? FileManager.default.removeItem(at: imageURL)
            }
            for item in matchingItems {
                if let thumbnailFilename = item.thumbnailFilename {
                    try? FileManager.default.removeItem(at: thumbnailsDirectory.appendingPathComponent(thumbnailFilename))
                }
            }
        }

        return CategoryDeletionResult(
            deletedCategoryID: id,
            deletedItemIDs: deletedItemIDs,
            reassignedItemIDs: reassignedItemIDs
        )
    }

    public func imageData(for item: SharedItem) -> Data? {
        guard item.kind == .image else { return nil }
        let url = baseDirectory.appendingPathComponent("Images", isDirectory: true)
            .appendingPathComponent(item.value)
        return try? Data(contentsOf: url)
    }

    public func thumbnailData(for item: SharedItem) -> Data? {
        guard let thumbnailFilename = item.thumbnailFilename else { return nil }
        let url = baseDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
            .appendingPathComponent(thumbnailFilename)
        return try? Data(contentsOf: url)
    }

    private var categoriesURL: URL {
        baseDirectory.appendingPathComponent("categories.json")
    }

    private var itemsURL: URL {
        baseDirectory.appendingPathComponent("saved-items.json")
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL, missingValue: T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try readUnlocked(type, from: url, missingValue: missingValue)
    }

    private func readUnlocked<T: Decodable>(_ type: T.Type, from url: URL, missingValue: T) throws -> T {
        guard FileManager.default.fileExists(atPath: url.path) else { return missingValue }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private func writeUnlocked<T: Encodable>(_ value: T, to url: URL) throws {
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}

public enum SharedLibraryError: LocalizedError {
    case invalidCategoryName
    case categoryNotFound
    case itemNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidCategoryName:
            return "Category names must contain 1 to 50 characters."
        case .categoryNotFound:
            return "The selected category does not exist."
        case .itemNotFound:
            return "The saved item does not exist."
        }
    }
}
