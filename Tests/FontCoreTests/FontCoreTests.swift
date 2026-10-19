import CoreText
import XCTest
@testable import FontCore

final class LocalizationTests: XCTestCase {
    func testEveryTextExistsInTheThreeLanguagesWithTheSamePlaceholders() {
        for key in L.allCases {
            guard let texts = L.table[key] else { return XCTFail("\(key) has no translations") }
            XCTAssertEqual(texts.count, 3, "\(key)")
            XCTAssertFalse(texts.contains { $0.isEmpty }, "\(key)")
            let placeholders = texts.map { t in ["%d", "%@"].map { t.components(separatedBy: $0).count - 1 } }
            XCTAssertEqual(Set(placeholders.map { $0.description }).count, 1, "\(key): \(texts)")
        }
    }

    func testFormatting() {
        XCTAssertEqual(L.familiesCount(.fr, 12), "12 familles")
        XCTAssertEqual(L.familiesCount(.en, 12), "12 families")
        XCTAssertEqual(L.familiesCount(.ja, 12), "12 ファミリー")
        XCTAssertEqual(L.uninstallConfirm(.ja, "Lato"), "「Lato」をアンインストールしますか？")
        XCTAssertEqual(InstallError.missingEntitlement.message(.en), "The font installation entitlement is missing: install Fontaine with TrollStore.")
    }
}

final class CatalogTests: XCTestCase {
    func testLoadsFamiliesClassifiedAndByWritingSystem() throws {
        let families = Catalog.load()
        XCTAssertGreaterThan(families.count, 50)
        XCTAssertFalse(families.contains { $0.name.hasPrefix(".") }, "private system faces are hidden")
        let menlo = try XCTUnwrap(families.first { $0.name == "Menlo" })
        XCTAssertEqual(menlo.fontClass, .monospaced)
        XCTAssertGreaterThanOrEqual(menlo.faces.count, 2)
        let regular = menlo.regular
        XCTAssertFalse(regular.isItalic)
        XCTAssertEqual(regular.style, "Regular")
        XCTAssertEqual(menlo.origin, .system)
        let japanese = families.filter { $0.writingSystems.contains(.japanese) }
        XCTAssertFalse(japanese.isEmpty)
        XCTAssertTrue(families.first { $0.name == "Times New Roman" }.map { $0.writingSystems.contains(.latin) } ?? false)
    }

    func testNameRulesWhenTheFontSaysNothing() {
        XCTAssertEqual(Catalog.classify(family: "Fira Code", symbolic: 0, mono: false), .monospaced)
        XCTAssertEqual(Catalog.classify(family: "Noto Serif JP", symbolic: 0, mono: false), .serif)
        XCTAssertEqual(Catalog.classify(family: "游ゴシック", symbolic: 0, mono: false), .sansSerif)
        XCTAssertEqual(Catalog.classify(family: "Brush Script", symbolic: 0, mono: false), .script)
        XCTAssertEqual(Catalog.classify(family: "Whatever", symbolic: 0, mono: false), .display)
        // The font's own class bits come first.
        XCTAssertEqual(Catalog.classify(family: "Mono Sans", symbolic: 8 << 28, mono: false), .sansSerif)
    }

    func testDetailsAndGlyphs() throws {
        let families = Catalog.load(languages: false)
        let georgia = try XCTUnwrap(families.first { $0.name == "Georgia" })
        let details = FontDetails.of(georgia.regular)
        XCTAssertGreaterThan(details.glyphCount, 100)
        XCTAssertGreaterThan(details.unitsPerEm, 0)
        XCTAssertNotNil(details.copyright)
        let ps = georgia.regular.postScriptName
        let chars = Glyphs.characters(ps, limit: 500)
        let a = try XCTUnwrap(chars.first { $0.value == "A" }?.key)
        let path = try XCTUnwrap(Glyphs.outline(ps, glyph: a))
        let box = path.boundingBox
        XCTAssertTrue(box.width > 0.2 && box.width <= 1.01 && box.minY >= -0.01 && box.maxY <= 1.01, "\(box)")
    }
}

