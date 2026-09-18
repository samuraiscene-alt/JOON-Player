import Foundation

@MainActor
final class SavedPlaylistStore: ObservableObject {
    struct SavedItem: Codable, Equatable {
        let fileName: String
        var bookmarkData: Data
    }

    struct Playlist: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        var items: [SavedItem]
        let createdAt: Date
        var updatedAt: Date
    }

    struct SaveResult {
        let savedCount: Int
        let skippedCount: Int
    }

    struct Resolution {
        let urls: [URL]
        let unavailableCount: Int
    }

    enum StoreError: LocalizedError {
        case noUsableFiles
        case unavailable

        var errorDescription: String? {
            switch self {
            case .noUsableFiles:
                return "저장할 수 있는 영상 파일을 찾지 못했습니다."
            case .unavailable:
                return "이 재생 목록의 파일을 다시 열 수 없습니다. 파일이 이동·삭제됐거나 클라우드/외장 저장장치 연결이 끊겼을 수 있습니다."
            }
        }
    }

    @Published private(set) var playlists: [Playlist] = []

    private let defaults: UserDefaults
    private let storageKey = "joonplayer.saved.playlists.v1"
    private let maximumPlaylistCount = 20

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func save(
        name: String,
        urls: [URL]
    ) throws -> SaveResult {
        var savedItems: [SavedItem] = []
        var skippedCount = 0

        for url in urls {
            do {
                let bookmark = try makeBookmark(for: url)
                savedItems.append(
                    SavedItem(
                        fileName: url.lastPathComponent,
                        bookmarkData: bookmark
                    )
                )
            } catch {
                skippedCount += 1
            }
        }

        guard !savedItems.isEmpty else {
            throw StoreError.noUsableFiles
        }

        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let finalName = trimmedName.isEmpty
            ? "재생 목록"
            : trimmedName

        let now = Date()

        if let index = playlists.firstIndex(
            where: {
                $0.name.compare(
                    finalName,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) == .orderedSame
            }
        ) {
            playlists[index].name = finalName
            playlists[index].items = savedItems
            playlists[index].updatedAt = now
        } else {
            playlists.insert(
                Playlist(
                    id: UUID(),
                    name: finalName,
                    items: savedItems,
                    createdAt: now,
                    updatedAt: now
                ),
                at: 0
            )
        }

        sortTrimAndSave()

        return SaveResult(
            savedCount: savedItems.count,
            skippedCount: skippedCount
        )
    }

    func resolve(_ playlist: Playlist) throws -> Resolution {
        guard let playlistIndex = playlists.firstIndex(
            where: { $0.id == playlist.id }
        ) else {
            throw StoreError.unavailable
        }

        var validItems: [SavedItem] = []
        var urls: [URL] = []
        var unavailableCount = 0

        for var item in playlists[playlistIndex].items {
            var isStale = false

            guard let url = try? URL(
                resolvingBookmarkData: item.bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                unavailableCount += 1
                continue
            }

            if isStale {
                guard let refreshed = try? makeBookmark(for: url) else {
                    unavailableCount += 1
                    continue
                }

                item.bookmarkData = refreshed
            }

            validItems.append(item)
            urls.append(url)
        }

        guard !urls.isEmpty else {
            remove(playlist)
            throw StoreError.unavailable
        }

        playlists[playlistIndex].items = validItems
        playlists[playlistIndex].updatedAt = Date()
        sortTrimAndSave()

        return Resolution(
            urls: urls,
            unavailableCount: unavailableCount
        )
    }

    func remove(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        save()
    }

    func removeAll() {
        playlists.removeAll()
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

    private func sortTrimAndSave() {
        playlists.sort { $0.updatedAt > $1.updatedAt }

        if playlists.count > maximumPlaylistCount {
            playlists = Array(
                playlists.prefix(maximumPlaylistCount)
            )
        }

        save()
    }

    private func load() {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(
                [Playlist].self,
                from: data
            )
        else {
            playlists = []
            return
        }

        playlists = decoded.sorted {
            $0.updatedAt > $1.updatedAt
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(playlists) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}
