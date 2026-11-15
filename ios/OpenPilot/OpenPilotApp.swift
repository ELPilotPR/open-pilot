import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct OpenPilotApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Conversation.self, Message.self, ProviderConfig.self, Project.self)
            // Migra las API keys legacy (texto plano) al Keychain una sola vez.
            ProviderConfig.migrateKeysToKeychain(in: ModelContext(container))
        } catch {
            fatalError("Open Pilot: no se pudo abrir la base de datos local (\(error)).")
        }
    }

    var body: some Scene {
        WindowGroup { RootView().onOpenURL { url in DeepLinkSupport.route(url) }.onContinueUserActivity(CSSearchableItemActionType) { SpotlightSupport.handle($0) }.onContinueUserActivity(HandoffSupport.activityType) { HandoffSupport.handle($0) } }
            .modelContainer(container)
    }
}
