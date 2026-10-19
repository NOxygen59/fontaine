> [!WARNING]
> **Projet personnel « vibecodé ».** Tout le code de ce dépôt (ou, pour un fork, toutes les modifications) a été écrit par **Claude** (Anthropic, via Claude Code), à la demande spécifique de [@NOxygen59](https://github.com/NOxygen59), pour **son appareil précis** :
>
> **iPad Pro 12,9" 5ᵉ génération (puce M1) — 512 Go de stockage, 8 Go de RAM — iOS 16.6.1, jailbreak Dopamine (rootless) + TrollStore.**
>
> Rien n'est testé ni prévu pour un autre appareil. Pas de support, pas de feuille de route : c'est un dépôt d'archive personnel, publié pour pouvoir reprendre le travail plus tard (modifications, mises à jour).

> [!NOTE]
> **Projet abandonné** le 14 octobre 2026. Sur l'iPad, iOS a refusé d'installer les polices, puis l'app a planté au lancement. Les contournements envisagés risquaient de toucher au système. Le code est gardé ici pour une éventuelle reprise.

**Licence :** MIT (voir [LICENSE](LICENSE)).

**Builds :** voir les [Releases](https://github.com/NOxygen59/fontaine/releases).

---

# Fontaine

A font manager for iPad (iOS 16+), in the spirit of macOS's Font Book, in French, English and
Japanese. Installed with TrollStore, which grants it `com.apple.developer.user-fonts`
(system-installation): fonts it installs go through iPadOS's own mechanism (CTFontManager,
persistent scope; the system asks to confirm) and show in Settings › General › Fonts and in apps
that use installed fonts (the iPadOS font picker). Deleting Fontaine removes them.

iPadOS installs only fonts from inside the installing app's bundle, which is read-only for the app:
each font is kept in Library/Application Support/Fontaine/Polices, and while it's on, a copy sits in
Fontaine.app/Fonts, put there by `fontaine-helper` (Helper/, run as root through TrollStore's
persona entitlement; it only ever writes font files in that folder). The system has the last word:
a font removed in Settings is marked off in Fontaine, never installed again by itself; a cancelled
install leaves nothing behind; a new build of the app gets the bundle copies back at launch.

- Every font, by family, shown in itself (cards or lines of sample text); search and sorting.
- Lists: all, favourites, installed with Fontaine, recently installed, iPadOS's, other apps'
  (through the system font picker); classes (serif, sans serif, monospaced, script, display,
  symbols); writing systems (Latin, Japanese, Chinese, Korean, Cyrillic, Greek, Arabic, Hebrew,
  Thai, Devanagari); your own collections.
- A family: header in its font, its styles, a preview (editable text, size, waterfall,
  characters), every glyph (outline grid, Unicode), details (version, designer, licence, languages…).
- Install from Files or "Open with", turn on and off, uninstall; duplicates and invalid files caught.
- Comparison of several fonts side by side; settings: language, appearance, accent colour,
  sample text, list preview size.

```sh
swift test                         # the core (catalog, installing, collections, the 3 languages)
packaging/package.sh               # dist/Fontaine-1.0.0-ios16.tipa
packaging/package.sh --simulator   # dist/simulator/Fontaine.app (no entitlement: test installs
                                   # with SIMCTL_CHILD_FONTAINE_TEST_SCOPE=process)
```
