// Fontaine: the fonts of the iPad, browsed, compared and installed (iOS 16+).

import SwiftUI
import UniformTypeIdentifiers

@main
struct FontaineApp: App {
    @StateObject private var app = AppState()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .tint(app.settings.accent.color)
                .preferredColorScheme(app.settings.appearance.scheme)
                .environment(\.locale, app.lang.locale)
                // Fonts opened from Files or shared from another app.
                .onOpenURL { url in
                    if FontInstaller.fontExtensions.contains(url.pathExtension.lowercased()) { app.importFonts([url]) }
                }
        }
        .onChange(of: phase) { phase in
            if phase == .active { app.refresh() }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(L.importFonts(app.lang)) { app.importing = true }
                    .keyboardShortcut("i", modifiers: .command)
                Button(L.comparison(app.lang)) { app.showComparison = true }
                    .keyboardShortcut("k", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button(L.settings(app.lang)) { app.showSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu(L.sectionLibrary(app.lang)) {
                Button(L.viewGrid(app.lang)) { app.settings.gridView = true }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button(L.viewList(app.lang)) { app.settings.gridView = false }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                Button(L.addToFavorites(app.lang)) { if let f = app.selectedFamily { app.toggleFavorite(f) } }
                    .keyboardShortcut("d", modifiers: .command)
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 250, ideal: 290)
        } content: {
            BrowserView()
                .navigationSplitViewColumnWidth(min: 340, ideal: 420)
        } detail: {
            if let family = app.family(app.selectedFamily) {
                FamilyDetailView(family: family)
                    .id(family.name)
            } else {
                WelcomeView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .overlay(alignment: .bottom) {
            if let toast = app.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $app.showSettings) { SettingsView() }
        .sheet(isPresented: $app.showComparison) { ComparisonView() }
        .fileImporter(isPresented: $app.importing, allowedContentTypes: Self.fontTypes, allowsMultipleSelection: true) { result in
            if case let .success(urls) = result { app.importFonts(urls) }
        }
        .confirmationDialog(L.uninstallConfirm(app.lang, app.confirmUninstall ?? ""),
                            isPresented: Binding(get: { app.confirmUninstall != nil }, set: { if !$0 { app.confirmUninstall = nil } }),
                            titleVisibility: .visible) {
            Button(L.uninstall(app.lang), role: .destructive) {
                if let name = app.confirmUninstall, let f = app.installed.first(where: { $0.families.contains(name) }) { app.uninstall(f) }
            }
            Button(L.cancel(app.lang), role: .cancel) {}
        } message: {
            Text(L.uninstallExplain(app.lang))
        }
    }

    static let fontTypes: [UTType] = [.font] + ["ttf", "otf", "ttc", "otc"].compactMap { UTType(filenameExtension: $0) }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        Label(toast.text, systemImage: toast.symbol)
            .font(.callout.weight(.medium))
            .foregroundStyle(toast.isError ? Color.red : Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
    }
}

/// The detail column before a font is chosen.
struct WelcomeView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            LinearGradient(colors: [app.settings.accent.color.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 18) {
                LogoView(size: 120)
                Text("Fontaine").font(.system(size: 44, weight: .bold, design: .serif))
                if app.loading {
                    ProgressView(L.loading(app.lang))
                } else {
                    Text(counted(app.families.count, one: .oneFamily, many: .familiesCount, app.lang) + " · " + counted(app.families.reduce(0) { $0 + $1.faces.count }, one: .oneStyle, many: .stylesCount, app.lang))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Button { app.importing = true } label: {
                    Label(L.importFonts(app.lang), systemImage: "square.and.arrow.down.on.square")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding()
        }
    }
}

/// The app's mark: "Aa" on the accent gradient.
struct LogoView: View {
    @EnvironmentObject var app: AppState
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [app.settings.accent.color, app.settings.accent.color.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("Aa")
                .font(.system(size: size * 0.5, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .frame(width: size, height: size)
        .shadow(color: app.settings.accent.color.opacity(0.4), radius: size * 0.15, y: size * 0.06)
    }
}
