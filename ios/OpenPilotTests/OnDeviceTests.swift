import XCTest
@testable import OpenPilot

final class OnDeviceTests: XCTestCase {
    func testFlattenSystemAndHistory() {
        let turns = [ChatTurn(role: "system", content: "Sé breve"),
                     ChatTurn(role: "user", content: "hola"),
                     ChatTurn(role: "assistant", content: "qué tal"),
                     ChatTurn(role: "user", content: "capital?")]
        let flat = OnDeviceSupport.flatten(turns)
        XCTAssertEqual(flat.instructions, "Sé breve")
        XCTAssertEqual(flat.prompt, "User: hola\nAssistant: qué tal\nUser: capital?")
    }

    func testFlattenNoSystem() {
        let flat = OnDeviceSupport.flatten([ChatTurn(role: "user", content: "x")])
        XCTAssertNil(flat.instructions)
        XCTAssertEqual(flat.prompt, "User: x")
    }

    func testDeltaIncremental() {
        XCTAssertEqual(OnDeviceSupport.delta(previous: "Hola", current: "Hola mundo"), " mundo")
        XCTAssertEqual(OnDeviceSupport.delta(previous: "", current: "abc"), "abc")
        XCTAssertEqual(OnDeviceSupport.delta(previous: "abc", current: "xyz"), "xyz")
    }

    func testAvailabilityMessage() {
        XCTAssertTrue(OnDeviceSupport.availabilityMessage(available: true, reason: nil).contains("ready"))
        XCTAssertTrue(OnDeviceSupport.availabilityMessage(available: false, reason: "deviceNotEligible").contains("deviceNotEligible"))
        XCTAssertFalse(OnDeviceSupport.availabilityMessage(available: false, reason: nil).isEmpty)
    }

    func testModels() async throws {
        let key = ""
        let ms = try await OnDeviceProvider().models(baseURL: "", apiKey: key)
        XCTAssertEqual(ms, ["apple-intelligence"])
    }

    func testFactoryRouting() {
        XCTAssertTrue(ProviderFactory.make(kind: "ondevice") is OnDeviceProvider)
        XCTAssertTrue(ProviderFactory.make(kind: "openai") is OpenAICompatibleProvider)
    }

    func testKindConstant() {
        XCTAssertEqual(OnDeviceSupport.kind, "ondevice")
        XCTAssertEqual(OnDeviceSupport.modelID, "apple-intelligence")
    }

    func testCurrentStatusNonEmpty() {
        XCTAssertFalse(OnDeviceProvider.currentStatus().isEmpty)
    }
}
