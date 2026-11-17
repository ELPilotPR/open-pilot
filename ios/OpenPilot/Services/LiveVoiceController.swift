import Foundation
import SwiftUI

/// Modo voz en vivo: conversación continua manos libres. Orquesta el bucle
/// escuchar → transcribir → enviar al modelo → leer la respuesta → volver a
/// escuchar, reutilizando VoiceManager (dictado + TTS on-device, sin backend).
/// La detección de pausa envía el utterance cuando el transcript se estabiliza.
@MainActor
final class LiveVoiceController: ObservableObject {
    enum Phase { case idle, listening, thinking, speaking }

    @Published var isActive = false
    @Published var phase: Phase = .idle
    @Published var heard = ""

    private let voice = VoiceManager.shared
    private var pollTask: Task<Void, Never>?

    /// ChatView lo asigna: envía el texto transcrito al modelo.
    var sendUtterance: ((String) -> Void)?

    func start() {
        guard !isActive else { return }
        isActive = true
        beginListening()
    }

    func stop() {
        isActive = false
        phase = .idle
        heard = ""
        pollTask?.cancel()
        pollTask = nil
        voice.stopDictation()
        voice.stopSpeaking()
    }

    /// ChatView lo llama cuando el asistente terminó de responder en modo vivo.
    func assistantDidFinish(_ text: String) {
        guard isActive, phase == .thinking else { return }
        phase = .speaking
        voice.toggleSpeak(text, id: UUID())
        let barge = VoiceSettings.bargeIn
        if barge { Task { await voice.startDictation() } }   // listen during playback
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self else { return }
            while self.isActive && self.voice.speakingID != nil {
                if VoiceCatalog.shouldBargeIn(transcript: self.voice.liveTranscript, enabled: barge) {
                    let heard = self.voice.liveTranscript
                    self.voice.stopSpeaking()
                    self.voice.stopDictation()
                    if !heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.submit(heard); return
                    }
                    self.beginListening(); return
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            if barge { self.voice.stopDictation() }
            if self.isActive { self.beginListening() }
        }
    }

    /// Reinicia la escucha (p. ej. al cambiar el idioma hablado desde el overlay).
    func restartListening() {
        guard isActive else { return }
        pollTask?.cancel()
        voice.stopDictation()
        beginListening()
    }

    private func beginListening() {
        guard isActive else { return }
        phase = .listening
        heard = ""
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // Espera al PRIMER arranque (permisos + motor) antes de pollear: si no,
            // el bucle rearmaba el dictado cada 200 ms mientras el permiso pendía.
            await self.voice.startDictation()
            guard self.isActive, self.phase == .listening else { return }
            var last = ""
            var stable = 0
            var emptyRearms = 0
            while self.isActive && self.phase == .listening {
                try? await Task.sleep(nanoseconds: 200_000_000)
                let t = self.voice.liveTranscript
                self.heard = t
                if !t.isEmpty && t == last { stable += 1 } else { stable = 0 }
                last = t
                // Pausa de ~1.6 s con texto → enviar.
                if stable >= 8 && !t.isEmpty { self.submit(t); return }
                if !self.voice.isListening {
                    if !t.isEmpty { self.submit(t); return }
                    // Sin utterance: re-armar, pero NO en bucle infinito silencioso.
                    emptyRearms += 1
                    if emptyRearms > 5 {
                        if self.voice.voiceError == nil {
                            self.voice.voiceError = "No se pudo iniciar el dictado. Revisa micrófono e idioma en Ajustes."
                        }
                        return
                    }
                    await self.voice.startDictation()
                    last = ""; stable = 0
                } else {
                    emptyRearms = 0
                }
            }
        }
    }

    private func submit(_ text: String) {
        voice.stopDictation()
        phase = .thinking
        heard = text
        sendUtterance?(text)
    }
}