final class InstallerTests: XCTestCase {
    var dir: URL!
    var fixture: URL!
    /// Stands for the app's bundle.
    var bundle: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        bundle = dir.appendingPathComponent("Fontaine.app/Fonts")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        // A small OFL font of the Mac's, renamed so it isn't already there.
        var data = try Data(contentsOf: Self.lycian)
        for (from, to) in [("Lycian", "Lycixn")] {
            for enc in [String.Encoding.ascii, .utf16BigEndian] {
                if let f = from.data(using: enc), let t = to.data(using: enc) {
                    while let r = data.range(of: f) { data.replaceSubrange(r, with: t) }
                }
            }
        }
        fixture = dir.appendingPathComponent("NotoSansLycixn-Regular.ttf")
        try data.write(to: fixture)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    static let lycian = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/NotoSansLycian-Regular.ttf")

    /// Like the app's root helper, into `bundle`.
    private func placement(failing: Bool = false) -> FontPlacement {
        let bundle = bundle!
        return FontPlacement(folder: bundle, put: { source in
            if failing { throw CocoaError(.fileWriteNoPermission) }
            let target = bundle.appendingPathComponent(source.lastPathComponent)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: source, to: target)
        }, delete: { try FileManager.default.removeItem(at: bundle.appendingPathComponent($0)) })
    }

    private func available(_ ps: String) -> Bool {
        let names = (CTFontCollectionCreateMatchingFontDescriptors(CTFontCollectionCreateFromAvailableFonts(nil)) as? [CTFontDescriptor] ?? [])
            .compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
        return names.contains(ps)
    }

    private func placed(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: bundle.appendingPathComponent(name).path)
    }

    func testImportActivateDeactivateRemove() async throws {
        let installer = FontInstaller(folder: dir.appendingPathComponent("lib"), scope: .process, placement: placement())
        guard case let .added(font) = installer.importFile(fixture) else { return XCTFail("not added") }
        XCTAssertEqual(font.postScriptNames, ["NotoSansLycixn-Regular"])
        XCTAssertEqual(font.families, ["Noto Sans Lycixn"])
        XCTAssertFalse(font.enabled)
        XCTAssertFalse(available("NotoSansLycixn-Regular"))
        XCTAssertFalse(placed(font.fileName), "placed only while on")

        // The same font again is a duplicate.
        XCTAssertEqual(installer.importFile(fixture), .duplicate(of: font))

        let on = await installer.activate([font.id])
        XCTAssertEqual(on, [])
        XCTAssertTrue(installer.fonts[0].enabled)
        XCTAssertTrue(available("NotoSansLycixn-Regular"))
        XCTAssertTrue(placed(font.fileName))
        let families = Catalog.load(installed: installer.allPostScriptNames, languages: false)
        let face = try XCTUnwrap(families.first { $0.name == "Noto Sans Lycixn" }?.regular)
        XCTAssertEqual(face.origin, .installed)
        XCTAssertEqual(face.url?.resolvingSymlinksInPath(), installer.registeredURL(of: font).resolvingSymlinksInPath(), "registered from the bundle")

        let off = await installer.deactivate([font.id])
        XCTAssertEqual(off, [])
        XCTAssertFalse(installer.fonts[0].enabled)
        XCTAssertFalse(available("NotoSansLycixn-Regular"))
        XCTAssertFalse(placed(font.fileName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: installer.url(of: font).path), "kept to turn on again")

        // State survives a relaunch.
        let again = FontInstaller(folder: dir.appendingPathComponent("lib"), scope: .process, placement: placement())
        XCTAssertEqual(again.fonts.map(\.id), [font.id])

        _ = await installer.activate([font.id])
        _ = await installer.remove([font.id])
        XCTAssertTrue(installer.fonts.isEmpty)
        XCTAssertFalse(available("NotoSansLycixn-Regular"))
        XCTAssertFalse(placed(font.fileName))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.url(of: font).path))
    }

    func testInstallLeavesNothingBehindWhenTheFontCantBeInstalled() async throws {
        let installer = FontInstaller(folder: dir.appendingPathComponent("lib"), scope: .process, placement: placement(failing: true))
        let report = await installer.install([fixture])
        XCTAssertEqual(report.installed, [])
        guard case .refused(.placement)? = report.problems.first else { return XCTFail("\(report.problems)") }
        XCTAssertTrue(installer.fonts.isEmpty)
        let kept = try FileManager.default.contentsOfDirectory(atPath: installer.folder.path).filter { $0.hasSuffix(".ttf") }
        XCTAssertEqual(kept, [])
        XCTAssertFalse(available("NotoSansLycixn-Regular"))
    }

    func testInstallReportsEachFile() async throws {
        let installer = FontInstaller(folder: dir.appendingPathComponent("lib"), scope: .process, placement: placement())
        let bogus = dir.appendingPathComponent("faux.ttf")
        try Data("pas une police".utf8).write(to: bogus)
        let report = await installer.install([fixture, bogus, Self.lycian])
        XCTAssertEqual(report.installed.map(\.families), [["Noto Sans Lycixn"]])
        XCTAssertEqual(report.problems, [.invalid("faux.ttf"), .taken("Noto Sans Lycian")])
        let twice = await installer.install([fixture])
        XCTAssertEqual(twice.problems, [.duplicate("Noto Sans Lycixn")])
        _ = await installer.remove(installer.fonts.map(\.id))
    }

    func testFontsRemovedFromTheSystemAreMarkedOffAndBundleCopiesComeBack() async throws {
        let installer = FontInstaller(folder: dir.appendingPathComponent("lib"), scope: .process, placement: placement())
        let report = await installer.install([fixture])
        let font = try XCTUnwrap(report.installed.first)

        // A new build of the app replaced its bundle: the copy is put back.
        try FileManager.default.removeItem(at: installer.registeredURL(of: font))
        XCTAssertFalse(installer.reconcile(known: Set(font.postScriptNames)))
        XCTAssertTrue(placed(font.fileName))
        XCTAssertTrue(installer.fonts[0].enabled)

        // Removed in Settings: off here too, and not installed again.
        XCTAssertTrue(installer.reconcile(known: []))
        XCTAssertFalse(installer.fonts[0].enabled)
        XCTAssertFalse(placed(font.fileName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: installer.url(of: font).path))
        XCTAssertFalse(installer.reconcile(known: []))

        // Registered still in this process (the test's stand-in for the system): taken off for good.
        _ = await installer.activate([font.id])
        _ = await installer.remove([font.id])
    }

    func testANonFontIsRefused() throws {
        let bogus = dir.appendingPathComponent("faux.ttf")
        try Data("pas une police".utf8).write(to: bogus)
        let installer = FontInstaller(folder: dir.appendingPathComponent("lib"), scope: .process)
        XCTAssertEqual(installer.importFile(bogus), .invalid("faux.ttf"))
        // A font, but not a kind iPadOS installs.
        let renamed = dir.appendingPathComponent("NotoSansLycixn.dfont")
        try FileManager.default.copyItem(at: fixture, to: renamed)
        XCTAssertEqual(installer.importFile(renamed), .invalid("NotoSansLycixn.dfont"))
        XCTAssertTrue(installer.fonts.isEmpty)
    }
}

