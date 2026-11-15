import XCTest
import MediaPlayer
@testable import OpenPilot

final class NowPlayingSupportTests: XCTestCase {
    func testTitleShort() { XCTAssertEqual(NowPlayingSupport.title(for: "Hola"), "Hola") }
    func testTitleEmpty() { XCTAssertEqual(NowPlayingSupport.title(for: "  "), "Open Pilot") }
    func testTitleTruncates() {
        let t = NowPlayingSupport.title(for: String(repeating: "x", count: 100))
        XCTAssertEqual(t.count, 41)
        XCTAssertTrue(t.hasSuffix("…"))
    }
    func testDurationMin() { XCTAssertEqual(NowPlayingSupport.estimatedDuration(""), 1.0) }
    func testDurationWords() { XCTAssertEqual(NowPlayingSupport.estimatedDuration("one two three four five"), 2.0, accuracy: 1e-9) }
    func testInfoKeys() {
        let info = NowPlayingSupport.info(text: "Hola", elapsed: 1, duration: 5, rate: 1)
        XCTAssertEqual(info[MPMediaItemPropertyTitle] as? String, "Hola")
        XCTAssertEqual(info[MPMediaItemPropertyArtist] as? String, "Open Pilot")
        XCTAssertEqual(info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval, 5)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval, 1)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyPlaybackRate] as? Float, 1)
    }
}