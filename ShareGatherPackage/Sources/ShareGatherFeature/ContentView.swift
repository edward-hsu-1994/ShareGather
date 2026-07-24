import SwiftUI
import UIKit
import ShareGatherStorage

private extension Notification.Name {
    static let sharedItemCategoryDidChange = Notification.Name("ShareGather.sharedItemCategoryDidChange")
    static let sharedItemDidDelete = Notification.Name("ShareGather.sharedItemDidDelete")
}

private struct CategoryItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
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
    @State private var isSelectingUncategorized = false
    @State private var selectedUncategorizedItemIDs: Set<UUID> = []
    @State private var isShowingUncategorizedBatchMove = false
    @State private var isShowingUncategorizedBatchDeleteConfirmation = false
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
                        },
                        onUpdatePin: updateItemPin,
                        onDeleteItems: deleteItems,
                        onMoveItems: moveItems
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
                            onRecategorize: requestRecategorization,
                            isSelecting: $isSelectingUncategorized,
                            selectedItemIDs: $selectedUncategorizedItemIDs
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
            .safeAreaInset(edge: .bottom) {
                if isSelectingUncategorized {
                    HStack(spacing: 12) {
                        Button {
                            isShowingUncategorizedBatchMove = true
                        } label: {
                            Label(copy.batchMoveTitle, systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedUncategorizedItemIDs.isEmpty)

                        Button(role: .destructive) {
                            isShowingUncategorizedBatchDeleteConfirmation = true
                        } label: {
                            Label(copy.batchDeleteTitle, systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedUncategorizedItemIDs.isEmpty)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.bar)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.appName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingInstructions = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel(copy.viewInstructions)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(
                            selectedLanguage: $selectedLanguage,
                            savedItemCount: savedItems.count,
                            onClearAllSavedContent: clearAllSavedContent
                        )
                    } label: {
                        Text(copy.settingsTitle)
                    }
                    .accessibilityLabel(copy.settingsTitle)
                }
            }
            .sheet(isPresented: $isShowingInstructions) {
                ShareInstructionsSheet(copy: copy)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isShowingCategoryReordering) {
                CategoryReorderingSheet(copy: copy, categories: categories) { reorderedCategories in
                    reorderCategories(reorderedCategories)
                }
            }
            .sheet(isPresented: $isShowingUncategorizedBatchMove) {
                CategorySelectionSheet(
                    copy: copy,
                    categories: categories,
                    includesUncategorized: false
                ) { categoryID in
                    let selectedIDs = Array(selectedUncategorizedItemIDs)
                    guard moveItems(selectedIDs, to: categoryID) != nil else { return }
                    selectedUncategorizedItemIDs.removeAll()
                    isSelectingUncategorized = false
                    isShowingUncategorizedBatchMove = false
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
            .alert(copy.batchDeleteConfirmationTitle, isPresented: $isShowingUncategorizedBatchDeleteConfirmation) {
                Button(copy.cancelTitle, role: .cancel) {}
                Button(copy.batchDeleteTitle, role: .destructive) {
                    guard deleteItems(Array(selectedUncategorizedItemIDs)) != nil else { return }
                    selectedUncategorizedItemIDs.removeAll()
                    isSelectingUncategorized = false
                }
            } message: {
                Text(copy.batchDeleteConfirmationMessage(selectedUncategorizedItemIDs.count))
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

    private func clearAllSavedContent(keepingCategories: Bool) {
        guard let store = try? SharedLibraryStore() else { return }
        guard (try? store.clearAllSavedContent(keepingCategories: keepingCategories)) != nil else { return }
        reloadLibrary()
    }

    private func updateItemPin(_ item: SharedItem, isPinned: Bool) -> SharedItem? {
        guard let store = try? SharedLibraryStore(),
              let updatedItem = try? store.updateItemPin(id: item.id, isPinned: isPinned) else {
            return nil
        }
        reloadLibrary()
        return updatedItem
    }

    private func deleteItems(_ itemIDs: [UUID]) -> [UUID]? {
        guard let store = try? SharedLibraryStore(),
              let deletedIDs = try? store.deleteItems(ids: itemIDs) else {
            return nil
        }
        reloadLibrary()
        return deletedIDs
    }

    private func moveItems(_ itemIDs: [UUID], to categoryID: UUID?) -> [SharedItem]? {
        guard let store = try? SharedLibraryStore(),
              let updatedItems = try? store.updateItemsCategory(ids: itemIDs, categoryID: categoryID) else {
            return nil
        }
        reloadLibrary()
        return updatedItems
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
    let savedItemCount: Int
    let onClearAllSavedContent: (Bool) -> Void
    @State private var isShowingClearAllItemsChoice = false

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

            Section(copy.dangerZoneTitle) {
                Button(role: .destructive) {
                    isShowingClearAllItemsChoice = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Spacer()
                        Text(copy.clearAllItemsTitle)
                    }
                }
                .disabled(savedItemCount == 0)
            }
        }
        .navigationTitle(copy.settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert(
            copy.clearAllItemsChoiceTitle,
            isPresented: $isShowingClearAllItemsChoice
        ) {
            Button(copy.clearAllItemsKeepCategoriesTitle, role: .destructive) {
                onClearAllSavedContent(true)
            }
            Button(copy.clearAllItemsAndCategoriesTitle, role: .destructive) {
                onClearAllSavedContent(false)
            }
            Button(copy.cancelTitle, role: .cancel) {}
        } message: {
            Text(copy.clearAllItemsChoiceMessage(savedItemCount))
        }
    }
}

private struct Copy {
    let language: AppLanguage

    private func text(_ key: String) -> String {
        SharedGatherLocalization.string(key, localeIdentifier: language.resolvedLocaleIdentifier)
    }

    var locale: Locale {
        Locale(identifier: language.resolvedLocaleIdentifier)
    }

    func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide).day().locale(locale))
    }

    var appName: String { text("app.name") }
    var languageTitle: String { text("app.language.title") }
    var settingsTitle: String { text("settings.title") }
    var dangerZoneTitle: String { text("settings.danger.title") }
    var clearAllItemsTitle: String { text("settings.clear.items") }
    var clearAllItemsChoiceTitle: String { text("settings.clear.items.choice.title") }
    var clearAllItemsKeepCategoriesTitle: String { text("settings.clear.items.keep.categories") }
    var clearAllItemsAndCategoriesTitle: String { text("settings.clear.items.delete.categories") }
    var pinItemTitle: String { text("item.pin") }
    var unpinItemTitle: String { text("item.unpin") }
    var selectTitle: String { text("common.select") }
    var batchMoveTitle: String { text("item.batch.move") }
    var batchDeleteTitle: String { text("item.batch.delete") }
    var batchDeleteConfirmationTitle: String { text("item.batch.delete.title") }
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

    func clearAllItemsChoiceMessage(_ count: Int) -> String {
        text("settings.clear.items.choice.message").replacingOccurrences(of: "%d", with: "\(count)")
    }

    func batchDeleteConfirmationMessage(_ count: Int) -> String {
        text("item.batch.delete.message").replacingOccurrences(of: "%d", with: "\(count)")
    }

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
    let onUpdatePin: (SharedItem, Bool) -> SharedItem?
    let onDeleteItems: ([UUID]) -> [UUID]?
    let onMoveItems: ([UUID], UUID?) -> [SharedItem]?
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

                HStack(spacing: 16) {
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
                                onRecategorizeToCategory: onRecategorizeToCategory,
                                onUpdatePin: onUpdatePin,
                                onDeleteItems: onDeleteItems,
                                onMoveItems: onMoveItems
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
    let onUpdatePin: (SharedItem, Bool) -> SharedItem?
    let onDeleteItems: ([UUID]) -> [UUID]?
    let onMoveItems: ([UUID], UUID?) -> [SharedItem]?
    @State private var isSelecting = false
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var isShowingBatchMove = false
    @State private var isShowingBatchDeleteConfirmation = false
    @State private var itemFrames: [UUID: CGRect] = [:]
    @State private var selectionDragAnchorID: UUID?
    @State private var selectionDragInitialIDs: Set<UUID> = []
    @State private var selectionDragSelectsItems = true

    init(
        copy: Copy,
        title: String,
        items: [SharedItem],
        categories: [SharedCategory],
        categoryID: UUID,
        onDelete: @escaping (SharedItem) -> Void,
        onDeleteItem: @escaping (SharedItem) -> Void,
        onRecategorizeToCategory: @escaping (SharedItem, UUID?) -> Void,
        onUpdatePin: @escaping (SharedItem, Bool) -> SharedItem?,
        onDeleteItems: @escaping ([UUID]) -> [UUID]?,
        onMoveItems: @escaping ([UUID], UUID?) -> [SharedItem]?
    ) {
        self.copy = copy
        self.title = title
        self.items = items
        self.categories = categories
        self.categoryID = categoryID
        self.onDelete = onDelete
        self.onDeleteItem = onDeleteItem
        self.onRecategorizeToCategory = onRecategorizeToCategory
        self.onUpdatePin = onUpdatePin
        self.onDeleteItems = onDeleteItems
        self.onMoveItems = onMoveItems
        _displayedItems = State(initialValue: items)
    }

    private var sortedItems: [SharedItem] {
        displayedItems.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
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
                            onRecategorize: onRecategorizeToCategory,
                            onTogglePin: { item in
                                guard let updatedItem = onUpdatePin(item, !item.isPinned) else { return }
                                guard let index = displayedItems.firstIndex(where: { $0.id == updatedItem.id }) else { return }
                                displayedItems[index] = updatedItem
                            },
                            isSelecting: isSelecting,
                            isSelected: selectedItemIDs.contains(item.id),
                            onToggleSelection: {
                                if selectedItemIDs.contains(item.id) {
                                    selectedItemIDs.remove(item.id)
                                } else {
                                    selectedItemIDs.insert(item.id)
                                }
                            },
                            onSelectionDragChanged: { location in
                                updateSelectionDrag(from: item, at: location)
                            },
                            onSelectionDragEnded: endSelectionDrag
                        )
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: CategoryItemFramePreferenceKey.self,
                                    value: [item.id: proxy.frame(in: .named("category-items"))]
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .coordinateSpace(name: "category-items")
        .onPreferenceChange(CategoryItemFramePreferenceKey.self) { itemFrames = $0 }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSelecting ? copy.cancelTitle : copy.selectTitle) {
                    isSelecting.toggle()
                    if !isSelecting {
                        selectedItemIDs.removeAll()
                        endSelectionDrag()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                HStack(spacing: 12) {
                    Button {
                        isShowingBatchMove = true
                    } label: {
                        Label(copy.batchMoveTitle, systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedItemIDs.isEmpty)

                    Button(role: .destructive) {
                        isShowingBatchDeleteConfirmation = true
                    } label: {
                        Label(copy.batchDeleteTitle, systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedItemIDs.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
            }
        }
        .sheet(isPresented: $isShowingBatchMove) {
            CategorySelectionSheet(copy: copy, categories: categories, excludingCategoryID: categoryID) { categoryID in
                let selectedIDs = Array(selectedItemIDs)
                guard onMoveItems(selectedIDs, categoryID) != nil else { return }
                displayedItems.removeAll { selectedItemIDs.contains($0.id) }
                selectedItemIDs.removeAll()
                isSelecting = false
                endSelectionDrag()
                isShowingBatchMove = false
            }
        }
        .alert(copy.batchDeleteConfirmationTitle, isPresented: $isShowingBatchDeleteConfirmation) {
            Button(copy.cancelTitle, role: .cancel) {}
            Button(copy.batchDeleteTitle, role: .destructive) {
                let selectedIDs = Array(selectedItemIDs)
                guard onDeleteItems(selectedIDs) != nil else { return }
                displayedItems.removeAll { selectedItemIDs.contains($0.id) }
                selectedItemIDs.removeAll()
                isSelecting = false
                endSelectionDrag()
            }
        } message: {
            Text(copy.batchDeleteConfirmationMessage(selectedItemIDs.count))
        }
        .onReceive(NotificationCenter.default.publisher(for: .sharedItemCategoryDidChange)) { notification in
            guard let updatedItem = notification.object as? SharedItem,
                  updatedItem.categoryID != categoryID else { return }
            displayedItems.removeAll { $0.id == updatedItem.id }
            selectedItemIDs.remove(updatedItem.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .sharedItemDidDelete)) { notification in
            guard let deletedItemID = notification.object as? UUID else { return }
            displayedItems.removeAll { $0.id == deletedItemID }
            selectedItemIDs.remove(deletedItemID)
        }
    }

    private func updateSelectionDrag(from item: SharedItem, at location: CGPoint) {
        if selectionDragAnchorID == nil {
            selectionDragAnchorID = item.id
            selectionDragInitialIDs = selectedItemIDs
            selectionDragSelectsItems = !selectedItemIDs.contains(item.id)
        }

        guard let anchorID = selectionDragAnchorID,
              let anchorIndex = sortedItems.firstIndex(where: { $0.id == anchorID }),
              let targetIndex = sortedItems.firstIndex(where: { itemFrames[$0.id]?.contains(location) == true }),
              targetIndex >= anchorIndex else {
            return
        }

        let rangeIDs = Set(sortedItems[anchorIndex...targetIndex].map(\.id))
        if selectionDragSelectsItems {
            selectedItemIDs = selectionDragInitialIDs.union(rangeIDs)
        } else {
            selectedItemIDs = selectionDragInitialIDs.subtracting(rangeIDs)
        }
    }

    private func endSelectionDrag() {
        selectionDragAnchorID = nil
        selectionDragInitialIDs.removeAll()
    }
}

private struct CategorizedItemRow: View {
    let copy: Copy
    let item: SharedItem
    let categories: [SharedCategory]
    let onDelete: (SharedItem) -> Void
    let onDeleteItem: (SharedItem) -> Void
    let onRecategorize: (SharedItem, UUID?) -> Void
    let onTogglePin: (SharedItem) -> Void
    let isSelecting: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onSelectionDragChanged: (CGPoint) -> Void
    let onSelectionDragEnded: () -> Void
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
            },
            pinAction: { onTogglePin(item) }
        )
        .allowsHitTesting(!isSelecting)
        .overlay(alignment: .trailing) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("category-items"))
                            .onChanged { onSelectionDragChanged($0.location) }
                            .onEnded { _ in onSelectionDragEnded() }
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityAction { onToggleSelection() }
            }
        }
        .overlay(alignment: .topLeading) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
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
    let excludingCategoryID: UUID?
    let includesUncategorized: Bool
    let onSelect: (UUID?) -> Void

    init(
        copy: Copy,
        categories: [SharedCategory],
        excludingCategoryID: UUID? = nil,
        includesUncategorized: Bool = true,
        onSelect: @escaping (UUID?) -> Void
    ) {
        self.copy = copy
        self.categories = categories
        self.excludingCategoryID = excludingCategoryID
        self.includesUncategorized = includesUncategorized
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List {
                if includesUncategorized {
                    Button {
                        onSelect(nil)
                    } label: {
                        Label(copy.uncategorizedTitle, systemImage: "tray")
                    }
                }

                Section(copy.categoriesTitle) {
                    ForEach(categories.filter { $0.id != excludingCategoryID }) { category in
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
    @Binding var isSelecting: Bool
    @Binding var selectedItemIDs: Set<UUID>
    @State private var itemPendingDeletion: SharedItem?
    @State private var itemFrames: [UUID: CGRect] = [:]
    @State private var selectionDragAnchorID: UUID?
    @State private var selectionDragInitialIDs: Set<UUID> = []
    @State private var selectionDragSelectsItems = true

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
                    HStack {
                        Text(copy.uncategorizedCollectionTitle)
                            .font(.headline)
                        Spacer(minLength: 8)
                        Button(isSelecting ? copy.cancelTitle : copy.selectTitle) {
                            isSelecting.toggle()
                            if !isSelecting {
                                selectedItemIDs.removeAll()
                                endSelectionDrag()
                            }
                        }
                    }

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
                        .allowsHitTesting(!isSelecting)
                        .overlay(alignment: .trailing) {
                            if isSelecting {
                                Image(systemName: selectedItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedItemIDs.contains(item.id) ? .blue : .secondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                    .highPriorityGesture(
                                        DragGesture(minimumDistance: 0, coordinateSpace: .named("uncategorized-items"))
                                            .onChanged { updateSelectionDrag(from: item, at: $0.location) }
                                            .onEnded { _ in endSelectionDrag() }
                                    )
                            }
                        }
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: CategoryItemFramePreferenceKey.self,
                                    value: [item.id: proxy.frame(in: .named("uncategorized-items"))]
                                )
                            }
                        }
                    }

                }
                .coordinateSpace(name: "uncategorized-items")
                .onPreferenceChange(CategoryItemFramePreferenceKey.self) { itemFrames = $0 }
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
        .onChange(of: isSelecting) { _, isSelecting in
            if !isSelecting { endSelectionDrag() }
        }
    }

    private func updateSelectionDrag(from item: SharedItem, at location: CGPoint) {
        if selectionDragAnchorID == nil {
            selectionDragAnchorID = item.id
            selectionDragInitialIDs = selectedItemIDs
            selectionDragSelectsItems = !selectedItemIDs.contains(item.id)
        }

        guard let anchorID = selectionDragAnchorID,
              let anchorIndex = uncategorizedItems.firstIndex(where: { $0.id == anchorID }),
              let targetIndex = uncategorizedItems.firstIndex(where: { itemFrames[$0.id]?.contains(location) == true }),
              targetIndex >= anchorIndex else {
            return
        }

        let rangeIDs = Set(uncategorizedItems[anchorIndex...targetIndex].map(\.id))
        if selectionDragSelectsItems {
            selectedItemIDs = selectionDragInitialIDs.union(rangeIDs)
        } else {
            selectedItemIDs = selectionDragInitialIDs.subtracting(rangeIDs)
        }
    }

    private func endSelectionDrag() {
        selectionDragAnchorID = nil
        selectionDragInitialIDs.removeAll()
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
    let pinAction: (() -> Void)?

    init(
        copy: Copy,
        item: SharedItem,
        onDelete: @escaping (SharedItem) -> Void,
        onDetailDelete: @escaping (SharedItem) -> Void,
        onRecategorize: @escaping (SharedItem) -> Void,
        pinAction: (() -> Void)? = nil
    ) {
        self.copy = copy
        self.item = item
        self.onDelete = onDelete
        self.onDetailDelete = onDetailDelete
        self.onRecategorize = onRecategorize
        self.pinAction = pinAction
    }

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

                    Text(copy.formattedDate(item.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let pinAction {
                Button(action: pinAction) {
                    Label(
                        item.isPinned ? copy.unpinItemTitle : copy.pinItemTitle,
                        systemImage: item.isPinned ? "pin.slash" : "pin"
                    )
                }
            }

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
                    Text(copy.formattedDate(item.createdAt))
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
