import SwiftUI

/// Bienvenida de primera vez: qué es Open Pilot y sus diferenciadores.
/// Se muestra una sola vez (flag `hasOnboarded`); re-visible desde Ajustes.
struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0

    private struct Card: Identifiable {
        let id = UUID()
        let symbol: String?      // nil → usa el logo de la app
        let title: String
        let body: String
    }

    private var cards: [Card] {
        [
            Card(symbol: nil,
                 title: T("Welcome to Open Pilot", "Bienvenido a Open Pilot"),
                 body: T("Private AI chat, your models. No backend — your iPhone talks straight to the model.",
                         "Chat de IA privado, con tus modelos. Sin backend: tu iPhone habla directo con el modelo.")),
            Card(symbol: "gauge.with.needle",
                 title: T("See everything", "Míralo todo"),
                 body: T("Live tokens per second and a context gauge on every chat, so you always know what's happening.",
                         "Tokens por segundo en vivo y un medidor de contexto en cada chat, para saber siempre qué pasa.")),
            Card(symbol: "server.rack",
                 title: T("Your models", "Tus modelos"),
                 body: T("A local server, cloud APIs, on-device Apple Intelligence, or a GGUF running on the phone. You choose.",
                         "Un server local, APIs en la nube, Apple Intelligence en el dispositivo o un GGUF corriendo en el teléfono. Tú eliges.")),
            Card(symbol: "lock.shield",
                 title: T("Private by design", "Privado por diseño"),
                 body: T("Keys in the Keychain, chats on device. Nothing leaves your phone except the calls you make to your models.",
                         "Claves en el Keychain, chats en el dispositivo. Nada sale de tu teléfono salvo las llamadas que haces a tus modelos.")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(T("Skip", "Saltar")) { onDone() }
                    .font(.subheadline).foregroundStyle(OP.textSecondary)
                    .padding(16)
            }
            TabView(selection: $page) {
                ForEach(Array(cards.enumerated()), id: \.offset) { idx, card in
                    VStack(spacing: 20) {
                        Spacer()
                        if let symbol = card.symbol {
                            Image(systemName: symbol)
                                .font(.system(size: 64, weight: .light))
                                .foregroundStyle(OP.accent)
                        } else {
                            Image("Logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        Text(card.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(OP.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(card.body)
                            .font(.body)
                            .foregroundStyle(OP.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                        Spacer()
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < cards.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onDone()
                }
                Haptic.light()
            } label: {
                Text(page < cards.count - 1 ? T("Next", "Siguiente") : T("Get started", "Empezar"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(OP.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(OP.canvas.ignoresSafeArea())
    }
}