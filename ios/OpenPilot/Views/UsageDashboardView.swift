import SwiftUI
import SwiftData
import Charts

/// Dashboard de uso: tokens y coste estimado por proveedor, calculado 100% en el
/// dispositivo a partir de los tokens que ya guarda cada respuesta. Sin red.
struct UsageDashboardView: View {
    @Query private var conversations: [Conversation]
    @Query(sort: \ProviderConfig.createdAt) private var providers: [ProviderConfig]

    private var summary: UsageSummary {
        let provByID = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
        var samples: [UsageSample] = []
        for c in conversations {
            let prov = provByID[c.providerID]
            let name = prov?.name ?? c.providerID
            let local = UsagePricing.isLocal(kind: prov?.kind ?? "", baseURL: prov?.baseURL ?? "")
            let override = prov.flatMap { ProviderPricing.resolve(enabled: $0.pricingEnabled, mode: $0.pricingMode, manualIn: $0.pricingInput, manualOut: $0.pricingOutput, autoJSON: $0.autoPricingJSON, model: c.model) }
            for m in c.messages where m.role == "assistant" && (m.promptTokens + m.completionTokens) > 0 {
                samples.append(UsageSample(providerID: c.providerID, providerName: name, model: c.model,
                                           promptTokens: m.promptTokens, completionTokens: m.completionTokens,
                                           date: m.createdAt, local: local, override: override))
            }
        }
        return UsageStats.summarize(samples)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    statCard(title: T("Estimated cost", "Coste estimado"),
                             value: String(format: "$%.2f", summary.totalCost), icon: "dollarsign.circle")
                    statCard(title: T("Tokens", "Tokens"),
                             value: formatTokens(summary.totalTokens), icon: "number")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text(T("Estimates from public per-token rates. Models running on your own device or LAN count $0.",
                       "Estimaciones con tarifas públicas por token. Los modelos en tu dispositivo o LAN cuentan $0."))
            }

            Section {
                ActivityHeatmapView(conversations: conversations)
                    .padding(.vertical, 4)
            } header: {
                Text(T("Activity", "Actividad"))
            } footer: {
                Text(T("Each cell is a day; darker means more activity. Tap a day for details.",
                       "Cada celda es un día; más oscuro = más actividad. Toca un día para ver el detalle."))
            }

            if summary.totalTokens > 0 {
                Section {
                    Chart(summary.byDay) { d in
                        BarMark(x: .value("Day", d.day, unit: .day),
                                y: .value("Tokens", d.tokens))
                            .foregroundStyle(OP.accent)
                    }
                    .frame(height: 160)
                    .chartYAxis { AxisMarks(position: .leading) }
                } header: {
                    Text(T("Last 14 days", "Últimos 14 días"))
                }

                Section {
                    ForEach(summary.byProvider) { p in providerRow(p) }
                } header: {
                    Text(T("By provider", "Por proveedor"))
                }
            } else {
                Section {
                    Text(T("No usage yet. Send a message and the tokens will show up here.",
                           "Aún no hay uso. Envía un mensaje y los tokens aparecerán aquí."))
                        .foregroundStyle(OP.textSecondary)
                }
            }
        }
        .navigationTitle(T("Usage", "Uso"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(OP.textSecondary)
            Text(value).font(.title2.bold()).foregroundStyle(OP.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func providerRow(_ p: ProviderUsage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(p.providerName).font(.headline).foregroundStyle(OP.textPrimary)
                Spacer()
                Text(String(format: "$%.2f", p.costUSD)).font(.subheadline.bold()).foregroundStyle(OP.accent)
            }
            HStack(spacing: 12) {
                Text("\(formatTokens(p.totalTokens)) tokens").font(.caption).foregroundStyle(OP.textSecondary)
                Text("\(p.messages) " + T("replies", "respuestas")).font(.caption).foregroundStyle(OP.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }
}