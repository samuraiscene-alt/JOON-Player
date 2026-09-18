import Foundation

@MainActor
final class RecentMediaStore: ObservableObject {
    struct Item: Codable, Identifiable, Equatable {
        let id: String
        let fileName: String
        var bookmarkData: Data
        var lastOpenedAt: Date
    }

    enum RecentMediaError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "최근 파일을 다시 열 수 없습니다. 파일이 이동·삭제됐거나 클라우드/외장 저장장치 연결이 끊겼을 수 있습니다."
        }
    }

    @Published private(set) var items: [Item] = []

    private let defaults: UserDefaults
    private let storageKey = "joonplayer.recent.media.v1"
    private let maximumItemCount = 12

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func remember(url: URL) throws {
        let bookmark = try makeBookmark(for: url)
        let id = Self.identifier(for: url)

        items.removeAll { $0.id == id }

        items.insert(
            Item(
                id: id,
                fileName: url.lastPathComponent,
                bookmarkData: bookmark,
                lastOpenedAt: Date()
            ),
            at: 0
        )

        trimAndSave()
    }

    func resolve(_ item: Item) throws -> URL {
        var isStale = false

        guard let url = try? URL(
            resolvingBookmarkData: item.bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            remove(item)
            throw RecentMediaError.unavailable
        }

        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return url
        }

        if isStale {
            guard let refreshedBookmark = try? makeBookmark(for: url) else {
                remove(item)
                throw RecentMediaError.unavailable
            }

            items[index].bookmarkData = refreshedBookmark
        }

        items[index].lastOpenedAt = Date()
        sortAndSave()

        return url
    }

    func remove(_ item: Item) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func removeAll() {
        items.removeAll()
        save()
    }

    private func makeBookmark(for url: URL) throws -> Data {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private static func identifier(for url: URL) -> String {
        let standardizedURL = url.standardizedFileURL
        let values = try? standardizedURL.resourceValues(
            forKeys: [.fileSizeKey, .contentModificationDateKey]
        )

        let fileSize = values?.fileSize ?? -1
        let modifiedAt = Int(
            values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        )

        return [
            standardizedURL.path.lowercased(),
            String(fileSize),
            String(modifiedAt)
        ].joined(separator: "|")
    }

    private func trimAndSave() {
        items.sort { $0.lastOpenedAt > $1.lastOpenedAt }

        if items.count > maximumItemCount {
            items = Array(items.prefix(maximumItemCount))
        }

        save()
    }

    private func sortAndSave() {
        items.sort { $0.lastOpenedAt > $1.lastOpenedAt }
        save()
    }

    private func load() {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Item].self, from: data)
        else {
            items = []
            return
        }

        items = decoded.sorted {
            $0.lastOpenedAt > $1.lastOpenedAt
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}
