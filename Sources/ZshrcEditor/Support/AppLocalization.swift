import Foundation

enum AppLanguage {
    case english
    case simplifiedChinese

    static var current: AppLanguage {
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
        case .english:
            return english
        case .simplifiedChinese:
            return simplifiedChinese
        }
    }

    static var save: String { text("Save", "保存") }
    static var editor: String { text("Editor", "编辑") }
    static var find: String { text("Find", "查找") }
    static var appearance: String { text("Appearance", "外观") }
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

    static var discardEditsTitle: String {
        text("Discard local edits and reload from disk?", "放弃本地修改并从磁盘重新加载？")
    }

    static var reload: String { text("Reload", "重新加载") }
    static var cancel: String { text("Cancel", "取消") }
    static var reloadMessage: String {
        text(
            "Your unsaved edits will be replaced by the current ~/.zshrc file on disk.",
            "你当前未保存的修改将被磁盘上的 ~/.zshrc 内容替换。"
        )
    }

    static var somethingWentWrong: String { text("Something went wrong", "发生错误") }
    static var ok: String { text("OK", "确定") }

    static var unsavedChanges: String { text("Unsaved changes", "未保存") }
    static var saved: String { text("Saved", "已保存") }
    static func lineColumn(_ line: Int, _ column: Int) -> String {
        text("Line \(line), Col \(column)", "第 \(line) 行，第 \(column) 列")
    }

    static var sourceFailed: String { text("source failed", "source 失败") }
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
    static var skippedAutoReload: String {
        text(
            "Skipped auto reload because you have unsaved edits.",
            "由于存在未保存修改，已跳过自动重新加载。"
        )
    }
    static var reloadedFromDisk: String {
        text("Reloaded ~/.zshrc from disk.", "已从磁盘重新加载 ~/.zshrc。")
    }

    static var quickJump: String { text("Quick Jump", "快速跳转") }
    static var quickJumpDescription: String {
        text(
            "Jump straight to exports, plain assignments, and aliases from your .zshrc.",
            "快速跳转到 .zshrc 中的 export、普通赋值和 alias。"
        )
    }
    static var filterSymbols: String { text("Filter symbols", "筛选符号") }
    static func variablesCount(_ count: Int) -> String {
        text("\(count) variables", "\(count) 个变量")
    }
    static func aliasesCount(_ count: Int) -> String {
        text("\(count) aliases", "\(count) 个别名")
    }
    static var noShellSymbolsFound: String { text("No shell symbols found", "未找到 Shell 符号") }
    static var noShellSymbolsDescription: String {
        text(
            "Add lines like `export API_KEY=...` or `alias gs='git status'` to populate this list.",
            "添加如 `export API_KEY=...` 或 `alias gs='git status'` 这样的行来填充列表。"
        )
    }
    static var environment: String { text("Environment", "环境变量") }
    static var aliases: String { text("Aliases", "别名") }
    static func lineBadge(_ line: Int) -> String {
        text("L\(line)", "第\(line)行")
    }

    static var badgeExport: String { text("export", "导出") }
    static var badgeVariable: String { text("var", "变量") }
    static var badgeAlias: String { text("alias", "别名") }
}
