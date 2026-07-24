import SwiftUI
import UIKit
import ShareGatherStorage

private extension Notification.Name {
    static let sharedItemCategoryDidChange = Notification.Name("ShareGather.sharedItemCategoryDidChange")
    static let sharedItemDidDelete = Notification.Name("ShareGather.sharedItemDidDelete")
}

public struct ContentView: View {
    @AppStorage("appLanguage") private var selectedLanguage = AppLanguage.system.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingInstructions = false
    @State private var isShowingCreateCategory = false
    @State private var newCategoryName = ""
    @State private var categoryPendingRename: SharedCategory?
    @State private var renamedCategoryName = ""
    @State private var isShowingRenameCategory = false
    @State private var itemPendingDeletion: SharedItem?
    @State private var itemPendingRecategorization: SharedItem?
    @State private var categoryPendingDeletion: SharedCategory?
    @State private var categoryDeletionDisposition: CategoryDeletionItemDisposition?
    @State private var isShowingCategoryItemChoice = false
    @State private var isShowingCategoryDeleteConfirmation = false
    @State private var isShowingRecategorization = false
    @State private var isShowingCategoryReordering = false
    @State private var savedItems: [SharedItem] = []
    @State private var categories: [SharedCategory] = []

    private var language: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .english
    }

    private var copy: Copy {
        Copy(language: language)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OfflinePrivacyBanner(copy: copy)

                    CategoryOverview(
                        copy: copy,
                        categories: categories,
                        items: savedItems,
                        onDelete: requestDelete,
                        onDeleteItem: deleteItem,
                        onRecategorize: requestRecategorization,
                        onRecategorizeToCategory: recategorizeItem,
                        onRenameCategory: requestRenameCategory,
                        onDeleteCategory: requestDeleteCategory,
                        onReorderCategories: {
                            isShowingCategoryReordering = true
                        }
                    ) {
                        newCategoryName = ""
                        isShowingCreateCategory = true
                    }

                    if savedItems.isEmpty {
                        EmptyInboxView(copy: copy)
                    } else {
                        UncategorizedItemsSection(
                            copy: copy,
                            items: savedItems,
                            onDelete: deleteItem,
                            onRecategorize: requestRecategorization
                        )
                    }

                    RecentSavedItemsSection(
                        copy: copy,
                        items: savedItems,
                        onDelete: requestDelete,
                        onDeleteItem: deleteItem,
                        onRecategorize: requestRecategorization
                    )

                    if savedItems.isEmpty {
                        ShareInstructionsCard(copy: copy) {
                            isShowingInstructions = true
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.appName)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $isShowingInstructions) {
                ShareInstructionsSheet(copy: copy)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isShowingCategoryReordering) {
                CategoryReorderingSheet(copy: copy, categories: categories) { reorderedCategories in
                    reorderCategories(reorderedCategories)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            isShowingInstructions = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .accessibilityLabel(copy.viewInstructions)

                        NavigationLink {
                            SettingsView(selectedLanguage: $selectedLanguage)
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(copy.settingsTitle)
                    }
                }
            }
            .onAppear {
                syncLanguagePreference()
                reloadLibrary()
            }
            .onChange(of: selectedLanguage) { _, _ in
                syncLanguagePreference()
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .alert(copy.createCategoryTitle, isPresented: $isShowingCreateCategory) {
                TextField(copy.categoryNamePlaceholder, text: $newCategoryName)
                Button(copy.cancelTitle, role: .cancel) {}
                Button(copy.createTitle) {
                    createCategory()
                }
            } message: {
                Text(copy.categoryNameHint)
            }
            .alert(copy.renameCategoryTitle, isPresented: $isShowingRenameCategory) {
                TextField(copy.categoryNamePlaceholder, text: $renamedCategoryName)
                Button(copy.cancelTitle, role: .cancel) {
                    categoryPendingRename = nil
                }
                Button(copy.saveTitle) {
                    renamePendingCategory()
                }
            } message: {
                Text(copy.categoryNameHint)
            }
            .alert(copy.deleteConfirmationTitle, isPresented: deleteAlertBinding) {
                Button(copy.cancelTitle, role: .cancel) {
                    itemPendingDeletion = nil
                }
                Button(copy.deleteTitle, role: .destructive) {
                    deletePendingItem()
                }
            } message: {
                Text(copy.deleteConfirmationMessage)
            }
            .sheet(isPresented: $isShowingRecategorization) {
                CategorySelectionSheet(copy: copy, categories: categories) { categoryID in
                    recategorizePendingItem(to: categoryID)
                }
            }
            .confirmationDialog(
                copy.categoryContainsItemsTitle,
                isPresented: $isShowingCategoryItemChoice,
                titleVisibility: .visible
            ) {
                Button(copy.deleteItemsAndCategoryTitle, role: .destructive) {
                    categoryDeletionDisposition = .deleteItems
                    isShowingCategoryItemChoice = false
                    isShowingCategoryDeleteConfirmation = true
                }

                Button(copy.keepItemsDeleteCategoryTitle) {
                    categoryDeletionDisposition = .moveItemsToUncategorized
                    isShowingCategoryItemChoice = false
                    isShowingCategoryDeleteConfirmation = true
                }

                Button(copy.cancelTitle, role: .cancel) {
                    clearPendingCategoryDeletion()
                }
            } message: {
                Text(copy.categoryContainsItemsMessage(categoryPendingDeletionItemCount))
            }
            .alert(
                copy.deleteCategoryConfirmationTitle,
                isPresented: $isShowingCategoryDeleteConfirmation
            ) {
                Button(copy.cancelTitle, role: .cancel) {
                    clearPendingCategoryDeletion()
                }
                Button(copy.deleteTitle, role: .destructive) {
                    deletePendingCategory()
                }
            } message: {
                Text(copy.deleteCategoryConfirmationMessage(
                    categoryName: categoryPendingDeletion?.name ?? "",
                    deletesItems: categoryDeletionDisposition == .deleteItems
                ))
            }
        }
    }

    public init() {}

    private func syncLanguagePreference() {
        UserDefaults(suiteName: SharedLibraryStore.appGroupIdentifier)?.set(
            selectedLanguage,
            forKey: SharedGatherLocalization.languagePreferenceKey
        )
    }

    private func reloadLibrary() {
        guard let store = try? SharedLibraryStore() else { return }
        savedItems = (try? store.loadItems()) ?? []
        categories = (try? store.loadCategories()) ?? []
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .active {
            reloadLibrary()
        }
    }

    private func createCategory() {
        guard let store = try? SharedLibraryStore() else { return }
        _ = try? store.createCategory(named: newCategoryName)
        reloadLibrary()
        newCategoryName = ""
    }

    private func requestRenameCategory(_ category: SharedCategory) {
        categoryPendingRename = category
        renamedCategoryName = category.name
        isShowingRenameCategory = true
    }

    private func renamePendingCategory() {
        guard let category = categoryPendingRename,
              let store = try? SharedLibraryStore() else { return }
        _ = try? store.renameCategory(id: category.id, named: renamedCategoryName)
        categoryPendingRename = nil
        renamedCategoryName = ""
        reloadLibrary()
    }

    private func reorderCategories(_ reorderedCategories: [SharedCategory]) {
        guard let store = try? SharedLibraryStore() else { return }
        guard (try? store.reorderCategories(ids: reorderedCategories.map(\.id))) != nil else { return }
        reloadLibrary()
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { itemPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    itemPendingDeletion = nil
                }
            }
        )
    }

    private func requestDelete(_ item: SharedItem) {
        itemPendingDeletion = item
    }

    private func deletePendingItem() {
        guard let item = itemPendingDeletion,
              let store = try? SharedLibraryStore() else { return }
        _ = try? store.deleteItem(id: item.id)
        itemPendingDeletion = nil
        reloadLibrary()
    }

    private func deleteItem(_ item: SharedItem) {
        guard let store = try? SharedLibraryStore() else { return }
        do {
            try store.deleteItem(id: item.id)
            NotificationCenter.default.post(name: .sharedItemDidDelete, object: item.id)
            reloadLibrary()
        } catch {
            return
        }
    }

    private func requestRecategorization(_ item: SharedItem) {
        itemPendingRecategorization = item
        isShowingRecategorization = true
    }

    private func recategorizePendingItem(to categoryID: UUID?) {
        guard let item = itemPendingRecategorization,
              let store = try? SharedLibraryStore() else { return }
        do {
            let updatedItem = try store.updateItemCategory(id: item.id, categoryID: categoryID)
            NotificationCenter.default.post(
                name: .sharedItemCategoryDidChange,
                object: updatedItem
            )
        } catch {
            return
        }
        itemPendingRecategorization = nil
        isShowingRecategorization = false
        reloadLibrary()
    }

    private func recategorizeItem(_ item: SharedItem, to categoryID: UUID?) {
        guard let store = try? SharedLibraryStore() else { return }
        do {
            let updatedItem = try store.updateItemCategory(id: item.id, categoryID: categoryID)
            NotificationCenter.default.post(name: .sharedItemCategoryDidChange, object: updatedItem)
            reloadLibrary()
        } catch {
            return
        }
    }

    private var categoryPendingDeletionItemCount: Int {
        guard let categoryID = categoryPendingDeletion?.id else { return 0 }
        return savedItems.count { $0.categoryID == categoryID }
    }

    private func requestDeleteCategory(_ category: SharedCategory) {
        categoryPendingDeletion = category
        categoryDeletionDisposition = categoryPendingDeletionItemCount > 0
            ? nil
            : .moveItemsToUncategorized

        if categoryPendingDeletionItemCount > 0 {
            isShowingCategoryItemChoice = true
        } else {
            isShowingCategoryDeleteConfirmation = true
        }
    }

    private func deletePendingCategory() {
        guard let category = categoryPendingDeletion,
              let disposition = categoryDeletionDisposition,
              let store = try? SharedLibraryStore() else { return }

        _ = try? store.deleteCategory(id: category.id, itemDisposition: disposition)
        clearPendingCategoryDeletion()
        reloadLibrary()
    }

    private func clearPendingCategoryDeletion() {
        categoryPendingDeletion = nil
        categoryDeletionDisposition = nil
        isShowingCategoryItemChoice = false
        isShowingCategoryDeleteConfirmation = false
    }
}

private enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case traditionalChinese = "zh-Hant"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            switch SharedGatherLocalization.systemLocaleIdentifier() {
            case "zh-Hant":
                return "System Default (繁體中文)"
            case "zh-Hans":
                return "System Default (简体中文)"
            default:
                return "System Default (English)"
            }
        case .english:
            return "English"
        case .traditionalChinese:
            return "繁體中文"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    var resolvedLocaleIdentifier: String {
        switch self {
        case .system:
            return SharedGatherLocalization.systemLocaleIdentifier()
        case .english, .traditionalChinese, .simplifiedChinese:
            return rawValue
        }
    }
}

private struct SettingsView: View {
    @Binding var selectedLanguage: String

    private var language: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .english
    }

    private var copy: Copy {
        Copy(language: language)
    }

    var body: some View {
        Form {
            Section(copy.languageTitle) {
                Picker(copy.languageTitle, selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language.rawValue)
                    }
                }
            }
        }
        .navigationTitle(copy.settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Copy {
    let language: AppLanguage

    private func text(_ key: String) -> String {
        SharedGatherLocalization.string(key, localeIdentifier: language.resolvedLocaleIdentifier)
    }

    var appName: String { text("app.name") }
    var languageTitle: String { text("app.language.title") }
    var settingsTitle: String { text("settings.title") }
    var privacyTitle: String { text("privacy.title") }
    var privacySubtitle: String { text("privacy.subtitle") }
    var emptyTitle: String { text("empty.title") }
    var emptyDescription: String { text("empty.description") }
    var shareCardTitle: String { text("share.card.title") }
    var instructionOne: String { text("instructions.one") }
    var instructionTwo: String { text("instructions.two") }
    var instructionThree: String { text("instructions.three") }
    var viewInstructions: String { text("share.instructions.view") }
    var savedItemsTitle: String { text("library.saved.title") }
    var recentItemsTitle: String { text("library.recent.title") }
    var recentItemsEmpty: String { text("library.recent.empty") }
    var uncategorizedTitle: String { text("library.uncategorized") }
    var savedImageTitle: String { text("library.saved.image") }
    var itemDetailTitle: String { text("library.item.detail") }
    var linkTitle: String { text("library.link") }
    var openLinkTitle: String { text("library.open.link") }
    var shareTitle: String { text("library.share") }
    var textTitle: String { text("library.text") }
    var imageTitle: String { text("library.image") }
    var savedDateTitle: String { text("library.saved.date") }
    var imageUnavailableTitle: String { text("library.image.unavailable") }
    var categoriesTitle: String { text("category.title") }
    var createCategoryTitle: String { text("category.create") }
    var renameCategoryTitle: String { text("category.rename") }
    var reorderCategoriesTitle: String { text("category.reorder") }
    var createTitle: String { text("common.create") }
    var saveTitle: String { text("common.save") }
    var cancelTitle: String { text("common.cancel") }
    var categoryNamePlaceholder: String { text("category.name.placeholder") }
    var categoryNameHint: String { text("category.name.hint") }
    var noCategoriesTitle: String { text("category.empty") }
    var noItemsInCategoryTitle: String { text("category.items.empty") }
    var deleteTitle: String { text("common.delete") }
    var deleteConfirmationTitle: String { text("item.delete.title") }
    var deleteConfirmationMessage: String { text("common.irreversible") }
    var moveToCategoryTitle: String { text("category.move") }
    var recategorizeTitle: String { text("category.move.action") }
    var categoryContainsItemsTitle: String { text("category.contains.title") }
    var deleteItemsAndCategoryTitle: String { text("category.delete.items") }
    var keepItemsDeleteCategoryTitle: String { text("category.keep.items") }
    var deleteCategoryConfirmationTitle: String { text("category.delete.title") }
    var createFirstCategoryTitle: String { text("category.first") }
    var uncategorizedCollectionTitle: String { text("library.uncategorized.title") }
    var sheetTitle: String { text("instructions.title") }
    var sheetHeadline: String { text("instructions.headline") }
    var sheetDescription: String { text("instructions.description") }
    var sheetInstructionOne: String { text("instructions.one") }
    var sheetInstructionTwo: String { text("instructions.two") }
    var sheetInstructionThree: String { text("instructions.three") }
    var done: String { text("common.done") }

    func categoryContainsItemsMessage(_ count: Int) -> String {
        text("category.contains.message").replacingOccurrences(of: "%d", with: "\(count)")
    }

    func itemCount(_ count: Int) -> String {
        text("library.item.count").replacingOccurrences(of: "%d", with: "\(count)")
    }

    func deleteCategoryConfirmationMessage(categoryName: String, deletesItems: Bool) -> String {
        text(deletesItems ? "category.delete.with.items" : "category.delete.keep.items")
            .replacingOccurrences(of: "%@", with: categoryName)
    }
}

private struct OfflinePrivacyBanner: View {
    let copy: Copy

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(.green)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(copy.privacyTitle)
                    .font(.subheadline.weight(.semibold))
                Text(copy.privacySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyInboxView: View {
    let copy: Copy

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 88, height: 88)
                .background(.blue.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(copy.emptyTitle)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(copy.emptyDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

private struct ShareInstructionsCard: View {
    let copy: Copy
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(copy.shareCardTitle, systemImage: "square.and.arrow.up")
                    .font(.headline)

            }

            Button(copy.viewInstructions, action: action)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.blue)
                .frame(width: 24, height: 24)
                .background(.blue.opacity(0.12), in: Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

private struct RecentSavedItemsSection: View {
    let copy: Copy
    let items: [SharedItem]
    let onDelete: (SharedItem) -> Void
    let onDeleteItem: (SharedItem) -> Void
    let onRecategorize: (SharedItem) -> Void

    private var recentItems: [SharedItem] {
        Array(items.sorted { $0.createdAt > $1.createdAt }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.recentItemsTitle)
                .font(.headline)

            if recentItems.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text(copy.recentItemsEmpty)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(recentItems) { item in
                    SavedItemRow(
                        copy: copy,
                        item: item,
                        onDelete: onDelete,
                        onDetailDelete: onDeleteItem,
                        onRecategorize: onRecategorize
                    )
                }
            }
        }
    }
}

private struct CategoryOverview: View {
    let copy: Copy
    let categories: [SharedCategory]
    let items: [SharedItem]
    let onDelete: (SharedItem) -> Void
    let onDeleteItem: (SharedItem) -> Void
    let onRecategorize: (SharedItem) -> Void
    let onRecategorizeToCategory: (SharedItem, UUID?) -> Void
    let onRenameCategory: (SharedCategory) -> Void
    let onDeleteCategory: (SharedCategory) -> Void
    let onReorderCategories: () -> Void
    let onCreateCategory: () -> Void

    private var countsByCategory: [UUID: Int] {
        Dictionary(
            items.compactMap { item in
                guard let categoryID = item.categoryID else { return nil }
                return (categoryID, 1)
            },
            uniquingKeysWith: +
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(copy.categoriesTitle)
                    .font(.headline)

                Spacer(minLength: 8)

                if !categories.isEmpty {
                    Button(action: onReorderCategories) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.subheadline.weight(.bold))
                    }
                    .accessibilityLabel(copy.reorderCategoriesTitle)
                }

                Button(action: onCreateCategory) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                }
                .accessibilityLabel(copy.createCategoryTitle)
            }

            if categories.isEmpty {
                OverviewEmptyCard(
                    text: copy.noCategoriesTitle,
                    buttonTitle: copy.createFirstCategoryTitle,
                    iconName: "folder.badge.plus",
                    action: onCreateCategory
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(categories) { category in
                        NavigationLink {
                            CategoryItemsView(
                                copy: copy,
                                title: category.name,
                                items: items.filter { $0.categoryID == category.id },
                                categories: categories,
                                categoryID: category.id,
                                onDelete: onDelete,
                                onDeleteItem: onDeleteItem,
                                onRecategorizeToCategory: onRecategorizeToCategory
                            )
                        } label: {
                            CategoryCard(
                                title: category.name,
                                countText: copy.itemCount(countsByCategory[category.id, default: 0]),
                                iconName: "folder.fill"
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                onRenameCategory(category)
                            } label: {
                                Label(copy.renameCategoryTitle, systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                onDeleteCategory(category)
                            } label: {
                                Label(copy.deleteTitle, systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct CategoryReorderingSheet: View {
    let copy: Copy
    @State private var categories: [SharedCategory]
    @Environment(\.dismiss) private var dismiss
    let onReorder: ([SharedCategory]) -> Void

    init(copy: Copy, categories: [SharedCategory], onReorder: @escaping ([SharedCategory]) -> Void) {
        self.copy = copy
        _categories = State(initialValue: categories)
        self.onReorder = onReorder
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Label(category.name, systemImage: "folder")
                }
                .onMove { source, destination in
                    categories.move(fromOffsets: source, toOffset: destination)
                    onReorder(categories)
                }
            }
            .navigationTitle(copy.reorderCategoriesTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.done) {
                        dismiss()
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }
}

private struct CategoryCard: View {
    let title: String
    let countText: String
    let iconName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(countText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct OverviewEmptyCard: View {
    let text: String
    let buttonTitle: String
    let iconName: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button(buttonTitle, action: action)
                .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct CategoryItemsView: View {
    let copy: Copy
    let title: String
    let items: [SharedItem]
    let categories: [SharedCategory]
    let onDelete: (SharedItem) -> Void
    let onDeleteItem: (SharedItem) -> Void
    @State private var displayedItems: [SharedItem]
    let categoryID: UUID
    let onRecategorizeToCategory: (SharedItem, UUID?) -> Void

    init(
        copy: Copy,
        title: String,
        items: [SharedItem],
        categories: [SharedCategory],
        categoryID: UUID,
        onDelete: @escaping (SharedItem) -> Void,
        onDeleteItem: @escaping (SharedItem) -> Void,
        onRecategorizeToCategory: @escaping (SharedItem, UUID?) -> Void
    ) {
        self.copy = copy
        self.title = title
        self.items = items
        self.categories = categories
        self.categoryID = categoryID
        self.onDelete = onDelete
        self.onDeleteItem = onDeleteItem
        self.onRecategorizeToCategory = onRecategorizeToCategory
        _displayedItems = State(initialValue: items)
    }

    private var sortedItems: [SharedItem] {
        displayedItems.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if sortedItems.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text(copy.noItemsInCategoryTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                } else {
                    ForEach(sortedItems) { item in
                        CategorizedItemRow(
                            copy: copy,
                            item: item,
                            categories: categories,
                            onDelete: onDelete,
                            onDeleteItem: onDeleteItem,
                            onRecategorize: onRecategorizeToCategory
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .sharedItemCategoryDidChange)) { notification in
            guard let updatedItem = notification.object as? SharedItem,
                  updatedItem.categoryID != categoryID else { return }
            displayedItems.removeAll { $0.id == updatedItem.id }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sharedItemDidDelete)) { notification in
            guard let deletedItemID = notification.object as? UUID else { return }
            displayedItems.removeAll { $0.id == deletedItemID }
        }
    }
}

private struct CategorizedItemRow: View {
    let copy: Copy
    let item: SharedItem
    let categories: [SharedCategory]
    let onDelete: (SharedItem) -> Void
    let onDeleteItem: (SharedItem) -> Void
    let onRecategorize: (SharedItem, UUID?) -> Void
    @State private var isShowingRecategorization = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        SavedItemRow(
            copy: copy,
            item: item,
            onDelete: { _ in
                isShowingDeleteConfirmation = true
            },
            onDetailDelete: onDeleteItem,
            onRecategorize: { _ in
                isShowingRecategorization = true
            }
        )
        .alert(copy.deleteConfirmationTitle, isPresented: $isShowingDeleteConfirmation) {
            Button(copy.cancelTitle, role: .cancel) {}
            Button(copy.deleteTitle, role: .destructive) {
                onDeleteItem(item)
            }
        } message: {
            Text(copy.deleteConfirmationMessage)
        }
        .sheet(isPresented: $isShowingRecategorization) {
            CategorySelectionSheet(copy: copy, categories: categories) { categoryID in
                onRecategorize(item, categoryID)
                isShowingRecategorization = false
            }
        }
    }
}

private struct CategorySelectionSheet: View {
    let copy: Copy
    let categories: [SharedCategory]
    let onSelect: (UUID?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                } label: {
                    Label(copy.uncategorizedTitle, systemImage: "tray")
                }

                Section(copy.categoriesTitle) {
                    ForEach(categories) { category in
                        Button {
                            onSelect(category.id)
                        } label: {
                            Label(category.name, systemImage: "folder")
                        }
                    }
                }
            }
            .navigationTitle(copy.moveToCategoryTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SavedItemsList: View {
    let copy: Copy
    let items: [SharedItem]
    let categories: [SharedCategory]

    private var sections: [SavedSection] {
        let categorizedItems = items.filter { $0.categoryID != nil }
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let grouped = Dictionary(grouping: categorizedItems) { item in
            item.categoryID.flatMap { categoryMap[$0] } ?? copy.uncategorizedTitle
        }
        return grouped
            .map { SavedSection(title: $0.key, items: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy.savedItemsTitle)
                .font(.headline)

            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(section.items) { item in
                        SavedItemRow(
                            copy: copy,
                            item: item,
                            onDelete: { _ in },
                            onDetailDelete: { _ in },
                            onRecategorize: { _ in }
                        )
                    }
                }
            }
        }
    }
}

private struct UncategorizedItemsSection: View {
    let copy: Copy
    let items: [SharedItem]
    let onDelete: (SharedItem) -> Void
    let onRecategorize: (SharedItem) -> Void
    @State private var itemPendingDeletion: SharedItem?

    private var uncategorizedItems: [SharedItem] {
        items
            .filter { $0.categoryID == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if uncategorizedItems.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(copy.uncategorizedCollectionTitle)
                        .font(.headline)

                    ForEach(uncategorizedItems) { item in
                        SavedItemRow(
                            copy: copy,
                            item: item,
                            onDelete: { item in
                                itemPendingDeletion = item
                            },
                            onDetailDelete: onDelete,
                            onRecategorize: onRecategorize
                        )
                    }
                }
            }
        }
        .alert(copy.deleteConfirmationTitle, isPresented: Binding(
            get: { itemPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    itemPendingDeletion = nil
                }
            }
        )) {
            Button(copy.cancelTitle, role: .cancel) {
                itemPendingDeletion = nil
            }
            Button(copy.deleteTitle, role: .destructive) {
                if let item = itemPendingDeletion {
                    onDelete(item)
                }
                itemPendingDeletion = nil
            }
        } message: {
            Text(copy.deleteConfirmationMessage)
        }
    }
}

private struct SavedSection: Identifiable {
    let title: String
    let items: [SharedItem]

    var id: String { title }
}

private struct SavedItemRow: View {
    let copy: Copy
    let item: SharedItem
    let onDelete: (SharedItem) -> Void
    let onDetailDelete: (SharedItem) -> Void
    let onRecategorize: (SharedItem) -> Void

    private var iconName: String {
        switch item.kind {
        case .url: return "link"
        case .text: return "text.alignleft"
        case .image: return "photo"
        }
    }

    private var displayTitle: String {
        if item.kind == .image {
            return copy.savedImageTitle
        }
        let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? item.value : title
    }

    private var displayDescription: String? {
        let description = item.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !description.isEmpty, description != displayTitle {
            return description
        }
        return nil
    }

    var body: some View {
        NavigationLink {
            SavedItemDetailView(copy: copy, item: item, onDelete: onDetailDelete)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                SavedItemThumbnail(item: item, fallbackIconName: iconName)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.subheadline)
                        .lineLimit(2)

                    if let displayDescription {
                        Text(displayDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Text(item.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onRecategorize(item)
            } label: {
                Label(copy.moveToCategoryTitle, systemImage: "folder")
            }

            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Label(copy.deleteTitle, systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onRecategorize(item)
            } label: {
                Label(copy.moveToCategoryTitle, systemImage: "folder")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Label(copy.deleteTitle, systemImage: "trash")
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SavedItemThumbnail: View {
    let item: SharedItem
    let fallbackIconName: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackIconName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.blue.opacity(0.12))
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
        .task {
            guard let store = try? SharedLibraryStore() else { return }
            let data = item.kind == .image
                ? store.imageData(for: item)
                : store.thumbnailData(for: item)
            image = data.flatMap(UIImage.init(data:))
        }
    }
}

private struct SavedItemDetailView: View {
    let copy: Copy
    let item: SharedItem
    let onDelete: (SharedItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingShareSheet = false
    @State private var isShowingDeleteConfirmation = false

    private var image: UIImage? {
        guard item.kind == .image,
              let store = try? SharedLibraryStore(),
              let data = store.imageData(for: item) else {
            return nil
        }
        return UIImage(data: data)
    }

    private var thumbnail: UIImage? {
        guard item.kind == .url,
              let store = try? SharedLibraryStore(),
              let data = store.thumbnailData(for: item) else {
            return nil
        }
        return UIImage(data: data)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if item.kind == .image {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        Text(copy.imageUnavailableTitle)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if let thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        if let title = item.title, !title.isEmpty {
                            Text(title)
                                .font(.headline)
                        }
                        if let description = item.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.value)
                            .font(.body)
                            .textSelection(.enabled)

                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                }

                HStack(spacing: 10) {
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label(copy.deleteTitle, systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 0)

                    Button {
                        isShowingShareSheet = true
                    } label: {
                        Label(copy.shareTitle, systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)

                    if item.kind == .url, let url = URL(string: item.value) {
                        Link(destination: url) {
                            Label(copy.openLinkTitle, systemImage: "safari")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(copy.savedDateTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.createdAt, format: .dateTime.year().month().day())
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(copy.itemDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(activityItems: activityItems)
        }
        .alert(copy.deleteConfirmationTitle, isPresented: $isShowingDeleteConfirmation) {
            Button(copy.cancelTitle, role: .cancel) {}
            Button(copy.deleteTitle, role: .destructive) {
                isShowingDeleteConfirmation = false
                onDelete(item)
                dismiss()
            }
        } message: {
            Text(copy.deleteConfirmationMessage)
        }
    }

    private var activityItems: [Any] {
        let original = item.originalContent
        switch original?.kind ?? item.kind {
        case .url:
            let value = original?.value ?? item.value
            return [URL(string: value) ?? value]
        case .text:
            return [original?.value ?? item.value]
        case .image:
            if let store = try? SharedLibraryStore(),
               let data = store.imageData(for: item),
               let image = UIImage(data: data) {
                return [image]
            }
            return [original?.value ?? item.value]
        }
    }

}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ShareInstructionsSheet: View {
    let copy: Copy
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Label(copy.sheetHeadline, systemImage: "bookmark.fill")
                    .font(.title3.weight(.bold))

                Text(copy.sheetDescription)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    InstructionRow(number: 1, text: copy.sheetInstructionOne)
                    InstructionRow(number: 2, text: copy.sheetInstructionTwo)
                    InstructionRow(number: 3, text: copy.sheetInstructionThree)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle(copy.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(copy.done) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Empty Inbox") {
    ContentView()
}

#Preview("Large Text") {
    ContentView()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
