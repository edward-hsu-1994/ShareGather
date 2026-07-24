import Foundation
import ZIPFoundation

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

public enum BackupImportMode: Sendable {
    case merge
    case replace
}

public struct BackupSummary: Sendable {
    public let categoryCount: Int
    public let itemCount: Int
    public let imageCount: Int
    public let thumbnailCount: Int

    public init(categoryCount: Int, itemCount: Int, imageCount: Int, thumbnailCount: Int) {
        self.categoryCount = categoryCount
        self.itemCount = itemCount
        self.imageCount = imageCount
        self.thumbnailCount = thumbnailCount
    }
}

public enum SharedLibraryBackupError: LocalizedError {
    case invalidBackup
    case unsupportedVersion
    case missingMedia
    case resourceLimitExceeded
    case unsafeContents
    case restoreFailed

    public var errorDescription: String? {
        switch self {
        case .invalidBackup: return "The backup file is invalid."
        case .unsupportedVersion: return "This backup version is not supported."
        case .missingMedia: return "The backup is missing saved media."
        case .resourceLimitExceeded: return "The backup exceeds the supported import limits."
        case .unsafeContents: return "The backup contains unsupported or unsafe files."
        case .restoreFailed: return "The backup could not be restored safely."
        }
    }
}

private struct ShareGatherBackupManifest: Codable {
    let identifier: String
    let version: Int
    let createdAt: Date
    let categoryCount: Int
    let itemCount: Int
    let imageCount: Int
    let thumbnailCount: Int
}

private enum BackupImportLimits {
    static let maximumArchiveSize: UInt64 = 256 * 1_024 * 1_024
    static let maximumEntryCount = 10_000
    static let maximumTotalUncompressedSize: UInt64 = 512 * 1_024 * 1_024
    static let maximumIndividualEntrySize: UInt64 = 128 * 1_024 * 1_024
    static let maximumMetadataSize: UInt64 = 8 * 1_024 * 1_024
    static let maximumPathLength = 240
}

private struct BackupImportTransactionJournal: Codable {
    let transactionDirectoryName: String
}

private struct PreparedBackupImport {
    let transactionDirectory: URL
    let candidateDirectory: URL
    let summary: BackupSummary
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
    private let transactionDirectoryPrefix = ".ShareGatherBackupImport-"
    private let transactionJournalFilename = ".ShareGatherBackupImport.json"
    private let libraryComponentNames = ["saved-items.json", "categories.json", "Images", "Thumbnails"]

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
        try recoverPendingBackupImport()
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

