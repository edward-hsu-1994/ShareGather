import UIKit
import LinkPresentation
import UniformTypeIdentifiers
import ShareGatherStorage
import ShareGatherReminders

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
    private var isSaving = false
    private var isCreatingReminder = false
    private var isCompletingRequest = false

    private let reminderService = ReminderService()

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
    private var reminderPromptTitle: String { text("reminder.prompt.title") }
    private var reminderPromptMessage: String { text("reminder.prompt.message") }
    private var reminderNotNowTitle: String { text("reminder.prompt.not.now") }
    private var reminderSetTitle: String { text("reminder.prompt.set") }
    private var reminderFormTitle: String { text("reminder.form.title") }
    private var reminderTitleLabel: String { text("reminder.form.reminder.title") }
    private var reminderNotesLabel: String { text("reminder.form.notes") }
    private var reminderDateLabel: String { text("reminder.form.date") }
    private var reminderCreateTitle: String { text("reminder.form.create") }
    private var reminderCreatedTitle: String { text("reminder.created.title") }
    private var reminderCreatedMessage: String { text("reminder.created.message") }
    private var reminderFailureTitle: String { text("reminder.failure.title") }
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
        guard !isSaving else { return }
        guard selectedCategoryID != nil || isUncategorizedSelected else {
            let alert = UIAlertController(title: selectCategoryMessage, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: doneTitle, style: .default))
            present(alert, animated: true)
            return
        }
        guard let store, let pendingKind else { return }
        isSaving = true
        saveButton.isEnabled = false

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
                let item = try store.saveItem(
                    kind: kind,
                    value: value,
                    categoryID: categoryID,
                    imageData: imageData,
                    title: title,
                    description: description,
                    thumbnailData: thumbnailData,
                    originalContent: originalContent
                )
                self.showReminderPrompt(for: item)
            } catch {
                self.showFailure()
            }
        }
    }

    private func showReminderPrompt(for item: SharedItem) {
        guard SharedGatherLocalization.isReminderPromptEnabled else {
            completeRequest()
            return
        }
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.statusLabel.text = self.savedTitle

            let alert = UIAlertController(
                title: self.reminderPromptTitle,
                message: self.reminderPromptMessage,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: self.reminderNotNowTitle, style: .cancel) { [weak self] _ in
                self?.completeRequest()
            })
            alert.addAction(UIAlertAction(title: self.reminderSetTitle, style: .default) { [weak self] _ in
                self?.presentReminderForm(for: item)
            })
            alert.addAction(UIAlertAction(title: self.text("reminder.prompt.dont.ask.again"), style: .default) { [weak self] _ in
                SharedGatherLocalization.setReminderPromptEnabled(false)
                self?.completeRequest()
            })
            self.present(alert, animated: true)
        }
    }

    private func presentReminderForm(for item: SharedItem) {
        let form = ReminderFormViewController(
            strings: ReminderFormViewController.Strings(
                screenTitle: reminderFormTitle,
                reminderTitle: reminderTitleLabel,
                notes: reminderNotesLabel,
                date: reminderDateLabel,
                cancel: cancelTitle,
                create: reminderCreateTitle
            ),
            initialTitle: defaultReminderTitle(for: item),
            initialNotes: text("reminder.default.notes"),
            initialDate: Date().addingTimeInterval(60 * 60)
        )
        form.onCancel = { [weak self] in
            self?.dismiss(animated: true) {
                self?.completeRequest()
            }
        }
        form.onCreate = { [weak self, weak form] title, notes, scheduledAt in
            self?.createReminder(
                for: item,
                title: title,
                notes: notes,
                scheduledAt: scheduledAt,
                form: form
            )
        }

        let navigationController = UINavigationController(rootViewController: form)
        navigationController.modalPresentationStyle = .formSheet
        navigationController.isModalInPresentation = true
        present(navigationController, animated: true)
    }

    private func defaultReminderTitle(for item: SharedItem) -> String {
        let contentTitle: String
        if let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            contentTitle = title
        } else {
            switch item.kind {
            case .url:
                let originalValue = item.originalContent?.value ?? item.value
                contentTitle = URL(string: originalValue)?.host ?? originalValue
            case .text:
                let originalValue = item.originalContent?.value ?? item.value
                let trimmed = originalValue.trimmingCharacters(in: .whitespacesAndNewlines)
                contentTitle = String(trimmed.prefix(80))
            case .image:
                contentTitle = itemTypeTitle
            }
        }

        return String(format: text("reminder.default.title"), contentTitle)
    }

    private func createReminder(
        for item: SharedItem,
        title: String,
        notes: String?,
        scheduledAt: Date,
        form: ReminderFormViewController?
    ) {
        guard !isCreatingReminder else { return }
        isCreatingReminder = true
        form?.setSubmitting(true)

        let draft = ReminderDraft(
            title: title,
            notes: notes,
            deepLinkURL: SharedItemDeepLink.url(for: item.id),
            scheduledAt: scheduledAt
        )
        Task { @MainActor [weak self, weak form] in
            guard let self else { return }
            do {
                try await reminderService.createReminder(from: draft)
                dismiss(animated: true) {
                    self.showReminderCreated()
                }
            } catch {
                isCreatingReminder = false
                form?.setSubmitting(false)
                dismiss(animated: true) {
                    self.showReminderFailure(error)
                }
            }
        }
    }

    private func showReminderCreated() {
        let alert = UIAlertController(
            title: reminderCreatedTitle,
            message: reminderCreatedMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: doneTitle, style: .default) { [weak self] _ in
            self?.completeRequest()
        })
        present(alert, animated: true)
    }

    private func showReminderFailure(_ error: Error) {
        let messageKey: String
        switch error as? ReminderCreationError {
        case .accessDenied, .accessRestricted:
            messageKey = "reminder.failure.access"
        case .noDefaultCalendar:
            messageKey = "reminder.failure.no.calendar"
        case .invalidTitle:
            messageKey = "reminder.failure.invalid.title"
        case .authorizationFailed, .saveFailed, .none:
            messageKey = "reminder.failure.generic"
        }

        let alert = UIAlertController(
            title: reminderFailureTitle,
            message: text(messageKey),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: doneTitle, style: .default) { [weak self] _ in
            self?.completeRequest()
        })
        present(alert, animated: true)
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
        completeRequest()
    }

    private func completeRequest() {
        guard !isCompletingRequest else { return }
        isCompletingRequest = true
        extensionContext?.completeRequest(returningItems: nil)
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "ShareGatherShareExtension", code: 1))
    }
}

