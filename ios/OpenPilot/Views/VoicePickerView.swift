import SwiftUI

/// Picks the on-device TTS voice and toggles barge-in (interrupt the assistant
/// by speaking). All voices come from the device; nothing is downloaded.
struct VoicePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected = VoiceSettings.identifier
    @State private var bargeIn = VoiceSettings.bargeIn
    @State private var voices: [VoiceOption] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(T("Voice", "Voz"), selection: $selected) {
                        Text(T("Automatic", "Automática")).tag("")
                        ForEach(voices) { v in
                            Text("\(v.name) · \(v.language)").tag(v.id)
                        }
                    }
                    Toggle(T("Interrupt when I speak", "Interrumpir cuando hablo"), isOn: $bargeIn)
                } header: {
                    Text(T("Speech", "Voz"))
                } footer: {
                    Text(T("Voices are provided by the device. “Interrupt when I speak” lets you cut the assistant off mid-sentence in live voice mode.",
                           "Las voces las provee el dispositivo. “Interrumpir cuando hablo” te deja cortar al asistente a media frase en el modo de voz en vivo."))
                }
                Section {
                    Button {
                        save()
                        VoiceManager.shared.toggleSpeak(
                            T("Hello, this is Open Pilot speaking.", "Hola, esto es Open Pilot hablando."),
                            id: UUID())
                    } label: {
                        Label(T("Preview voice", "Probar voz"), systemImage: "speaker.wave.2")
                    }
                }
            }
            .navigationTitle(T("Voice", "Voz"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Done", "Listo")) { save(); dismiss() }
                }
            }
            .onAppear { voices = VoiceCatalog.options(for: VoiceCatalog.currentPrefix) }
        }
    }

    private func save() {
        VoiceSettings.identifier = selected
        VoiceSettings.bargeIn = bargeIn
    }
}