// One family: a header in its own font, its styles, and three tabs (preview, glyphs, details).

import CoreText
import SwiftUI

struct FamilyDetailView: View {
    @EnvironmentObject var app: AppState
    let family: FontFamily
    @State private var faceID: String?
    @State private var tab = Tab.preview

    enum Tab: Hashable { case preview, glyphs, info }

    private var face: FontFace { family.faces.first { $0.postScriptName == faceID } ?? family.regular }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                styles
                Picker("", selection: $tab) {
                    Text(L.tabPreview(app.lang)).tag(Tab.preview)
                    Text(L.tabGlyphs(app.lang)).tag(Tab.glyphs)
                    Text(L.tabInfo(app.lang)).tag(Tab.info)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                switch tab {
                case .preview: PreviewTab(family: family, face: face)
                case .glyphs: GlyphsTab(face: face).id(face.postScriptName)
                case .info: InfoTab(family: family, face: face).id(face.postScriptName)
                }
            }
            .padding(.bottom, 40)
        }
        .navigationTitle(family.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { app.toggleComparison(family.name) } label: {
                    Image(systemName: app.comparing.contains(family.name) ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                }
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { app.toggleFavorite(family.name) } } label: {
                    Image(systemName: app.isFavorite(family.name) ? "heart.fill" : "heart").foregroundStyle(.pink)
                }
                Menu { FamilyMenu(family: family) } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .onAppear {
            faceID = family.regular.postScriptName
            if app.detailTab == "glyphs" { tab = .glyphs } else if app.detailTab == "info" { tab = .info }
        }
    }

    private var header: some View {
        LinearGradient(colors: family.fontClass.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(height: 230)
            // A big glyph in the background, as a watermark (an overlay: it doesn't size the header).
            .overlay(alignment: .bottomTrailing) {
                Text(watermark)
                    .font(.face(face.postScriptName, size: 260))
                    .foregroundStyle(.white.opacity(0.16))
                    .lineLimit(1)
                    .fixedSize()
                    .offset(x: 40, y: 70)
            }
            .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 10) {
                Text(family.name)
                    .font(.face(face.postScriptName, size: 54))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(text: family.fontClass.label(app.lang), symbol: family.fontClass.symbolName)
                        Chip(text: origin, symbol: family.origin == .installed ? "checkmark.seal.fill" : (family.origin == .system ? "apple.logo" : "app.badge"))
                        Chip(text: counted(family.faces.count, one: .oneStyle, many: .stylesCount, app.lang), symbol: "square.stack.3d.up")
                        if family.languageCount > 0 { Chip(text: counted(family.languageCount, one: .oneLanguage, many: .languagesCount, app.lang), symbol: "globe") }
                        ForEach(WritingSystem.allCases.filter { family.writingSystems.contains($0) }, id: \.self) { w in
                            Chip(text: w.label(app.lang), symbol: nil)
                        }
                    }
                }
            }
            .padding(24)
            }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: family.fontClass.gradient[1].opacity(0.35), radius: 18, y: 10)
        .padding([.horizontal, .top])
    }

    private var origin: String {
        switch family.origin {
        case .system: return L.originSystem(app.lang)
        case .installed: return L.originInstalled(app.lang)
        case .other: return L.originOther(app.lang)
        }
    }

    private var watermark: String {
        family.writingSystems.contains(.latin) || family.writingSystems.isEmpty ? "Ag" : (WritingSystem.allCases.first { family.writingSystems.contains($0) }?.sample ?? "Ag")
    }

    private var styles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.faces(app.lang)).font(.headline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(family.faces) { f in
                        Button { withAnimation(.easeInOut(duration: 0.2)) { faceID = f.postScriptName } } label: {
                            Text(f.style)
                                .font(.face(f.postScriptName, size: 17))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(f.postScriptName == face.postScriptName ? app.settings.accent.color.opacity(0.18) : Color(.secondarySystemBackground),
                                            in: Capsule())
                                .overlay(Capsule().strokeBorder(f.postScriptName == face.postScriptName ? app.settings.accent.color : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct Chip: View {
    let text: String
    let symbol: String?

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.22), in: Capsule())
    }
}

// MARK: Preview

struct PreviewTab: View {
    @EnvironmentObject var app: AppState
    let family: FontFamily
    let face: FontFace
    @State private var text = ""
    @State private var size: Double = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            card {
                TextField(L.sampleText(app.lang), text: $text, axis: .vertical)
                    .font(.face(face.postScriptName, size: size))
                    .lineLimit(1...8)
                HStack(spacing: 12) {
                    Image(systemName: "textformat.size.smaller")
                    Slider(value: $size, in: 8...160)
                    Image(systemName: "textformat.size.larger")
                    Text("\(Int(size)) pt").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 48)
                }
                .foregroundStyle(.secondary)
            }
            section(L.waterfall(app.lang)) {
                ForEach([12, 18, 24, 32, 48, 72], id: \.self) { s in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(s)").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 26, alignment: .trailing)
                        Text(shown).font(.face(face.postScriptName, size: CGFloat(s))).lineLimit(1)
                    }
                }
            }
            section(L.characters(app.lang)) {
                Text(repertoire)
                    .font(.face(face.postScriptName, size: 30))
                    .lineSpacing(8)
                    .textSelection(.enabled)
            }
            if family.faces.count > 1 {
                section(L.faces(app.lang)) {
                    ForEach(family.faces) { f in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(f.style).font(.caption).foregroundStyle(.secondary)
                            Text(shown).font(.face(f.postScriptName, size: 26)).lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .onAppear { if text.isEmpty { text = app.sample } }
    }

    private var shown: String { text.isEmpty ? app.sample : text }

    private var repertoire: String {
        let ws = family.writingSystems
        var lines: [String] = []
        if ws.contains(.latin) || ws.isEmpty {
            lines += ["ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", "0123456789 àâçéèêëîïôûùüÿœæ", "!?&@#%*()[]{}«»“”‘’…–—€$£¥"]
        }
        if ws.contains(.japanese) { lines += ["あいうえお かきくけこ さしすせそ", "アイウエオ カキクケコ", "永東京日本語漢字書体"] }
        if ws.contains(.chinese) && !ws.contains(.japanese) { lines += ["永东京中文汉字字体书法"] }
        if ws.contains(.korean) { lines += ["가나다라마바사 아자차카타파하"] }
        if ws.contains(.cyrillic) { lines += ["АБВГДЕЖЗИЙКЛМН абвгдежзий"] }
        if ws.contains(.greek) { lines += ["ΑΒΓΔΕΖΗΘΙΚΛΜΝ αβγδεζηθ"] }
        if ws.contains(.arabic) { lines += ["ابتثجحخدذرزسشصضطظعغفقكلمنهوي"] }
        if ws.contains(.hebrew) { lines += ["אבגדהוזחטיכלמנסעפצקרשת"] }
        if ws.contains(.thai) { lines += ["กขฃคฅฆงจฉชซฌญฎฏ"] }
        if ws.contains(.devanagari) { lines += ["अआइईउऊऋएऐओऔकखगघ"] }
        if family.fontClass == .symbol { lines += ["★☆✓✗♠♣♥♦→←↑↓"] }
        return lines.joined(separator: "\n")
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            card(content)
        }
    }
}

// MARK: Glyphs

/// A face's glyph outlines, made once and kept.
@MainActor
final class GlyphSource: ObservableObject {
    let postScriptName: String
    let count: Int
    @Published private(set) var characters: [Int: String] = [:]
    private var cache: [Int: Path] = [:]

    init(_ postScriptName: String) {
        self.postScriptName = postScriptName
        count = Glyphs.count(postScriptName)
        let name = postScriptName
        Task {
            let map = await Task.detached(priority: .utility) { Glyphs.characters(name) }.value
            characters = map
        }
    }

    func path(_ glyph: Int) -> Path? {
        if let p = cache[glyph] { return p }
        guard let cg = Glyphs.outline(postScriptName, glyph: glyph) else { return nil }
        let p = Path(cg)
        cache[glyph] = p
        return p
    }
}

struct GlyphsTab: View {
    @EnvironmentObject var app: AppState
    @StateObject private var source: GlyphSource
    @State private var picked: Int?
    @State private var cell: Double = 64

    init(face: FontFace) {
        _source = StateObject(wrappedValue: GlyphSource(face.postScriptName))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L.glyphsCount(app.lang, source.count)).font(.headline)
                Spacer()
                Image(systemName: "square.grid.3x3").foregroundStyle(.secondary)
                Slider(value: $cell, in: 40...120).frame(width: 160)
                Image(systemName: "square.grid.2x2").foregroundStyle(.secondary)
            }
            if let g = picked, let path = source.path(g) {
                HStack(spacing: 24) {
                    GlyphShape(path: path)
                        .fill(app.settings.accent.color)
                        .frame(width: 180, height: 180)
                        .background(GridBackdrop())
                    VStack(alignment: .leading, spacing: 8) {
                        Text("#\(g)").font(.title2.monospacedDigit().bold())
                        if let ch = source.characters[g] {
                            Text(ch).font(.title)
                            Text(ch.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " "))
                                .font(.callout.monospaced()).foregroundStyle(.secondary)
                            Button { UIPasteboard.general.string = ch } label: { Label(L.copyName(app.lang), systemImage: "doc.on.doc") }
                                .buttonStyle(.bordered)
                        }
                    }
                    Spacer()
                }
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .transition(.scale.combined(with: .opacity))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: cell), spacing: 6)], spacing: 6) {
                ForEach(0..<min(source.count, 65_535), id: \.self) { g in
                    GlyphCell(source: source, glyph: g, selected: picked == g)
                        .frame(height: cell)
                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { picked = g } }
                }
            }
        }
        .padding(.horizontal)
    }
}

