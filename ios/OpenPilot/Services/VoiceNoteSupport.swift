import Foundation

/// Helpers puros para notas de voz (grabar → transcribir → enviar).
enum VoiceNoteSupport {
    static func formatDuration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    static func cleanTranscript(_ s: String) -> String {
        let collapsed = s.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func fileName(date: Date = Date()) -> String {
        "voicenote-\(Int(date.timeIntervalSince1970)).m4a"
    }

    static func messageText(transcript: String) -> String {
        cleanTranscript(transcript)
    }

    /// Normaliza averagePower (dB, -160…0) a 0…1 con suelo -60 dB para el espectro.
    static func level(fromDB db: Float) -> Float {
        if db.isNaN { return 0 }
        let minDb: Float = -60
        return max(0, min(1, (db - minDb) / -minDb))
    }
}