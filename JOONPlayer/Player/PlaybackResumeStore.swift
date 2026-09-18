import Foundation

final class PlaybackResumeStore {
    static let shared = PlaybackResumeStore()

    private struct Record: Codable {
        let position: Double
        let duration: Double
        let updatedAt: Date
    }

    private let defaults: UserDefaults
    private let storageKey = "joonplayer.playback.resume.v1"
    private let maximumRecordCount = 100

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func identifier(for url: URL) -> String {
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

    func position(for identifier: String) -> Double? {
        loadRecords()[identifier]?.position
    }

    func save(position: Double, duration: Double, for identifier: String) {
        guard position.isFinite, duration.isFinite, duration > 0 else { return }

        var records = loadRecords()
        let remaining = duration - position

        if position < 10 || remaining <= 30 {
            records.removeValue(forKey: identifier)
            store(records)
            return
        }

        records[identifier] = Record(
            position: position,
            duration: duration,
            updatedAt: Date()
        )

        if records.count > maximumRecordCount {
            let keep = records
                .sorted { $0.value.updatedAt > $1.value.updatedAt }
                .prefix(maximumRecordCount)

            records = Dictionary(uniqueKeysWithValues: keep)
        }

        store(records)
    }

    func remove(for identifier: String) {
        var records = loadRecords()
        records.removeValue(forKey: identifier)
        store(records)
    }

    private func loadRecords() -> [String: Record] {
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: Record].self, from: data)) ?? [:]
    }

    private func store(_ records: [String: Record]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