struct GlyphCell: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var source: GlyphSource
    let glyph: Int
    let selected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? app.settings.accent.color.opacity(0.2) : Color(.secondarySystemBackground))
            if let p = source.path(glyph) {
                GlyphShape(path: p).fill(Color.primary).padding(6)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(glyph)").font(.system(size: 8).monospacedDigit()).foregroundStyle(.tertiary).padding(3)
        }
    }
}

/// A glyph outline (in a 1-unit box) scaled to its frame.
struct GlyphShape: Shape {
    let path: Path

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        return path.applying(CGAffineTransform(scaleX: side, y: side).concatenating(
            CGAffineTransform(translationX: rect.minX + (rect.width - side) / 2, y: rect.minY + (rect.height - side) / 2)))
    }
}

struct GridBackdrop: View {
    var body: some View {
        Canvas { ctx, size in
            for i in 1..<4 {
                let x = size.width * CGFloat(i) / 4, y = size.height * CGFloat(i) / 4
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(.secondary.opacity(0.2)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: Info

struct InfoTab: View {
    @EnvironmentObject var app: AppState
    let family: FontFamily
    let face: FontFace
    @State private var details: FontDetails?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let installed = app.installedFont(for: family) {
                HStack {
                    Label(installed.enabled ? L.enabled(app.lang) : L.disabled(app.lang), systemImage: installed.enabled ? "checkmark.circle.fill" : "pause.circle.fill")
                        .foregroundStyle(installed.enabled ? .green : .orange)
                    Spacer()
                    Toggle("", isOn: Binding(get: { installed.enabled }, set: { app.setEnabled(installed, $0) })).labelsHidden()
                    Button(role: .destructive) { app.confirmUninstall = family.name } label: { Label(L.uninstall(app.lang), systemImage: "trash") }
                        .buttonStyle(.bordered)
                }
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            if let d = details {
                VStack(spacing: 0) {
                    row(L.infoPostScript(app.lang), face.postScriptName, mono: true)
                    row(L.infoVersion(app.lang), d.version)
                    row(L.infoDesigner(app.lang), d.designer)
                    row(L.infoManufacturer(app.lang), d.manufacturer)
                    row(L.infoFormat(app.lang), d.format)
                    row(L.infoFileSize(app.lang), d.fileSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) })
                    row(L.tabGlyphs(app.lang), "\(d.glyphCount)")
                    row(L.infoUnitsPerEm(app.lang), "\(d.unitsPerEm)")
                    row(L.infoTrademark(app.lang), d.trademark)
                    row(L.infoCopyright(app.lang), d.copyright)
                    row(L.infoLicense(app.lang), d.license)
                    row(L.infoDescription(app.lang), d.description)
                    row(L.infoFile(app.lang), face.url?.lastPathComponent, mono: true)
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                if !d.languages.isEmpty {
                    Text(L.infoLanguages(app.lang) + " (\(d.languages.count))").font(.headline)
                    FlowLayout(spacing: 6) {
                        ForEach(languageNames(d.languages), id: \.self) { name in
                            Text(name)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(app.settings.accent.color.opacity(0.12), in: Capsule())
                        }
                    }
                }
                if family.origin == .installed, let url = face.url {
                    ShareLink(item: url) { Label(L.shareFile(app.lang), systemImage: "square.and.arrow.up") }
                        .buttonStyle(.bordered)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .task {
            let f = face
            details = await Task.detached(priority: .userInitiated) { FontDetails.of(f) }.value
        }
    }

    private func languageNames(_ codes: [String]) -> [String] {
        Array(Set(codes.map { app.lang.locale.localizedString(forIdentifier: $0) ?? $0 })).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String?, mono: Bool = false) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title).foregroundStyle(.secondary).frame(width: 170, alignment: .leading)
                Text(value)
                    .font(mono ? .callout.monospaced() : .callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            Divider().padding(.leading, 18)
        }
    }
}

/// Lays out its children in rows, wrapping (tags).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += row + spacing
                row = 0
            }
            x += size.width + spacing
            row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += row + spacing
                row = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}
