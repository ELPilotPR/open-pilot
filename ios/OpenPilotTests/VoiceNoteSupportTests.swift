import XCTest
@testable import OpenPilot

final class VoiceNoteSupportTests: XCTestCase {
    func testFormatZero() { XCTAssertEqual(VoiceNoteSupport.formatDuration(0), "0:00") }
    func testFormatSeconds() { XCTAssertEqual(VoiceNoteSupport.formatDuration(65), "1:05") }
    func testFormatLarge() { XCTAssertEqual(VoiceNoteSupport.formatDuration(3600), "60:00") }
    func testFormatNegative() { XCTAssertEqual(VoiceNoteSupport.formatDuration(-5), "0:00") }
    func testCleanCollapses() {
        XCTAssertEqual(VoiceNoteSupport.cleanTranscript("  hola   mundo \n qué  tal "), "hola mundo qué tal")
    }
    func testCleanEmpty() { XCTAssertEqual(VoiceNoteSupport.cleanTranscript("   "), "") }
    func testFileName() {
        let n = VoiceNoteSupport.fileName(date: Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(n, "voicenote-1000.m4a")
    }
    func testMessageText() {
        XCTAssertEqual(VoiceNoteSupport.messageText(transcript: "  hola  "), "hola")
    }
}