import SwiftUI

/// Espectro de barras animado por el nivel de micrófono (0…1) mientras se graba.
/// Cada barra combina el nivel global con una variación determinista por índice
/// para parecer un ecualizador, sin aleatoriedad por frame (barato y estable).
struct VoiceSpectrum: View {
    let level: Float
    let active: Bool
    var barCount: Int = 24

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(active ? OP.accent : OP.textTertiary)
                    .frame(width: 4, height: barHeight(i))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
        .frame(height: 48)
        .accessibilityLabel(T("Audio level", "Nivel de audio"))
    }

    private func barHeight(_ i: Int) -> CGFloat {
        guard active else { return 4 }
        let phase = Float(i) * 0.7
        let wave = (sin(phase + level * 6) + 1) / 2   // 0…1
        let mix = level * (0.55 + 0.45 * wave)
        return CGFloat(4 + mix * 44)
    }
}