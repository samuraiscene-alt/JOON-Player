import Foundation

enum PlayerQuickAction:
    String,
    CaseIterable,
    Identifiable,
    Hashable
{
    case bookmark
    case snapshot
    case previousFrame
    case nextFrame
    case mute
    case pictureInPicture

    static let storageKey =
        "joonplayer.quick.actions.v1"

    static let maximumSelectionCount = 3

    static var defaultActions: [PlayerQuickAction] {
        [
            .bookmark,
            .snapshot,
            .nextFrame
        ]
    }

    static var defaultStorageValue: String {
        encoded(defaultActions)
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookmark:
            return "북마크 저장"
        case .snapshot:
            return "스크린샷"
        case .previousFrame:
            return "이전 프레임"
        case .nextFrame:
            return "다음 프레임"
        case .mute:
            return "음소거"
        case .pictureInPicture:
            return "PiP"
        }
    }

    var systemImage: String {
        switch self {
        case .bookmark:
            return "bookmark.badge.plus"
        case .snapshot:
            return "camera"
        case .previousFrame:
            return "backward.end.fill"
        case .nextFrame:
            return "forward.end.fill"
        case .mute:
            return "speaker.slash"
        case .pictureInPicture:
            return "pip.enter"
        }
    }

    static func decoded(
        from storageValue: String
    ) -> [PlayerQuickAction] {
        var seen = Set<PlayerQuickAction>()

        return storageValue
            .split(separator: ",")
            .compactMap {
                PlayerQuickAction(
                    rawValue: String($0)
                )
            }
            .filter {
                seen.insert($0).inserted
            }
            .prefix(maximumSelectionCount)
            .map { $0 }
    }

    static func encoded(
        _ actions: [PlayerQuickAction]
    ) -> String {
        actions
            .prefix(maximumSelectionCount)
            .map(\.rawValue)
            .joined(separator: ",")
    }
}
