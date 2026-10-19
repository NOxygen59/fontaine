// Every font the system offers, grouped into families, classified (serif, sans serif, monospaced,
// script…) and by writing system, with each face's details. CoreText only: the same on iPadOS and
// macOS (where the tests run).

import CoreGraphics
import CoreText
import Foundation

public enum FontClass: String, Codable, CaseIterable, Sendable {
    case serif, sansSerif, monospaced, script, display, symbol
}

/// Writing systems a family covers (from the languages it supports).
public enum WritingSystem: String, Codable, CaseIterable, Sendable {
    case latin, japanese, chinese, korean, cyrillic, greek, arabic, hebrew, thai, devanagari

    /// A language that needs the writing system.
    var probe: String {
        switch self {
        case .latin: return "fr"
        case .japanese: return "ja"
        case .chinese: return "zh"
        case .korean: return "ko"
        case .cyrillic: return "ru"
        case .greek: return "el"
        case .arabic: return "ar"
        case .hebrew: return "he"
        case .thai: return "th"
        case .devanagari: return "hi"
        }
    }

    /// A short sample in the writing system.
    public var sample: String {
        switch self {
        case .latin: return "Aa"
        case .japanese: return "あ字"
        case .chinese: return "汉字"
        case .korean: return "한글"
        case .cyrillic: return "Жж"
        case .greek: return "Ωω"
        case .arabic: return "عر"
        case .hebrew: return "אב"
        case .thai: return "กข"
        case .devanagari: return "अआ"
        }
    }
}

public enum FontOrigin: String, Codable, Sendable {
    /// Part of iPadOS.
    case system
    /// Installed with this app.
    case installed
    /// Anything else (another app's, a profile's…).
    case other
}

public struct FontFace: Identifiable, Hashable, Sendable {
    public var id: String { postScriptName }
    public let postScriptName: String
    public let family: String
    public let style: String
    public let displayName: String
    /// -1 (thinnest) … 1 (heaviest), 0 regular.
    public let weight: Double
    public let width: Double
    public let isItalic: Bool
    public let isMonospaced: Bool
    public let fontClass: FontClass
    public let url: URL?
    public let origin: FontOrigin

    /// Lightest first, uprights before italics.
    public static func order(_ a: FontFace, _ b: FontFace) -> Bool {
        if a.isItalic != b.isItalic, abs(a.weight - b.weight) < 0.01 { return !a.isItalic }
        if abs(a.weight - b.weight) >= 0.01 { return a.weight < b.weight }
        if abs(a.width - b.width) >= 0.01 { return a.width < b.width }
        return a.style < b.style
    }
}

public struct FontFamily: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public var faces: [FontFace]
    public var writingSystems: Set<WritingSystem>
    public var languageCount: Int

    public var fontClass: FontClass { regular.fontClass }
    public var origin: FontOrigin {
        if faces.contains(where: { $0.origin == .installed }) { return .installed }
        return faces.allSatisfy { $0.origin == .system } ? .system : .other
    }

    /// The face closest to a plain regular.
    public var regular: FontFace {
        faces.min { a, b in
            let da = abs(a.weight) + (a.isItalic ? 1 : 0) + abs(a.width)
            let db = abs(b.weight) + (b.isItalic ? 1 : 0) + abs(b.width)
            return da < db
        } ?? faces[0]
    }
}

