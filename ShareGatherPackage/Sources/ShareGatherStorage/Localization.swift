import Foundation

public enum SharedGatherLocalization {
    public static let languagePreferenceKey = "appLanguage"

    private static let simplifiedChinese: [String: String] = [
        "app.language.title": "语言",
        "settings.title": "设置",
        "settings.preferences.title": "偏好",
        "settings.application.information.title": "应用程序信息",
        "backup.export": "导出备份",
        "backup.import": "导入备份",
        "backup.merge": "合并到现有收藏",
        "backup.replace": "替换现有收藏",
        "backup.import.message": "请选择要如何还原这个备份。",
        "backup.import.success.title": "备份导入完成",
        "backup.import.success.message": "你的收藏已成功还原。",
        "backup.import.failure.title": "无法导入备份",
        "backup.import.failure.message": "请选择有效的 ShareGather 备份档案后再试一次。",
        "settings.danger.title": "危险区域",
        "settings.clear.items": "清空所有收藏",
        "settings.clear.items.choice.title": "清空所有收藏",
        "settings.clear.items.choice.message": "这将永久删除 %d 个收藏及其图片。是否保留分类？",
        "settings.clear.items.keep.categories": "保留分类",
        "settings.clear.items.delete.categories": "删除收藏与分类",
        "app.name": "ShareGather",
        "privacy.title": "内容会私密地储存在此设备",
        "privacy.subtitle": "无需账号、不上云端，离线也能使用。",
        "privacy.policy.title": "隐私政策",
        "privacy.policy.last.updated": "最后更新：%@",
        "privacy.policy.introduction": "ShareGather 专为在 iPhone 本机储存内容、供你稍后查看而设计。本政策说明 App 如何处理这些内容。",
        "privacy.policy.information.title": "ShareGather 储存的信息",
        "privacy.policy.information.introduction": "当你透过 iOS 分享选单或“存到 ShareGather”操作储存内容时，ShareGather 可能会储存：",
        "privacy.policy.information.content": "你选择分享给 App 的网址、文字和图片。",
        "privacy.policy.information.metadata": "已储存网址可用时的标题、描述、来源和缩图。",
        "privacy.policy.information.preferences": "分类、项目顺序、置顶项目选择，以及你选择的 App 语言。",
        "privacy.policy.information.detail": "这些信息储存在设备上的 ShareGather 共享 App Group 容器，仅用于提供 App 的储存、整理、预览和再次分享功能。",
        "privacy.policy.no.account.title": "无账号、追踪或云端服务",
        "privacy.policy.no.account.detail": "ShareGather 不需要账号或登入。App 不营运自己的服务器或云端储存服务，也不包含分析、广告、追踪或数据经纪商整合。ShareGather 不会将你储存的内容传送至 ShareGather 控制的服务器。",
        "privacy.policy.metadata.title": "网址元数据请求",
        "privacy.policy.metadata.detail": "对于分享的网址，ShareGather 可能使用 Apple 的 Link Presentation 框架请求预览元数据，例如网页标题或缩图。这项请求是选用的：即使元数据载入失败，原始网址仍会储存。",
        "privacy.policy.metadata.third.party.detail": "发生这类请求时，该网址所对应的网站及其使用的服务可能会收到你的网络信息，例如 IP 地址，并依其隐私政策处理该请求。ShareGather 无法控制这些第三方。",
        "privacy.policy.backup.title": "备份导入与导出",
        "privacy.policy.backup.detail": "当你主动导出备份并透过系统分享选单传送时，备份档案可能包含你的收藏、分类、图片和缩图。接收档案的 App 或服务会依其隐私政策处理该档案。导入备份时，ShareGather 会从你选择的档案读取资料并储存在此设备。",
        "privacy.policy.choices.title": "你的选择与资料删除",
        "privacy.policy.choices.detail": "你可以控制储存的内容。你可以删除单一项目、删除分类、将项目移至未分类，或在设置中使用“清空所有收藏”。清空收藏会移除储存的项目资料及相关的本机图片和缩图；你可选择保留或删除分类。删除 App 可能会移除本机资料，请勿将删除后重新安装视为备份或导出方式。",
        "privacy.policy.changes.title": "本政策的变更",
        "privacy.policy.changes.detail": "若 ShareGather 的资料处理方式有所变更，本政策会在此代码库更新，并标示修订日期。",
        "privacy.policy.contact.title": "联络方式",
        "privacy.policy.contact.detail": "若有隐私问题或意见回馈，请在 ShareGather 项目代码库建立 issue。",
        "privacy.policy.repository.link.title": "开启 GitHub Repository",
        "privacy.policy.repository.url": "https://github.com/edward-hsu-1994/ShareGather",
        "empty.title": "先收藏，之后再看",
        "empty.description": "从喜欢的 App 分享链接、图片或文字，等有空时再回来查看。",
        "share.card.title": "从其他 App 收藏内容",
        "share.instructions.view": "查看使用方式",
        "library.saved.title": "你的收藏",
        "library.recent.title": "最近的新收藏",
        "library.recent.empty": "最近收藏的内容会显示在这里。",
        "library.uncategorized": "未分类",
        "library.saved.image": "已保存的图片",
        "library.item.detail": "收藏内容",
        "library.link": "链接",
        "library.open.link": "打开链接",
        "library.share": "分享",
        "library.text": "文字",
        "library.image": "图片",
        "library.saved.date": "收藏日期",
        "library.image.unavailable": "这张图片目前无法读取。",
        "category.title": "分类",
        "category.create": "创建分类",
        "category.rename": "重命名分类",
        "category.reorder": "重新排列分类",
        "common.create": "创建",
        "common.save": "保存",
        "common.cancel": "取消",
        "common.select": "选择",
        "item.batch.move": "移动",
        "item.batch.delete": "删除",
        "item.batch.delete.title": "删除所选收藏？",
        "item.batch.delete.message": "这将永久删除 %d 个收藏，且无法恢复。",
        "category.name.placeholder": "分类名称",
        "category.name.hint": "为你的收藏建立一个整理的位置。",
        "category.empty": "目前还没有分类",
        "category.items.empty": "这个分类目前没有收藏",
        "common.delete": "删除",
        "item.delete.title": "要删除这个收藏吗？",
        "item.pin": "置顶",
        "item.unpin": "取消置顶",
        "common.irreversible": "此操作无法恢复。",
        "category.move": "移至分类",
        "category.move.action": "移动",
        "category.contains.title": "此分类包含收藏",
        "category.delete.items": "删除收藏与分类",
        "category.keep.items": "保留收藏，删除分类",
        "category.delete.title": "要删除这个分类吗？",
        "category.first": "创建第一个分类",
        "library.uncategorized.title": "未分类收藏",
        "instructions.title": "使用方式",
        "instructions.headline": "简单留下重要内容",
        "instructions.description": "ShareGather 会将收藏内容保留在此设备，等你有空时随时回来查看。",
        "instructions.one": "打开社交 App 或浏览器",
        "instructions.two": "对感兴趣的内容点击分享",
        "instructions.three": "从分享选单选择 ShareGather",
        "common.done": "完成",
        "category.contains.message": "此分类有 %d 个收藏，要同时删除吗？",
        "library.item.count": "%d 个项目",
        "category.delete.with.items": "分类「%@」及其中所有收藏都会被删除，此操作无法恢复。",
        "category.delete.keep.items": "分类「%@」会被删除，其中的收藏会移至未分类。",
        "share.status.preparing": "正在准备分享内容…",
        "share.status.saving": "正在保存…",
        "share.status.saved": "已保存",
        "share.status.failed": "保存失败",
        "share.category.title": "选择分类",
        "share.category.subtitle": "将这则分享内容保存到适合的位置",
        "category.create.new": "创建新分类",
        "category.empty.message": "创建一个分类，将这则分享内容保存到适合的位置。",
        "category.new": "新增分类",
        "category.select.message": "请先选择分类",
        "category.name.invalid": "分类名称需为 1 到 50 个字符。"
    ]

