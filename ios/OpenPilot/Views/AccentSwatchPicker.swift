import SwiftUI

/// Fila de muestras circulares para elegir el color de acento de la app.
struct AccentSwatchPicker: View {
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(AccentTheme.allCases) { theme in
                    Button {
                        selection = theme.rawValue
                        Haptic.medium()
                    } label: {
                        Circle()
                            .fill(theme.color)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(OP.textPrimary,
                                                           lineWidth: selection == theme.rawValue ? 2.5 : 0))
                            .overlay(Image(systemName: "checkmark")
                                .font(.caption.bold()).foregroundStyle(.white)
                                .opacity(selection == theme.rawValue ? 1 : 0))
                            .accessibilityLabel(theme.label)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}