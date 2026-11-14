import SwiftUI

/// Micro-interacciones y componentes de pulido del chat.
enum Haptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

/// Boton que se encoge levemente al presionar (feedback tactil visual).
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Indicador de "escribiendo": tres puntos que pulsan escalonados.
struct TypingIndicator: View {
    @State private var anim = false
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(OP.textTertiary).frame(width: 7, height: 7)
                    .scaleEffect(anim ? 1 : 0.5)
                    .opacity(anim ? 1 : 0.35)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.18), value: anim)
            }
        }
        .onAppear { anim = true }
        .frame(height: 18)
        .accessibilityLabel("Escribiendo")
    }
}

/// Boton flotante para volver al final del chat.
struct ScrollToBottomButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down").font(.system(size: 14, weight: .bold))
                .foregroundStyle(OP.textPrimary)
                .frame(width: 36, height: 36)
                .background(OP.elevated)
                .clipShape(Circle())
                .overlay(Circle().stroke(OP.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
