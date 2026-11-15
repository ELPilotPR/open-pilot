import SwiftUI
import SwiftData

struct KeyboardSettingsView: View {
    @AppStorage("keyboardEnabled") private var enabled = false
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section {
                Toggle(T("Enable AI Keyboard", "Activar teclado IA"), isOn: $enabled)
            } footer: {
                Text(T("Shares your active OpenAI-compatible provider with the Open Pilot keyboard so you can ask from any app. Your API key lives in the shared app group while this is on.",
                       "Comparte tu proveedor OpenAI-compatible activo con el teclado de Open Pilot para preguntar desde cualquier app. Tu clave vive en el app group compartido mientras esté activo."))
            }
            Section(T("Setup", "Configuración")) {
                Text(T("1. Settings → General → Keyboard → Keyboards → Add New Keyboard… → Open Pilot.",
                       "1. Ajustes → General → Teclado → Teclados → Añadir nuevo teclado… → Open Pilot."))
                Text(T("2. Tap Open Pilot and allow Full Access (needed to reach your model).",
                       "2. Toca Open Pilot y permite Acceso completo (necesario para llegar a tu modelo)."))
                Text(T("3. Switch to the Open Pilot keyboard (🌐), type a prompt, Ask, then Insert.",
                       "3. Cambia al teclado Open Pilot (🌐), escribe, Ask y luego Insert."))
            }
        }
        .navigationTitle(T("AI Keyboard", "Teclado IA"))
        .onChange(of: enabled) { _, _ in KeyboardBridge.refresh(context: context) }
    }
}