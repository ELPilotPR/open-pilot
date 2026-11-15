import SwiftUI
import Charts

/// Renders a CSV table as a bar chart: the first column supplies category labels and
/// the first fully-numeric column supplies the values. Pure on-device, no network.
struct CSVChartView: View {
    let table: CodeInterpreter.CSVTable

    private struct Point: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    private var points: [Point] {
        guard let yi = table.firstNumericColumn else { return [] }
        let xi = yi == 0 ? min(1, table.columns.count - 1) : 0
        guard let values = table.numericValues(yi) else { return [] }
        return zip(table.rows, values).map { row, v in
            let label = xi < row.count ? row[xi] : ""
            return Point(label: label.isEmpty ? "—" : label, value: v)
        }
    }

    private var valueName: String {
        guard let yi = table.firstNumericColumn else { return "" }
        return table.columns[yi]
    }

    var body: some View {
        if points.isEmpty {
            Text(T("No numeric column to chart", "No hay columna numérica para graficar"))
                .font(.caption)
                .foregroundStyle(OP.textTertiary)
                .padding(12)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(valueName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(OP.textTertiary)
                Chart(points) { p in
                    BarMark(
                        x: .value("Category", p.label),
                        y: .value(valueName, p.value)
                    )
                    .foregroundStyle(OP.accent)
                    .cornerRadius(4)
                }
                .frame(height: 180)
            }
            .padding(12)
        }
    }
}