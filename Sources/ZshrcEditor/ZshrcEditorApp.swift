import AppKit
import Combine

@MainActor
final class EditorCommandCoordinator {
    var onSave: @MainActor @Sendable () async -> Void = { }
    var onFind: @MainActor () -> Void = { }
    var onRevealInFinder: @MainActor () -> Void = { }

    func save() {
        let action = onSave
        Task { @MainActor in
            await action()
        }
    }

    func find() {
        onFind()
    }

    func revealInFinder() {
        onRevealInFinder()
    }
}

@MainActor
final class AppMenuActionHandler: NSObject {
    static let shared = AppMenuActionHandler()

    var onSave: @MainActor () -> Void = { }
    var onRevealInFinder: @MainActor () -> Void = { }
    var onFind: @MainActor () -> Void = { }
    var onThemeChange: @MainActor (String) -> Void = { _ in }
    var onLanguageChange: @MainActor (String) -> Void = { _ in }

    @objc func save(_ sender: Any?) {
        onSave()
    }

    @objc func revealInFinder(_ sender: Any?) {
        onRevealInFinder()
    }

    @objc func find(_ sender: Any?) {
        onFind()
    }

    @objc func zoomIn(_ sender: Any?) {
        AppEditorSettings.shared.increaseFontSize()
    }

    @objc func zoomOut(_ sender: Any?) {
        AppEditorSettings.shared.decreaseFontSize()
    }

    @objc func actualSize(_ sender: Any?) {
        AppEditorSettings.shared.resetFontSize()
    }

    @objc func openDeveloperGitHub(_ sender: Any?) {
        AppOpenActions.openInBrowser(ZshrcEditorApp.developerGitHubURL)
    }

    @objc func openProjectGitHub(_ sender: Any?) {
        AppOpenActions.openInBrowser(ZshrcEditorApp.projectGitHubURL)
    }

    @objc func selectThemeSystem(_ sender: Any?) {
        selectTheme(.system)
    }

    @objc func selectThemeLight(_ sender: Any?) {
        selectTheme(.light)
    }

    @objc func selectThemeDark(_ sender: Any?) {
        selectTheme(.dark)
    }

    @objc func selectLanguageSystem(_ sender: Any?) {
        selectLanguage(.system)
    }

    @objc func selectLanguageEnglish(_ sender: Any?) {
        selectLanguage(.english)
    }

    @objc func selectLanguageSimplifiedChinese(_ sender: Any?) {
        selectLanguage(.simplifiedChinese)
    }

    private func selectTheme(_ theme: AppThemeMode) {
        UserDefaults.standard.set(theme.rawValue, forKey: AppThemeMode.storageKey)
        onThemeChange(theme.rawValue)
        MenuBarController.installMenu()
    }

    private func selectLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        onLanguageChange(language.rawValue)
        MenuBarController.installMenu()
    }
}

@MainActor
final class SettingsMenuDelegate: NSObject, NSMenuDelegate {
    static let shared = SettingsMenuDelegate()

    func menuWillOpen(_ menu: NSMenu) {
        MenuBarController.stripIcons(in: menu)
    }
}

