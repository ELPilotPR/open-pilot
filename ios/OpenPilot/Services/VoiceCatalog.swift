import Foundation
import AVFoundation

/// A selectable on-device speech voice.
struct VoiceOption: Identifiable, Equatable {
    let id: String        // AVSpeechSynthesisVoice.identifier
    let name: String
    let language: String
    let quality: Int      // 1 default, 2 enhanced, 3 premium
}

/// Persisted voice preferences (UserDefaults, shared with the Settings UI).
enum VoiceSettings {
    static var identifier: String {
        get { UserDefaults.standard.string(forKey: "voice.identifier") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "voice.identifier") }
    }
    static var bargeIn: Bool {
        get { UserDefaults.standard.object(forKey: "voice.bargeIn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "voice.bargeIn") }
    }
}

enum VoiceCatalog {
    /// Pure filter + sort (best quality first, then name). Unit-testable without
    /// touching the real device voice list.
    static func filterAndSort(_ voices: [VoiceOption], languagePrefix: String) -> [VoiceOption] {
        let p = languagePrefix.lowercased()
        return voices
            .filter { $0.language.lowercased().hasPrefix(p) }
            .sorted { a, b in
                if a.quality != b.quality { return a.quality > b.quality }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }

    /// The device's installed voices for a language prefix ("es" / "en").
    static func options(for languagePrefix: String) -> [VoiceOption] {
        let real = AVSpeechSynthesisVoice.speechVoices().map {
            VoiceOption(id: $0.identifier, name: $0.name, language: $0.language,
                        quality: Int($0.quality.rawValue))
        }
        return filterAndSort(real, languagePrefix: languagePrefix)
    }

    static var currentPrefix: String { LanguageManager.shared.current == .es ? "es" : "en" }

    /// Whether speech detected during playback should interrupt the TTS. Pure.
    static func shouldBargeIn(transcript: String, enabled: Bool) -> Bool {
        enabled && !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}