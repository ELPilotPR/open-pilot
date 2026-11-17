import XCTest
@testable import OpenPilot

final class ModelCompareTests: XCTestCase {

    private func provider(_ id: String, _ name: String, models: [String]) -> ProviderConfig {
        ProviderConfig(id: id, name: name, baseURL: "https://example.com", models: models)
    }

    func testTurnsForPrompt() {
        let turns = ModelCompare.turns(for: "hola")
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].role, "user")
        XCTAssertEqual(turns[0].content, "hola")
    }

    func testApplyDeltaAppends() {
        var c = ModelCompare.Column(providerID: "p", model: "m", label: "P")
        ModelCompare.apply(.delta("Ho"), to: &c)
        ModelCompare.apply(.delta("la"), to: &c)
        XCTAssertEqual(c.text, "Hola")
    }

    func testApplyReasoningAndUsage() {
        var c = ModelCompare.Column(providerID: "p", model: "m", label: "P")
        ModelCompare.apply(.reasoning("pensando"), to: &c)
        ModelCompare.apply(.usage(promptTokens: 10, completionTokens: 42), to: &c)
        XCTAssertEqual(c.reasoning, "pensando")
        XCTAssertEqual(c.completionTokens, 42)
    }

    func testApplyDoneStopsStreaming() {
        var c = ModelCompare.Column(providerID: "p", model: "m", label: "P")
        c.isStreaming = true
        ModelCompare.apply(.done, to: &c)
        XCTAssertFalse(c.isStreaming)
    }

    func testDefaultColumnsTwoProviders() {
        let a = provider("a", "Casa", models: ["m1"])
        let b = provider("b", "Nube", models: ["m2"])
        let cols = ModelCompare.defaultColumns(providers: [a, b], preferred: a, model: "m1")
        XCTAssertEqual(cols.count, 2)
        XCTAssertEqual(cols[0].providerID, "a")
        XCTAssertEqual(cols[1].providerID, "b")
        XCTAssertEqual(cols[1].model, "m2")
    }

    func testDefaultColumnsSameProviderTwoModels() {
        let a = provider("a", "Casa", models: ["m1", "m2"])
        let cols = ModelCompare.defaultColumns(providers: [a], preferred: a, model: "m1")
        XCTAssertEqual(cols.count, 2)
        XCTAssertEqual(cols[0].model, "m1")
        XCTAssertEqual(cols[1].model, "m2")
        XCTAssertEqual(cols[0].providerID, cols[1].providerID)
    }

    func testDefaultColumnsSingleModel() {
        let a = provider("a", "Casa", models: ["m1"])
        let cols = ModelCompare.defaultColumns(providers: [a], preferred: a, model: "m1")
        XCTAssertEqual(cols.count, 1)
    }

    func testDefaultColumnsEmpty() {
        XCTAssertTrue(ModelCompare.defaultColumns(providers: [], preferred: nil, model: "").isEmpty)
    }

    // MARK: - Compare 2.0: metrics, ranking, N-way columns, winner

    func testApplyUsageCapturesPromptTokens() {
        var c = ModelCompare.Column(providerID: "p", model: "m", label: "P")
        ModelCompare.apply(.usage(promptTokens: 10, completionTokens: 42), to: &c)
        XCTAssertEqual(c.promptTokens, 10)
        XCTAssertEqual(c.completionTokens, 42)
    }

    func testAvgTPS() {
        XCTAssertEqual(ModelCompare.avgTPS(tokens: 100, elapsed: 2.0), 50.0)
        XCTAssertNil(ModelCompare.avgTPS(tokens: 100, elapsed: nil))
        XCTAssertNil(ModelCompare.avgTPS(tokens: 0, elapsed: 2.0))
        XCTAssertNil(ModelCompare.avgTPS(tokens: 100, elapsed: 0.01))
    }

    private func col(_ ttft: TimeInterval?, _ tokens: Int, _ elapsed: TimeInterval?) -> ModelCompare.Column {
        var c = ModelCompare.Column(providerID: "p", model: "m", label: "P")
        c.ttft = ttft; c.completionTokens = tokens; c.elapsed = elapsed
        return c
    }

    func testFastestTTFT() {
        let cols = [col(0.5, 10, 1.0), col(0.2, 10, 1.0), col(nil, 10, 1.0)]
        XCTAssertEqual(ModelCompare.fastestTTFT(cols), 1)
        XCTAssertNil(ModelCompare.fastestTTFT([col(nil, 0, nil)]))
    }

    func testFastestTPS() {
        let cols = [col(0.1, 10, 1.0), col(0.1, 100, 2.0), col(0.1, 0, 1.0)]
        XCTAssertEqual(ModelCompare.fastestTPS(cols), 1)
        XCTAssertNil(ModelCompare.fastestTPS([col(0.1, 0, nil)]))
    }

    func testNextColumnPicksUnusedCombo() {
        let a = provider("a", "Casa", models: ["m1", "m2"])
        let b = provider("b", "Nube", models: ["m3"])
        let existing = [ModelCompare.Column(providerID: "a", model: "m1", label: "Casa")]
        let next = ModelCompare.nextColumn(providers: [a, b], existing: existing)
        XCTAssertEqual(next?.providerID, "a")
        XCTAssertEqual(next?.model, "m2")
    }

    func testNextColumnSkipsToOtherProvider() {
        let a = provider("a", "Casa", models: ["m1"])
        let b = provider("b", "Nube", models: ["m3"])
        let existing = [ModelCompare.Column(providerID: "a", model: "m1", label: "Casa")]
        let next = ModelCompare.nextColumn(providers: [a, b], existing: existing)
        XCTAssertEqual(next?.providerID, "b")
        XCTAssertEqual(next?.model, "m3")
    }

    func testNextColumnAllUsedDuplicatesFirst() {
        let a = provider("a", "Casa", models: ["m1"])
        let existing = [ModelCompare.Column(providerID: "a", model: "m1", label: "Casa")]
        let next = ModelCompare.nextColumn(providers: [a], existing: existing)
        XCTAssertEqual(next?.providerID, "a")
        XCTAssertEqual(next?.model, "m1")
    }

    func testNextColumnEmptyProviders() {
        XCTAssertNil(ModelCompare.nextColumn(providers: [], existing: []))
    }

    @MainActor
    func testAddRemoveColumn() {
        let a = provider("a", "Casa", models: ["m1", "m2"])
        let mc = ModelCompare(columns: ModelCompare.defaultColumns(providers: [a], preferred: a, model: "m1"))
        let start = mc.columns.count
        mc.addColumn(providers: [a])
        XCTAssertEqual(mc.columns.count, start + 1)
        mc.removeColumn(id: mc.columns[0].id)
        XCTAssertEqual(mc.columns.count, start)
        while mc.columns.count > 1 { mc.removeColumn(id: mc.columns[0].id) }
        mc.removeColumn(id: mc.columns[0].id)   // must keep the last column
        XCTAssertEqual(mc.columns.count, 1)
    }

    @MainActor
    func testPickWinnerSingleAndToggle() {
        let a = provider("a", "Casa", models: ["m1", "m2"])
        let mc = ModelCompare(columns: ModelCompare.defaultColumns(providers: [a], preferred: a, model: "m1"))
        let id0 = mc.columns[0].id, id1 = mc.columns[1].id
        mc.pickWinner(id: id0)
        XCTAssertTrue(mc.columns[0].isWinner)
        XCTAssertFalse(mc.columns[1].isWinner)
        mc.pickWinner(id: id1)
        XCTAssertFalse(mc.columns[0].isWinner)
        XCTAssertTrue(mc.columns[1].isWinner)
        mc.pickWinner(id: id1)
        XCTAssertFalse(mc.columns.contains { $0.isWinner })
    }
}