public enum Catalog {
    /// Every family available now. `installed` are the PostScript names this app installed;
    /// `languages` (slower: each font is opened) fills the writing systems.
    public static func load(installed: Set<String> = [], languages: Bool = true) -> [FontFamily] {
        let collection = CTFontCollectionCreateFromAvailableFonts(nil)
        let descriptors = (CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor]) ?? []
        var byFamily: [String: [FontFace]] = [:]
        var seen = Set<String>()
        for d in descriptors {
            guard let face = face(from: d, installed: installed), !seen.contains(face.postScriptName) else { continue }
            seen.insert(face.postScriptName)
            byFamily[face.family, default: []].append(face)
        }
        var families = byFamily.map { name, faces in
            FontFamily(name: name, faces: faces.sorted(by: FontFace.order), writingSystems: [], languageCount: 0)
        }
        if languages {
            for i in families.indices {
                let langs = supportedLanguages(families[i].regular.postScriptName)
                families[i].languageCount = langs.count
                families[i].writingSystems = writingSystems(of: langs)
            }
        }
        return families.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func face(from d: CTFontDescriptor, installed: Set<String>) -> FontFace? {
        func attr<T>(_ key: CFString) -> T? { CTFontDescriptorCopyAttribute(d, key) as? T }
        guard let ps: String = attr(kCTFontNameAttribute), let family: String = attr(kCTFontFamilyNameAttribute) else { return nil }
        // The system's private UI faces (".SFUI…") and its fallback font are no one's to manage.
        if ps.hasPrefix(".") || family.hasPrefix(".") || ps == "LastResort" { return nil }
        let traits: [String: Any] = attr(kCTFontTraitsAttribute) ?? [:]
        let weight = (traits[kCTFontWeightTrait as String] as? Double) ?? 0
        let width = (traits[kCTFontWidthTrait as String] as? Double) ?? 0
        let slant = (traits[kCTFontSlantTrait as String] as? Double) ?? 0
        let symbolic = (traits[kCTFontSymbolicTrait as String] as? UInt32) ?? 0
        let style: String = attr(kCTFontStyleNameAttribute) ?? "Regular"
        let url: URL? = attr(kCTFontURLAttribute)
        let italic = symbolic & CTFontSymbolicTraits.traitItalic.rawValue != 0 || slant > 0.01
        let mono = symbolic & CTFontSymbolicTraits.traitMonoSpace.rawValue != 0
        let origin: FontOrigin = installed.contains(ps) ? .installed : (isSystemFile(url) ? .system : .other)
        return FontFace(postScriptName: ps, family: family, style: style, displayName: attr(kCTFontDisplayNameAttribute) ?? ps,
                        weight: weight, width: width, isItalic: italic, isMonospaced: mono,
                        fontClass: classify(family: family, symbolic: symbolic, mono: mono), url: url, origin: origin)
    }

    /// The system's own fonts: in a System/Library folder (also inside the Simulator's runtime), or
    /// downloaded on demand by the system as a font asset.
    static func isSystemFile(_ url: URL?) -> Bool {
        guard let path = url?.path else { return false }
        return path.contains("/System/Library/") || path.contains("MobileAsset") || path.contains("/Library/Fonts/")
    }

    /// From the font's own class bits, else from its name.
    public static func classify(family: String, symbolic: UInt32, mono: Bool) -> FontClass {
        if mono { return .monospaced }
        switch (symbolic & CTFontSymbolicTraits.traitClassMask.rawValue) >> 28 {
        case 1, 2, 3, 4, 5, 7: return .serif
        case 8: return .sansSerif
        case 9: return .display
        case 10: return .script
        case 12: return .symbol
        default: break
        }
        let n = family.lowercased()
        let rules: [(FontClass, [String])] = [
            (.monospaced, ["mono", "code", "courier", "menlo", "consol", "terminal"]),
            (.symbol, ["symbol", "dingbat", "emoji", "webding", "wingding", "braille", "zapf"]),
            (.script, ["script", "hand", "brush", "marker", "chalk", "snell", "zapfino", "noteworthy", "bradley", "party", "savoye", "apple chancery", "signpainter", "klee", "教科書"]),
            (.sansSerif, ["sans", "gothic", "grotesk", "helvetica", "arial", "verdana", "avenir", "futura", "gill", "optima", "trebuchet", "tahoma", "din", "hiragino kaku", "ゴシック", "黑", "hei", "pingfang", "sf pro", "roboto", "inter"]),
            (.serif, ["serif", "times", "georgia", "garamond", "baskerville", "bodoni", "didot", "palatino", "charter", "cochin", "hoefler", "iowan", "mincho", "明朝", "song", "宋", "myungjo", "bookman", "caslon", "athelas", "charis", "seravek"]),
        ]
        for (cls, words) in rules where words.contains(where: { n.contains($0) }) { return cls }
        return .display
    }

    static func supportedLanguages(_ postScriptName: String) -> [String] {
        let font = CTFontCreateWithName(postScriptName as CFString, 12, nil)
        return (CTFontCopySupportedLanguages(font) as? [String]) ?? []
    }

