import Foundation

/// Rejilla de actividad estilo GitHub/Qoder: columnas = semanas, filas = días (7).
/// 100% puro y testeable (sin SwiftUI): agregación por día natural, niveles de
/// intensidad relativos al máximo y alineación de la rejilla al calendario.
enum ActivityHeatmap {
    struct DayStats: Equatable {
        var sessions: Int = 0
        var tokens: Int = 0
    }

    struct Cell: Equatable {
        let date: Date
        let stats: DayStats
    }

    enum Metric: String, CaseIterable, Identifiable {
        case sessions, tokens
        var id: String { rawValue }
    }

    /// Agrega items (fecha, tokens) por día natural: cada item cuenta como una
    /// sesión y sus tokens se suman. Los tokens negativos se tratan como 0.
    nonisolated static func aggregate(_ items: [(date: Date, tokens: Int)],
                                    calendar: Calendar) -> [Date: DayStats] {
        var out: [Date: DayStats] = [:]
        for it in items {
            let day = calendar.startOfDay(for: it.date)
            var st = out[day] ?? DayStats()
            st.sessions += 1
            st.tokens += max(0, it.tokens)
            out[day] = st
        }
        return out
    }

    /// Valor de una celda para la métrica elegida.
    nonisolated static func value(_ stats: DayStats, metric: Metric) -> Int {
        metric == .sessions ? stats.sessions : stats.tokens
    }

    /// Nivel 0...4 relativo al máximo de la rejilla (cuartiles):
    /// 0 si no hay actividad; 1 ≤25%, 2 ≤50%, 3 ≤75%, 4 >75% del máximo.
    nonisolated static func level(value: Int, peak: Int) -> Int {
        guard value > 0, peak > 0 else { return 0 }
        let r = Double(value) / Double(peak)
        if r <= 0.25 { return 1 }
        if r <= 0.50 { return 2 }
        if r <= 0.75 { return 3 }
        return 4
    }

    /// Construye `weeks` columnas de 7 días terminando en la semana de `ending`.
    /// La última columna contiene `ending`; el resto se alinea al inicio de semana
    /// de `calendar`. Los días sin datos quedan con stats vacíos (nivel 0).
    nonisolated static func grid(ending: Date, weeks: Int,
                                 stats: [Date: DayStats],
                                 calendar: Calendar) -> [[Cell]] {
        guard weeks > 0 else { return [] }
        let endDay = calendar.startOfDay(for: ending)
        let weekday = calendar.component(.weekday, from: endDay)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let lastColStart = calendar.date(byAdding: .day, value: -offset, to: endDay),
              let start = calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: lastColStart)
        else { return [] }
        var cols: [[Cell]] = []
        for w in 0..<weeks {
            var col: [Cell] = []
            for d in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: w * 7 + d, to: start) else { continue }
                col.append(Cell(date: day, stats: stats[day] ?? DayStats()))
            }
            cols.append(col)
        }
        return cols
    }

    /// Máximo de la métrica en toda la rejilla (para normalizar los niveles).
    nonisolated static func peak(_ cols: [[Cell]], metric: Metric) -> Int {
        cols.flatMap { $0 }.map { value($0.stats, metric: metric) }.max() ?? 0
    }
}
