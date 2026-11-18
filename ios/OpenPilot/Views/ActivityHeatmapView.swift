import SwiftUI

/// Rejilla de actividad de un año (estilo Qoder/GitHub) para el dashboard de uso.
/// Sessions o Tokens por día; la intensidad es relativa al día más activo.
/// Toda la lógica de agregación/niveles vive en `ActivityHeatmap` (puro, testeado).
struct ActivityHeatmapView: View {
    let conversations: [Conversation]
    var weeks: Int = 52
    @State private var metric: ActivityHeatmap.Metric = .tokens
    @State private var selected: ActivityHeatmap.Cell?

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        return c
    }

    private var columns: [[ActivityHeatmap.Cell]] {
        let cal = calendar
        let items = conversations.map { (date: $0.createdAt, tokens: $0.messages.reduce(0) { $0 + $1.promptTokens + $1.completionTokens }) }
        let stats = ActivityHeatmap.aggregate(items, calendar: cal)
        return ActivityHeatmap.grid(ending: Date(), weeks: weeks, stats: stats, calendar: cal)
    }

    private func label(_ m: ActivityHeatmap.Metric) -> String {
        m == .sessions ? T("Sessions", "Sesiones") : T("Tokens", "Tokens")
    }

    private func color(level: Int) -> Color {
        switch level {
        case 0: return OP.accent.opacity(0.10)
        case 1: return OP.accent.opacity(0.30)
        case 2: return OP.accent.opacity(0.52)
        case 3: return OP.accent.opacity(0.74)
        default: return OP.accent
        }
    }

    var body: some View {
        let cols = columns
        let peak = ActivityHeatmap.peak(cols, metric: metric)
        let now = Date()
        VStack(alignment: .leading, spacing: 10) {
            Picker(T("Metric", "Métrica"), selection: $metric) {
                ForEach(ActivityHeatmap.Metric.allCases) { m in
                    Text(label(m)).tag(m)
                }
            }
            .pickerStyle(.segmented)

            GeometryReader { geo in
                let gap: CGFloat = 2
                let cell = max(3, (geo.size.width - CGFloat(weeks - 1) * gap) / CGFloat(weeks))
                let gridHeight = 7 * cell + 6 * gap
                ZStack(alignment: .topLeading) {
                    // Etiquetas de mes sobre la primera columna de cada mes.
                    ForEach(Array(cols.enumerated()), id: \.offset) { idx, col in
                        if let first = col.first,
                           calendar.component(.day, from: first.date) <= 7 {
                            Text(monthLabel(first.date))
                                .font(.system(size: 8))
                                .foregroundStyle(OP.textSecondary)
                                .offset(x: CGFloat(idx) * (cell + gap), y: -12)
                        }
                    }
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(Array(cols.enumerated()), id: \.offset) { _, col in
                            VStack(spacing: gap) {
                                ForEach(Array(col.enumerated()), id: \.offset) { _, c in
                                    let v = ActivityHeatmap.value(c.stats, metric: metric)
                                    let future = c.date > now
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(future ? Color.clear : color(level: ActivityHeatmap.level(value: v, peak: peak)))
                                        .frame(width: cell, height: cell)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2)
                                                .stroke(OP.accent, lineWidth: selected == c ? 1 : 0)
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture { if !future { selected = (selected == c ? nil : c) } }
                                        .accessibilityLabel("\(dayLabel(c.date)): \(v) \(label(metric))")
                                }
                            }
                        }
                    }
                    .offset(y: 0)
                }
                .frame(width: geo.size.width, height: gridHeight, alignment: .topLeading)
            }
            .aspectRatio(CGFloat(weeks) / 7.0, contentMode: .fit)
            .padding(.top, 12)

            HStack(spacing: 4) {
                Text(T("Less", "Menos")).font(.system(size: 9)).foregroundStyle(OP.textSecondary)
                ForEach(0..<5, id: \.self) { lv in
                    RoundedRectangle(cornerRadius: 2).fill(color(level: lv)).frame(width: 9, height: 9)
                }
                Text(T("More", "Más")).font(.system(size: 9)).foregroundStyle(OP.textSecondary)
                Spacer()
                if let s = selected {
                    Text("\(dayLabel(s.date)) · \(s.stats.sessions) \(T("sessions", "sesiones")) · \(s.stats.tokens) tok")
                        .font(.system(size: 9)).foregroundStyle(OP.textSecondary).lineLimit(1)
                }
            }
        }
    }

    private func monthLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = LanguageManager.shared.current == .es ? Locale(identifier: "es") : Locale(identifier: "en")
        f.dateFormat = "LLL"
        return f.string(from: d).capitalized
    }

    private func dayLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = LanguageManager.shared.current == .es ? Locale(identifier: "es") : Locale(identifier: "en")
        f.dateFormat = "d MMM"
        return f.string(from: d)
    }
}
