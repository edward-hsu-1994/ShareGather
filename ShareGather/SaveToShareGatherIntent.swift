import AppIntents
import ShareGatherStorage

struct SaveToShareGatherIntent: AppIntent {
    static let title: LocalizedStringResource = "save.to.sharegather"
    static let description = IntentDescription("Save a URL or text to ShareGather.")
    static var openAppWhenRun = false

    @Parameter(title: "Content")
    var content: String

    init() {}

    init(content: String) {
        self.content = content
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let kind: SharedItemKind = URL(string: content) != nil ? .url : .text
        let store = try SharedLibraryStore()
        _ = try store.saveItem(
            kind: kind,
            value: content,
            categoryID: nil,
            title: nil,
            description: nil,
            thumbnailData: nil,
            originalContent: SharedOriginalContent(
                kind: kind,
                value: content
            )
        )

        return .result(dialog: "Saved to ShareGather.")
    }
}

struct ShareGatherShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveToShareGatherIntent(),
            phrases: [
                "Save content to \(.applicationName)",
                "儲存內容到 \(.applicationName)",
                "保存内容到 \(.applicationName)"
            ],
            shortTitle: "儲存到ShareGather",
            systemImageName: "tray.and.arrow.down"
        )
    }
}
