// The app's words in French, English and Japanese, chosen in the app's settings (not only the
// iPad's language).

import Foundation

/// "1 style" / "12 styles": the singular when there is one.
public func counted(_ n: Int, one: L, many: L, _ lang: Lang) -> String {
    n == 1 ? one(lang) : many(lang, n)
}

public enum Lang: String, CaseIterable, Codable, Identifiable, Sendable {
    case fr, en, ja

    public var id: String { rawValue }

    /// Its own name, in itself.
    public var nativeName: String {
        switch self {
        case .fr: return "Français"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }

    public var flag: String {
        switch self {
        case .fr: return "🇫🇷"
        case .en: return "🇬🇧"
        case .ja: return "🇯🇵"
        }
    }

    public var locale: Locale { Locale(identifier: rawValue) }

    /// A pangram (every letter of the alphabet) or its classic equivalent.
    public var sample: String {
        switch self {
        case .fr: return "Portez ce vieux whisky au juge blond qui fume."
        case .en: return "The quick brown fox jumps over the lazy dog."
        case .ja: return "いろはにほへと ちりぬるを わかよたれそ"
        }
    }

    /// The iPad's preferred language, if it's one of ours (French otherwise).
    public static var device: Lang {
        for id in Locale.preferredLanguages {
            if let l = Lang(rawValue: String(id.prefix(2))) { return l }
        }
        return .fr
    }
}

public enum L: String, CaseIterable, Sendable {
    case sectionLibrary, listAll, listFavorites, listInstalled, listRecent, listSystem, listOther
    case sectionClasses, serif, sansSerif, monospaced, script, display, symbol
    case sectionWriting, latin, japanese, chinese, korean, cyrillic, greek, arabic, hebrew, thai, devanagari
    case sectionCollections, newCollection, collectionName, rename, delete, cancel, ok, done, create, settings
    case searchPrompt, familiesCount, stylesCount, languagesCount, glyphsCount
    case emptyTitle, emptyFavorites, emptyInstalled, emptyCollection, emptyOther, emptySearch
    case sortName, sortStyles, sortClass, sortBy, viewGrid, viewList
    case importFonts, addToFavorites, removeFromFavorites, addToCollection, removeFromCollection, copyName, addToComparison, showOtherApps
    case tabPreview, tabGlyphs, tabInfo, size, sampleText, waterfall, characters, faces
    case originSystem, originInstalled, originOther, enabled, disabled, enable, disable, uninstall, uninstallConfirm, uninstallExplain
    case infoPostScript, infoVersion, infoDesigner, infoManufacturer, infoCopyright, infoLicense, infoDescription, infoTrademark
    case infoFormat, infoFileSize, infoUnitsPerEm, infoLanguages, infoFile, shareFile
    case installTitle, installExplain, installButton, importedCount, duplicateMsg, takenMsg, invalidMsg, errorTitle
    case errAlreadyInstalled, errNotInstalled, errCancelled, errDuplicateName, errInvalidFile, errMissingEntitlement, errRefused
    case errInvalidLocation, errLimit, errInUse, errPlacement
    case comparison, comparisonEmpty, clearAll
    case settingsLanguage, settingsAppearance, appearanceSystem, appearanceLight, appearanceDark
    case settingsPreview, settingsDefaultText, settingsPreviewSize, settingsAccent, settingsAbout, aboutText, reset
    case loading, compareCount, pickerTitle
    case oneFamily, oneStyle, oneLanguage, oneImported

    public func callAsFunction(_ lang: Lang, _ args: CVarArg...) -> String {
        let texts = Self.table[self] ?? [rawValue, rawValue, rawValue]
        let index = Lang.allCases.firstIndex(of: lang) ?? 0
        let text = texts.indices.contains(index) ? texts[index] : rawValue
        return args.isEmpty ? text : String(format: text, locale: lang.locale, arguments: args)
    }

