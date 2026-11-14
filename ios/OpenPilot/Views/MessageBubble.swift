import SwiftUI
import UIKit

/// Fila de mensaje con entrada animada e indicador de "escribiendo".
struct MessageRow: View {
    let message: Message
    var isActive: Bool = false
    var onRegenerate: (() -> Void)? = nil
    @State private var copied = false
    @State private var saved = false
    @State private var appeared = false
    @State private var reasoningExpanded = false
    @ObservedObject private var voice = VoiceManager.shared

    var body: some View {
        rowContent
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                withAnimation(.spring(duration: 0.4, bounce: 0.15)) { appeared = true }
            }
    }

    @ViewBuilder
    private var rowContent: some View {
        if message.role == "user" {
            HStack {
                Spacer(minLength: 48)
                VStack(alignment: .trailing, spacing: 6) {
                    if !message.imageData.isEmpty, let ui = UIImage(data: message.imageData) {
                        Image(uiImage: ui).resizable().scaledToFit()
                            .frame(maxWidth: 240, maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.body).foregroundStyle(OP.textPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(OP.userBubble)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .textSelection(.enabled)
                    }
                }
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkle")
                    .font(.system(size: 16)).foregroundStyle(OP.textPrimary)
                    .frame(width: 26, height: 26)
                    .symbolEffect(.pulse, options: .repeating, isActive: isActive)
                VStack(alignment: .leading, spacing: 10) {
                    if !message.reasoning.isEmpty { reasoningView }
                    if let w = message.weather { WeatherCard(snap: w) }
                    if let c = message.currency { CurrencyCard(snap: c) }
                    if !message.imageData.isEmpty, let ui = UIImage(data: message.imageData) {
                        generatedImage(ui)
                    } else if message.text.isEmpty && message.reasoning.isEmpty && message.weatherData.isEmpty && message.currencyData.isEmpty {
                        TypingIndicator().padding(.vertical, 4)
                    } else if !message.text.isEmpty {
                        MarkdownView(text: message.text, sources: message.sources)
                            .textSelection(.enabled)
                    }
                    if !message.sources.isEmpty { sourcesView }
                    HStack(spacing: 12) {
                        if message.completionTokens > 0 { metricsView }
                        Spacer(minLength: 0)
                        if let onRegenerate { regenerateButton(onRegenerate) }
                        if !message.text.isEmpty { speakButton }
                        if !message.text.isEmpty { copyButton }
                    }
                }
            }
        }
    }

    private func generatedImage(_ ui: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(uiImage: ui).resizable().scaledToFit()
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Button {
                UIImageWriteToSavedPhotosAlbum(ui, nil, nil, nil)
                Haptic.success()
                saved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
            } label: {
                Label(saved ? T("Saved", "Guardada") : T("Save", "Guardar"), systemImage: saved ? "checkmark" : "square.and.arrow.down")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(saved ? OP.success : OP.textSecondary)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    /// Razonamiento en vivo: se expande solo mientras el modelo "piensa"
    /// (streaming activo y aún sin respuesta) y se colapsa al empezar el texto.
    private var isThinking: Bool { isActive && message.text.isEmpty }

    private var reasoningView: some View {
        DisclosureGroup(isExpanded: $reasoningExpanded) {
            Text(message.reasoning)
                .font(.caption).foregroundStyle(OP.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .symbolEffect(.pulse, options: .repeating, isActive: isThinking)
                Text(isThinking ? T("Thinking…", "Pensando…") : T("Reasoning", "Razonamiento"))
            }
            .font(.caption.weight(.medium)).foregroundStyle(OP.textSecondary)
        }
        .tint(OP.textSecondary)
        .onChange(of: isThinking) { _, thinking in
            withAnimation(.easeInOut(duration: 0.25)) { reasoningExpanded = thinking }
        }
        .onAppear { reasoningExpanded = isThinking }
    }

    private var metricsView: some View {
        HStack(spacing: 8) {
            Label(String(format: "%.1f tok/s", message.tokensPerSecond), systemImage: "bolt.fill")
            Text("↑\(message.promptTokens) ↓\(message.completionTokens)")
        }
        .font(.caption2)
        .foregroundStyle(OP.textTertiary)
    }

    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = message.text
            Haptic.success()
            withAnimation(.spring(duration: 0.3)) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { copied = false }
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 13))
                .foregroundStyle(copied ? OP.success : OP.textSecondary)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func regenerateButton(_ action: @escaping () -> Void) -> some View {
        Button { action(); Haptic.light() } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 13))
                .foregroundStyle(OP.textSecondary)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var speakButton: some View {
        let speaking = voice.speakingID == message.id
        return Button {
            voice.toggleSpeak(message.text, id: message.id)
            Haptic.light()
        } label: {
            Image(systemName: speaking ? "stop.circle" : "speaker.wave.2")
                .font(.system(size: 13))
                .foregroundStyle(speaking ? OP.accent : OP.textSecondary)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var sourcesView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(message.sources.enumerated()), id: \.element.id) { idx, src in
                    if let u = URL(string: src.url) {
                        Link(destination: u) {
                            HStack(spacing: 4) {
                                Text("[\(idx + 1)]").font(.caption2.weight(.bold))
                                Text(src.title.isEmpty ? src.url : src.title)
                                    .font(.caption2).lineLimit(1)
                            }
                            .foregroundStyle(OP.accent)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(OP.userBubble)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}