    public static func writingSystems(of languages: [String]) -> Set<WritingSystem> {
        let codes = Set(languages.map { $0.split(separator: "-").first.map(String.init) ?? $0 })
        var out = Set<WritingSystem>()
        for ws in WritingSystem.allCases where codes.contains(ws.probe) { out.insert(ws) }
        // A font with kanji and kana counts as Japanese even when it lists only Chinese, or the reverse.
        if codes.contains("zh"), codes.contains("ja") { out.insert(.chinese) }
        return out
    }
}

/// What a font file says about itself.
public struct FontDetails: Sendable {
    public var version: String?
    public var designer: String?
    public var designerURL: String?
    public var manufacturer: String?
    public var vendorURL: String?
    public var copyright: String?
    public var license: String?
    public var licenseURL: String?
    public var description: String?
    public var trademark: String?
    public var glyphCount: Int
    public var unitsPerEm: Int
    public var languages: [String]
    public var format: String?
    public var fileSize: Int64?

    public static func of(_ face: FontFace) -> FontDetails {
        let font = CTFontCreateWithName(face.postScriptName as CFString, 24, nil)
        func name(_ key: CFString) -> String? {
            guard let s = CTFontCopyName(font, key) as String?, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return s
        }
        var size: Int64?
        if let url = face.url, let v = try? url.resourceValues(forKeys: [.fileSizeKey]), let s = v.fileSize { size = Int64(s) }
        let ext = face.url?.pathExtension.lowercased()
        let format: String? = switch ext {
        case "ttf": "TrueType"
        case "otf": "OpenType (CFF)"
        case "ttc": "TrueType Collection"
        case "otc": "OpenType Collection"
        case nil: nil
        default: ext?.uppercased()
        }
        return FontDetails(version: name(kCTFontVersionNameKey), designer: name(kCTFontDesignerNameKey), designerURL: name(kCTFontDesignerURLNameKey),
                           manufacturer: name(kCTFontManufacturerNameKey), vendorURL: name(kCTFontVendorURLNameKey),
                           copyright: name(kCTFontCopyrightNameKey), license: name(kCTFontLicenseNameKey), licenseURL: name(kCTFontLicenseURLNameKey),
                           description: name(kCTFontDescriptionNameKey), trademark: name(kCTFontTrademarkNameKey),
                           glyphCount: CTFontGetGlyphCount(font), unitsPerEm: Int(CTFontGetUnitsPerEm(font)),
                           languages: (CTFontCopySupportedLanguages(font) as? [String]) ?? [], format: format, fileSize: size)
    }
}

/// A glyph's outline, in a 1-unit box (y down), for drawing at any size.
public enum Glyphs {
    public static func count(_ postScriptName: String) -> Int {
        CTFontGetGlyphCount(CTFontCreateWithName(postScriptName as CFString, 100, nil))
    }

    public static func outline(_ postScriptName: String, glyph: Int) -> CGPath? {
        let font = CTFontCreateWithName(postScriptName as CFString, 100, nil)
        let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
        let height = ascent + descent
        guard height > 0, let path = CTFontCreatePathForGlyph(font, CGGlyph(clamping: glyph), nil) else { return nil }
        var g = CGGlyph(clamping: glyph)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &g, &advance, 1)
        // Flip (glyphs are y-up), centre the advance in the box, scale to 1.
        var t = CGAffineTransform(scaleX: 1 / height, y: -1 / height)
            .translatedBy(x: (height - advance.width) / 2, y: -ascent)
        return path.copy(using: &t)
    }

    /// The character a glyph draws, when the font's character map says.
    public static func characters(_ postScriptName: String, limit: Int = 70_000) -> [Int: String] {
        let font = CTFontCreateWithName(postScriptName as CFString, 12, nil)
        let set = CTFontCopyCharacterSet(font) as CharacterSet
        var out: [Int: String] = [:]
        for plane in 0..<3 where set.hasMember(inPlane: UInt8(plane)) {
            for v in (plane << 16)..<((plane + 1) << 16) {
                guard let scalar = Unicode.Scalar(v), set.contains(scalar) else { continue }
                var units = Array(String(scalar).utf16)
                var glyphs = [CGGlyph](repeating: 0, count: units.count)
                if CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count), let g = glyphs.first, out[Int(g)] == nil {
                    out[Int(g)] = String(scalar)
                }
                if out.count >= limit { return out }
            }
        }
        return out
    }
}