    public static func string(_ key: String, localeIdentifier: String) -> String {
        if localeIdentifier == "zh-Hans", let value = simplifiedChinese[key] {
            return value
        }
        if let value = resourceString(key: key, localeIdentifier: localeIdentifier) {
            return value
        }
        return resourceString(key: key, localeIdentifier: "en") ?? key
    }

    private static func resourceString(key: String, localeIdentifier: String) -> String? {
        guard let path = Bundle.module.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: "\(localeIdentifier).lproj"
        ),
        let data = FileManager.default.contents(atPath: path),
        let values = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: String] else {
            return nil
        }
        return values[key]
    }

    public static func sharedLanguageIdentifier() -> String {
        let preference = UserDefaults(suiteName: SharedLibraryStore.appGroupIdentifier)?
            .string(forKey: languagePreferenceKey) ?? "system"
        switch preference {
        case "en", "zh-Hant", "zh-Hans":
            return preference
        default:
            return systemLocaleIdentifier()
        }
    }

    public static func systemLocaleIdentifier() -> String {
        let identifier = (Locale.preferredLanguages.first ?? Locale.current.identifier)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()

        if identifier.hasPrefix("zh") {
            if identifier.contains("hans") || identifier.contains("zh-cn") || identifier.contains("zh-sg") {
                return "zh-Hans"
            }
            return "zh-Hant"
        }
        return "en"
    }
}