    @discardableResult
    public func exportBackup(to destinationURL: URL) throws -> BackupSummary {
        lock.lock()
        defer { lock.unlock() }

        let fileManager = FileManager.default
        let stagingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("ShareGatherBackup-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: stagingDirectory) }

        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let categories = try readUnlocked([SharedCategory].self, from: categoriesURL, missingValue: [])
        let items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
        let imagesDirectory = stagingDirectory.appendingPathComponent("Images", isDirectory: true)
        let thumbnailsDirectory = stagingDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

        var imageCount = 0
        var thumbnailCount = 0
        for item in items {
            if item.kind == .image {
                let source = baseDirectory.appendingPathComponent("Images", isDirectory: true).appendingPathComponent(item.value)
                guard fileManager.fileExists(atPath: source.path) else { throw SharedLibraryBackupError.missingMedia }
                try fileManager.copyItem(at: source, to: imagesDirectory.appendingPathComponent(item.value))
                imageCount += 1
            }
            if let thumbnailFilename = item.thumbnailFilename {
                let source = baseDirectory.appendingPathComponent("Thumbnails", isDirectory: true).appendingPathComponent(thumbnailFilename)
                guard fileManager.fileExists(atPath: source.path) else { throw SharedLibraryBackupError.missingMedia }
                try fileManager.copyItem(at: source, to: thumbnailsDirectory.appendingPathComponent(thumbnailFilename))
                thumbnailCount += 1
            }
        }

        try JSONEncoder().encode(categories).write(to: stagingDirectory.appendingPathComponent("categories.json"), options: .atomic)
        try JSONEncoder().encode(items).write(to: stagingDirectory.appendingPathComponent("items.json"), options: .atomic)
        let manifest = ShareGatherBackupManifest(
            identifier: "com.sharegather.backup", version: 1, createdAt: Date(),
            categoryCount: categories.count, itemCount: items.count,
            imageCount: imageCount, thumbnailCount: thumbnailCount
        )
        try JSONEncoder().encode(manifest).write(to: stagingDirectory.appendingPathComponent("manifest.json"), options: .atomic)
        try? fileManager.removeItem(at: destinationURL)
        try fileManager.zipItem(at: stagingDirectory, to: destinationURL, shouldKeepParent: false)
        return BackupSummary(categoryCount: categories.count, itemCount: items.count, imageCount: imageCount, thumbnailCount: thumbnailCount)
    }

    public func validateBackup(at backupURL: URL) throws -> BackupSummary {
        let extractionDirectory = try extractBackup(at: backupURL)
        defer { try? FileManager.default.removeItem(at: extractionDirectory) }
        let payload = try readBackupPayload(from: extractionDirectory)
        return payload.summary
    }

    @discardableResult
    public func importBackup(at backupURL: URL, mode: BackupImportMode) throws -> BackupSummary {
        let extractionDirectory = try extractBackup(at: backupURL)
        defer { try? FileManager.default.removeItem(at: extractionDirectory) }
        let payload = try readBackupPayload(from: extractionDirectory)

        lock.lock()
        defer { lock.unlock() }

        let prepared = try prepareBackupImport(payload: payload, extractedAt: extractionDirectory, mode: mode)
        do {
            try commitPreparedBackupImport(prepared)
            return prepared.summary
        } catch {
            try? FileManager.default.removeItem(at: prepared.transactionDirectory)
            throw error
        }
    }

    private func extractBackup(at backupURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let values = try backupURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              let fileSize = values.fileSize,
              UInt64(fileSize) <= BackupImportLimits.maximumArchiveSize else {
            throw SharedLibraryBackupError.resourceLimitExceeded
        }
        let archive: Archive
        do {
            archive = try Archive(url: backupURL, accessMode: .read)
        } catch {
            throw SharedLibraryBackupError.invalidBackup
        }

        var entryCount = 0
        var totalUncompressedSize: UInt64 = 0
        var paths = Set<String>()
        for entry in archive {
            entryCount += 1
            guard entryCount <= BackupImportLimits.maximumEntryCount else {
                throw SharedLibraryBackupError.resourceLimitExceeded
            }
            try validateArchiveEntry(entry, paths: &paths)
            guard entry.uncompressedSize <= BackupImportLimits.maximumIndividualEntrySize,
                  totalUncompressedSize <= BackupImportLimits.maximumTotalUncompressedSize - entry.uncompressedSize else {
                throw SharedLibraryBackupError.resourceLimitExceeded
            }
            totalUncompressedSize += entry.uncompressedSize
        }

        let extractionDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareGatherRestore-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)
        do {
            for entry in archive {
                let destination = extractionDirectory.appendingPathComponent(
                    entry.path,
                    isDirectory: entry.type == .directory
                )
                if entry.type == .directory {
                    try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                } else {
                    try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    _ = try archive.extract(entry, to: destination)
                }
            }
            return extractionDirectory
        } catch {
            try? fileManager.removeItem(at: extractionDirectory)
            throw SharedLibraryBackupError.invalidBackup
        }
    }

