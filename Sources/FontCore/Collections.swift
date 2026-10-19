// Ways to look at the fonts: built-in lists, classes, writing systems, and the user's own
// collections and favourites.

import Foundation

public struct FontCollection: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var symbol: String
    public var families: [String]
    public let created: Date

    public init(name: String, symbol: String = "✦", families: [String] = []) {
        id = UUID()
        self.name = name
        self.symbol = symbol
        self.families = families
        created = Date()
    }
}

public enum LibraryList: String, CaseIterable, Codable, Sendable {
    case all, favorites, installed, recentlyInstalled, system, other
}

/// What the sidebar shows.
public enum Selection: Hashable, Codable, Sendable {
    case list(LibraryList)
    case fontClass(FontClass)
    case writing(WritingSystem)
    case collection(UUID)
}

public struct CollectionStore: Codable, Sendable {
    public var favorites: Set<String> = []
    public var collections: [FontCollection] = []

    public init() {}

    public static func load(from url: URL) -> CollectionStore {
        guard let data = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(CollectionStore.self, from: data) else { return CollectionStore() }
        return s
    }

    public func save(to url: URL) {
        if let data = try? JSONEncoder().encode(self) { try? data.write(to: url, options: .atomic) }
    }

    /// The families `selection` shows. `installedAt` dates the fonts this app installed.
    public func families(_ all: [FontFamily], for selection: Selection, installedAt: [String: Date] = [:], now: Date = Date()) -> [FontFamily] {
        switch selection {
        case let .list(list):
            switch list {
            case .all: return all
            case .favorites: return all.filter { favorites.contains($0.name) }
            case .installed: return all.filter { $0.origin == .installed }
            case .recentlyInstalled:
                let since = now.addingTimeInterval(-30 * 86_400)
                return all.filter { ($0.faces.compactMap { installedAt[$0.postScriptName] }.max() ?? .distantPast) >= since }
                    .sorted { ($0.faces.compactMap { installedAt[$0.postScriptName] }.max() ?? .distantPast) > ($1.faces.compactMap { installedAt[$0.postScriptName] }.max() ?? .distantPast) }
            case .system: return all.filter { $0.origin == .system }
            case .other: return all.filter { $0.origin == .other }
            }
        case let .fontClass(c):
            return all.filter { $0.fontClass == c }
        case let .writing(w):
            return all.filter { $0.writingSystems.contains(w) }
        case let .collection(id):
            guard let c = collections.first(where: { $0.id == id }) else { return [] }
            let names = Set(c.families)
            return all.filter { names.contains($0.name) }
        }
    }

    public mutating func toggleFavorite(_ family: String) {
        if favorites.contains(family) { favorites.remove(family) } else { favorites.insert(family) }
    }

    public mutating func add(_ family: String, to id: UUID) {
        guard let i = collections.firstIndex(where: { $0.id == id }), !collections[i].families.contains(family) else { return }
        collections[i].families.append(family)
    }

    public mutating func remove(_ family: String, from id: UUID) {
        guard let i = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[i].families.removeAll { $0 == family }
    }
}
