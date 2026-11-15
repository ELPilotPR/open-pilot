import Foundation

/// Mensaje serializable para Handoff.
struct HandoffMessage: Codable, Equatable {
    let role: String
    let text: String
}

struct HandoffPayload: Equatable {
    let title: String
    let messages: [HandoffMessage]
}

/// Handoff iPhone↔iPad↔Mac. Sin backend ni sync: la actividad lleva el transcript
/// y el otro dispositivo crea una conversación con ese contenido.
enum HandoffSupport {
    static let activityType = "com.openpilot.app.chat"
    static var pending: HandoffPayload?

    static func transcript(_ c: Conversation) -> [HandoffMessage] {
        c.sortedMessages
            .filter { $0.role == "user" || $0.role == "assistant" }
            .map { HandoffMessage(role: $0.role, text: $0.text) }
    }

    static func encode(_ msgs: [HandoffMessage]) -> String {
        guard let d = try? JSONEncoder().encode(msgs), let s = String(data: d, encoding: .utf8) else { return "[]" }
        return s
    }

    static func decode(_ s: String) -> [HandoffMessage] {
        guard let d = s.data(using: .utf8),
              let m = try? JSONDecoder().decode([HandoffMessage].self, from: d) else { return [] }
        return m
    }

    static func configure(_ activity: NSUserActivity, for c: Conversation?) {
        guard let c else { activity.userInfo = [:]; return }
        activity.title = c.title.isEmpty ? "Open Pilot" : c.title
        activity.userInfo = ["title": c.title, "transcript": encode(transcript(c))]
        activity.isEligibleForHandoff = true
    }

    static func payload(from activity: NSUserActivity) -> HandoffPayload? {
        guard activity.activityType == activityType,
              let info = activity.userInfo,
              let t = info["transcript"] as? String else { return nil }
        let msgs = decode(t)
        guard !msgs.isEmpty else { return nil }
        return HandoffPayload(title: (info["title"] as? String) ?? "", messages: msgs)
    }

    static func handle(_ activity: NSUserActivity) {
        if let p = payload(from: activity) { pending = p }
    }
}