    private func readBackupPayload(from directory: URL) throws -> (categories: [SharedCategory], items: [SharedItem], summary: BackupSummary) {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        guard let manifest = try? JSONDecoder().decode(ShareGatherBackupManifest.self, from: limitedData(at: manifestURL)),
              manifest.identifier == "com.sharegather.backup" else {
            throw SharedLibraryBackupError.invalidBackup
        }
        guard manifest.version == 1 else { throw SharedLibraryBackupError.unsupportedVersion }
        guard let categories = try? JSONDecoder().decode([SharedCategory].self, from: limitedData(at: directory.appendingPathComponent("categories.json"))),
              let items = try? JSONDecoder().decode([SharedItem].self, from: limitedData(at: directory.appendingPathComponent("items.json"))),
              manifest.categoryCount == categories.count,
              manifest.itemCount == items.count,
              Set(categories.map(\.id)).count == categories.count,
              Set(items.map(\.id)).count == items.count,
              items.allSatisfy({ item in
                  item.categoryID == nil || categories.contains(where: { $0.id == item.categoryID })
              }) else {
            throw SharedLibraryBackupError.invalidBackup
        }

        let imageFilenames = Set(items.compactMap { $0.kind == .image ? $0.value : nil })
        let thumbnailFilenames = Set(items.compactMap(\.thumbnailFilename))
        guard imageFilenames.count == items.filter({ $0.kind == .image }).count,
              thumbnailFilenames.count == items.compactMap(\.thumbnailFilename).count,
              imageFilenames.allSatisfy(isSafeMediaFilename),
              thumbnailFilenames.allSatisfy(isSafeMediaFilename),
              items.allSatisfy({ item in
                  item.originalContent?.assetFilename.map(isSafeMediaFilename) ?? true
              }),
              manifest.imageCount == imageFilenames.count,
              manifest.thumbnailCount == thumbnailFilenames.count else {
            throw SharedLibraryBackupError.unsafeContents
        }
        for item in items {
            if item.kind == .image, !isRegularFile(directory.appendingPathComponent("Images").appendingPathComponent(item.value)) { throw SharedLibraryBackupError.missingMedia }
            if let thumbnail = item.thumbnailFilename, !isRegularFile(directory.appendingPathComponent("Thumbnails").appendingPathComponent(thumbnail)) { throw SharedLibraryBackupError.missingMedia }
        }
        guard try mediaFilenames(in: directory.appendingPathComponent("Images")) == imageFilenames,
              try mediaFilenames(in: directory.appendingPathComponent("Thumbnails")) == thumbnailFilenames else {
            throw SharedLibraryBackupError.unsafeContents
        }
        return (categories, items, BackupSummary(categoryCount: categories.count, itemCount: items.count, imageCount: manifest.imageCount, thumbnailCount: manifest.thumbnailCount))
    }

    private func validateArchiveEntry(_ entry: Entry, paths: inout Set<String>) throws {
        guard paths.insert(entry.path).inserted,
              entry.path.count <= BackupImportLimits.maximumPathLength,
              !entry.path.contains("\\"),
              !entry.path.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              entry.type == .file || entry.type == .directory else {
            throw SharedLibraryBackupError.unsafeContents
        }

        let isDirectory = entry.type == .directory
        guard entry.path.hasSuffix("/") == isDirectory else {
            throw SharedLibraryBackupError.unsafeContents
        }
        let normalizedPath = isDirectory ? String(entry.path.dropLast()) : entry.path
        let components = normalizedPath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.isEmpty,
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw SharedLibraryBackupError.unsafeContents
        }