final class CollectionTests: XCTestCase {
    func testListsAndCollections() {
        func family(_ name: String, _ cls: FontClass, _ origin: FontOrigin, _ ws: Set<WritingSystem>) -> FontFamily {
            let face = FontFace(postScriptName: name.replacingOccurrences(of: " ", with: ""), family: name, style: "Regular", displayName: name,
                                weight: 0, width: 0, isItalic: false, isMonospaced: cls == .monospaced, fontClass: cls, url: nil, origin: origin)
            return FontFamily(name: name, faces: [face], writingSystems: ws, languageCount: 1)
        }
        let all = [family("Georgia", .serif, .system, [.latin]), family("Hiragino Sans", .sansSerif, .system, [.latin, .japanese]),
                   family("Fira Code", .monospaced, .installed, [.latin])]
        var store = CollectionStore()
        store.toggleFavorite("Georgia")
        XCTAssertEqual(store.families(all, for: .list(.favorites)).map(\.name), ["Georgia"])
        XCTAssertEqual(store.families(all, for: .list(.installed)).map(\.name), ["Fira Code"])
        XCTAssertEqual(store.families(all, for: .writing(.japanese)).map(\.name), ["Hiragino Sans"])
        XCTAssertEqual(store.families(all, for: .fontClass(.monospaced)).map(\.name), ["Fira Code"])
        let c = FontCollection(name: "Titres")
        store.collections.append(c)
        store.add("Georgia", to: c.id)
        store.add("Georgia", to: c.id)
        store.add("Fira Code", to: c.id)
        XCTAssertEqual(store.families(all, for: .collection(c.id)).map(\.name), ["Georgia", "Fira Code"])
        store.remove("Georgia", from: c.id)
        XCTAssertEqual(store.families(all, for: .collection(c.id)).map(\.name), ["Fira Code"])
        XCTAssertEqual(store.families(all, for: .list(.recentlyInstalled), installedAt: ["FiraCode": Date()]).map(\.name), ["Fira Code"])
    }
}
