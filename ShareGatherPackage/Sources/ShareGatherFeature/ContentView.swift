import SwiftUI
import UIKit
import ShareGatherStorage

public struct ContentView: View {
    @AppStorage("appLanguage") private var selectedLanguage = AppLanguage.english.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingInstructions = false
    @State private var isShowingCreateCategory = false
    @State private var newCategoryName = ""
    @State private var itemPendingDeletion: SharedItem?
    @State private var itemPendingRecategorization: SharedItem?
    @State private var categoryPendingDeletion: SharedCategory?
    @State private var categoryDeletionDisposition: CategoryDeletionItemDisposition?
    @State private var isShowingCategoryItemChoice = false
    @State private var isShowingCategoryDeleteConfirmation = false
    @State private var isShowingRecategorization = false
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
                        onRecategorize: requestRecategorization,
                        onDeleteCategory: requestDeleteCategory
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
                            onDelete: requestDelete,
                            onRecategorize: requestRecategorization
                        )
                    }

                    ShareInstructionsCard(copy: copy) {
                        isShowingInstructions = true
                    }

                    RecentSavedItemsSection(
                        copy: copy,
                        items: savedItems,
                        onDelete: requestDelete,
                        onRecategorize: requestRecategorization
                    )
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(copy.languageTitle, selection: $selectedLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName)
                                    .tag(language.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: "globe")
                    }
                    .accessibilityLabel(copy.languageTitle)
                }
            }
            .onAppear {
                reloadLibrary()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    reloadLibrary()
                }
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
            .confirmationDialog(
                copy.moveToCategoryTitle,
                isPresented: $isShowingRecategorization,
                titleVisibility: .visible
            ) {
                Button(copy.uncategorizedTitle) {
                    recategorizePendingItem(to: nil)
                }

                ForEach(categories) { category in
                    Button(category.name) {
                        recategorizePendingItem(to: category.id)
                    }
                }

                Button(copy.cancelTitle, role: .cancel) {
                    itemPendingRecategorization = nil
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

    private func reloadLibrary() {
        guard let store = try? SharedLibraryStore() else { return }
        savedItems = (try? store.loadItems()) ?? []
        categories = (try? store.loadCategories()) ?? []
    }

    private func createCategory() {
        guard let store = try? SharedLibraryStore() else { return }
        _ = try? store.createCategory(named: newCategoryName)
        reloadLibrary()
        newCategoryName = ""
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

    private func requestRecategorization(_ item: SharedItem) {
        itemPendingRecategorization = item
        isShowingRecategorization = true
    }

    private func recategorizePendingItem(to categoryID: UUID?) {
        guard let item = itemPendingRecategorization,
              let store = try? SharedLibraryStore() else { return }
        _ = try? store.updateItemCategory(id: item.id, categoryID: categoryID)
        itemPendingRecategorization = nil
        isShowingRecategorization = false
        reloadLibrary()
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
    case english = "en"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .traditionalChinese:
            return "繁體中文"
        }
    }
}

private struct Copy {
    let language: AppLanguage

    var appName: String { "ShareGather" }
    var languageTitle: String { language == .english ? "Language" : "語系" }

    var privacyTitle: String {
        language == .english ? "Saved privately on this device" : "內容會私密地儲存在此裝置"
    }

    var privacySubtitle: String {
        language == .english ? "No account. No cloud. Available offline." : "不需帳號、不上雲端，離線也能使用。"
    }

    var emptyTitle: String {
        language == .english ? "Save it for later" : "先收藏，之後再看"
    }

    var emptyDescription: String {
        language == .english
            ? "Share links, images, or text from your favorite apps and find them here when you have time."
            : "從喜歡的 App 分享連結、圖片或文字，等有空時再回來查看。"
    }

    var shareCardTitle: String {
        language == .english ? "Save from another app" : "從其他 App 收藏內容"
    }

    var instructionOne: String {
        language == .english ? "Find something you want to remember" : "找到想留下來的內容"
    }

    var instructionTwo: String {
        language == .english ? "Tap the Share button" : "點選分享按鈕"
    }

    var instructionThree: String {
        language == .english ? "Choose ShareGather" : "選擇 ShareGather"
    }

    var viewInstructions: String {
        language == .english ? "View instructions" : "查看使用方式"
    }

    var savedItemsTitle: String {
        language == .english ? "Your saved items" : "你的收藏"
    }

    var recentItemsTitle: String {
        language == .english ? "Recent saved items" : "最近的新收藏"
    }

    var recentItemsEmpty: String {
        language == .english ? "Your recent saved items will appear here." : "最近收藏的內容會顯示在這裡。"
    }

    var uncategorizedTitle: String {
        language == .english ? "Uncategorized" : "未分類"
    }

    var savedImageTitle: String {
        language == .english ? "Saved image" : "已儲存的圖片"
    }

    var itemDetailTitle: String {
        language == .english ? "Saved item" : "收藏內容"
    }

    var linkTitle: String {
        language == .english ? "Link" : "連結"
    }

    var textTitle: String {
        language == .english ? "Text" : "文字"
    }

    var imageTitle: String {
        language == .english ? "Image" : "圖片"
    }

    var savedDateTitle: String {
        language == .english ? "Saved on" : "收藏日期"
    }

    var imageUnavailableTitle: String {
        language == .english ? "This image is not available." : "這張圖片目前無法讀取。"
    }

    var categoriesTitle: String {
        language == .english ? "Categories" : "分類"
    }

    var createCategoryTitle: String {
        language == .english ? "Create a category" : "建立分類"
    }

    var createTitle: String {
        language == .english ? "Create" : "建立"
    }

    var cancelTitle: String {
        language == .english ? "Cancel" : "取消"
    }

    var categoryNamePlaceholder: String {
        language == .english ? "Category name" : "分類名稱"
    }

    var categoryNameHint: String {
        language == .english ? "Give your saved items a place to go." : "為你的收藏建立一個整理的位置。"
    }

    var noCategoriesTitle: String {
        language == .english ? "No categories yet" : "目前還沒有分類"
    }

    var noItemsInCategoryTitle: String {
        language == .english ? "No saved items in this category" : "這個分類目前沒有收藏"
    }

    var deleteTitle: String {
        language == .english ? "Delete" : "刪除"
    }

    var deleteConfirmationTitle: String {
        language == .english ? "Delete saved item?" : "要刪除這個收藏嗎？"
    }

    var deleteConfirmationMessage: String {
        language == .english ? "This action cannot be undone." : "此操作無法復原。"
    }

    var moveToCategoryTitle: String {
        language == .english ? "Move to category" : "移至分類"
    }

    var recategorizeTitle: String {
        language == .english ? "Move" : "移動"
    }

    var categoryContainsItemsTitle: String {
        language == .english ? "Category contains saved items" : "此分類包含收藏"
    }

    func categoryContainsItemsMessage(_ count: Int) -> String {
        language == .english
            ? "This category contains \(count) saved item\(count == 1 ? "" : "s"). Do you also want to delete them?"
            : "此分類有 \(count) 個收藏，要同時刪除嗎？"
    }

    var deleteItemsAndCategoryTitle: String {
        language == .english ? "Delete items and category" : "刪除收藏與分類"
    }

    var keepItemsDeleteCategoryTitle: String {
        language == .english ? "Keep items, delete category" : "保留收藏，刪除分類"
    }

    var deleteCategoryConfirmationTitle: String {
        language == .english ? "Delete this category?" : "要刪除這個分類嗎？"
    }

    func deleteCategoryConfirmationMessage(categoryName: String, deletesItems: Bool) -> String {
        if language == .english {
            return deletesItems
                ? "\"\(categoryName)\" and all of its saved items will be deleted. This action cannot be undone."
                : "\"\(categoryName)\" will be deleted and its saved items will become Uncategorized."
        }
        return deletesItems
            ? "分類「\(categoryName)」及其中所有收藏都會被刪除，此操作無法復原。"
            : "分類「\(categoryName)」會被刪除，其中的收藏會移至未分類。"
    }

    var createFirstCategoryTitle: String {
        language == .english ? "Create your first category" : "建立第一個分類"
    }

    var uncategorizedCollectionTitle: String {
        language == .english ? "Uncategorized saved items" : "未分類收藏"
    }

    func itemCount(_ count: Int) -> String {
        language == .english
            ? "\(count) \(count == 1 ? "item" : "items")"
            : "\(count) 個項目"
    }

    var sheetTitle: String {
        language == .english ? "How it works" : "使用方式"
    }

    var sheetHeadline: String {
        language == .english ? "A simple way to keep what matters" : "簡單留下重要內容"
    }

    var sheetDescription: String {
        language == .english
            ? "ShareGather keeps your saved content on this device, ready whenever you have a quiet moment."
            : "ShareGather 會將收藏內容保留在此裝置，等你有空時隨時回來查看。"
    }

    var sheetInstructionOne: String {
        language == .english ? "Open a social app or browser" : "開啟社群 App 或瀏覽器"
    }

    var sheetInstructionTwo: String {
        language == .english ? "Tap Share on something interesting" : "對感興趣的內容點選分享"
    }

    var sheetInstructionThree: String {
        language == .english ? "Select ShareGather from the Share Sheet" : "從分享選單選擇 ShareGather"
    }

    var done: String { language == .english ? "Done" : "完成" }
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

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: copy.instructionOne)
                InstructionRow(number: 2, text: copy.instructionTwo)
                InstructionRow(number: 3, text: copy.instructionThree)
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
    let onRecategorize: (SharedItem) -> Void
    let onDeleteCategory: (SharedCategory) -> Void
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
                                onDelete: onDelete,
                                onRecategorize: onRecategorize
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
    let onRecategorize: (SharedItem) -> Void

    private var sortedItems: [SharedItem] {
        items.sorted { $0.createdAt > $1.createdAt }
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
                        SavedItemRow(
                            copy: copy,
                            item: item,
                            onDelete: onDelete,
                            onRecategorize: onRecategorize
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

    private var uncategorizedItems: [SharedItem] {
        items
            .filter { $0.categoryID == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
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
                        onDelete: onDelete,
                        onRecategorize: onRecategorize
                    )
                }
            }
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
    let onRecategorize: (SharedItem) -> Void

    private var iconName: String {
        switch item.kind {
        case .url: return "link"
        case .text: return "text.alignleft"
        case .image: return "photo"
        }
    }

    var body: some View {
        NavigationLink {
            SavedItemDetailView(copy: copy, item: item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .foregroundStyle(.blue)
                    .frame(width: 28, height: 28)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.kind == .image ? copy.savedImageTitle : item.value)
                        .font(.subheadline)
                        .lineLimit(3)

                    Text(item.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
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

private struct SavedItemDetailView: View {
    let copy: Copy
    let item: SharedItem

    private var kindTitle: String {
        switch item.kind {
        case .url: return copy.linkTitle
        case .text: return copy.textTitle
        case .image: return copy.imageTitle
        }
    }

    private var image: UIImage? {
        guard item.kind == .image,
              let store = try? SharedLibraryStore(),
              let data = store.imageData(for: item) else {
            return nil
        }
        return UIImage(data: data)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(kindTitle, systemImage: iconName)
                    .font(.headline)
                    .foregroundStyle(.blue)

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
                    Text(item.value)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(copy.savedDateTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.createdAt, format: .dateTime.year().month().day())
                        .font(.subheadline)
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(copy.itemDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var iconName: String {
        switch item.kind {
        case .url: return "link"
        case .text: return "text.alignleft"
        case .image: return "photo"
        }
    }
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