        switch components {
        case ["manifest.json"], ["categories.json"], ["items.json"]:
            guard !isDirectory, entry.uncompressedSize <= BackupImportLimits.maximumMetadataSize else {
                throw SharedLibraryBackupError.unsafeContents
            }
        case ["Images"], ["Thumbnails"]:
            guard isDirectory else { throw SharedLibraryBackupError.unsafeContents }
        case let components where components.count == 2 && (components[0] == "Images" || components[0] == "Thumbnails"):
            guard !isDirectory, isSafeMediaFilename(components[1]) else {
                throw SharedLibraryBackupError.unsafeContents
            }
        default:
            throw SharedLibraryBackupError.unsafeContents
        }
    }

    private func limitedData(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              let fileSize = values.fileSize,
              UInt64(fileSize) <= BackupImportLimits.maximumMetadataSize else {
            throw SharedLibraryBackupError.resourceLimitExceeded
        }
        return try Data(contentsOf: url)
    }

    private func isSafeMediaFilename(_ filename: String) -> Bool {
        !filename.isEmpty &&
            filename.count <= BackupImportLimits.maximumPathLength &&
            !filename.hasPrefix(".") &&
            !filename.contains("/") &&
            !filename.contains("\\") &&
            !filename.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }

    private func isRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private func mediaFilenames(in directory: URL) throws -> Set<String> {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: []
        )
        guard urls.allSatisfy({ isSafeMediaFilename($0.lastPathComponent) && isRegularFile($0) }) else {
            throw SharedLibraryBackupError.unsafeContents
        }
        return Set(urls.map(\.lastPathComponent))
    }

    private func prepareBackupImport(
        payload: (categories: [SharedCategory], items: [SharedItem], summary: BackupSummary),
        extractedAt extractionDirectory: URL,
        mode: BackupImportMode
    ) throws -> PreparedBackupImport {
        let fileManager = FileManager.default
        let transactionDirectory = baseDirectory
            .appendingPathComponent("\(transactionDirectoryPrefix)\(UUID().uuidString)", isDirectory: true)
        let candidateDirectory = transactionDirectory.appendingPathComponent("candidate", isDirectory: true)
        let candidateImagesDirectory = candidateDirectory.appendingPathComponent("Images", isDirectory: true)
        let candidateThumbnailsDirectory = candidateDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        do {
            try fileManager.createDirectory(at: candidateImagesDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: candidateThumbnailsDirectory, withIntermediateDirectories: true)

            var categories: [SharedCategory]
            var items: [SharedItem]
            switch mode {
            case .merge:
                categories = try readUnlocked([SharedCategory].self, from: categoriesURL, missingValue: [])
                items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
                try copyExistingMediaDirectory(named: "Images", to: candidateImagesDirectory)
                try copyExistingMediaDirectory(named: "Thumbnails", to: candidateThumbnailsDirectory)
            case .replace:
                categories = []
                items = []
            }

            let existingCategoryIDs = Set(categories.map(\.id))
            categories.append(contentsOf: payload.categories.filter { !existingCategoryIDs.contains($0.id) })
            let existingItemIDs = Set(items.map(\.id))

            for original in payload.items where !existingItemIDs.contains(original.id) {
                var value = original.value
                var thumbnailFilename = original.thumbnailFilename
                var originalContent = original.originalContent
                if original.kind == .image {
                    let newFilename = "\(UUID().uuidString).image"
                    try fileManager.copyItem(
                        at: extractionDirectory.appendingPathComponent("Images").appendingPathComponent(original.value),
                        to: candidateImagesDirectory.appendingPathComponent(newFilename)
                    )
                    value = newFilename
                    originalContent = originalContent.map {
                        SharedOriginalContent(
                            kind: $0.kind,
                            value: $0.value,
                            sourceText: $0.sourceText,
                            assetFilename: newFilename
                        )
                    }
                }
                if let originalThumbnailFilename = thumbnailFilename {
                    let newFilename = "\(UUID().uuidString).thumbnail"
                    try fileManager.copyItem(
                        at: extractionDirectory.appendingPathComponent("Thumbnails").appendingPathComponent(originalThumbnailFilename),
                        to: candidateThumbnailsDirectory.appendingPathComponent(newFilename)
                    )
                    thumbnailFilename = newFilename
                }
                items.append(
                    SharedItem(
                        id: original.id,
                        kind: original.kind,
                        value: value,
                        title: original.title,
                        description: original.description,
                        thumbnailFilename: thumbnailFilename,
                        originalContent: originalContent,
                        createdAt: original.createdAt,
                        categoryID: original.categoryID,
                        isPinned: original.isPinned
                    )
                )
            }

            try write(categories, to: candidateDirectory.appendingPathComponent("categories.json"))
            try write(items, to: candidateDirectory.appendingPathComponent("saved-items.json"))
            try validateLibrary(at: candidateDirectory, categories: categories, items: items)
            return PreparedBackupImport(
                transactionDirectory: transactionDirectory,
                candidateDirectory: candidateDirectory,
                summary: payload.summary
            )
        } catch {
            try? fileManager.removeItem(at: transactionDirectory)
            throw error
        }
    }

    private func commitPreparedBackupImport(_ prepared: PreparedBackupImport) throws {
        let fileManager = FileManager.default
        let rollbackDirectory = prepared.transactionDirectory.appendingPathComponent("rollback", isDirectory: true)
        try fileManager.createDirectory(at: rollbackDirectory, withIntermediateDirectories: true)
        let journal = BackupImportTransactionJournal(
            transactionDirectoryName: prepared.transactionDirectory.lastPathComponent
        )
        try JSONEncoder().encode(journal).write(to: transactionJournalURL, options: .atomic)

        do {
            for component in libraryComponentNames {
                let liveURL = baseDirectory.appendingPathComponent(component)
                guard fileManager.fileExists(atPath: liveURL.path) else { continue }
                try fileManager.moveItem(at: liveURL, to: rollbackDirectory.appendingPathComponent(component))
            }
            for component in libraryComponentNames {
                try fileManager.moveItem(
                    at: prepared.candidateDirectory.appendingPathComponent(component),
                    to: baseDirectory.appendingPathComponent(component)
                )
            }
            let categories = try readUnlocked([SharedCategory].self, from: categoriesURL, missingValue: [])
            let items = try readUnlocked([SharedItem].self, from: itemsURL, missingValue: [])
            try validateLibrary(at: baseDirectory, categories: categories, items: items)
            try fileManager.removeItem(at: transactionJournalURL)
            try? fileManager.removeItem(at: prepared.transactionDirectory)
        } catch {
            do {
                try restoreLibrary(from: rollbackDirectory)
                try? fileManager.removeItem(at: transactionJournalURL)
            } catch {
                throw SharedLibraryBackupError.restoreFailed
            }
            throw error
        }
    }

    private func recoverPendingBackupImport() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: transactionJournalURL.path) else { return }
        guard let journal = try? JSONDecoder().decode(
            BackupImportTransactionJournal.self,
            from: Data(contentsOf: transactionJournalURL)
        ), journal.transactionDirectoryName.hasPrefix(transactionDirectoryPrefix),
              !journal.transactionDirectoryName.contains("/") else {
            throw SharedLibraryBackupError.restoreFailed
        }
        let transactionDirectory = baseDirectory.appendingPathComponent(journal.transactionDirectoryName, isDirectory: true)
        let rollbackDirectory = transactionDirectory.appendingPathComponent("rollback", isDirectory: true)
        do {
            try restoreLibrary(from: rollbackDirectory)
            try fileManager.removeItem(at: transactionJournalURL)
            try? fileManager.removeItem(at: transactionDirectory)
        } catch {
            throw SharedLibraryBackupError.restoreFailed
        }
    }

    private func restoreLibrary(from rollbackDirectory: URL) throws {
        let fileManager = FileManager.default
        for component in libraryComponentNames {
            let liveURL = baseDirectory.appendingPathComponent(component)
            if fileManager.fileExists(atPath: liveURL.path) {
                try fileManager.removeItem(at: liveURL)
            }
        }
        for component in libraryComponentNames {
            let rollbackURL = rollbackDirectory.appendingPathComponent(component)
            if fileManager.fileExists(atPath: rollbackURL.path) {
                try fileManager.moveItem(at: rollbackURL, to: baseDirectory.appendingPathComponent(component))
            }
        }
    }

    private func copyExistingMediaDirectory(named name: String, to destination: URL) throws {
        let source = baseDirectory.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        try FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private func validateLibrary(at directory: URL, categories: [SharedCategory], items: [SharedItem]) throws {
        guard Set(categories.map(\.id)).count == categories.count,
              Set(items.map(\.id)).count == items.count,
              items.allSatisfy({ item in
                  item.categoryID == nil || categories.contains(where: { $0.id == item.categoryID })
              }) else {
            throw SharedLibraryBackupError.restoreFailed
        }
        let imageFilenames = Set(items.compactMap { $0.kind == .image ? $0.value : nil })
        let thumbnailFilenames = Set(items.compactMap(\.thumbnailFilename))
        guard imageFilenames.allSatisfy(isSafeMediaFilename),
              thumbnailFilenames.allSatisfy(isSafeMediaFilename),
              try mediaFilenames(in: directory.appendingPathComponent("Images")) == imageFilenames,
              try mediaFilenames(in: directory.appendingPathComponent("Thumbnails")) == thumbnailFilenames else {
            throw SharedLibraryBackupError.restoreFailed
        }
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

    private var transactionJournalURL: URL {
        baseDirectory.appendingPathComponent(transactionJournalFilename)
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

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }

    private func writeUnlocked<T: Encodable>(_ value: T, to url: URL) throws {
        try write(value, to: url)
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
