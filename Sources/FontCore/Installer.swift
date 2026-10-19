// Installing fonts for the whole system (iPadOS's own mechanism: CTFontManager with the persistent
// scope, the system asks the user to confirm), turning them off and on, removing them.
//
// iPadOS installs only fonts inside the installing app's own bundle (or its on-demand resources):
// each font is kept in the installer's folder, and while it's on, a copy of it sits in the bundle
// (see ``FontPlacement``). The system's word is final: a font taken off in Settings › General ›
// Fonts is marked off here, never installed again behind the user's back.

import CoreText
import Foundation

public struct InstalledFont: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    /// The file, in the installer's folder.
    public let fileName: String
    public let postScriptNames: [String]
    public let families: [String]
    public var enabled: Bool
    public let installedAt: Date
    public let fileSize: Int64
}

public enum ImportOutcome: Equatable, Sendable {
    case added(InstalledFont)
    /// Already installed (same PostScript names).
    case duplicate(of: InstalledFont)
    /// A font of the same PostScript name is already on the device (iPadOS's, another app's): the
    /// family's name.
    case taken(String)
    /// Not a font CoreText can read.
    case invalid(String)
}

/// Why the system refused (the app words it in the user's language).
public enum InstallError: Error, Equatable, Sendable {
    case alreadyInstalled, notInstalled, cancelled, duplicateName, invalidFile, missingEntitlement, refused
    /// The file isn't where the system takes fonts from (on iPadOS, the app's bundle).
    case invalidLocation
    /// The system's limit on installed fonts is reached.
    case limitReached
    case inUse
    /// The font's copy couldn't be put in the app's bundle (the reason).
    case placement(String)
    case other(String)

    init(_ e: NSError) {
        switch CTFontManagerError(rawValue: CFIndex(e.code)) {
        case .alreadyRegistered: self = .alreadyInstalled
        case .notRegistered: self = .notInstalled
        case .cancelledByUser: self = .cancelled
        case .duplicatedName: self = .duplicateName
        case .invalidFontData, .unrecognizedFormat: self = .invalidFile
        case .missingEntitlement: self = .missingEntitlement
        case .registrationFailed: self = .refused
        case .invalidFilePath: self = .invalidLocation
        case .exceededResourceLimit: self = .limitReached
        case .inUse: self = .inUse
        default: self = .other(e.localizedDescription)
        }
    }
}

/// What went wrong with one of the files given to ``FontInstaller/install(_:)``.
public enum InstallProblem: Equatable, Sendable {
    /// Already installed with this app: the family's name.
    case duplicate(String)
    /// See ``ImportOutcome/taken(_:)``.
    case taken(String)
    /// Not a font file: the file's name.
    case invalid(String)
    /// The system didn't install it.
    case refused(InstallError)
}

public struct InstallReport: Equatable, Sendable {
    public var installed: [InstalledFont] = []
    public var problems: [InstallProblem] = []
}

/// Where fonts are registered from. iPadOS takes system-wide installs only from the installing
/// app's bundle, which the app can't write to itself: the app gives `put` and `delete`, which can
/// (its root helper). For the process scope (the Simulator, the tests) fonts are registered where
/// they're kept: ``inPlace``.
public struct FontPlacement: Sendable {
    /// The folder fonts are registered from; nil: the installer's own.
    public let folder: URL?
    /// Puts a copy of a kept font file in `folder`, under the same name (replacing it).
    public let put: @Sendable (URL) throws -> Void
    /// Deletes a file of `folder`, by name.
    public let delete: @Sendable (String) throws -> Void

    public init(folder: URL, put: @escaping @Sendable (URL) throws -> Void, delete: @escaping @Sendable (String) throws -> Void) {
        self.folder = folder
        self.put = put
        self.delete = delete
    }

    private init() {
        folder = nil
        put = { _ in }
        delete = { _ in }
    }

    public static let inPlace = FontPlacement()
}

