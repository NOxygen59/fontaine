// The app's state: settings (language, look, preview), the catalog, installing, collections and
// the comparison.

import CoreText
import SwiftUI
import UIKit

enum Appearance: String, CaseIterable, Codable {
    case system, light, dark

    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: L {
        switch self {
        case .system: return .appearanceSystem
        case .light: return .appearanceLight
        case .dark: return .appearanceDark
        }
    }
}

enum Accent: String, CaseIterable, Codable {
    case indigo, pink, orange, teal, purple, green

    var color: Color {
        switch self {
        case .indigo: return .indigo
        case .pink: return .pink
        case .orange: return .orange
        case .teal: return .teal
        case .purple: return .purple
        case .green: return .green
        }
    }
}

struct Settings: Codable, Equatable {
    var lang = Lang.device
    var appearance = Appearance.system
    var accent = Accent.indigo
    /// Empty: the language's own sample.
    var sampleText = ""
    var listPreviewSize: Double = 30
    var gridView = true

    static let key = "fontaine.settings"

    static func load() -> Settings {
        guard let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Settings.self, from: d) else { return Settings() }
        return s
    }

    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) }
    }
}

enum SortOrder: String, CaseIterable {
    case name, styles, fontClass

    var label: L {
        switch self {
        case .name: return .sortName
        case .styles: return .sortStyles
        case .fontClass: return .sortClass
        }
    }
}

/// A short notice at the bottom of the screen.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let symbol: String
    var isError = false
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings = Settings.load() { didSet { if settings != oldValue { settings.save() } } }
    @Published private(set) var families: [FontFamily] = []
    @Published private(set) var loading = true
    @Published var selection: Selection? = .list(.all)
    @Published var selectedFamily: String?
    @Published var search = ""
    @Published var sort = SortOrder.name
    @Published var store: CollectionStore { didSet { store.save(to: Self.storeURL) } }
    @Published var comparing: [String] = []
    @Published var toast: Toast?
    @Published var showSettings = false
    @Published var showComparison = false
    @Published var importing = false
    @Published var confirmUninstall: String?
    @Published private(set) var installed: [InstalledFont] = []

    let installer: FontInstaller

    static var supportFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Fontaine", isDirectory: true)
    }

    static var storeURL: URL { supportFolder.appendingPathComponent("collections.json") }

    var lang: Lang { settings.lang }
    var sample: String { settings.sampleText.isEmpty ? lang.sample : settings.sampleText }

    init() {
        try? FileManager.default.createDirectory(at: Self.supportFolder, withIntermediateDirectories: true)
        // FONTAINE_TEST_SCOPE=process (Simulator tests only: it can't hold the system-install
        // entitlement) installs for this app alone, from where the fonts are kept. System-wide
        // installs come from the app's bundle, where the root helper puts them.
        let scope: CTFontManagerScope = ProcessInfo.processInfo.environment["FONTAINE_TEST_SCOPE"] == "process" ? .process : .persistent
        installer = FontInstaller(folder: Self.supportFolder.appendingPathComponent("Polices", isDirectory: true), scope: scope,
                                  placement: scope == .persistent ? RootHelper.placement : .inPlace)
        store = CollectionStore.load(from: Self.storeURL)
        installed = installer.fonts
        Task {
            await installer.reconcile()
            await reload()
            simulatorScript()
        }
    }

    /// On coming back to the app: fonts may have been removed in Settings › General › Fonts.
    func refresh() {
        guard !loading else { return }
        Task {
            if await installer.reconcile() { await reload() }
        }
    }

    /// A tab the detail view opens on (the test hook sets it).
    @Published var detailTab: String?

    /// For trying the app in the Simulator, from environment variables only (a normal launch has
    /// none): FONTAINE_TEST_LANG (fr/en/ja), FONTAINE_TEST_IMPORT (a file in Documents),
    /// FONTAINE_TEST_LIST (all, installed…), FONTAINE_TEST_FAMILY, FONTAINE_TEST_TAB (glyphs, info),
    /// FONTAINE_TEST_SETTINGS=1, FONTAINE_TEST_LISTVIEW=1.
    private func simulatorScript() {
        let env = ProcessInfo.processInfo.environment
        if let l = env["FONTAINE_TEST_LANG"].flatMap(Lang.init(rawValue:)) { settings.lang = l }
        if env["FONTAINE_TEST_LISTVIEW"] == "1" { settings.gridView = false }
        if let list = env["FONTAINE_TEST_LIST"].flatMap(LibraryList.init(rawValue:)) { selection = .list(list) }
        if let w = env["FONTAINE_TEST_WRITING"].flatMap(WritingSystem.init(rawValue:)) { selection = .writing(w) }
        if let name = env["FONTAINE_TEST_FAMILY"] { selectedFamily = name }
        detailTab = env["FONTAINE_TEST_TAB"]
        if env["FONTAINE_TEST_SETTINGS"] == "1" { showSettings = true }
        if let file = env["FONTAINE_TEST_IMPORT"] {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            importFonts([docs.appendingPathComponent(file)])
        }
    }

    func reload() async {
        let names = installer.allPostScriptNames
        let loaded = await Task.detached(priority: .userInitiated) { Catalog.load(installed: names) }.value
        families = loaded
        installed = installer.fonts
        loading = false
    }

    // MARK: Lists

    var installedAt: [String: Date] {
        var out: [String: Date] = [:]
        for f in installed { for ps in f.postScriptNames { out[ps] = f.installedAt } }
        return out
    }

    /// The families the sidebar's choice shows, searched and sorted.
    var visibleFamilies: [FontFamily] {
        var list = store.families(families, for: selection ?? .list(.all), installedAt: installedAt)
        let words = search.lowercased().split(separator: " ")
        if !words.isEmpty {
            list = list.filter { f in
                let hay = (f.name + " " + f.faces.map(\.style).joined(separator: " ")).lowercased()
                return words.allSatisfy { hay.contains($0) }
            }
        }
        switch sort {
        case .name: break
        case .styles: list.sort { $0.faces.count > $1.faces.count }
        case .fontClass: list.sort { ($0.fontClass.rawValue, $0.name) < ($1.fontClass.rawValue, $1.name) }
        }
        return list
    }

    func count(_ s: Selection) -> Int {
        store.families(families, for: s, installedAt: installedAt).count
    }

    func family(_ name: String?) -> FontFamily? {
        guard let name else { return nil }
        return families.first { $0.name == name }
    }

    /// This app's installed font behind a family, if any.
    func installedFont(for family: FontFamily) -> InstalledFont? {
        let names = Set(family.faces.map(\.postScriptName))
        return installed.first { !names.isDisjoint(with: $0.postScriptNames) }
    }

    /// Families of fonts this app installed but turned off (not in the catalog then).
    var disabledInstalled: [InstalledFont] { installed.filter { !$0.enabled } }

    // MARK: Installing

    func importFonts(_ urls: [URL]) {
        Task {
            let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
            let report = await installer.install(urls)
            scoped.forEach { $0.stopAccessingSecurityScopedResource() }
            removeInboxCopies(urls)
            if let p = report.problems.first {
                show(Toast(text: p.message(lang), symbol: "exclamationmark.triangle.fill", isError: true))
            } else if !report.installed.isEmpty {
                show(Toast(text: counted(report.installed.count, one: .oneImported, many: .importedCount, lang), symbol: "checkmark.seal.fill"))
            }
            guard !report.installed.isEmpty else { return }
            await reload()
            selection = .list(.installed)
            selectedFamily = report.installed.first?.families.first
        }
    }

    /// Files opened in Fontaine from another app arrive as copies in Documents/Inbox: once
    /// imported (kept in the installer's folder), they're only clutter.
    private func removeInboxCopies(_ urls: [URL]) {
        let inbox = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Inbox", isDirectory: true).resolvingSymlinksInPath().path + "/"
        for url in urls where url.resolvingSymlinksInPath().path.hasPrefix(inbox) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func setEnabled(_ font: InstalledFont, _ on: Bool) {
        Task {
            let errors = on ? await installer.activate([font.id]) : await installer.deactivate([font.id])
            if let e = errors.first { show(Toast(text: e.message(lang), symbol: "exclamationmark.triangle.fill", isError: true)) }
            await reload()
        }
    }

    func uninstall(_ font: InstalledFont) {
        Task {
            let errors = await installer.remove([font.id])
            if let e = errors.first { show(Toast(text: e.message(lang), symbol: "exclamationmark.triangle.fill", isError: true)) }
            if let name = selectedFamily, font.families.contains(name) { selectedFamily = nil }
            await reload()
        }
    }

    // MARK: Collections & comparison

    func toggleFavorite(_ family: String) { store.toggleFavorite(family) }
    func isFavorite(_ family: String) -> Bool { store.favorites.contains(family) }

    func createCollection(_ name: String, symbol: String, with family: String? = nil) {
        var c = FontCollection(name: name.isEmpty ? L.newCollection(lang) : name, symbol: symbol)
        if let family { c.families = [family] }
        store.collections.append(c)
    }

    func toggleComparison(_ family: String) {
        if let i = comparing.firstIndex(of: family) { comparing.remove(at: i) } else { comparing.append(family) }
    }

    func copyName(_ family: FontFamily) {
        UIPasteboard.general.string = family.name
        show(Toast(text: family.name, symbol: "doc.on.doc.fill"))
    }

    func show(_ t: Toast) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = t }
        let id = t.id
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if toast?.id == id { withAnimation { toast = nil } }
        }
    }
}

