import XCTest
@testable import OpenPilot

/// Tests del helper puro de la rejilla de actividad (agregación, niveles, grid).
final class ActivityHeatmapTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 1
        return c
    }
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testAggregateSameDaySumsSessionsAndTokens() {
        let stats = ActivityHeatmap.aggregate([
            (date: day(2026, 11, 17), tokens: 100),
            (date: day(2026, 11, 17), tokens: 50),
        ], calendar: cal)
        XCTAssertEqual(stats.count, 1)
        let st = stats[cal.startOfDay(for: day(2026, 11, 17))]
        XCTAssertEqual(st?.sessions, 2)
        XCTAssertEqual(st?.tokens, 150)
    }

    func testAggregateSeparatesDays() {
        let stats = ActivityHeatmap.aggregate([
            (date: day(2026, 11, 16), tokens: 10),
            (date: day(2026, 11, 17), tokens: 20),
        ], calendar: cal)
        XCTAssertEqual(stats.count, 2)
    }

    func testAggregateClampsNegativeTokens() {
        let stats = ActivityHeatmap.aggregate([(date: day(2026, 11, 17), tokens: -5)], calendar: cal)
        XCTAssertEqual(stats[cal.startOfDay(for: day(2026, 11, 17))]?.tokens, 0)
        XCTAssertEqual(stats[cal.startOfDay(for: day(2026, 11, 17))]?.sessions, 1)
    }

    func testValueSelectsMetric() {
        let st = ActivityHeatmap.DayStats(sessions: 3, tokens: 999)
        XCTAssertEqual(ActivityHeatmap.value(st, metric: .sessions), 3)
        XCTAssertEqual(ActivityHeatmap.value(st, metric: .tokens), 999)
    }

    func testLevelZeroWhenNoActivityOrNoPeak() {
        XCTAssertEqual(ActivityHeatmap.level(value: 0, peak: 100), 0)
        XCTAssertEqual(ActivityHeatmap.level(value: 5, peak: 0), 0)
    }

    func testLevelQuartiles() {
        XCTAssertEqual(ActivityHeatmap.level(value: 25, peak: 100), 1)
        XCTAssertEqual(ActivityHeatmap.level(value: 26, peak: 100), 2)
        XCTAssertEqual(ActivityHeatmap.level(value: 50, peak: 100), 2)
        XCTAssertEqual(ActivityHeatmap.level(value: 51, peak: 100), 3)
        XCTAssertEqual(ActivityHeatmap.level(value: 75, peak: 100), 3)
        XCTAssertEqual(ActivityHeatmap.level(value: 76, peak: 100), 4)
        XCTAssertEqual(ActivityHeatmap.level(value: 100, peak: 100), 4)
    }

    func testGridShape() {
        let cols = ActivityHeatmap.grid(ending: day(2026, 11, 17), weeks: 4, stats: [:], calendar: cal)
        XCTAssertEqual(cols.count, 4)
        for col in cols { XCTAssertEqual(col.count, 7) }
    }

    func testGridZeroWeeksIsEmpty() {
        XCTAssertTrue(ActivityHeatmap.grid(ending: day(2026, 11, 17), weeks: 0, stats: [:], calendar: cal).isEmpty)
    }

    func testGridLastColumnContainsEnding() {
        let ending = day(2026, 11, 17)
        let cols = ActivityHeatmap.grid(ending: ending, weeks: 6, stats: [:], calendar: cal)
        let target = cal.startOfDay(for: ending)
        XCTAssertTrue(cols.last!.contains { $0.date == target })
    }

    func testGridAlignsToFirstWeekday() {
        let cols = ActivityHeatmap.grid(ending: day(2026, 11, 17), weeks: 6, stats: [:], calendar: cal)
        let first = cols.first!.first!.date
        XCTAssertEqual(cal.component(.weekday, from: first), cal.firstWeekday)
    }

    func testGridMapsStatsToCorrectDay() {
        let target = day(2026, 11, 17)
        let stats = ActivityHeatmap.aggregate([(date: target, tokens: 100)], calendar: cal)
        let cols = ActivityHeatmap.grid(ending: target, weeks: 4, stats: stats, calendar: cal)
        let key = cal.startOfDay(for: target)
        let cell = cols.flatMap { $0 }.first { $0.date == key }
        XCTAssertEqual(cell?.stats.tokens, 100)
        XCTAssertEqual(cell?.stats.sessions, 1)
    }

    func testPeakIsMaxAcrossGrid() {
        let stats = ActivityHeatmap.aggregate([
            (date: day(2026, 11, 16), tokens: 10),
            (date: day(2026, 11, 17), tokens: 300),
        ], calendar: cal)
        let cols = ActivityHeatmap.grid(ending: day(2026, 11, 17), weeks: 4, stats: stats, calendar: cal)
        XCTAssertEqual(ActivityHeatmap.peak(cols, metric: .tokens), 300)
        XCTAssertEqual(ActivityHeatmap.peak(cols, metric: .sessions), 1)
    }
}
