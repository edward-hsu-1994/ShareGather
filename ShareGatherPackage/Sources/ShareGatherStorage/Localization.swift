import Foundation

public enum SharedGatherLocalization {
    public static let languagePreferenceKey = "appLanguage"

    private static let simplifiedChinese: [String: String] = [
        "app.language.title": "语言",
        "app.name": "ShareGather",
        "privacy.title": "内容会私密地储存在此设备",
        "privacy.subtitle": "无需账号、不上云端，离线也能使用。",
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
        "library.text": "文字",
        "library.image": "图片",
        "library.saved.date": "收藏日期",
        "library.image.unavailable": "这张图片目前无法读取。",
        "category.title": "分类",
        "category.create": "创建分类",
        "category.rename": "重命名分类",
        "common.create": "创建",
        "common.save": "保存",
        "common.cancel": "取消",
        "category.name.placeholder": "分类名称",
        "category.name.hint": "为你的收藏建立一个整理的位置。",
        "category.empty": "目前还没有分类",
        "category.items.empty": "这个分类目前没有收藏",
        "common.delete": "删除",
        "item.delete.title": "要删除这个收藏吗？",
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
        return String(
            localized: String.LocalizationValue(key),
            bundle: .module,
            locale: Locale(identifier: localeIdentifier)
        )
    }

    public static func sharedLanguageIdentifier() -> String {
        let preference = UserDefaults(suiteName: SharedLibraryStore.appGroupIdentifier)?
            .string(forKey: languagePreferenceKey) ?? "system"
        switch preference {
        case "en", "zh-Hant", "zh-Hans":
            return preference
        default:
            let localeIdentifier = Locale.current.identifier
            if localeIdentifier.contains("zh_Hans") || localeIdentifier.contains("zh-CN") {
                return "zh-Hans"
            }
            if localeIdentifier.contains("zh_Hant") || localeIdentifier.contains("zh-TW") {
                return "zh-Hant"
            }
            return "en"
        }
    }
}