public final class FontInstaller: @unchecked Sendable {
    public static let fontExtensions: Set<String> = ["ttf", "otf", "ttc", "otc"]

    public let folder: URL
    public let scope: CTFontManagerScope
    public let placement: FontPlacement
    public private(set) var fonts: [InstalledFont] = []
    private let lock = NSLock()

    private var stateURL: URL { folder.appendingPathComponent("polices.json") }

    /// `scope` is `.persistent` in the app (for every app on the device), `.process` in tests.
    public init(folder: URL, scope: CTFontManagerScope = .persistent, placement: FontPlacement = .inPlace) {
        self.folder = folder
        self.scope = scope
        self.placement = placement
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: stateURL), let saved = try? JSONDecoder().decode([InstalledFont].self, from: data) {
            fonts = saved.filter { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0.fileName).path) }
        }
    }

    /// The kept file.
    public func url(of font: InstalledFont) -> URL { folder.appendingPathComponent(font.fileName) }

    /// The file the system takes the font from.
    public func registeredURL(of font: InstalledFont) -> URL {
        (placement.folder ?? folder).appendingPathComponent(font.fileName)
    }

    /// PostScript names of the installed fonts that are on.
    public var enabledPostScriptNames: Set<String> {
        Set(fonts.filter(\.enabled).flatMap(\.postScriptNames))
    }

    public var allPostScriptNames: Set<String> { Set(fonts.flatMap(\.postScriptNames)) }

    /// What a file holds, without installing it: (PostScript name, family) of each face.
    public static func inspect(_ url: URL) -> [(String, String)] {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return [] }
        return descriptors.compactMap { d in
            guard let ps = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String else { return nil }
            return (ps, (CTFontDescriptorCopyAttribute(d, kCTFontFamilyNameAttribute) as? String) ?? ps)
        }
    }

    /// Imports font files and turns them on, in one go. A file the system doesn't take (the user
    /// cancelled, it refused…) leaves nothing behind.
    public func install(_ sources: [URL]) async -> InstallReport {
        var report = InstallReport()
        var fresh: [UUID] = [], again: [UUID] = []
        for source in sources {
            switch importFile(source) {
            case let .added(f): fresh.append(f.id)
            // Already here but off: importing it again turns it back on.
            case let .duplicate(of: f) where !f.enabled: again.append(f.id)
            case let .duplicate(of: f): report.problems.append(.duplicate(f.families.first ?? f.fileName))
            case let .taken(name): report.problems.append(.taken(name))
            case let .invalid(name): report.problems.append(.invalid(name))
            }
        }
        let ids = fresh + again
        guard !ids.isEmpty else { return report }
        report.problems += await activate(ids).map(InstallProblem.refused)
        discard(fonts.filter { fresh.contains($0.id) && !$0.enabled }.map(\.id))
        report.installed = fonts.filter { ids.contains($0.id) && $0.enabled }
        return report
    }

    /// Copies a font file into the installer's folder (not yet on: see ``activate(_:)``).
    public func importFile(_ source: URL) -> ImportOutcome {
        let ext = source.pathExtension.lowercased()
        let faces = Self.inspect(source)
        guard Self.fontExtensions.contains(ext), !faces.isEmpty else { return .invalid(source.lastPathComponent) }
        let names = faces.map(\.0)
        if let existing = fonts.first(where: { !Set($0.postScriptNames).isDisjoint(with: names) }) {
            return .duplicate(of: existing)
        }
        // The system would refuse it, or the two would clash.
        if let clash = faces.first(where: { Self.exists($0.0) }) {
            return .taken(clash.1)
        }
        var name = source.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        while name.hasPrefix(".") { name.removeFirst() }
        if name.isEmpty { name = "police" }
        var target = folder.appendingPathComponent(name).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: target.path) {
            target = folder.appendingPathComponent("\(name) \(n)").appendingPathExtension(ext)
            n += 1
        }
        do {
            try FileManager.default.copyItem(at: source, to: target)
        } catch {
            return .invalid(source.lastPathComponent)
        }
        let size = (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        let font = InstalledFont(id: UUID(), fileName: target.lastPathComponent, postScriptNames: names,
                                 families: Array(Set(faces.map(\.1))).sorted(), enabled: false, installedAt: Date(), fileSize: size)
        lock.withLock { fonts.append(font) }
        save()
        return .added(font)
    }

    /// Places the fonts and registers them with the system (iPadOS asks the user to confirm a
    /// system-wide install).
    public func activate(_ ids: [UUID]) async -> [InstallError] {
        let targets = fonts.filter { ids.contains($0.id) && !$0.enabled }
        guard !targets.isEmpty else { return [] }
        var errors: [InstallError] = []
        var placed: [InstalledFont] = []
        for f in targets {
            do {
                try place(f)
                placed.append(f)
            } catch {
                errors.append(.placement(error.localizedDescription))
            }
        }
        guard !placed.isEmpty else { return errors }
        // Already registered is as good as registered.
        let failures = await register(placed.map(registeredURL(of:)), on: true).filter { $0.error != .alreadyInstalled }
        let registered = registeredNames()
        var on: [UUID] = []
        for f in placed {
            if isRegistered(f, registered) || !blamed(f, failures) { on.append(f.id) } else { unplace(f) }
        }
        setEnabled(on, true)
        return errors + failures.map(\.error)
    }

    /// Takes the fonts off the system (the kept files stay, to turn them on again).
    public func deactivate(_ ids: [UUID]) async -> [InstallError] {
        let targets = fonts.filter { ids.contains($0.id) && $0.enabled }
        guard !targets.isEmpty else { return [] }
        // Already gone is as good as gone.
        let failures = await register(targets.map(registeredURL(of:)), on: false).filter { $0.error != .notInstalled }
        let registered = registeredNames()
        let off = targets.filter { !isRegistered($0, registered) || !blamed($0, failures) }
        off.forEach(unplace)
        setEnabled(off.map(\.id), false)
        return failures.map(\.error)
    }

    /// Takes the fonts off the system and deletes their files. A font the system keeps stays here
    /// too: deleting its file would leave the system pointing at nothing.
    public func remove(_ ids: [UUID]) async -> [InstallError] {
        let errors = await deactivate(ids)
        discard(fonts.filter { ids.contains($0.id) && !$0.enabled }.map(\.id))
        return errors
    }

    /// Brings the records in line with the system, at launch and on coming back to the app: fonts
    /// taken off in Settings › General › Fonts are marked off (their files stay, to turn them on
    /// again), and fonts that are on get their bundle copy back if it's gone (installing a new
    /// build of the app replaces its bundle). Whether a font changed.
    @discardableResult
    public func reconcile() async -> Bool {
        let on = fonts.filter(\.enabled)
        guard !on.isEmpty else { return false }
        if scope == .process {
            // Process registrations end with the process: they're made again (nothing to confirm).
            let registered = registeredNames()
            let lost = on.filter { !isRegistered($0, registered) }
            if !lost.isEmpty { _ = await register(lost.map(registeredURL(of:)), on: true) }
            return false
        }
        return reconcile(known: registeredNames().union(Self.availableNames()))
    }

    /// `known`: the PostScript names the system has. Both of its lists are asked (what this app
    /// registered, what it can use) so that one of them failing can't turn fonts off.
    func reconcile(known: Set<String>) -> Bool {
        var gone: [InstalledFont] = []
        for f in fonts where f.enabled {
            if !isRegistered(f, known) {
                gone.append(f)
            } else if !FileManager.default.fileExists(atPath: registeredURL(of: f).path) {
                try? place(f)
            }
        }
        gone.forEach(unplace)
        setEnabled(gone.map(\.id), false)
        return !gone.isEmpty
    }

    // MARK: -

    /// Forgets fonts that aren't registered and deletes their files.
    private func discard(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let gone = lock.withLock { () -> [InstalledFont] in
            let gone = fonts.filter { ids.contains($0.id) }
            fonts.removeAll { ids.contains($0.id) }
            return gone
        }
        for f in gone {
            unplace(f)
            try? FileManager.default.removeItem(at: url(of: f))
        }
        save()
    }

    private func place(_ f: InstalledFont) throws {
        guard placement.folder != nil else { return }
        try placement.put(url(of: f))
    }

    private func unplace(_ f: InstalledFont) {
        guard placement.folder != nil, FileManager.default.fileExists(atPath: registeredURL(of: f).path) else { return }
        try? placement.delete(f.fileName)
    }

    private func isRegistered(_ f: InstalledFont, _ names: Set<String>) -> Bool {
        !Set(f.postScriptNames).isDisjoint(with: names)
    }

    /// Whether a failure names the font's file (or names no file: it may be any of them).
    private func blamed(_ f: InstalledFont, _ failures: [Failure]) -> Bool {
        failures.contains { $0.url == nil || $0.url?.lastPathComponent == f.fileName }
    }

    /// PostScript names this app has registered (on iPadOS; on macOS, which has no per-app list,
    /// every font available).
    private func registeredNames() -> Set<String> {
        #if os(iOS)
        let descriptors = (CTFontManagerCopyRegisteredFontDescriptors(scope, true) as? [CTFontDescriptor]) ?? []
        return Set(descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String })
        #else
        return Self.availableNames()
        #endif
    }

    /// Whether a font of that PostScript name is on the device, listed or not (some of the system's
    /// are only there for its own use).
    static func exists(_ postScriptName: String) -> Bool {
        CTFontCopyPostScriptName(CTFontCreateWithName(postScriptName as CFString, 12, nil)) as String == postScriptName
    }

    /// PostScript names of every font this process can use.
    static func availableNames() -> Set<String> {
        let descriptors = (CTFontCollectionCreateMatchingFontDescriptors(CTFontCollectionCreateFromAvailableFonts(nil)) as? [CTFontDescriptor]) ?? []
        return Set(descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String })
    }

    private func setEnabled(_ ids: [UUID], _ on: Bool) {
        guard !ids.isEmpty else { return }
        lock.withLock {
            for i in fonts.indices where ids.contains(fonts[i].id) { fonts[i].enabled = on }
        }
        save()
    }

    private func save() {
        let snapshot = lock.withLock { fonts }
        if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: stateURL, options: .atomic) }
    }

    private struct Failure {
        var url: URL?
        var error: InstallError
    }

    private func register(_ urls: [URL], on: Bool) async -> [Failure] {
        await withCheckedContinuation { (c: CheckedContinuation<[Failure], Never>) in
            // The handler may run several times (on a system queue, never the main actor) before `done`.
            final class Box: @unchecked Sendable {
                let lock = NSLock()
                var failures: [Failure] = []
                var finished = false
            }
            let box = Box()
            let handler: @Sendable (CFArray, Bool) -> Bool = { errors, done in
                box.lock.withLock {
                    for case let e as NSError in (errors as [AnyObject]) {
                        let urls = (e.userInfo[kCTFontManagerErrorFontURLsKey as String] as? [URL]) ?? []
                        let error = InstallError(e)
                        if urls.isEmpty {
                            box.failures.append(Failure(url: nil, error: error))
                        } else {
                            box.failures.append(contentsOf: urls.map { Failure(url: $0, error: error) })
                        }
                    }
                    if done, !box.finished {
                        box.finished = true
                        c.resume(returning: box.failures)
                    }
                }
                return true
            }
            if on {
                CTFontManagerRegisterFontURLs(urls as CFArray, scope, true, handler)
            } else {
                CTFontManagerUnregisterFontURLs(urls as CFArray, scope, handler)
            }
        }
    }
}
