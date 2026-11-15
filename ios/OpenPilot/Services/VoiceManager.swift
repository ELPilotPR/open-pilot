import Foundation
import AVFoundation
import Speech
import SwiftUI

/// Voz 100% on-device (sin backend nuestro): dictado con Speech de Apple y
/// lectura en voz alta con AVSpeechSynthesizer. Singleton compartido para que
/// solo suene una voz a la vez y el dictado alimente el composer.
@MainActor
final class VoiceManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = VoiceManager()

    // Dictado
    @Published var isListening = false
    @Published var liveTranscript = ""
    @Published var voiceError: String?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    // Lectura en voz alta
    @Published var speakingID: UUID?
    private let synth = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synth.delegate = self
    }

    // MARK: - Dictado

    func toggleDictation() {
        if isListening { stopDictation(); return }
        Task { await startDictation() }
    }

    func startDictation() async {
        voiceError = nil
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard status == .authorized else {
            voiceError = "Permiso de reconocimiento de voz denegado. Actívalo en Ajustes → Open Pilot."
            return
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard mic else {
            voiceError = "Permiso de micrófono denegado. Actívalo en Ajustes → Open Pilot."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            voiceError = "El reconocimiento de voz no está disponible ahora."
            return
        }
        stopSpeaking()
        stopEngine()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Un I/O previo (p.ej. el altavoz) puede seguir soltando el hardware:
            // espera un instante y reintenta una vez antes de rendirte.
            try? await Task.sleep(nanoseconds: 250_000_000)
            do {
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                voiceError = "No se pudo iniciar el audio. Cierra otras apps que usen el micrófono (llamadas, grabadora) e inténtalo de nuevo."
                return
            }
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req
        let input = engine.inputNode
        try? input.setVoiceProcessingEnabled(true)   // echo cancellation (barge-in)
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch {
            voiceError = "No se pudo iniciar el micrófono."
            request = nil; task = nil
            return
        }
        liveTranscript = ""
        isListening = true
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result { self.liveTranscript = result.bestTranscription.formattedString }
                if error != nil || (result?.isFinal ?? false) { self.stopDictation() }
            }
        }
    }

    func stopDictation() {
        guard isListening else { return }
        stopEngine()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        // NO desactivar la sesión aquí: desactivar/cambiar con I/O recién parado
        // provoca el error de activación (!pri). Se deja activa para el TTS.
    }

    private func stopEngine() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
    }

    // MARK: - Lectura en voz alta

    func toggleSpeak(_ text: String, id: UUID) {
        if speakingID == id { stopSpeaking(); return }
        stopDictation()
        stopSpeaking()
        let clean = Self.plainText(text)
        guard !clean.isEmpty else { return }
        let session = AVAudioSession.sharedInstance()
        // Misma categoría que el dictado (.playAndRecord) para no cambiar de
        // categoría con I/O corriendo (causa del error de activación).
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        let utt = AVSpeechUtterance(string: clean)
        let prefix = VoiceCatalog.currentPrefix
        utt.voice = AVSpeechSynthesisVoice(identifier: VoiceSettings.identifier)
            ?? AVSpeechSynthesisVoice(language: prefix == "es" ? "es-ES" : "en-US")
            ?? AVSpeechSynthesisVoice(language: prefix)
        utt.rate = AVSpeechUtteranceDefaultSpeechRate
        speakingID = id
        synth.speak(utt)
    }

    func stopSpeaking() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        speakingID = nil
    }

    /// Quita markdown/citas para que la lectura suene natural.
    private static func plainText(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "```[\\s\\S]*?```", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\[\\d+\\]", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "[*#`>]", with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingID = nil }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingID = nil }
    }
}