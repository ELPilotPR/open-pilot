import SwiftUI

/// Editor de instrucciones personalizadas persistentes (dos campos estilo
/// "custom instructions" + interruptor). Todo se guarda en el dispositivo.
struct CustomInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("customInstructionsEnabled") private var enabled = true
    @AppStorage("customAboutYou") private var aboutYou = ""
    @AppStorage("customResponsePrefs") private var responsePrefs = ""

    var body: some View {
        List {
            Section {
                Toggle(T("Enable custom instructions", "Activar instrucciones personalizadas"), isOn: $enabled)
            } footer: {
                Text(T("Applied to every new message, across all your providers. Stored only on this iPhone.",
                       "Se aplican a cada mensaje nuevo, en todos tus proveedores. Se guardan solo en este iPhone."))
            }

            Section {
                TextEditor(text: $aboutYou)
                    .frame(minHeight: 96)
                    .disabled(!enabled)
                    .accessibilityLabel(T("About you", "Sobre ti"))
            } header: {
                Text(T("What should the model know about you?", "¿Qué debería saber el modelo sobre ti?"))
            } footer: {
                Text(T("Context, preferences, projects — anything that helps it tailor answers.",
                       "Contexto, preferencias, proyectos: lo que ayude a personalizar las respuestas."))
            }

            Section {
                TextEditor(text: $responsePrefs)
                    .frame(minHeight: 96)
                    .disabled(!enabled)
                    .accessibilityLabel(T("Response preferences", "Preferencias de respuesta"))
            } header: {
                Text(T("How should it respond?", "¿Cómo quieres que responda?"))
            } footer: {
                Text(T("Tone, format, length, language — e.g. “always in Spanish, use tables”.",
                       "Tono, formato, longitud, idioma: p. ej. «siempre en español, usa tablas»."))
            }
        }
        .scrollContentBackground(.hidden)
        .background(OP.canvas)
        .tint(OP.accent)
        .navigationTitle(T("Custom instructions", "Instrucciones personalizadas"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(T("Done", "Listo")) { dismiss() }
            }
        }
    }
}
