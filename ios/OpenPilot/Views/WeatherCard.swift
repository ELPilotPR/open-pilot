import SwiftUI
import Charts

/// Tarjeta de clima nativa (GenUI): location + temperatura grande + toggle F/C
/// + tira diaria seleccionable
/// + gráfica horaria (área naranja para temperatura, barras azules para lluvia).
/// Datos de Open-Meteo (WeatherService), sin backend.
struct WeatherCard: View {
    let snap: WeatherSnapshot
    @State private var unit: String
    @State private var focusDay: String
    @State private var focusMode: Mode = .temp
    enum Mode { case temp, precip }

    init(snap: WeatherSnapshot) {
        self.snap = snap
        _unit = State(initialValue: snap.defaultUnit)
        _focusDay = State(initialValue: snap.daily.first?.date ?? "")
    }

    // Conversión canónica (°C/km·h) → unidad elegida.
    private func temp(_ c: Double) -> Int { Int((unit == "F" ? c * 9 / 5 + 32 : c).rounded()) }
    private func wind(_ kmh: Double) -> Int { Int((unit == "F" ? kmh * 0.621371 : kmh).rounded()) }
    private var windUnit: String { unit == "F" ? "mph" : "km/h" }
    private var focusedDay: WeatherSnapshot.Day? { snap.daily.first { $0.date == focusDay } ?? snap.daily.first }
    private var focusedHours: [WeatherSnapshot.Hour] { snap.hourly.filter { $0.dayKey == focusDay } }
    private var tempDomain: ClosedRange<Int> {
        let vals = focusedHours.map { temp($0.temp) }
        let lo = (vals.min() ?? 0) - 2
        let hi = (vals.max() ?? 10) + 2
        return lo...max(hi, lo + 1)
    }
    private let orange = Color(red: 0.945, green: 0.627, blue: 0.227) // #F1A03A del RE

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            hero
            if let d = focusedDay { todayStats(d) }
            dailyStrip
            Picker("", selection: $focusMode) {
                Text(T("Temperature", "Temperatura")).tag(Mode.temp)
                Text(T("Rain", "Lluvia")).tag(Mode.precip)
            }
            .pickerStyle(.segmented)
            hourlyChart
            Text(T("Source: Open-Meteo", "Fuente: Open-Meteo"))
                .font(.caption2).foregroundStyle(OP.textTertiary)
        }
        .padding(14)
        .background(OP.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(OP.border, lineWidth: 1))
    }

    // MARK: - Header (location + toggle F/C)

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.caption2).foregroundStyle(OP.textTertiary)
            Text(snap.location)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(OP.textPrimary).lineLimit(1)
            Spacer(minLength: 4)
            HStack(spacing: 0) {
                unitButton("F")
                unitButton("C")
            }
            .background(OP.composerBg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(OP.border, lineWidth: 1))
        }
    }

    private func unitButton(_ u: String) -> some View {
        Button { unit = u } label: {
            Text("°\(u)")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(unit == u ? OP.textPrimary : OP.textTertiary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(unit == u ? OP.accent.opacity(0.25) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero (temperatura actual grande + icono + condición)

    private var hero: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(temp(snap.current.temp))°")
                    .font(.system(size: 46, weight: .light, design: .rounded))
                    .foregroundStyle(OP.textPrimary)
                Text(WMO.describe(snap.current.code, isDay: snap.current.isDay).desc)
                    .font(.subheadline).foregroundStyle(OP.textSecondary)
                Text(T("Feels like", "Sensación") + " \(temp(snap.current.feelsLike))°")
                    .font(.caption).foregroundStyle(OP.textTertiary)
            }
            Spacer()
            Image(systemName: WMO.describe(snap.current.code, isDay: snap.current.isDay).symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 54))
        }
    }

    // MARK: - Datos del día enfocado

    private func todayStats(_ d: WeatherSnapshot.Day) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                stat(T("High", "Máx"), "\(temp(d.high))°")
                stat(T("Low", "Mín"), "\(temp(d.low))°")
                stat(T("Wind", "Viento"), "\(WMO.windDir(snap.current.windDirection)) \(wind(snap.current.windSpeed)) \(windUnit)")
                stat(T("Rain", "Lluvia"), "\(d.precip)%")
            }
            HStack(spacing: 16) {
                stat(T("Humidity", "Humedad"), "\(snap.current.humidity)%")
                if !d.sunset.isEmpty { stat(T("Sunset", "Ocaso"), d.sunset) }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(OP.textTertiary)
            Text(value).font(.footnote).fontWeight(.medium).foregroundStyle(OP.textPrimary)
        }
    }

    // MARK: - Tira diaria seleccionable

    private var dailyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(snap.daily, id: \.date) { d in
                    Button { focusDay = d.date } label: {
                        VStack(spacing: 4) {
                            Text(d.label).font(.caption2)
                                .foregroundStyle(focusDay == d.date ? OP.textPrimary : OP.textSecondary)
                            Image(systemName: WMO.describe(d.code).symbol)
                                .symbolRenderingMode(.multicolor).font(.system(size: 20))
                            Text("\(temp(d.high))°").font(.caption).fontWeight(.semibold)
                                .foregroundStyle(OP.textPrimary)
                            Text("\(temp(d.low))°").font(.caption2)
                                .foregroundStyle(OP.textTertiary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(focusDay == d.date ? OP.accent.opacity(0.16) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Gráfica horaria (Swift Charts)

    private var hourlyChart: some View {
        let hours = Array(focusedHours.enumerated())
        return Chart {
            if focusMode == .temp {
                ForEach(hours, id: \.element.time) { idx, h in
                    AreaMark(x: .value("Hora", idx), y: .value("Temp", temp(h.temp)))
                        .foregroundStyle(LinearGradient(colors: [orange.opacity(0.45), orange.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.linear)
                    LineMark(x: .value("Hora", idx), y: .value("Temp", temp(h.temp)))
                        .foregroundStyle(orange)
                        .interpolationMethod(.linear)
                }
            } else {
                ForEach(hours, id: \.element.time) { idx, h in
                    BarMark(x: .value("Hora", idx), y: .value("Lluvia", h.precip))
                        .foregroundStyle(Color.blue.opacity(0.7))
                }
            }
        }
        .chartYScale(domain: focusMode == .precip ? 0...100 : tempDomain)
        .chartXScale(domain: 0...max(focusedHours.count - 1, 1))
        .chartXAxis {
            AxisMarks(values: .stride(by: 6)) { value in
                AxisValueLabel {
                    if let i = value.as(Int.self), i >= 0, i < focusedHours.count {
                        Text(focusedHours[i].label).font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(OP.border.opacity(0.5))
                AxisValueLabel().font(.caption2)
            }
        }
        .frame(height: 120)
    }
}
