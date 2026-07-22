import UIKit
import LinkPresentation
import UniformTypeIdentifiers
import ShareGatherStorage

final class ShareViewController: UIViewController {
    private var store: SharedLibraryStore?
    private var categories: [SharedCategory] = []
    private var selectedCategoryID: UUID?
    private var isUncategorizedSelected = false
    private var pendingKind: SharedItemKind?
    private var pendingValue = ""
    private var pendingDescription: String?
    private var pendingTitle: String?
    private var pendingThumbnailData: Data?
    private var pendingImageData: Data?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let saveButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let statusLabel = UILabel()

    private var localeIdentifier: String { SharedGatherLocalization.sharedLanguageIdentifier() }
    private func text(_ key: String) -> String {
        SharedGatherLocalization.string(key, localeIdentifier: localeIdentifier)
    }

    private var savingTitle: String { text("share.status.saving") }
    private var savedTitle: String { text("share.status.saved") }
    private var failedTitle: String { text("share.status.failed") }
    private var doneTitle: String { text("common.done") }
    private var cancelTitle: String { text("common.cancel") }
    private var chooseCategoryTitle: String { text("share.category.title") }
    private var chooseCategorySubtitle: String { text("share.category.subtitle") }
    private var createCategoryTitle: String { text("category.create.new") }
    private var createTitle: String { text("common.create") }
    private var categoryNamePlaceholder: String { text("category.name.placeholder") }
    private var noCategoriesTitle: String { text("category.empty") }
    private var noCategoriesMessage: String { text("category.empty.message") }
    private var newCategoryButtonTitle: String { text("category.new") }
    private var uncategorizedTitle: String { text("library.uncategorized") }
    private var selectCategoryMessage: String { text("category.select.message") }
    private var invalidCategoryMessage: String { text("category.name.invalid") }
    private var itemTypeTitle: String {
        switch pendingKind {
        case .url: return text("library.link")
        case .text: return text("library.text")
        case .image: return text("library.image")
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

        statusLabel.text = text("share.status.preparing")
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
              let providers = extensionItem.attachments,
              !providers.isEmpty else {
            showFailure()
            return
        }

        pendingDescription = extensionItem.attributedContentText?.string
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) {
            loadURL(from: provider)
        } else if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }) {
            loadText(from: provider)
        } else if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) {
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
            let kind: SharedItemKind = URL(string: text)?.scheme == nil ? .text : .url
            self.finishPreparing(kind: kind, value: text)
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
            self.preparePreviewMetadata()
        }
    }

    private func preparePreviewMetadata() {
        guard pendingKind == .url, let url = URL(string: pendingValue) else {
            loadCategories()
            return
        }

        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { [weak self] metadata, _ in
            guard let self else { return }
            self.pendingTitle = metadata?.title
            let finish = { [weak self] in
                self?.loadCategories()
            }
            guard let imageProvider = metadata?.imageProvider else {
                finish()
                return
            }
            imageProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                self?.pendingThumbnailData = data
                finish()
            }
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
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = chooseCategorySubtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let thumbnailView = UIImageView(image: pendingThumbnailData.flatMap(UIImage.init(data:)))
        thumbnailView.image = thumbnailView.image ?? UIImage(systemName: pendingKind == .url ? "link" : "doc.text")
        thumbnailView.tintColor = .systemBlue
        thumbnailView.backgroundColor = .systemBlue.withAlphaComponent(0.12)
        thumbnailView.layer.cornerRadius = 10
        thumbnailView.clipsToBounds = true
        thumbnailView.contentMode = pendingThumbnailData == nil ? .center : .scaleAspectFill
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false

        let previewTitleLabel = UILabel()
        previewTitleLabel.text = pendingTitle ?? (pendingKind == .image ? itemTypeTitle : pendingValue)
        previewTitleLabel.font = .preferredFont(forTextStyle: .headline)
        previewTitleLabel.textColor = .label
        previewTitleLabel.numberOfLines = 2

        let descriptionLabel = UILabel()
        descriptionLabel.text = pendingDescription ?? URL(string: pendingValue)?.host
        descriptionLabel.font = .preferredFont(forTextStyle: .subheadline)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 1
        descriptionLabel.lineBreakMode = .byTruncatingTail

        let valueLabel = UILabel()
        valueLabel.text = pendingKind == .url ? pendingValue : nil
        valueLabel.font = .preferredFont(forTextStyle: .caption1)
        valueLabel.textColor = .secondaryLabel
        valueLabel.numberOfLines = 1
        valueLabel.lineBreakMode = .byTruncatingTail

        let textStack = UIStackView(arrangedSubviews: [previewTitleLabel, descriptionLabel, valueLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        let previewCard = UIStackView(arrangedSubviews: [thumbnailView, textStack])
        previewCard.axis = .horizontal
        previewCard.alignment = .center
        previewCard.spacing = 12
        previewCard.isLayoutMarginsRelativeArrangement = true
        previewCard.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        previewCard.backgroundColor = .secondarySystemGroupedBackground
        previewCard.layer.cornerRadius = 16
        NSLayoutConstraint.activate([
            thumbnailView.widthAnchor.constraint(equalToConstant: 64),
            thumbnailView.heightAnchor.constraint(equalToConstant: 64),
            previewCard.heightAnchor.constraint(equalToConstant: 112)
        ])

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = 58
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
        newCategoryButton.configuration = .tinted()
        newCategoryButton.addTarget(self, action: #selector(createCategory), for: .touchUpInside)

        saveButton.setTitle(text("common.save"), for: .normal)
        saveButton.configuration = .filled()
        saveButton.configuration?.cornerStyle = .capsule
        saveButton.isEnabled = selectedCategoryID != nil
        saveButton.addTarget(self, action: #selector(saveSelectedItem), for: .touchUpInside)

        cancelButton.configuration = .plain()
        let bottomButtons = UIStackView(arrangedSubviews: [cancelButton, saveButton])
        bottomButtons.axis = .horizontal
        bottomButtons.distribution = .fillEqually
        bottomButtons.spacing = 10

        let actionButtons = UIStackView(arrangedSubviews: [newCategoryButton, bottomButtons])
        actionButtons.axis = .vertical
        actionButtons.spacing = 10

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, previewCard, tableView, actionButtons])
        stack.axis = .vertical
        stack.spacing = 12

        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            tableView.heightAnchor.constraint(lessThanOrEqualToConstant: 340),
            cancelButton.heightAnchor.constraint(equalToConstant: 40)
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
                self.isUncategorizedSelected = false
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
        guard selectedCategoryID != nil || isUncategorizedSelected else {
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
        let categoryID = selectedCategoryID
        if pendingKind == .url, let url = URL(string: value) {
            let metadataProvider = LPMetadataProvider()
            metadataProvider.startFetchingMetadata(for: url) { [weak self] metadata, _ in
                let description = self?.pendingDescription ?? url.host
                let persist: (Data?) -> Void = { thumbnailData in
                    self?.persistItem(
                        store: store,
                        kind: pendingKind,
                        value: value,
                        title: metadata?.title,
                        description: description,
                        thumbnailData: thumbnailData,
                        originalContent: SharedOriginalContent(
                            kind: pendingKind,
                            value: value,
                            sourceText: description
                        ),
                        categoryID: categoryID,
                        imageData: imageData
                    )
                }
                guard let imageProvider = metadata?.imageProvider else {
                    persist(nil)
                    return
                }
                imageProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    persist(data)
                }
            }
        } else {
            persistItem(
                store: store,
                kind: pendingKind,
                value: value,
                title: nil,
                description: pendingDescription,
                thumbnailData: nil,
                originalContent: SharedOriginalContent(
                    kind: pendingKind,
                    value: value,
                    sourceText: pendingDescription
                ),
                categoryID: categoryID,
                imageData: imageData
            )
        }
    }

    private func persistItem(
        store: SharedLibraryStore,
        kind: SharedItemKind,
        value: String,
        title: String?,
        description: String?,
        thumbnailData: Data?,
        originalContent: SharedOriginalContent,
        categoryID: UUID?,
        imageData: Data?
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try store.saveItem(
                    kind: kind,
                    value: value,
                    categoryID: categoryID,
                    imageData: imageData,
                    title: title,
                    description: description,
                    thumbnailData: thumbnailData,
                    originalContent: originalContent
                )
                self.showSuccess()
            } catch {
                self.showFailure()
            }
        }
    }

    private func showSuccess() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil)
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
        categories.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        if indexPath.row == 0 {
            cell.textLabel?.text = uncategorizedTitle
            cell.imageView?.image = UIImage(systemName: "tray")
            cell.accessoryType = isUncategorizedSelected ? .checkmark : .none
        } else {
            let category = categories[indexPath.row - 1]
            cell.textLabel?.text = category.name
            cell.imageView?.image = UIImage(systemName: "folder")
            cell.accessoryType = !isUncategorizedSelected && category.id == selectedCategoryID ? .checkmark : .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            selectedCategoryID = nil
            isUncategorizedSelected = true
        } else {
            selectedCategoryID = categories[indexPath.row - 1].id
            isUncategorizedSelected = false
        }
        tableView.reloadData()
        saveButton.isEnabled = true
    }
}
