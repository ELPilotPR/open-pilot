import Foundation
import ActivityKit

/// Gestiona la Live Activity del turno en curso. Todo va guardado: si el usuario
/// no tiene Live Activities activas (o falla ActivityKit), el chat sigue igual.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    private var activity: Activity<ChatActivityAttributes>?
    private var lastUpdate = Date.distantPast

    private var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(title: String) {
        guard enabled, activity == nil else { return }
        let attrs = ChatActivityAttributes(title: title.isEmpty ? "Open Pilot" : title)
        let state = ChatActivityAttributes.ContentState(snippet: "", status: "streaming")
        activity = try? Activity.request(attributes: attrs, content: .init(state: state, staleDate: nil))
        lastUpdate = .distantPast
    }

    func update(snippet: String) {
        guard let activity else { return }
        let now = Date()
        guard now.timeIntervalSince(lastUpdate) >= 0.5 else { return }   // throttle (rate limit de ActivityKit)
        lastUpdate = now
        let state = ChatActivityAttributes.ContentState(snippet: LiveActivitySupport.snippet(snippet), status: "streaming")
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}