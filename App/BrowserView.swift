// The middle column: the families of the chosen list, as cards or as lines of sample text, each in
// its own font.

import SwiftUI

struct BrowserView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let families = app.visibleFamilies
        Group {
            if app.loading {
                ProgressView(L.loading(app.lang)).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if families.isEmpty && !(app.selection == .list(.installed) && !app.disabledInstalled.isEmpty) {
                EmptyListView()
            } else if app.settings.gridView {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                        ForEach(families) { f in
                            FamilyCard(family: f, selected: app.selectedFamily == f.name)
                                .onTapGesture { app.selectedFamily = f.name }
                                .contextMenu { FamilyMenu(family: f) }
                        }
                    }
                    .padding(14)
                    DisabledInstalledSection()
                }
            } else {
                List(selection: $app.selectedFamily) {
                    ForEach(families) { f in
                        FamilyRow(family: f)
                            .tag(f.name)
                            .contextMenu { FamilyMenu(family: f) }
                    }
                    DisabledInstalledSection()
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $app.search, placement: .navigationBarDrawer(displayMode: .always), prompt: L.searchPrompt(app.lang))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker(L.sortBy(app.lang), selection: $app.sort) {
                        ForEach(SortOrder.allCases, id: \.self) { Text($0.label(app.lang)).tag($0) }
                    }
                } label: { Label(L.sortBy(app.lang), systemImage: "arrow.up.arrow.down") }
                Button { withAnimation(.spring()) { app.settings.gridView.toggle() } } label: {
                    Label(app.settings.gridView ? L.viewList(app.lang) : L.viewGrid(app.lang),
                          systemImage: app.settings.gridView ? "list.bullet" : "square.grid.2x2")
                }
                Button { app.importing = true } label: { Label(L.importFonts(app.lang), systemImage: "plus") }
            }
        }
    }

    private var title: String {
        switch app.selection ?? .list(.all) {
        case let .list(l): return l.label(app.lang)
        case let .fontClass(c): return c.label(app.lang)
        case let .writing(w): return w.label(app.lang)
        case let .collection(id): return app.store.collections.first { $0.id == id }.map { "\($0.symbol) \($0.name)" } ?? ""
        }
    }
}

struct EmptyListView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: app.search.isEmpty ? "textformat" : "magnifyingglass")
                .font(.system(size: 46))
                .foregroundStyle(.secondary)
            Text(L.emptyTitle(app.lang)).font(.title3.bold())
            Text(hint).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 340)
            if app.selection == .list(.installed) {
                Button { app.importing = true } label: { Label(L.importFonts(app.lang), systemImage: "square.and.arrow.down") }
                    .buttonStyle(.borderedProminent)
            }
            if app.selection == .list(.other) {
                OtherAppsButton()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hint: String {
        if !app.search.isEmpty { return L.emptySearch(app.lang, app.search) }
        switch app.selection {
        case .list(.favorites)?: return L.emptyFavorites(app.lang)
        case .list(.installed)?, .list(.recentlyInstalled)?: return L.emptyInstalled(app.lang)
        case .list(.other)?: return L.emptyOther(app.lang)
        case .collection?: return L.emptyCollection(app.lang)
        default: return ""
        }
    }
}

/// Fonts this app installed but turned off: not in the system's catalog, still here to turn on.
struct DisabledInstalledSection: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        if app.selection == .list(.installed), !app.disabledInstalled.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(L.disabled(app.lang)).font(.headline).foregroundStyle(.secondary)
                ForEach(app.disabledInstalled) { f in
                    HStack {
                        Image(systemName: "textformat").foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(f.families.joined(separator: ", ")).font(.body.weight(.medium))
                            Text(f.fileName).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L.enable(app.lang)) { app.setEnabled(f, true) }.buttonStyle(.bordered)
                        Button(role: .destructive) { app.confirmUninstall = f.families.first } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(14)
        }
    }
}

