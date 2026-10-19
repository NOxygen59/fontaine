// The sidebar: the library's lists, classes, writing systems and the user's collections.

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var app: AppState
    @State private var newCollection = false
    @State private var renaming: FontCollection?
    @State private var name = ""

    var body: some View {
        List(selection: $app.selection) {
            Section {
                HStack(spacing: 14) {
                    LogoView(size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fontaine").font(.system(.title2, design: .serif).weight(.bold))
                        Text(counted(app.families.count, one: .oneFamily, many: .familiesCount, app.lang)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
            }
            Section(L.sectionLibrary(app.lang)) {
                ForEach(LibraryList.allCases, id: \.self) { list in
                    row(.list(list), title: list.label(app.lang), symbol: symbol(list), tint: tint(list))
                }
            }
            Section(L.sectionClasses(app.lang)) {
                ForEach(FontClass.allCases, id: \.self) { c in
                    row(.fontClass(c), title: c.label(app.lang), symbol: c.symbolName, tint: c.gradient[0])
                }
            }
            Section(L.sectionWriting(app.lang)) {
                ForEach(WritingSystem.allCases, id: \.self) { w in
                    let n = app.count(.writing(w))
                    if n > 0 || app.loading {
                        NavigationLink(value: Selection.writing(w)) {
                            HStack {
                                Text(w.sample)
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 30, height: 24)
                                    .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                                Text(w.label(app.lang))
                                Spacer()
                                Text("\(n)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section {
                ForEach(app.store.collections) { c in
                    NavigationLink(value: Selection.collection(c.id)) {
                        HStack {
                            Text(c.symbol).font(.title3).frame(width: 30)
                            Text(c.name)
                            Spacer()
                            Text("\(c.families.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button { name = c.name; renaming = c } label: { Label(L.rename(app.lang), systemImage: "pencil") }
                        Button(role: .destructive) {
                            app.store.collections.removeAll { $0.id == c.id }
                            if app.selection == .collection(c.id) { app.selection = .list(.all) }
                        } label: { Label(L.delete(app.lang), systemImage: "trash") }
                    }
                }
                Button { newCollection = true } label: {
                    Label(L.newCollection(app.lang), systemImage: "plus.circle.fill")
                }
            } header: {
                Text(L.sectionCollections(app.lang))
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Fontaine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { app.showSettings = true } label: { Label(L.settings(app.lang), systemImage: "gearshape") }
                Spacer()
                Button { app.showComparison = true } label: {
                    Label(L.compareCount(app.lang, app.comparing.count), systemImage: "rectangle.split.2x1")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .sheet(isPresented: $newCollection) { CollectionEditor(collection: nil) }
        .sheet(item: $renaming) { CollectionEditor(collection: $0) }
    }

    private func row(_ s: Selection, title: String, symbol: String, tint: Color) -> some View {
        NavigationLink(value: s) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 24)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 6))
                Text(title)
                Spacer()
                Text("\(app.count(s))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    private func symbol(_ l: LibraryList) -> String {
        switch l {
        case .all: return "textformat.size"
        case .favorites: return "heart.fill"
        case .installed: return "square.and.arrow.down.fill"
        case .recentlyInstalled: return "clock.fill"
        case .system: return "apple.logo"
        case .other: return "app.badge"
        }
    }

    private func tint(_ l: LibraryList) -> Color {
        switch l {
        case .all: return app.settings.accent.color
        case .favorites: return .pink
        case .installed: return .green
        case .recentlyInstalled: return .orange
        case .system: return .gray
        case .other: return .blue
        }
    }
}

struct CollectionEditor: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let collection: FontCollection?
    @State private var name = ""
    @State private var symbol = "✦"

    private let symbols = ["✦", "📰", "🎨", "✍️", "🖋️", "💼", "🎬", "🎮", "🇯🇵", "🌸", "🔤", "🧪", "⭐️", "🏷️", "📚", "🖥️"]

    var body: some View {
        NavigationStack {
            Form {
                Section(L.collectionName(app.lang)) {
                    TextField(L.collectionName(app.lang), text: $name)
                        .font(.title3)
                }
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(symbols, id: \.self) { s in
                            Text(s)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(symbol == s ? app.settings.accent.color.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { symbol = s }
                        }
                    }
                }
            }
            .navigationTitle(collection == nil ? L.newCollection(app.lang) : L.rename(app.lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.cancel(app.lang)) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(collection == nil ? L.create(app.lang) : L.ok(app.lang)) {
                        if let c = collection, let i = app.store.collections.firstIndex(where: { $0.id == c.id }) {
                            app.store.collections[i].name = name.isEmpty ? c.name : name
                            app.store.collections[i].symbol = symbol
                        } else {
                            app.createCollection(name, symbol: symbol)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let c = collection {
                    name = c.name
                    symbol = c.symbol
                }
            }
        }
        .presentationDetents([.medium])
    }
}
