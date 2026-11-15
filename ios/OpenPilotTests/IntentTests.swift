import XCTest
import AppIntents
@testable import OpenPilot

final class IntentTests: XCTestCase {
    func testAskTurns() {
        let turns = IntentSupport.askTurns(question: "¿capital de Francia?")
        XCTAssertEqual(turns.count, 2)
        XCTAssertEqual(turns[0].role, "system")
        XCTAssertEqual(turns[1].role, "user")
        XCTAssertEqual(turns[1].content, "¿capital de Francia?")
    }

    func testReduceDeltas() {
        let events: [ChatEvent] = [.delta("Hola"), .reasoning("x"), .delta(" mundo"), .done]
        XCTAssertEqual(IntentSupport.reduce(events), "Hola mundo")
    }

    func testNewChatIntentSetsFlag() async throws {
        UserDefaults.standard.removeObject(forKey: IntentSupport.newChatFlag)
        _ = try await NewChatIntent().perform()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: IntentSupport.newChatFlag))
        UserDefaults.standard.removeObject(forKey: IntentSupport.newChatFlag)
    }

    func testVoiceIntentSetsFlag() async throws {
        UserDefaults.standard.removeObject(forKey: IntentSupport.voiceFlag)
        _ = try await StartVoiceIntent().perform()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: IntentSupport.voiceFlag))
        UserDefaults.standard.removeObject(forKey: IntentSupport.voiceFlag)
    }

    func testOpenAppWhenRun() {
        XCTAssertTrue(NewChatIntent.openAppWhenRun)
        XCTAssertTrue(StartVoiceIntent.openAppWhenRun)
    }

    func testAskIntentEmptyQuestion() async throws {
        let intent = AskOpenPilotIntent()
        intent.question = "   "
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "No question provided.")
    }
}
