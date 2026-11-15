import XCTest
@testable import OpenPilot

final class DebateSupportTests: XCTestCase {

    private func opp(_ label: String, _ text: String) -> DebateSupport.Opponent {
        DebateSupport.Opponent(label: label, text: text)
    }

    // MARK: - opponentsBlock

    func testOpponentsBlockLabelsAndJoins() {
        let block = DebateSupport.opponentsBlock([opp("Casa", "París."), opp("Qwen", "Paris es la capital.")])
        XCTAssertTrue(block.contains("[Casa]:"))
        XCTAssertTrue(block.contains("[Qwen]:"))
        XCTAssertTrue(block.contains("París."))
    }

    func testOpponentsBlockSkipsEmpty() {
        let block = DebateSupport.opponentsBlock([opp("Casa", "  "), opp("Qwen", "Respuesta.")])
        XCTAssertFalse(block.contains("[Casa]"))
        XCTAssertTrue(block.contains("[Qwen]"))
    }

    func testOpponentsBlockAllEmpty() {
        XCTAssertEqual(DebateSupport.opponentsBlock([opp("A", ""), opp("B", "\n ")]), "")
    }

    // MARK: - rebuttalPrompt

    func testRebuttalIncludesOriginalRoundAndOpponents() {
        let s = DebateSupport.rebuttalPrompt(original: "¿Capital de Francia?", round: 2,
                                             opponents: [opp("Qwen", "París.")])
        XCTAssertTrue(s.contains("¿Capital de Francia?"))
        XCTAssertTrue(s.contains("2"))
        XCTAssertTrue(s.contains("[Qwen]"))
        XCTAssertTrue(s.contains("París."))
    }

    func testRebuttalNoOpponentsStillAsksRefinedAnswer() {
        let s = DebateSupport.rebuttalPrompt(original: "Pregunta", round: 3, opponents: [opp("X", "")])
        XCTAssertTrue(s.contains("Pregunta"))
        XCTAssertTrue(s.contains("3"))
        XCTAssertFalse(s.contains("[X]"))
    }

    func testRebuttalNonEmpty() {
        XCTAssertFalse(DebateSupport.rebuttalPrompt(original: "q", round: 2, opponents: []).isEmpty)
    }

    // MARK: - debateTurns

    func testRoundOneIsPlainPrompt() {
        let turns = DebateSupport.debateTurns(original: "Hola", round: 1, opponents: [opp("A", "x")])
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].role, "user")
        XCTAssertEqual(turns[0].content, "Hola")
    }

    func testRoundZeroOrNegativeIsPlainPrompt() {
        XCTAssertEqual(DebateSupport.debateTurns(original: "Hola", round: 0, opponents: [])[0].content, "Hola")
    }

    func testLaterRoundCarriesOpponents() {
        let turns = DebateSupport.debateTurns(original: "Tema", round: 2, opponents: [opp("B", "Argumento B.")])
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].role, "user")
        XCTAssertTrue(turns[0].content.contains("Argumento B."))
        XCTAssertTrue(turns[0].content.contains("Tema"))
    }
}