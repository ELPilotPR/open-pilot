import WidgetKit
import SwiftUI

// MARK: - Recent chats

struct RecentChatsEntry: TimelineEntry {
    let date: Date
    let chats: [WidgetChat]
}

struct RecentChatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentChatsEntry {
        RecentChatsEntry(date: .now, chats: [
            WidgetChat(id: "demo", title: "Open Pilot", snippet: "Ask anything, on your models.", date: .now)
        ])
    }
    func getSnapshot(in context: Context, completion: @escaping (RecentChatsEntry) -> Void) {
        completion(RecentChatsEntry(date: .now, chats: WidgetSnapshot.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentChatsEntry>) -> Void) {
        let entry = RecentChatsEntry(date: .now, chats: WidgetSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800))))
    }
}

struct RecentChatsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RecentChatsEntry

    private var limit: Int { family == .systemSmall ? 2 : 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Open Pilot", systemImage: "paperplane.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            if entry.chats.isEmpty {
                Text("No chats yet. Tap to start one.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.chats.prefix(limit)) { chat in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(chat.title).font(.caption.weight(.medium)).lineLimit(1)
                        if family != .accessoryRectangular {
                            Text(chat.snippet).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "openpilot://newchat"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct RecentChatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OpenPilotRecentChats", provider: RecentChatsProvider()) { entry in
            RecentChatsView(entry: entry)
        }
        .configurationDisplayName("Recent chats")
        .description("Your latest conversations at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Quick actions

struct QuickActionsEntry: TimelineEntry { let date: Date }

struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry { QuickActionsEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) { completion(QuickActionsEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        completion(Timeline(entries: [QuickActionsEntry(date: .now)], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct QuickActionsView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            Link(destination: URL(string: "openpilot://ask")!) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.title2)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            VStack(spacing: 8) {
                Link(destination: URL(string: "openpilot://ask")!) {
                    Label("Ask", systemImage: "text.bubble.fill").frame(maxWidth: .infinity)
                }
                Link(destination: URL(string: "openpilot://voice")!) {
                    Label("Voice", systemImage: "mic.fill").frame(maxWidth: .infinity)
                }
                Link(destination: URL(string: "openpilot://newchat")!) {
                    Label("New chat", systemImage: "plus.bubble.fill").frame(maxWidth: .infinity)
                }
            }
            .font(.caption.weight(.medium))
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct QuickActionsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OpenPilotQuickActions", provider: QuickActionsProvider()) { entry in
            QuickActionsView()
        }
        .configurationDisplayName("Quick actions")
        .description("Ask, dictate, or start a new chat.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

@main
struct OpenPilotWidgets: WidgetBundle {
    var body: some Widget {
        RecentChatsWidget()
        QuickActionsWidget()
    }
}