struct FamilyCard: View {
    @EnvironmentObject var app: AppState
    let family: FontFamily
    let selected: Bool

    var body: some View {
        let face = family.regular
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: family.fontClass.gradient.map { $0.opacity(0.22) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(glyphs)
                    .font(.face(face.postScriptName, size: 56))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 10)
                HStack(spacing: 4) {
                    if app.isFavorite(family.name) { Image(systemName: "heart.fill").foregroundStyle(.pink) }
                    if family.origin == .installed { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
                }
                .font(.caption)
                .padding(8)
            }
            .frame(height: 112)
            VStack(alignment: .leading, spacing: 2) {
                Text(family.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(counted(family.faces.count, one: .oneStyle, many: .stylesCount, app.lang) + " · " + family.fontClass.label(app.lang))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(selected ? app.settings.accent.color.opacity(0.15) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(selected ? app.settings.accent.color : .clear, lineWidth: 2))
        .scaleEffect(selected ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .hoverEffect(.lift)
    }

    /// "Aa", or a sample of the script the font is made for.
    private var glyphs: String {
        let ws = family.writingSystems
        // A CJK font is shown in its own script (it usually has Latin letters too).
        if let cjk = [WritingSystem.japanese, .korean, .chinese].first(where: { ws.contains($0) }) { return cjk.sample }
        if !ws.contains(.latin) {
            if let first = WritingSystem.allCases.first(where: { ws.contains($0) }) { return first.sample }
        }
        return family.fontClass == .symbol ? "★✓" : "Aa"
    }
}

struct FamilyRow: View {
    @EnvironmentObject var app: AppState
    let family: FontFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(family.name).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                if family.origin == .installed { Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(.green) }
                if app.isFavorite(family.name) { Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.pink) }
                Spacer()
                Text(counted(family.faces.count, one: .oneStyle, many: .stylesCount, app.lang)).font(.caption2).foregroundStyle(.tertiary)
            }
            Text(app.sample)
                .font(.face(family.regular.postScriptName, size: app.settings.listPreviewSize))
                .lineLimit(1)
        }
        .padding(.vertical, 6)
    }
}

/// Everything one can do with a family, from its card or row.
struct FamilyMenu: View {
    @EnvironmentObject var app: AppState
    let family: FontFamily

    var body: some View {
        Button { app.toggleFavorite(family.name) } label: {
            Label(app.isFavorite(family.name) ? L.removeFromFavorites(app.lang) : L.addToFavorites(app.lang),
                  systemImage: app.isFavorite(family.name) ? "heart.slash" : "heart")
        }
        Menu {
            ForEach(app.store.collections) { c in
                Button("\(c.symbol) \(c.name)") { app.store.add(family.name, to: c.id) }
            }
            Button { app.createCollection(family.name, symbol: "✦", with: family.name) } label: {
                Label(L.newCollection(app.lang), systemImage: "plus")
            }
        } label: { Label(L.addToCollection(app.lang), systemImage: "folder.badge.plus") }
        if case let .collection(id)? = app.selection {
            Button { app.store.remove(family.name, from: id) } label: { Label(L.removeFromCollection(app.lang), systemImage: "folder.badge.minus") }
        }
        Button { app.toggleComparison(family.name) } label: {
            Label(L.addToComparison(app.lang), systemImage: app.comparing.contains(family.name) ? "checkmark" : "rectangle.split.2x1")
        }
        Button { app.copyName(family) } label: { Label(L.copyName(app.lang), systemImage: "doc.on.doc") }
        if let installed = app.installedFont(for: family) {
            Divider()
            Button { app.setEnabled(installed, !installed.enabled) } label: {
                Label(installed.enabled ? L.disable(app.lang) : L.enable(app.lang), systemImage: installed.enabled ? "pause.circle" : "play.circle")
            }
            Button(role: .destructive) { app.confirmUninstall = family.name } label: { Label(L.uninstall(app.lang), systemImage: "trash") }
        }
    }
}
