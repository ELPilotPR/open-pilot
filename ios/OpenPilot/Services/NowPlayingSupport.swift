import Foundation
import MediaPlayer

/// Helpers puros para los metadatos de Now Playing (pantalla de bloqueo).
enum NowPlayingSupport {
    static func title(for text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.count > 40 ? String(t.prefix(40)) + "…" : (t.isEmpty ? "Open Pilot" : t)
    }

    /// Duración estimada a ~150 palabras/minuto.
    static func estimatedDuration(_ text: String) -> TimeInterval {
        let words = text.split { $0.isWhitespace }.count
        return max(1.0, Double(words) / 2.5)
    }

    static func info(text: String, elapsed: TimeInterval, duration: TimeInterval, rate: Float) -> [String: Any] {
        [
            MPMediaItemPropertyTitle: title(for: text),
            MPMediaItemPropertyArtist: "Open Pilot",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: rate
        ]
    }
}