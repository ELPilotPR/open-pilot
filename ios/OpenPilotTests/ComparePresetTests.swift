import XCTest
@testable import OpenPilot

/// Tests de los presets del comparador: lógica pura + persistencia local.
final class ComparePresetTests: XCTestCase {

    private func col(_ p: String, _ m: String, _ l: String) -> ModelCompare.Column {
        ModelCompare.Column(providerID: p, model: m, label: l)
    }

    func testMakePresetMapsColumns() {
        let preset = ModelCompare.makePreset(name: "A vs B", columns: [col("p1", "m1", "A"), col("p2", "m2", "B")])
        XCTAssertEqual(preset.name, "A vs B")
        XCTAssertEqual(preset.columns.count, 2)
        XCTAssertEqual(preset.columns[0].providerID, "p1")
        XCTAssertEqual(preset.columns[0].model, "m1")
        XCTAssertEqual(preset.columns[0].label, "A")
        XCTAssertEqual(preset.columns[1].providerID, "p2")
    }

    func testColumnsFromPresetAreFreshAndIdle() {
        let preset = ModelCompare.makePreset(name: "X", columns: [col("p1", "m1", "A"), col("p2", "m2", "B")])
        let cols = ModelCompare.columns(from: preset)
        XCTAssertEqual(cols.count, 2)
        XCTAssertEqual(cols[0].providerID, "p1")
        XCTAssertEqual(cols[1].model, "m2")
        XCTAssertEqual(cols[1].label, "B")
        XCTAssertTrue(cols[0].text.isEmpty)
        XCTAssertFalse(cols[0].isStreaming)
        XCTAssertNil(cols[0].ttft)
    }

    func testUpsertAppendsNewestFirst() {
        let a = ModelCompare.Preset(name: "A", columns: [])
        let b = ModelCompare.Preset(name: "B", columns: [])
        let list = ModelCompare.upsert(b, into: ModelCompare.upsert(a, into: []))
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.first?.name, "B")
    }

    func testUpsertReplacesSameID() {
        var a = ModelCompare.Preset(name: "A", columns: [])
        let list1 = ModelCompare.upsert(a, into: [])
        a.name = "A2"
        let list2 = ModelCompare.upsert(a, into: list1)
        XCTAssertEqual(list2.count, 1)
        XCTAssertEqual(list2.first?.name, "A2")
    }

    func testUpsertRespectsLimit() {
        var list: [ModelCompare.Preset] = []
        for i in 0..<25 {
            list = ModelCompare.upsert(ModelCompare.Preset(name: "p\(i)", columns: []), into: list, limit: 20)
        }
        XCTAssertEqual(list.count, 20)
        XCTAssertEqual(list.first?.name, "p24")
    }

    func testRemoveByID() {
        let a = ModelCompare.Preset(name: "A", columns: [])
        let b = ModelCompare.Preset(name: "B", columns: [])
        let list = ModelCompare.remove(id: a.id, from: [a, b])
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.id, b.id)
    }

    func testSaveLoadRoundtrip() {
        let name = "op.preset.roundtrip"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        let p = ModelCompare.makePreset(name: "Fast vs Smart", columns: [col("p1", "m1", "A"), col("p2", "m2", "B")])
        ModelCompare.savePresets([p], d)
        XCTAssertEqual(ModelCompare.loadPresets(d), [p])
        d.removePersistentDomain(forName: name)
    }

    func testLoadEmptyWhenNoKey() {
        let name = "op.preset.empty"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        XCTAssertTrue(ModelCompare.loadPresets(d).isEmpty)
    }
}
