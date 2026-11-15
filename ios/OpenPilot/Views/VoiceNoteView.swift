import SwiftUI

/// Nota de voz: grabar → transcribir → insertar el texto en el composer.
struct VoiceNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rec = VoiceNoteRecorder()
    var onInsert: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: rec.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 84))
                    .foregroundStyle(rec.isRecording ? OP.danger : OP.accent)
                    .symbolEffect(.pulse, isActive: rec.isRecording)
                Text(rec.isRecording ? VoiceNoteSupport.formatDuration(rec.elapsed)
                                     : T("Tap record and speak", "Toca grabar y habla"))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(OP.textSecondary)
                if rec.isProcessing { ProgressView(T("Transcribing…", "Transcribiendo…")) }
                if !rec.transcript.isEmpty {
                    Text(rec.transcript)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                if let e = rec.error {
                    Text(e).font(.caption).foregroundStyle(OP.danger)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        Task { if rec.isRecording { await rec.stop() } else { await rec.start() } }
                    } label: {
                        Label(rec.isRecording ? T("Stop", "Detener") : T("Record", "Grabar"),
                              systemImage: rec.isRecording ? "stop.fill" : "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(rec.isProcessing)
                    if !rec.transcript.isEmpty {
                        Button { onInsert(rec.transcript); dismiss() } label: {
                            Label(T("Use", "Usar"), systemImage: "checkmark").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle(T("Voice note", "Nota de voz"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Close", "Cerrar")) { rec.cancel(); dismiss() }
                }
            }
        }
    }
}