private final class ReminderFormViewController: UIViewController {
    struct Strings {
        let screenTitle: String
        let reminderTitle: String
        let notes: String
        let date: String
        let cancel: String
        let create: String
    }

    var onCancel: (() -> Void)?
    var onCreate: ((String, String?, Date) -> Void)?

    private let strings: Strings
    private let initialTitle: String
    private let initialNotes: String
    private let initialDate: Date
    private let localeIdentifier: String

    private let titleField = UITextField()
    private let notesView = UITextView()
    private let datePicker = UIDatePicker()
    private lazy var cancelButton = UIBarButtonItem(
        title: strings.cancel,
        style: .plain,
        target: self,
        action: #selector(cancelTapped)
    )
    private lazy var createButton = UIBarButtonItem(
        title: strings.create,
        style: .done,
        target: self,
        action: #selector(createTapped)
    )

    init(
        strings: Strings,
        initialTitle: String,
        initialNotes: String,
        initialDate: Date,
        localeIdentifier: String = SharedGatherLocalization.sharedLanguageIdentifier()
    ) {
        self.strings = strings
        self.initialTitle = initialTitle
        self.initialNotes = initialNotes
        self.initialDate = initialDate
        self.localeIdentifier = localeIdentifier
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureForm()
    }

    func setSubmitting(_ isSubmitting: Bool) {
        titleField.isEnabled = !isSubmitting
        notesView.isEditable = !isSubmitting
        datePicker.isEnabled = !isSubmitting
        cancelButton.isEnabled = !isSubmitting
        createButton.isEnabled = !isSubmitting
        isModalInPresentation = isSubmitting

        if isSubmitting {
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: indicator)
        } else {
            navigationItem.rightBarButtonItem = createButton
            updateCreateButton()
        }
    }

    private func configureNavigation() {
        title = strings.screenTitle
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = createButton
    }

    private func configureForm() {
        view.backgroundColor = .systemGroupedBackground

        titleField.text = initialTitle
        titleField.font = .preferredFont(forTextStyle: .body)
        titleField.adjustsFontForContentSizeCategory = true
        titleField.borderStyle = .roundedRect
        titleField.clearButtonMode = .whileEditing
        titleField.returnKeyType = .done
        titleField.accessibilityLabel = strings.reminderTitle
        titleField.addTarget(self, action: #selector(titleChanged), for: .editingChanged)

        notesView.text = initialNotes
        notesView.font = .preferredFont(forTextStyle: .body)
        notesView.adjustsFontForContentSizeCategory = true
        notesView.backgroundColor = .secondarySystemGroupedBackground
        notesView.layer.cornerRadius = 10
        notesView.layer.borderWidth = 1 / UIScreen.main.scale
        notesView.layer.borderColor = UIColor.separator.cgColor
        notesView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        notesView.accessibilityLabel = strings.notes

        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .compact
        datePicker.locale = Locale(identifier: localeIdentifier)
        datePicker.minimumDate = Date()
        datePicker.date = max(initialDate, Date())
        datePicker.accessibilityLabel = strings.date

        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive

        let formStack = UIStackView(arrangedSubviews: [
            makeSection(label: strings.reminderTitle, control: titleField),
            makeSection(label: strings.notes, control: notesView),
            makeSection(label: strings.date, control: datePicker)
        ])
        formStack.axis = .vertical
        formStack.spacing = 24

        view.addSubview(scrollView)
        scrollView.addSubview(formStack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        formStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            formStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            formStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            formStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            formStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            formStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
            notesView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110)
        ])

        updateCreateButton()
    }

    private func makeSection(label text: String, control: UIView) -> UIStackView {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    @objc private func titleChanged() {
        updateCreateButton()
    }

    private func updateCreateButton() {
        createButton.isEnabled = !(titleField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    @objc private func createTapped() {
        let title = (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let notes = notesView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        onCreate?(title, notes.isEmpty ? nil : notes, datePicker.date)
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
