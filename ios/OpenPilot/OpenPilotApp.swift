import SwiftUI
import SwiftData

@main
struct OpenPilotApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Conversation.self, Message.self, ProviderConfig.self])
    }
}