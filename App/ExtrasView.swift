// Settings, the comparison, and the system's font picker (fonts other apps installed).

import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L.settingsLanguage(app.lang)) {
                    HStack(spacing: 12) {
                        ForEach(Lang.allCases) { l in
                            Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { app.settings.lang = l } } label: {
                                VStack(spacing: 8) {
                                    Text(l.flag).font(.system(size: 40))
                                    Text(l.nativeName).font(.headline)
                                    Text(l.sample)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(app.lang == l ? app.settings.accent.color.opacity(0.16) : Color(.tertiarySystemFill),
                                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(app.lang == l ? app.settings.accent.color : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section(L.settingsAppearance(app.lang)) {
                    Picker(L.settingsAppearance(app.lang), selection: $app.settings.appearance) {
                        ForEach(Appearance.allCases, id: \.self) { Text($0.label(app.lang)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text(L.settingsAccent(app.lang))
                        Spacer()
                        ForEach(Accent.allCases, id: \.self) { a in
                            Circle()
                                .fill(a.color.gradient)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().strokeBorder(.white, lineWidth: app.settings.accent == a ? 3 : 0))
                                .shadow(color: a.color.opacity(app.settings.accent == a ? 0.6 : 0), radius: 6)
                                .onTapGesture { withAnimation { app.settings.accent = a } }
                        }
                    }
                }
                Section(L.settingsPreview(app.lang)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.settingsDefaultText(app.lang)).font(.subheadline).foregroundStyle(.secondary)
                        TextField(app.lang.sample, text: $app.settings.sampleText, axis: .vertical)
                            .font(.system(.title3, design: .serif))
                            .lineLimit(1...4)
                        if !app.settings.sampleText.isEmpty {
                            Button(L.reset(app.lang)) { app.settings.sampleText = "" }.font(.callout)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text(L.settingsPreviewSize(app.lang) + " · \(Int(app.settings.listPreviewSize)) pt").font(.subheadline).foregroundStyle(.secondary)
                        Slider(value: $app.settings.listPreviewSize, in: 16...64, step: 1)
                    }
                }
                Section(L.settingsAbout(app.lang)) {
                    HStack(spacing: 16) {
                        LogoView(size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fontaine 1.0").font(.headline)
                            Text(L.aboutText(app.lang)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(L.settings(app.lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L.done(app.lang)) { dismiss() } }
            }
        }
    }
}

struct ComparisonView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var size: Double = 40

    var body: some View {
        NavigationStack {
            Group {
                if app.comparing.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "rectangle.split.2x1").font(.system(size: 46)).foregroundStyle(.secondary)
                        Text(L.comparisonEmpty(app.lang)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            TextField(L.sampleText(app.lang), text: $text)
                            HStack {
                                Image(systemName: "textformat.size")
                                Slider(value: $size, in: 12...120)
                                Text("\(Int(size)) pt").font(.caption.monospacedDigit()).frame(width: 48)
                            }
                            .foregroundStyle(.secondary)
                        }
                        ForEach(app.comparing, id: \.self) { name in
                            if let f = app.family(name) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(f.name).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                        Text(f.fontClass.label(app.lang)).font(.caption2)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(LinearGradient(colors: f.fontClass.gradient, startPoint: .leading, endPoint: .trailing).opacity(0.25), in: Capsule())
                                    }
                                    Text(text.isEmpty ? app.sample : text)
                                        .font(.face(f.regular.postScriptName, size: size))
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .onMove { app.comparing.move(fromOffsets: $0, toOffset: $1) }
                        .onDelete { app.comparing.remove(atOffsets: $0) }
                    }
                }
            }
            .navigationTitle(L.comparison(app.lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L.done(app.lang)) { dismiss() } }
                ToolbarItemGroup(placement: .cancellationAction) {
                    if !app.comparing.isEmpty {
                        Button(L.clearAll(app.lang), role: .destructive) { app.comparing.removeAll() }
                        EditButton()
                    }
                }
            }
        }
    }
}

/// Opens the system's font picker, the only place fonts installed by other apps show.
struct OtherAppsButton: View {
    @EnvironmentObject var app: AppState
    @State private var open = false
    @State private var picked: UIFontDescriptor?

    var body: some View {
        VStack(spacing: 14) {
            Button { open = true } label: { Label(L.showOtherApps(app.lang), systemImage: "textformat") }
                .buttonStyle(.bordered)
            if let d = picked {
                VStack(spacing: 6) {
                    Text(d.object(forKey: .family) as? String ?? d.postscriptName).font(.headline)
                    Text(app.sample).font(Font(UIFont(descriptor: d, size: 30))).lineLimit(2)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .sheet(isPresented: $open) {
            FontPicker { picked = $0 }
        }
    }
}

struct FontPicker: UIViewControllerRepresentable {
    let onPick: (UIFontDescriptor) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIFontPickerViewController {
        let config = UIFontPickerViewController.Configuration()
        config.includeFaces = true
        config.displayUsingSystemFont = false
        let picker = UIFontPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIFontPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
        let onPick: (UIFontDescriptor) -> Void

        init(onPick: @escaping (UIFontDescriptor) -> Void) {
            self.onPick = onPick
        }

        func fontPickerViewControllerDidPickFont(_ controller: UIFontPickerViewController) {
            if let d = controller.selectedFontDescriptor { onPick(d) }
            controller.dismiss(animated: true)
        }
    }
}
