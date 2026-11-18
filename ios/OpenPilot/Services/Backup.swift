import Foundation
import SwiftData

/// Respaldo completo 100% local (sin backend): todos los chats + metadatos de
/// proveedores en un único JSON portable. Las API keys NUNCA se incluyen (viven
/// en el Keychain del dispositivo); al restaurar, el usuario reintroduce sus keys.
/// Reusa `ConversationExport.Document`/`materialize` para el árbol de versiones.
enum Backup {

    struct ProviderItem: Codable, Equatable {
        var id: String
        var name: String
        var kind: String
        var baseURL: String
        var models: [String]
        var imageCapability: String
        var contextWindow: Int
        // Sin apiKey / apiKeyLegacy: las claves no salen del Keychain.
    }

    struct ConversationItem: Codable {
        var conversationID: UUID
        var isPinned: Bool
        var isArchived: Bool
        var tags: [String]
        var document: ConversationExport.Document
    }

    struct Bundle: Codable {
        var format: String = "openpilot.backup"
        var version: Int = 1
        var exportedAt: Date
        var conversations: [ConversationItem]
        var providers: [ProviderItem]
    }

    enum BackupError: LocalizedError {
        case invalidFormat
        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "Not an Open Pilot backup file."
            }
        }
    }

    // MARK: - Export

    /// Ensambla el bundle. Excluye chats temporales (efímeros). Nunca copia keys.
    static func bundle(conversations: [Conversation], providers: [ProviderConfig]) -> Bundle {
        let convs = conversations.filter { !$0.isTemporary }.map { c in
            ConversationItem(
                conversationID: c.id, isPinned: c.isPinned, isArchived: c.isArchived,
                tags: c.tags, document: ConversationExport.document(c)
            )
        }
        let provs = providers.map { p in
            ProviderItem(id: p.id, name: p.name, kind: p.kind, baseURL: p.baseURL,
                         models: p.models, imageCapability: p.imageCapability,
                         contextWindow: p.contextWindow)
        }
        return Bundle(exportedAt: Date(), conversations: convs, providers: provs)
    }

    static func jsonData(_ b: Bundle) throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(b)
    }

    static func decode(_ data: Data) throws -> Bundle {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let b = try dec.decode(Bundle.self, from: data)
        guard b.format == "openpilot.backup" else { throw BackupError.invalidFormat }
        return b
    }

    // MARK: - Import / restore

    /// Restaura el bundle. `replace=true` borra todos los chats existentes antes
    /// (cascade arrastra sus mensajes); `false` añade copias nuevas. Los proveedores
    /// se fusionan por id (los existentes no se tocan; nunca se escriben keys).
    /// Devuelve cuántos chats y proveedores nuevos se insertaron.
    @discardableResult
    static func restore(_ b: Bundle, into context: ModelContext, replace: Bool) -> (conversations: Int, providers: Int) {
        if replace {
            let existing = (try? context.fetch(FetchDescriptor<Conversation>())) ?? []
            for c in existing { context.delete(c) }   // cascade elimina sus mensajes
        }
        var addedConvs = 0
        for item in b.conversations {
            let c = ConversationExport.materialize(item.document, into: context)
            c.isPinned = item.isPinned
            c.isArchived = item.isArchived
            c.tags = item.tags
            addedConvs += 1
        }
        let existingProvIDs = Set(((try? context.fetch(FetchDescriptor<ProviderConfig>())) ?? []).map { $0.id })
        var addedProvs = 0
        for p in b.providers where !existingProvIDs.contains(p.id) {
            let np = ProviderConfig(id: p.id, name: p.name, kind: p.kind, baseURL: p.baseURL, models: p.models, imageCapability: p.imageCapability)
            np.contextWindow = p.contextWindow
            context.insert(np)
            addedProvs += 1
        }
        try? context.save()
        return (addedConvs, addedProvs)
    }
}
