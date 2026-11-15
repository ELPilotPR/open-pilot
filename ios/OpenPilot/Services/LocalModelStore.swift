import Foundation

/// Gestiona los archivos .gguf descargados en el contenedor de la app.
enum LocalModelStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LocalModels", isDirectory: true)
    }

    static func ensureDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func url(for filename: String) -> URL { directory.appendingPathComponent(filename) }

    static func isDownloaded(_ filename: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: filename).path)
    }

    static func downloaded() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasSuffix(".gguf") }.sorted()
    }

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    static func sizeGB(_ filename: String) -> Double {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url(for: filename).path)
        let bytes = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        return Double(bytes) / 1_073_741_824.0
    }
}