@MainActor
enum MenuBarController {
    static func scheduleInstallation() {
        for delay in [0.0, 0.05, 0.15, 0.35, 0.75, 1.25] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                installMenu()
            }
        }
    }

    static func installMenu() {
        let mainMenu = NSMenu()
        mainMenu.showsStateColumn = false
        mainMenu.addItem(appMenuItem())
        mainMenu.addItem(settingsMenuItem())
        NSApp.mainMenu = mainMenu
    }

    private static func appMenuItem() -> NSMenuItem {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "zshrc"
        let submenu = NSMenu(title: appName)
        submenu.showsStateColumn = false

        submenu.addItem(menuItem(
            title: L10n.aboutProject,
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: "",
            target: NSApp
        ))
        submenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesMenu.showsStateColumn = false
        servicesItem.submenu = servicesMenu
        submenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        submenu.addItem(.separator())
        submenu.addItem(menuItem(
            title: L10n.hideApp(appName),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h",
            target: NSApp
        ))

        let hideOthersItem = menuItem(
            title: L10n.hideOthers,
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h",
            target: NSApp
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        submenu.addItem(hideOthersItem)

        submenu.addItem(menuItem(
            title: L10n.showAll,
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: "",
            target: NSApp
        ))
        submenu.addItem(.separator())
        submenu.addItem(menuItem(
            title: L10n.quitApp(appName),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q",
            target: NSApp
        ))

        let item = NSMenuItem()
        item.submenu = submenu
        return item
    }

    private static func settingsMenuItem() -> NSMenuItem {
        let submenu = NSMenu(title: L10n.settings)
        submenu.showsStateColumn = false
        submenu.delegate = SettingsMenuDelegate.shared
        let handler = AppMenuActionHandler.shared

        submenu.addItem(menuItem(
            title: L10n.save,
            action: #selector(AppMenuActionHandler.save(_:)),
            keyEquivalent: "s",
            target: handler
        ))
        submenu.addItem(menuItem(
            title: L10n.revealInFinder,
            action: #selector(AppMenuActionHandler.revealInFinder(_:)),
            keyEquivalent: "o",
            target: handler
        ))
        submenu.addItem(.separator())
        submenu.addItem(menuItem(
            title: L10n.find,
            action: #selector(AppMenuActionHandler.find(_:)),
            keyEquivalent: "f",
            target: handler
        ))
        submenu.addItem(.separator())
        submenu.addItem(menuItem(
            title: L10n.zoomIn,
            action: #selector(AppMenuActionHandler.zoomIn(_:)),
            keyEquivalent: "=",
            target: handler
        ))
        submenu.addItem(menuItem(
            title: L10n.zoomOut,
            action: #selector(AppMenuActionHandler.zoomOut(_:)),
            keyEquivalent: "-",
            target: handler
        ))
        submenu.addItem(menuItem(
            title: L10n.actualSize,
            action: #selector(AppMenuActionHandler.actualSize(_:)),
            keyEquivalent: "0",
            target: handler
        ))
        submenu.addItem(.separator())
        submenu.addItem(themeMenuItem())
        submenu.addItem(languageMenuItem())
        submenu.addItem(.separator())
        submenu.addItem(menuItem(
            title: L10n.developerGitHub,
            action: #selector(AppMenuActionHandler.openDeveloperGitHub(_:)),
            keyEquivalent: "",
            target: handler
        ))
        submenu.addItem(menuItem(
            title: L10n.projectGitHub,
            action: #selector(AppMenuActionHandler.openProjectGitHub(_:)),
            keyEquivalent: "",
            target: handler
        ))
        stripIcons(in: submenu)

        let item = NSMenuItem(title: L10n.settings, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private static func themeMenuItem() -> NSMenuItem {
        let selected = AppThemeMode(
            rawValue: UserDefaults.standard.string(forKey: AppThemeMode.storageKey) ?? AppThemeMode.system.rawValue
        ) ?? .system
        let submenu = NSMenu(title: L10n.appearance)
        submenu.showsStateColumn = false
        let handler = AppMenuActionHandler.shared

        submenu.addItem(selectableMenuItem(
            title: AppThemeMode.system.title,
            action: #selector(AppMenuActionHandler.selectThemeSystem(_:)),
            isOn: selected == .system,
            target: handler
        ))
        submenu.addItem(selectableMenuItem(
            title: AppThemeMode.light.title,
            action: #selector(AppMenuActionHandler.selectThemeLight(_:)),
            isOn: selected == .light,
            target: handler
        ))
        submenu.addItem(selectableMenuItem(
            title: AppThemeMode.dark.title,
            action: #selector(AppMenuActionHandler.selectThemeDark(_:)),
            isOn: selected == .dark,
            target: handler
        ))

        let item = NSMenuItem(title: L10n.appearance, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private static func languageMenuItem() -> NSMenuItem {
        let selected = AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.system.rawValue
        ) ?? .system
        let submenu = NSMenu(title: L10n.language)
        submenu.showsStateColumn = false
        let handler = AppMenuActionHandler.shared

        submenu.addItem(selectableMenuItem(
            title: AppLanguage.system.title,
            action: #selector(AppMenuActionHandler.selectLanguageSystem(_:)),
            isOn: selected == .system,
            target: handler
        ))
        submenu.addItem(selectableMenuItem(
            title: AppLanguage.english.title,
            action: #selector(AppMenuActionHandler.selectLanguageEnglish(_:)),
            isOn: selected == .english,
            target: handler
        ))
        submenu.addItem(selectableMenuItem(
            title: AppLanguage.simplifiedChinese.title,
            action: #selector(AppMenuActionHandler.selectLanguageSimplifiedChinese(_:)),
            isOn: selected == .simplifiedChinese,
            target: handler
        ))

        let item = NSMenuItem(title: L10n.language, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private static func menuItem(title: String, action: Selector?, keyEquivalent: String, target: AnyObject?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        return item
    }

    fileprivate static func stripIcons(in menu: NSMenu) {
        for item in menu.items {
            item.image = nil
            item.onStateImage = NSImage(size: .zero)
            item.offStateImage = NSImage(size: .zero)
            item.mixedStateImage = NSImage(size: .zero)
            clearActionImageIfNeeded(for: item)
            if let submenu = item.submenu {
                stripIcons(in: submenu)
            }
        }
    }

    private static func clearActionImageIfNeeded(for item: NSMenuItem) {
        let hasActionImageSelector = NSSelectorFromString("_setHasActionImage:")
        if item.responds(to: hasActionImageSelector),
           let method = item.method(for: hasActionImageSelector) {
            typealias BoolSetter = @convention(c) (AnyObject, Selector, Bool) -> Void
            let fn = unsafeBitCast(method, to: BoolSetter.self)
            fn(item, hasActionImageSelector, false)
        }

        let actionImageSelector = NSSelectorFromString("_setActionImage:")
        if item.responds(to: actionImageSelector),
           let method = item.method(for: actionImageSelector) {
            typealias ObjectSetter = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
            let fn = unsafeBitCast(method, to: ObjectSetter.self)
            fn(item, actionImageSelector, nil)
        }
    }

    private static func selectableMenuItem(
        title: String,
        action: Selector,
        isOn: Bool,
        target: AnyObject
    ) -> NSMenuItem {
        let resolvedTitle = isOn ? "\(title)  " : title
        return menuItem(title: resolvedTitle, action: action, keyEquivalent: "", target: target)
    }
}

@MainActor
final class ZshrcEditorApp: NSObject, NSApplicationDelegate {
    static let projectGitHubURL = URL(string: "https://github.com/iHongRen/zshrc")!
    static let developerGitHubURL = URL(string: "https://github.com/iHongRen")!

    private var window: NSWindow?
    private var windowController: NSWindowController?
    private let viewModel = EditorViewModel()
    private let editorSettings = AppEditorSettings.shared
    private let commandCoordinator = EditorCommandCoordinator()

    func applicationWillFinishLaunching(_ notification: Notification) {
        MenuBarController.installMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenuActions()
        createWindow()

        Task { @MainActor in
            await viewModel.load()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        MenuBarController.installMenu()
        Task { @MainActor [weak self] in
            await self?.viewModel.syncWithDiskIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func configureMenuActions() {
        AppMenuActionHandler.shared.onSave = { [weak self] in
            self?.commandCoordinator.save()
        }
        AppMenuActionHandler.shared.onRevealInFinder = { [weak self] in
            self?.commandCoordinator.revealInFinder()
        }
        AppMenuActionHandler.shared.onFind = { [weak self] in
            self?.commandCoordinator.find()
        }
        AppMenuActionHandler.shared.onThemeChange = { _ in }
        AppMenuActionHandler.shared.onLanguageChange = { _ in }
    }

    private func createWindow() {
        let rootViewController = MainViewController(
            viewModel: viewModel,
            editorSettings: editorSettings,
            commandCoordinator: commandCoordinator
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: MainViewController.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = viewModel.targetURL.lastPathComponent
        window.isReleasedWhenClosed = false
        window.contentViewController = rootViewController
        window.setContentSize(MainViewController.defaultContentSize)
        window.minSize = NSSize(
            width: MainViewController.minimumContentSize.width,
            height: MainViewController.minimumContentSize.height
        )
        window.contentMinSize = MainViewController.minimumContentSize
        window.center()
        self.window = window
        let windowController = NSWindowController(window: window)
        self.windowController = windowController

        DispatchQueue.main.async {
            NSApp.activate()
            windowController.showWindow(nil)
            window.makeKey()
            window.makeMain()
            window.orderFrontRegardless()
        }
    }
}

@main
enum AppLauncher {
    @MainActor
    private static let delegate = ZshrcEditorApp()

    @MainActor
    static func main() {
        let app = NSApplication.shared

        NSWindow.allowsAutomaticWindowTabbing = false
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}
