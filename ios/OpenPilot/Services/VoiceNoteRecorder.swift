import Foundation
import AVFoundation
import Speech

/// Graba una nota de voz a fichero (AVAudioRecorder) y la transcribe con Speech
/// de Apple (SFSpeechURLRecognitionRequest). On-device cuando el modelo lo permite.
@MainActor
final class VoiceNoteRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var transcript = ""
    @Published var error: String?
    @Published var elapsed = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    private final class ResumeBox { var resumed = false }

    func start() async {
        error = nil; transcript = ""
        let status = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard status == .authorized else { error = "Permiso de reconocimiento de voz denegado."; return }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard mic else { error = "Permiso de micrófono denegado."; return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(VoiceNoteSupport.fileName())
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.record()
            recorder = r; fileURL = url; isRecording = true; elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.elapsed += 1 }
            }
        } catch {
            self.error = "No se pudo iniciar la grabación."
        }
    }

    func stop() async {
        guard isRecording else { return }
        recorder?.stop(); recorder = nil
        timer?.invalidate(); timer = nil
        isRecording = false
        guard let url = fileURL else { return }
        isProcessing = true
        transcript = await transcribe(url) ?? ""
        isProcessing = false
        if transcript.isEmpty { error = "No se entendió el audio. Inténtalo de nuevo." }
        try? FileManager.default.removeItem(at: url)
        fileURL = nil
    }

    func cancel() {
        recorder?.stop(); recorder = nil
        timer?.invalidate(); timer = nil
        isRecording = false; isProcessing = false
        if let u = fileURL { try? FileManager.default.removeItem(at: u); fileURL = nil }
    }

    private func transcribe(_ url: URL) async -> String? {
        guard let recognizer, recognizer.isAvailable else { return nil }
        let req = SFSpeechURLRecognitionRequest(url: url)
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        let box = ResumeBox()
        return await withCheckedContinuation { cont in
            recognizer.recognitionTask(with: req) { result, error in
                if box.resumed { return }
                if let result, result.isFinal {
                    box.resumed = true
                    cont.resume(returning: VoiceNoteSupport.cleanTranscript(result.bestTranscription.formattedString))
                } else if error != nil {
                    box.resumed = true
                    cont.resume(returning: nil)
                }
            }
        }
    }
}