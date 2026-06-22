import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    static let storageKey = "app_language"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            L10n.followSystem
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        }
    }

    static var current: AppLanguage {
        if let storedValue = UserDefaults.standard.string(forKey: storageKey),
           let storedLanguage = AppLanguage(rawValue: storedValue),
           storedLanguage != .system {
            return storedLanguage
        }

        return resolvedSystemLanguage
    }

    private static var resolvedSystemLanguage: AppLanguage {
        let candidates = Bundle.main.preferredLocalizations
            + Locale.preferredLanguages
            + [Locale.autoupdatingCurrent.identifier]

        for candidate in candidates {
            let normalized = candidate.lowercased()

            if normalized.contains("zh-hans")
                || normalized.contains("zh_cn")
                || normalized.contains("zh-cn")
                || normalized.contains("zh_sg")
                || normalized.contains("zh-sg")
                || normalized == "zh" {
                return .simplifiedChinese
            }

            if normalized.hasPrefix("en") {
                return .english
            }
        }

        return .english
    }
}

enum L10n {
    private static func text(_ english: String, _ simplifiedChinese: String) -> String {
        switch AppLanguage.current {
        case .system:
            return english
        case .english:
            return english
        case .simplifiedChinese:
            return simplifiedChinese
        }
    }

    static var save: String { text("Save", "保存") }
    static var aboutProject: String { text("About This Project", "关于本项目") }
    static var settings: String { text("Settings", "设置") }
    static func hideApp(_ appName: String) -> String {
        text("Hide \(appName)", "隐藏\(appName)")
    }
    static var hideOthers: String { text("Hide Others", "隐藏其他") }
    static var showAll: String { text("Show All", "显示全部") }
    static func quitApp(_ appName: String) -> String {
        text("Quit \(appName)", "退出\(appName)")
    }
    static var editor: String { text("Editor", "编辑") }
    static var find: String { text("Find", "查找") }
    static var appearance: String { text("Appearance", "外观") }
    static var language: String { text("Language", "语言") }
    static var followSystem: String { text("Follow System", "跟随系统") }
    static var help: String { text("Help", "帮助") }
    static var developerGitHub: String { text("Developer @仙银", "开发者 @仙银") }
    static var projectGitHub: String { text("Project GitHub", "项目 GitHub") }
    static var matchSystem: String { text("Match System", "跟随系统") }
    static var light: String { text("Light", "浅色") }
    static var dark: String { text("Dark", "深色") }
    static var file: String { text("File", "文件") }
    static var revealInFinder: String { text("Reveal .zshrc in Finder", "在 Finder 中显示 .zshrc") }
    static var view: String { text("View", "显示") }
    static var zoomIn: String { text("Zoom In", "放大") }
    static var zoomOut: String { text("Zoom Out", "缩小") }
    static var actualSize: String { text("Actual Size", "实际大小") }
    static var undo: String { text("Undo", "撤销") }
    static var redo: String { text("Redo", "重做") }
    static var cut: String { text("Cut", "剪切") }
    static var copy: String { text("Copy", "复制") }
    static var paste: String { text("Paste", "粘贴") }
    static var delete: String { text("Delete", "删除") }
    static var selectAll: String { text("Select All", "全选") }

    static var cancel: String { text("Cancel", "取消") }
    static var somethingWentWrong: String { text("Something went wrong", "发生错误") }
    static var ok: String { text("OK", "确定") }

    static var unsavedChanges: String { text("Unsaved changes", "未保存") }
    static var saved: String { text("Saved", "已保存") }
    static func modifiedAt(_ time: String) -> String {
        text("Modified at \(time)", "修改于 \(time)")
    }
    static func lineColumn(_ line: Int, _ column: Int) -> String {
        text("Line \(line), Col \(column)", "第 \(line) 行，第 \(column) 列")
    }

    static var sourceFailed: String { text("source failed", "source 失败") }
    static var sourceSucceeded: String { text("source ok", "source 成功") }
    static var noMatches: String { text("No matches", "无匹配") }
    static func matchesCount(current: Int, total: Int) -> String {
        text("\(current)/\(total) matches", "\(current)/\(total) 个匹配")
    }

    static var noResults: String { text("No results", "无结果") }
    static var searchPlaceholder: String { text("Search in .zshrc", "搜索 .zshrc") }
    static var matchCase: String { text("Match case", "区分大小写") }

    static var syntaxOk: String { text("syntax ok", "语法正常") }
    static func syntaxErrorAt(_ line: Int) -> String {
        text("syntax error @ \(line)", "语法错误 @ \(line)")
    }
    static var syntaxError: String { text("syntax error", "语法错误") }
    static var zshReportedSyntaxError: String {
        text("zsh reported a syntax error.", "zsh 报告了语法错误。")
    }

    static func unableToRead(_ fileName: String, _ message: String) -> String {
        text("Unable to read \(fileName): \(message)", "无法读取 \(fileName)：\(message)")
    }

    static func unableToSave(_ fileName: String, _ message: String) -> String {
        text("Unable to save \(fileName): \(message)", "无法保存 \(fileName)：\(message)")
    }

    static func fixSyntaxErrorsBeforeSaving(_ message: String) -> String {
        text(
            "Fix syntax errors before saving: \(message)",
            "请先修复语法错误再保存：\(message)"
        )
    }

    static func savedButSourceFailed(_ message: String) -> String {
        text(
            "Saved the file, but `source` failed: \(message)",
            "文件已保存，但 `source` 执行失败：\(message)"
        )
    }

    static var unknownZshError: String { text("Unknown zsh error.", "未知 zsh 错误。") }
}