/// The look of each class, for headers and cards.
extension FontClass {
    var gradient: [Color] {
        switch self {
        case .serif: return [Color(red: 0.95, green: 0.55, blue: 0.3), Color(red: 0.85, green: 0.25, blue: 0.35)]
        case .sansSerif: return [Color(red: 0.2, green: 0.55, blue: 0.95), Color(red: 0.25, green: 0.8, blue: 0.85)]
        case .monospaced: return [Color(red: 0.15, green: 0.7, blue: 0.5), Color(red: 0.1, green: 0.45, blue: 0.4)]
        case .script: return [Color(red: 0.95, green: 0.4, blue: 0.65), Color(red: 0.6, green: 0.35, blue: 0.9)]
        case .display: return [Color(red: 0.45, green: 0.35, blue: 0.95), Color(red: 0.75, green: 0.3, blue: 0.85)]
        case .symbol: return [Color(red: 0.45, green: 0.5, blue: 0.6), Color(red: 0.25, green: 0.3, blue: 0.4)]
        }
    }

    var symbolName: String {
        switch self {
        case .serif: return "textformat"
        case .sansSerif: return "textformat.alt"
        case .monospaced: return "chevron.left.forwardslash.chevron.right"
        case .script: return "signature"
        case .display: return "sparkles"
        case .symbol: return "star.square.on.square"
        }
    }
}

extension Font {
    /// A face by its PostScript name.
    static func face(_ postScriptName: String, size: CGFloat) -> Font {
        Font(CTFontCreateWithName(postScriptName as CFString, size, nil) as UIFont)
    }
}
