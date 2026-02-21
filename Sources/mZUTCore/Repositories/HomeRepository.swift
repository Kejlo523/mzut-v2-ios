import Foundation

public final class HomeRepository {
    private enum Keys {
        static let tiles = "tiles_config"
    }

    private let store: KeyValueStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(store: KeyValueStore = UserDefaultsStore(suiteName: "mzut_home_prefs")) {
        self.store = store
    }

    public func saveTiles(_ tiles: [Tile]) {
        guard let data = try? encoder.encode(tiles) else {
            return
        }
        store.set(data, forKey: Keys.tiles)
    }

    public func loadTiles() -> [Tile] {
        guard let data = store.data(forKey: Keys.tiles),
              let tiles = try? decoder.decode([Tile].self, from: data),
              !tiles.isEmpty else {
            return createDefaultTiles()
        }
        let normalized = tiles.map(normalizeTileLabels)
        if normalized != tiles {
            saveTiles(normalized)
        }
        return normalized
    }

    public func createDefaultTiles() -> [Tile] {
        [
            Tile(
                id: 1,
                col: 0,
                row: 0,
                colSpan: 2,
                rowSpan: 2,
                title: "Plan zajęć",
                description: "Widok dnia, tygodnia i miesiąca",
                actionType: .plan
            ),
            Tile(
                id: 2,
                col: 2,
                row: 0,
                colSpan: 2,
                rowSpan: 2,
                title: "Oceny",
                description: "Średnia i punkty ECTS",
                actionType: .grades
            ),
            Tile(
                id: 3,
                col: 0,
                row: 2,
                colSpan: 2,
                rowSpan: 2,
                title: "Informacje",
                description: "Dane o studiach i przebiegu",
                actionType: .info
            ),
            Tile(
                id: 4,
                col: 2,
                row: 2,
                colSpan: 2,
                rowSpan: 2,
                title: "Aktualności ZUT",
                description: "Komunikaty i ogłoszenia",
                actionType: .news
            )
        ]
    }

    public func restoreDefaults() -> [Tile] {
        let defaults = createDefaultTiles()
        saveTiles(defaults)
        return defaults
    }

    private func normalizeTileLabels(_ tile: Tile) -> Tile {
        var updated = tile
        switch updated.id {
        case 1 where updated.actionType == .plan:
            updated.title = "Plan zajęć"
            updated.description = "Widok dnia, tygodnia i miesiąca"
        case 2 where updated.actionType == .grades:
            updated.title = "Oceny"
            updated.description = "Średnia i punkty ECTS"
        case 3 where updated.actionType == .info:
            updated.title = "Informacje"
            updated.description = "Dane o studiach i przebiegu"
        case 4 where updated.actionType == .news || updated.actionType == .newsLatest:
            updated.title = "Aktualności ZUT"
            updated.description = "Komunikaty i ogłoszenia"
        default:
            break
        }
        return updated
    }
}