    /// French, English, Japanese.
    static let table: [L: [String]] = [
        .sectionLibrary: ["Bibliothèque", "Library", "ライブラリ"],
        .listAll: ["Toutes les polices", "All Fonts", "すべてのフォント"],
        .listFavorites: ["Favoris", "Favorites", "お気に入り"],
        .listInstalled: ["Installées par moi", "Installed by Me", "自分でインストール"],
        .listRecent: ["Installées récemment", "Recently Installed", "最近インストール"],
        .listSystem: ["Polices d'iPadOS", "iPadOS Fonts", "iPadOS のフォント"],
        .listOther: ["Autres apps", "Other Apps", "他のアプリ"],
        .sectionClasses: ["Classification", "Classification", "分類"],
        .serif: ["Sérif", "Serif", "セリフ"],
        .sansSerif: ["Sans sérif", "Sans Serif", "サンセリフ"],
        .monospaced: ["Monospace", "Monospaced", "等幅"],
        .script: ["Manuscrite", "Script", "手書き風"],
        .display: ["Fantaisie", "Display", "ディスプレイ"],
        .symbol: ["Symboles", "Symbols", "記号"],
        .sectionWriting: ["Écritures", "Writing Systems", "文字体系"],
        .latin: ["Latin", "Latin", "ラテン文字"],
        .japanese: ["Japonais", "Japanese", "日本語"],
        .chinese: ["Chinois", "Chinese", "中国語"],
        .korean: ["Coréen", "Korean", "韓国語"],
        .cyrillic: ["Cyrillique", "Cyrillic", "キリル文字"],
        .greek: ["Grec", "Greek", "ギリシャ文字"],
        .arabic: ["Arabe", "Arabic", "アラビア文字"],
        .hebrew: ["Hébreu", "Hebrew", "ヘブライ文字"],
        .thai: ["Thaï", "Thai", "タイ文字"],
        .devanagari: ["Dévanagari", "Devanagari", "デーヴァナーガリー"],
        .sectionCollections: ["Mes collections", "My Collections", "マイコレクション"],
        .newCollection: ["Nouvelle collection", "New Collection", "新規コレクション"],
        .collectionName: ["Nom de la collection", "Collection name", "コレクション名"],
        .rename: ["Renommer", "Rename", "名前を変更"],
        .delete: ["Supprimer", "Delete", "削除"],
        .cancel: ["Annuler", "Cancel", "キャンセル"],
        .ok: ["OK", "OK", "OK"],
        .done: ["Terminé", "Done", "完了"],
        .create: ["Créer", "Create", "作成"],
        .settings: ["Réglages", "Settings", "設定"],
        .searchPrompt: ["Rechercher une police", "Search fonts", "フォントを検索"],
        .familiesCount: ["%d familles", "%d families", "%d ファミリー"],
        .stylesCount: ["%d styles", "%d styles", "%d スタイル"],
        .languagesCount: ["%d langues", "%d languages", "%d 言語"],
        .glyphsCount: ["%d glyphes", "%d glyphs", "%d グリフ"],
        .emptyTitle: ["Aucune police ici", "No Fonts Here", "フォントがありません"],
        .emptyFavorites: ["Touchez ♡ sur une police pour l'ajouter à vos favoris.", "Tap ♡ on a font to add it to your favorites.", "フォントの ♡ をタップしてお気に入りに追加しましょう。"],
        .emptyInstalled: ["Importez des fichiers .ttf, .otf ou .ttc depuis Fichiers : ils seront installés pour tout l'iPad.", "Import .ttf, .otf or .ttc files from Files: they will be installed for the whole iPad.", "「ファイル」から .ttf、.otf、.ttc を読み込むと、iPad 全体にインストールされます。"],
        .emptyCollection: ["Touchez longuement une police puis « Ajouter à une collection ».", "Touch and hold a font, then choose “Add to Collection”.", "フォントを長押しして「コレクションに追加」を選びます。"],
        .emptyOther: ["Les polices installées par d'autres apps ne sont visibles qu'avec le sélecteur du système.", "Fonts installed by other apps are only visible through the system font picker.", "他のアプリでインストールされたフォントは、システムのフォントピッカーでのみ表示できます。"],
        .emptySearch: ["Aucune police ne correspond à « %@ ».", "No font matches “%@”.", "「%@」に一致するフォントはありません。"],
        .sortName: ["Nom", "Name", "名前"],
        .sortStyles: ["Nombre de styles", "Number of styles", "スタイル数"],
        .sortClass: ["Classification", "Classification", "分類"],
        .sortBy: ["Trier par", "Sort by", "並べ替え"],
        .viewGrid: ["Grille", "Grid", "グリッド"],
        .viewList: ["Liste", "List", "リスト"],
        .importFonts: ["Importer des polices…", "Import Fonts…", "フォントを読み込む…"],
        .addToFavorites: ["Ajouter aux favoris", "Add to Favorites", "お気に入りに追加"],
        .removeFromFavorites: ["Retirer des favoris", "Remove from Favorites", "お気に入りから削除"],
        .addToCollection: ["Ajouter à une collection", "Add to Collection", "コレクションに追加"],
        .removeFromCollection: ["Retirer de la collection", "Remove from Collection", "コレクションから削除"],
        .copyName: ["Copier le nom", "Copy Name", "名前をコピー"],
        .addToComparison: ["Comparer", "Compare", "比較する"],
        .showOtherApps: ["Voir les polices d'autres apps…", "Show Other Apps' Fonts…", "他のアプリのフォントを表示…"],
        .tabPreview: ["Aperçu", "Preview", "プレビュー"],
        .tabGlyphs: ["Glyphes", "Glyphs", "グリフ"],
        .tabInfo: ["Infos", "Info", "情報"],
        .size: ["Taille", "Size", "サイズ"],
        .sampleText: ["Texte d'aperçu", "Sample text", "サンプルテキスト"],
        .waterfall: ["Cascade", "Waterfall", "ウォーターフォール"],
        .characters: ["Caractères", "Characters", "文字"],
        .faces: ["Styles", "Styles", "スタイル"],
        .originSystem: ["Fait partie d'iPadOS", "Part of iPadOS", "iPadOS に付属"],
        .originInstalled: ["Installée avec Fontaine", "Installed with Fontaine", "Fontaine でインストール"],
        .originOther: ["Installée par une autre app", "Installed by another app", "他のアプリでインストール"],
        .enabled: ["Activée", "On", "有効"],
        .disabled: ["Désactivée", "Off", "無効"],
        .enable: ["Activer", "Turn On", "有効にする"],
        .disable: ["Désactiver", "Turn Off", "無効にする"],
        .uninstall: ["Désinstaller", "Uninstall", "アンインストール"],
        .uninstallConfirm: ["Désinstaller « %@ » ?", "Uninstall “%@”?", "「%@」をアンインストールしますか？"],
        .uninstallExplain: ["La police disparaîtra de toutes les apps de l'iPad, et son fichier sera supprimé.", "The font will disappear from every app on this iPad, and its file will be deleted.", "このフォントは iPad のすべてのアプリから削除され、ファイルも削除されます。"],
        .infoPostScript: ["Nom PostScript", "PostScript name", "PostScript 名"],
        .infoVersion: ["Version", "Version", "バージョン"],
        .infoDesigner: ["Créateur", "Designer", "デザイナー"],
        .infoManufacturer: ["Fonderie", "Manufacturer", "製造元"],
        .infoCopyright: ["Copyright", "Copyright", "著作権"],
        .infoLicense: ["Licence", "License", "ライセンス"],
        .infoDescription: ["Description", "Description", "説明"],
        .infoTrademark: ["Marque", "Trademark", "商標"],
        .infoFormat: ["Format", "Format", "形式"],
        .infoFileSize: ["Taille du fichier", "File size", "ファイルサイズ"],
        .infoUnitsPerEm: ["Unités par em", "Units per em", "em あたりのユニット"],
        .infoLanguages: ["Langues prises en charge", "Supported languages", "対応言語"],
        .infoFile: ["Fichier", "File", "ファイル"],
        .shareFile: ["Partager le fichier…", "Share File…", "ファイルを共有…"],
        .installTitle: ["Installer des polices", "Install Fonts", "フォントをインストール"],
        .installExplain: ["iPadOS va vous demander de confirmer. Les polices seront ensuite disponibles dans Réglages › Général › Polices et dans les apps compatibles (Pages, Keynote, Procreate…).", "iPadOS will ask you to confirm. The fonts will then be available in Settings › General › Fonts and in apps that support them (Pages, Keynote, Procreate…).", "iPadOS が確認を求めます。インストール後は「設定」›「一般」›「フォント」や、対応アプリ（Pages、Keynote、Procreate など）で使えます。"],
        .installButton: ["Installer", "Install", "インストール"],
        .importedCount: ["%d polices ajoutées", "%d fonts added", "%d 個のフォントを追加しました"],
        .duplicateMsg: ["« %@ » est déjà installée", "“%@” is already installed", "「%@」はすでにインストールされています"],
        .takenMsg: ["« %@ » est déjà sur l'iPad (police d'iPadOS ou d'une autre app)", "“%@” is already on this iPad (an iPadOS font or another app's)", "「%@」はすでに iPad にあります（iPadOS または他のアプリのフォント）"],
        .invalidMsg: ["« %@ » n'est pas une police lisible", "“%@” is not a readable font", "「%@」は読み込めるフォントではありません"],
        .errorTitle: ["Opération impossible", "Couldn't Do That", "操作できませんでした"],
        .errAlreadyInstalled: ["Cette police est déjà installée.", "This font is already installed.", "このフォントはすでにインストールされています。"],
        .errNotInstalled: ["Cette police n'est pas installée.", "This font isn't installed.", "このフォントはインストールされていません。"],
        .errCancelled: ["Installation annulée.", "Installation cancelled.", "インストールはキャンセルされました。"],
        .errDuplicateName: ["Une police du même nom existe déjà sur l'iPad.", "A font with the same name already exists on this iPad.", "同じ名前のフォントがすでに iPad にあります。"],
        .errInvalidFile: ["Le fichier de police est invalide.", "The font file is invalid.", "フォントファイルが無効です。"],
        .errMissingEntitlement: ["L'autorisation d'installer des polices manque : installez Fontaine avec TrollStore.", "The font installation entitlement is missing: install Fontaine with TrollStore.", "フォントをインストールする権限がありません。TrollStore で Fontaine をインストールしてください。"],
        .errRefused: ["Le système a refusé l'installation.", "The system refused the installation.", "システムがインストールを拒否しました。"],
        .errInvalidLocation: ["iPadOS refuse l'emplacement du fichier : il n'installe que les polices placées dans l'app.", "iPadOS refused the file's location: it only installs fonts inside the app.", "iPadOS はファイルの場所を拒否しました。アプリ内に置かれたフォントしかインストールできません。"],
        .errLimit: ["iPadOS a atteint sa limite de polices installées.", "iPadOS has reached its limit of installed fonts.", "iPadOS でインストールできるフォントの上限に達しました。"],
        .errInUse: ["La police est en cours d'utilisation.", "The font is in use.", "このフォントは使用中です。"],
        .errPlacement: ["Impossible de placer la police dans Fontaine.app (%@).", "Couldn't put the font inside Fontaine.app (%@).", "フォントを Fontaine.app 内に配置できませんでした（%@）。"],
        .comparison: ["Comparaison", "Comparison", "比較"],
        .comparisonEmpty: ["Ajoutez des polices à comparer : appui long sur une police, puis « Comparer ».", "Add fonts to compare: touch and hold a font, then choose “Compare”.", "比較するフォントを追加しましょう。フォントを長押しして「比較する」を選びます。"],
        .clearAll: ["Tout retirer", "Clear All", "すべて削除"],
        .settingsLanguage: ["Langue", "Language", "言語"],
        .settingsAppearance: ["Apparence", "Appearance", "外観"],
        .appearanceSystem: ["Comme l'iPad", "Match iPad", "iPad に合わせる"],
        .appearanceLight: ["Clair", "Light", "ライト"],
        .appearanceDark: ["Sombre", "Dark", "ダーク"],
        .settingsPreview: ["Aperçu", "Preview", "プレビュー"],
        .settingsDefaultText: ["Texte d'aperçu par défaut", "Default sample text", "デフォルトのサンプルテキスト"],
        .settingsPreviewSize: ["Taille de l'aperçu dans la liste", "Preview size in the list", "リストのプレビューサイズ"],
        .settingsAccent: ["Couleur d'accent", "Accent color", "アクセントカラー"],
        .settingsAbout: ["À propos", "About", "このアプリについて"],
        .aboutText: ["Fontaine installe les polices avec le mécanisme d'iPadOS lui-même : vous confirmez chaque installation, elles apparaissent dans Réglages › Général › Polices et dans les apps qui utilisent le sélecteur de polices d'iPadOS. Supprimer Fontaine les retire.", "Fontaine installs fonts with iPadOS's own mechanism: you confirm each install, and they show in Settings › General › Fonts and in apps that use the iPadOS font picker. Deleting Fontaine removes them.", "Fontaine は iPadOS 自身の仕組みでフォントをインストールします。インストールのたびに確認され、「設定」›「一般」›「フォント」と、iPadOS のフォントピッカーを使うアプリに表示されます。Fontaine を削除するとフォントも削除されます。"],
        .reset: ["Rétablir", "Reset", "リセット"],
        .loading: ["Chargement des polices…", "Loading fonts…", "フォントを読み込み中…"],
        .compareCount: ["Comparer (%d)", "Compare (%d)", "比較（%d）"],
        .pickerTitle: ["Polices d'autres apps", "Other Apps' Fonts", "他のアプリのフォント"],
        .oneFamily: ["1 famille", "1 family", "1 ファミリー"],
        .oneStyle: ["1 style", "1 style", "1 スタイル"],
        .oneLanguage: ["1 langue", "1 language", "1 言語"],
        .oneImported: ["Police ajoutée", "Font added", "フォントを追加しました"],
    ]
}

extension FontClass {
    public var label: L {
        switch self {
        case .serif: return .serif
        case .sansSerif: return .sansSerif
        case .monospaced: return .monospaced
        case .script: return .script
        case .display: return .display
        case .symbol: return .symbol
        }
    }
}

extension WritingSystem {
    public var label: L {
        switch self {
        case .latin: return .latin
        case .japanese: return .japanese
        case .chinese: return .chinese
        case .korean: return .korean
        case .cyrillic: return .cyrillic
        case .greek: return .greek
        case .arabic: return .arabic
        case .hebrew: return .hebrew
        case .thai: return .thai
        case .devanagari: return .devanagari
        }
    }
}

extension LibraryList {
    public var label: L {
        switch self {
        case .all: return .listAll
        case .favorites: return .listFavorites
        case .installed: return .listInstalled
        case .recentlyInstalled: return .listRecent
        case .system: return .listSystem
        case .other: return .listOther
        }
    }
}

extension InstallError {
    public var label: L? {
        switch self {
        case .alreadyInstalled: return .errAlreadyInstalled
        case .notInstalled: return .errNotInstalled
        case .cancelled: return .errCancelled
        case .duplicateName: return .errDuplicateName
        case .invalidFile: return .errInvalidFile
        case .missingEntitlement: return .errMissingEntitlement
        case .refused: return .errRefused
        case .invalidLocation: return .errInvalidLocation
        case .limitReached: return .errLimit
        case .inUse: return .errInUse
        case .placement: return .errPlacement
        case .other: return nil
        }
    }

    public func message(_ lang: Lang) -> String {
        switch self {
        case let .other(text): return text
        case let .placement(reason): return L.errPlacement(lang, reason)
        default: return label.map { $0(lang) } ?? ""
        }
    }
}

extension InstallProblem {
    public func message(_ lang: Lang) -> String {
        switch self {
        case let .duplicate(name): return L.duplicateMsg(lang, name)
        case let .taken(name): return L.takenMsg(lang, name)
        case let .invalid(name): return L.invalidMsg(lang, name)
        case let .refused(error): return error.message(lang)
        }
    }
}
