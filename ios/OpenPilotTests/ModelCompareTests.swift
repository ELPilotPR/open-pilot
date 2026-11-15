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
}