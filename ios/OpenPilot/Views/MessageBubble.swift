import SwiftUI
import UIKit

/// Fila de mensaje con entrada animada e indicador de "escribiendo".
struct MessageRow: View {
    let message: Message
    var isActive: Bool = false
    var liveTPS: Double = 0
    var onRegenerate: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onVariation: (() -> Void)? = nil
    var onEditImage: (() -> Void)? = nil
    /// Navegación de versiones < n/m > (0 = sin versiones).
    var versionCurrent: Int = 0
    var versionTotal: Int = 0
    var onSwitchVersion: ((Int) -> Void)? = nil
    @State private var copied = false
    @State private var saved = false
    @State private var appeared = false
    @State private var reasoningExpanded = false
    @State private var sourcesExpanded = false
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
                VStack(alignment: .trailing, spacing: 4) {
                    VStack(alignment: .trailing, spacing: 6) {
                        if !message.imageData.isEmpty, let ui = UIImage(data: message.imageData) {
                            Image(uiImage: ui).resizable().scaledToFit()
                                .frame(maxWidth: 240, maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        if let name = message.attachmentName {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.fill").font(.system(size: 14)).foregroundStyle(OP.accent)
                                Text(name).font(.caption.weight(.medium)).foregroundStyle(OP.textPrimary).lineLimit(1)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(OP.userBubble)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    .contentShape(RoundedRectangle(cornerRadius: 20))
                    .onTapGesture { onEdit?() }
                    .contextMenu {
                        if let onEdit {
                            Button { onEdit() } label: { Label(T("Edit", "Editar"), systemImage: "pencil") }
                        }
                        Button { copyMessage() } label: { Label(T("Copy", "Copiar"), systemImage: "doc.on.doc") }
                    }
                    .accessibilityLabel(T("Your message", "Tu mensaje"))
                    .accessibilityHint(T("Tap to edit and resend", "Toca para editar y reenviar"))
                    versionNav
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
                        MarkdownView(text: message.text + (isActive ? " ▍" : ""), sources: message.sources)
                            .textSelection(.enabled)
                    }
                    if !message.sources.isEmpty { sourcesView }
                    HStack(spacing: 12) {
                        versionNav
                        if isActive && liveTPS > 0 {
                            liveMetricsView
                        } else if message.completionTokens > 0 {
                            metricsView
                        }
                        Spacer(minLength: 0)
                        if let onRegenerate { regenerateButton(onRegenerate) }
                        if !message.text.isEmpty && !isActive { speakButton }
                        if !message.text.isEmpty && !isActive { copyButton }
                        if !message.text.isEmpty && !isActive { feedbackButtons }
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
                .contextMenu {
                    if let onVariation {
                        Button { onVariation() } label: { Label(T("Create variation", "Crear variación"), systemImage: "wand.and.stars") }
                    }
                    if let onEditImage {
                        Button { onEditImage() } label: { Label(T("Edit with prompt…", "Editar con prompt…"), systemImage: "slider.horizontal.3") }
                    }
                }
            HStack(spacing: 14) {
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
                if let onVariation {
                    Button { onVariation() } label: {
                        Label(T("Variation", "Variación"), systemImage: "wand.and.stars")
                            .font(.caption.weight(.medium)).foregroundStyle(OP.textSecondary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                if let onEditImage {
                    Button { onEditImage() } label: {
                        Label(T("Edit", "Editar"), systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.medium)).foregroundStyle(OP.textSecondary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    /// Razonamiento en vivo: se expande solo mientras el modelo "piensa"
    /// (streaming activo y aún sin respuesta) y se colapsa al empezar el texto.
    private var isThinking: Bool { isActive && message.text.isEmpty }

    /// Selector de versiones < n/m > (solo si hay más de una rama hermana).
    @ViewBuilder private var versionNav: some View {
        if versionTotal > 1 {
            HStack(spacing: 2) {
                Button { onSwitchVersion?(versionCurrent - 1) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .disabled(versionCurrent <= 1)
                Text("\(versionCurrent)/\(versionTotal)")
                    .font(.caption2.weight(.medium)).monospacedDigit()
                    .foregroundStyle(OP.textSecondary)
                Button { onSwitchVersion?(versionCurrent + 1) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .disabled(versionCurrent >= versionTotal)
            }
            .buttonStyle(.plain)
            .foregroundStyle(OP.textSecondary)
            .accessibilityLabel(T("Message version \(versionCurrent) of \(versionTotal)",
                                  "Versión \(versionCurrent) de \(versionTotal) del mensaje"))
        }
    }

    private var reasoningView: some View {
        DisclosureGroup(isExpanded: $reasoningExpanded) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(message.reasoning)
                            .font(.caption).foregroundStyle(OP.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        Color.clear.frame(height: 1).id("reasoningEnd")
                    }
                    .padding(.top, 4)
                }
                .frame(maxHeight: 180)
                .onChange(of: message.reasoning) { _, _ in
                    if isThinking { proxy.scrollTo("reasoningEnd", anchor: .bottom) }
                }
                .onAppear { if isThinking { proxy.scrollTo("reasoningEnd", anchor: .bottom) } }
            }
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

    /// Velocidad EN VIVO mientras el modelo genera (tok/s pulsante en azul).
    private var liveMetricsView: some View {
        let thermal = DeviceHealth.thermalTier
        return HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .symbolEffect(.pulse, options: .repeating, isActive: true)
            Text(LiveSpeed.label(liveTPS))
                .monospacedDigit()
            if thermal.shouldWarn {
                Image(systemName: thermal.symbol)
                    .foregroundStyle(thermal == .critical ? .red : .orange)
                    .accessibilityLabel(thermal.label)
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(OP.accent)
        .accessibilityLabel(T("Generating", "Generando") + ", " + LiveSpeed.label(liveTPS)
                            + (thermal.shouldWarn ? ", " + thermal.label : ""))
    }

    private func copyMessage() {
        UIPasteboard.general.string = message.text
        Haptic.success()
        withAnimation(.spring(duration: 0.3)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { copied = false } }
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
                .accessibilityLabel(T("Copy", "Copiar"))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func regenerateButton(_ action: @escaping () -> Void) -> some View {
        Button { action(); Haptic.light() } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 13))
                .foregroundStyle(OP.textSecondary)
                .accessibilityLabel(T("Regenerate", "Regenerar"))
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
                .accessibilityLabel(speaking ? T("Stop speaking", "Dejar de leer") : T("Read aloud", "Leer en voz alta"))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    /// 👍/👎 sobre la respuesta. El voto se persiste en el mensaje.
    @ViewBuilder private var feedbackButtons: some View {
        Button {
            message.toggleFeedback(1); Haptic.light()
        } label: {
            Image(systemName: message.feedback == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                .font(.system(size: 13))
                .foregroundStyle(message.feedback == 1 ? OP.accent : OP.textSecondary)
                .accessibilityLabel(T("Good response", "Buena respuesta"))
        }
        .buttonStyle(ScaleButtonStyle())
        Button {
            message.toggleFeedback(-1); Haptic.light()
        } label: {
            Image(systemName: message.feedback == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                .font(.system(size: 13))
                .foregroundStyle(message.feedback == -1 ? OP.danger : OP.textSecondary)
                .accessibilityLabel(T("Bad response", "Mala respuesta"))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var sourcesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { sourcesExpanded.toggle() }
                Haptic.selection()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe").font(.caption2)
                    Text(T("Sources (\(message.sources.count))", "Fuentes (\(message.sources.count))"))
                        .font(.caption.weight(.semibold))
                    Image(systemName: sourcesExpanded ? "chevron.up" : "chevron.down").font(.caption2)
                }
                .foregroundStyle(OP.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(T("Sources", "Fuentes"))
            .accessibilityValue("\(message.sources.count)")
            if sourcesExpanded {
                VStack(spacing: 6) {
                    ForEach(Array(message.sources.enumerated()), id: \.element.id) { idx, src in
                        sourceRow(idx: idx, src: src)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(message.sources.enumerated()), id: \.element.id) { idx, src in
                            if let u = URL(string: src.url) {
                                Link(destination: u) {
                                    HStack(spacing: 5) {
                                        FaviconView(url: src.url, size: 14)
                                        Text("[\(idx + 1)]").font(.caption2.weight(.bold))
                                        Text(src.title.isEmpty ? CitationReference.domain(of: src.url) : src.title)
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
    }

    private func sourceRow(idx: Int, src: WebSource) -> some View {
        Group {
            if let u = URL(string: src.url) {
                Link(destination: u) { sourceRowContent(idx: idx, src: src) }
            } else {
                sourceRowContent(idx: idx, src: src)
            }
        }
    }

    private func sourceRowContent(idx: Int, src: WebSource) -> some View {
        HStack(alignment: .top, spacing: 8) {
            FaviconView(url: src.url, size: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("[\(idx + 1)]").font(.caption2.weight(.bold)).foregroundStyle(OP.accent)
                    Text(src.title.isEmpty ? src.url : src.title)
                        .font(.caption.weight(.semibold)).foregroundStyle(OP.textPrimary).lineLimit(1)
                }
                Text(CitationReference.domain(of: src.url)).font(.caption2).foregroundStyle(OP.textTertiary)
                if !src.snippet.isEmpty {
                    Text(src.snippet).font(.caption2).foregroundStyle(OP.textSecondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(OP.textTertiary)
        }
        .padding(10)
        .background(OP.userBubble)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
