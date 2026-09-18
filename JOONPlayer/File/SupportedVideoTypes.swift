import UniformTypeIdentifiers

enum SupportedVideoTypes {
    static let all: [UTType] = {
        var types: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        let extensions = ["mkv", "avi", "m4v", "ts", "m2ts", "webm", "flv"]

        for ext in extensions {
            let type = UTType(filenameExtension: ext) ?? UTType(importedAs: "public.\(ext)")
            if !types.contains(type) {
                types.append(type)
            }
        }

        return types
    }()
}
