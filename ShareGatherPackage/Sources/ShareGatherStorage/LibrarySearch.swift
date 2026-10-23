import Foundation

/// Local, whole-library text matching for saved items.
///
/// Matching is case-insensitive substring matching over the text a person can
/// actually read on an item: the saved title, the description, the URL or text
/// value, the original shared value and its source text, and the category name.
/// An image item's stored value is an internal asset filename rather than
/// user-visible content, so it is not searched; an image still matches through its
/// title, description, original content, and category name.
///
/// This type never touches the network or the file system; it only inspects
/// already-loaded items.
public enum LibrarySearch {
    /// Trims whitespace and newlines from a search query.
    /// - Parameter rawQuery: The query entered by the person.
    /// - Returns: The query without surrounding whitespace; an empty result means the normal library should remain visible.
    public static func normalizedQuery(_ rawQuery: String) -> String {
        rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns whether a saved item contains the non-empty query in a readable field.
    /// - Parameters:
    ///   - item: The saved item to inspect.
    ///   - rawQuery: The case-insensitive query to match.
    ///   - categoryName: The item's category name, if its category is available.
    /// - Returns: `true` for an empty query or when any searchable field contains it.
    public static func matches(
        _ item: SharedItem,
        query rawQuery: String,
        categoryName: String? = nil
    ) -> Bool {
        let query = normalizedQuery(rawQuery)
        guard !query.isEmpty else { return true }
        return matches(item, normalizedQuery: query, categoryName: categoryName)
    }

    /// Filters items without changing their input order.
    /// - Parameters:
    ///   - items: The already-loaded saved items to inspect.
    ///   - rawQuery: The query to match.
    ///   - categoryNames: Category names keyed by category ID; missing entries are ignored.
    /// - Returns: Matching items in input order, or the original items for an empty query.
    public static func items(
        in items: [SharedItem],
        matching rawQuery: String,
        categoryNames: [UUID: String] = [:]
    ) -> [SharedItem] {
        let query = normalizedQuery(rawQuery)
        guard !query.isEmpty else { return items }
        return items.filter {
            matches(
                $0,
                normalizedQuery: query,
                categoryName: $0.categoryID.flatMap { categoryNames[$0] }
            )
        }
    }

    /// Matches user-visible item fields without allocating an intermediate text array.
    private static func matches(
        _ item: SharedItem,
        normalizedQuery query: String,
        categoryName: String?
    ) -> Bool {
        contains(query, in: item.title)
            || contains(query, in: item.description)
            || (item.kind != .image && contains(query, in: item.value))
            || contains(query, in: item.originalContent?.value)
            || contains(query, in: item.originalContent?.sourceText)
            || contains(query, in: categoryName)
    }

    /// Checks one optional field without creating a copy of the query or field.
    private static func contains(_ query: String, in text: String?) -> Bool {
        guard let text else { return false }
        return text.range(of: query, options: .caseInsensitive) != nil
    }
}