import SwiftUI
import Charts

/// Tarjeta de conversión de divisas (GenUI). Datos de frankfurter.dev (BCE, sin
/// key). Estilo: paleta OP.
struct CurrencyCard: View {
    let snap: CurrencySnapshot

    private var trendPct: Double? {
        guard let first = snap.history.first?.value, let last = snap.history.last?.value, first > 0 else { return nil }
        return (last - first) / first * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            result
            rateRow
            if snap.history.count >= 2 { sparkline }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OP.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(OP.border, lineWidth: 1))
    }

    private var header: some View {
        HStack {
            Label(T("Currency conversion", "Conversión de divisas"), systemImage: "arrow.left.arrow.right.circle.fill")
                .font(.footnote.weight(.semibold)).foregroundStyle(OP.textSecondary)
            Spacer()
            Text(snap.date).font(.caption2).foregroundStyle(OP.textTertiary)
        }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(fmt(snap.converted)) \(snap.to)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(OP.textPrimary)
            Text("\(fmt(snap.amount)) \(snap.from) · \(snap.fromName)")
                .font(.footnote).foregroundStyle(OP.textSecondary)
        }
    }

    private var rateRow: some View {
        HStack(spacing: 6) {
            Text("1 \(snap.from) = \(String(format: "%.4f", snap.rate)) \(snap.to)")
                .font(.caption).foregroundStyle(OP.textSecondary)
            if let t = trendPct {
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: t >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%.2f%%", abs(t)))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(t >= 0 ? Color.green : Color.red)
            }
        }
    }

    private var sparkline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(T("Last 30 days", "Últimos 30 días")).font(.caption2).foregroundStyle(OP.textTertiary)
            Chart(snap.history, id: \.date) { p in
                AreaMark(x: .value("Fecha", p.date), y: .value("Tasa", p.value))
                    .foregroundStyle(OP.accent.opacity(0.12))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Fecha", p.date), y: .value("Tasa", p.value))
                    .foregroundStyle(OP.accent)
                    .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: yDomain)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 64)
        }
    }

    private var yDomain: ClosedRange<Double> {
        let vals = snap.history.map { $0.value }
        let lo = vals.min() ?? 0, hi = vals.max() ?? 1
        let pad = max((hi - lo) * 0.15, hi * 0.001)
        return (lo - pad)...(hi + pad)
    }

    private func fmt(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }
}