import UIKit
import UniformTypeIdentifiers
import ShareGatherStorage

final class ShareViewController: UIViewController {
    private var store: SharedLibraryStore?
    private var categories: [SharedCategory] = []
    private var selectedCategoryID: UUID?
    private var pendingKind: SharedItemKind?
    private var pendingValue = ""
    private var pendingImageData: Data?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let saveButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let statusLabel = UILabel()

    private var isTraditionalChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }

    private var savingTitle: String { isTraditionalChinese ? "正在儲存…" : "Saving…" }
    private var savedTitle: String { isTraditionalChinese ? "已儲存" : "Saved" }
    private var failedTitle: String { isTraditionalChinese ? "儲存失敗" : "Could not save" }
    private var doneTitle: String { isTraditionalChinese ? "完成" : "Done" }
    private var cancelTitle: String { isTraditionalChinese ? "取消" : "Cancel" }
    private var chooseCategoryTitle: String { isTraditionalChinese ? "選擇分類" : "Choose a category" }
    private var createCategoryTitle: String { isTraditionalChinese ? "建立新分類" : "Create a new category" }
    private var createTitle: String { isTraditionalChinese ? "建立" : "Create" }
    private var categoryNamePlaceholder: String { isTraditionalChinese ? "分類名稱" : "Category name" }
    private var noCategoriesTitle: String { isTraditionalChinese ? "還沒有分類" : "No categories yet" }
    private var noCategoriesMessage: String {
        isTraditionalChinese ? "建立一個分類，將這則分享內容儲存到適合的位置。" : "Create a category to save this shared item in the right place."
    }
    private var newCategoryButtonTitle: String { isTraditionalChinese ? "新增分類" : "New category" }
    private var selectCategoryMessage: String { isTraditionalChinese ? "請先選擇分類" : "Select a category first" }
    private var invalidCategoryMessage: String {
        isTraditionalChinese ? "分類名稱需為 1 到 50 個字元。" : "Category names must contain 1 to 50 characters."
    }
    private var itemTypeTitle: String {
        switch pendingKind {
        case .url: return isTraditionalChinese ? "連結" : "Link"
        case .text: return isTraditionalChinese ? "文字" : "Text"
        case .image: return isTraditionalChinese ? "圖片" : "Image"
        case .none: return ""
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureBaseView()
        processSharedContent()
    }

    private func configureBaseView() {
        view.backgroundColor = .systemBackground
        let iconView = UIImageView(image: UIImage(systemName: "tray.and.arrow.down.fill"))
        iconView.tintColor = .systemBlue
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 42, weight: .medium)

        let titleLabel = UILabel()
        titleLabel.text = "ShareGather"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center

        statusLabel.text = "Preparing shared item…"
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        activityIndicator.startAnimating()
        doneButton.setTitle(doneTitle, for: .normal)
        doneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        doneButton.isHidden = true
        doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)

        cancelButton.setTitle(cancelTitle, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [doneButton, cancelButton])
        buttons.axis = .vertical
        buttons.spacing = 8

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, statusLabel, activityIndicator, buttons])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16

        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconView.heightAnchor.constraint(equalToConstant: 56),
            buttons.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
        ])
    }

    private func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = extensionItem.attachments?.first else {
            showFailure()
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            loadURL(from: provider)
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            loadText(from: provider)
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            loadImage(from: provider)
        } else {
            showFailure()
        }
    }

    private func loadURL(from provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
            guard let self else { return }
            let url: URL?
            if let item = item as? URL {
                url = item
            } else if let item = item as? NSURL {
                url = item as URL
            } else if let item = item as? String {
                url = URL(string: item)
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }

            guard error == nil, let url else {
                self.showFailure()
                return
            }
            self.finishPreparing(kind: .url, value: url.absoluteString)
        }
    }

    private func loadText(from provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
            guard let self else { return }
            let text = (item as? String) ?? (item as? NSString).map(String.init)
            guard error == nil, let text, !text.isEmpty else {
                self.showFailure()
                return
            }
            self.finishPreparing(kind: .text, value: text)
        }
    }

    private func loadImage(from provider: NSItemProvider) {
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, error in
            guard let self, error == nil, let data else {
                self?.showFailure()
                return
            }
            self.pendingImageData = data
            self.finishPreparing(kind: .image, value: "")
        }
    }

    private func finishPreparing(kind: SharedItemKind, value: String) {
        DispatchQueue.main.async {
            self.pendingKind = kind
            self.pendingValue = value
            self.loadCategories()
        }
    }

    private func loadCategories() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let store = try SharedLibraryStore()
                let categories = try store.loadCategories()
                DispatchQueue.main.async {
                    self.store = store
                    self.categories = categories
                    self.renderCategorySelection()
                }
            } catch {
                self.showFailure()
            }
        }
    }

    private func renderCategorySelection() {
        view.subviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = .systemGroupedBackground

        let titleLabel = UILabel()
        titleLabel.text = chooseCategoryTitle
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center

        let previewLabel = UILabel()
        previewLabel.text = itemTypeTitle
        previewLabel.font = .preferredFont(forTextStyle: .subheadline)
        previewLabel.textColor = .secondaryLabel
        previewLabel.textAlignment = .center

        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        if categories.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "\(noCategoriesTitle)\n\n\(noCategoriesMessage)"
            emptyLabel.numberOfLines = 0
            emptyLabel.textAlignment = .center
            emptyLabel.textColor = .secondaryLabel
            tableView.backgroundView = emptyLabel
        } else {
            tableView.backgroundView = nil
        }

        let newCategoryButton = UIButton(type: .system)
        newCategoryButton.setTitle(newCategoryButtonTitle, for: .normal)
        newCategoryButton.addTarget(self, action: #selector(createCategory), for: .touchUpInside)

        saveButton.setTitle(isTraditionalChinese ? "儲存" : "Save", for: .normal)
        saveButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        saveButton.isEnabled = selectedCategoryID != nil
        saveButton.addTarget(self, action: #selector(saveSelectedItem), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [newCategoryButton, saveButton, cancelButton])
        buttons.axis = .vertical
        buttons.spacing = 8

        let stack = UIStackView(arrangedSubviews: [titleLabel, previewLabel, tableView, buttons])
        stack.axis = .vertical
        stack.spacing = 8

        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            tableView.heightAnchor.constraint(lessThanOrEqualToConstant: 360)
        ])
    }

    @objc private func createCategory() {
        let alert = UIAlertController(title: createCategoryTitle, message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = self.categoryNamePlaceholder
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: createTitle, style: .default) { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text else { return }
            do {
                let category = try self.store?.createCategory(named: name)
                self.categories = try self.store?.loadCategories() ?? []
                self.selectedCategoryID = category?.id
                self.renderCategorySelection()
            } catch {
                self.showCategoryError()
            }
        })
        present(alert, animated: true)
    }

    private func showCategoryError() {
        let alert = UIAlertController(title: failedTitle, message: invalidCategoryMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: doneTitle, style: .default))
        present(alert, animated: true)
    }

    @objc private func saveSelectedItem() {
        guard let categoryID = selectedCategoryID else {
            let alert = UIAlertController(title: selectCategoryMessage, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: doneTitle, style: .default))
            present(alert, animated: true)
            return
        }
        guard let store, let pendingKind else { return }

        view.subviews.forEach { $0.removeFromSuperview() }
        statusLabel.text = savingTitle
        statusLabel.textColor = .secondaryLabel
        activityIndicator.startAnimating()
        let stack = UIStackView(arrangedSubviews: [activityIndicator, statusLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        let value = pendingValue
        let imageData = pendingImageData
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try store.saveItem(kind: pendingKind, value: value, categoryID: categoryID, imageData: imageData)
                self.showSuccess()
            } catch {
                self.showFailure()
            }
        }
    }

    private func showSuccess() {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.statusLabel.text = self.savedTitle
            self.statusLabel.textColor = .label
            self.doneButton.isHidden = false
            self.cancelButton.isHidden = true
            self.view.subviews.forEach { $0.removeFromSuperview() }
            let stack = UIStackView(arrangedSubviews: [self.statusLabel, self.doneButton])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 16
            self.view.addSubview(stack)
            stack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
            ])
        }
    }

    private func showFailure() {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.statusLabel.text = self.failedTitle
            self.doneButton.isHidden = false
            self.view.subviews.forEach { $0.removeFromSuperview() }
            let stack = UIStackView(arrangedSubviews: [self.statusLabel, self.doneButton, self.cancelButton])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 16
            self.view.addSubview(stack)
            stack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
            ])
        }
    }

    @objc private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "ShareGatherShareExtension", code: 1))
    }
}

extension ShareViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        categories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let category = categories[indexPath.row]
        cell.textLabel?.text = category.name
        cell.accessoryType = category.id == selectedCategoryID ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedCategoryID = categories[indexPath.row].id
        tableView.reloadData()
        saveButton.isEnabled = true
    }
}
