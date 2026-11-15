import XCTest
@testable import OpenPilot

/// Favicons de fuentes (helper puro, sin red).
final class FaviconTests: XCTestCase {
    func testBuildsURLForValidHost() {
        let u = Favicon.url(for: "https://www.example.com/path?q=1")
        XCTAssertNotNil(u)
        let s = u!.absoluteString
        XCTAssertTrue(s.contains("domain=example.com"), s)
        XCTAssertTrue(s.contains("sz=64"), s)
    }

    func testStripsWWWAndLowercases() {
        let s = Favicon.url(for: "https://WWW.Example.COM/")!.absoluteString
        XCTAssertTrue(s.contains("domain=example.com"), s)
        XCTAssertFalse(s.contains("WWW"), s)
    }

    func testSizeClamped() {
        XCTAssertTrue(Favicon.url(for: "https://x.com", size: 1)!.absoluteString.contains("sz=16"))
        XCTAssertTrue(Favicon.url(for: "https://x.com", size: 9999)!.absoluteString.contains("sz=256"))
    }

    func testNilForInvalidURL() {
        XCTAssertNil(Favicon.url(for: "not a url"))
        XCTAssertNil(Favicon.url(for: ""))
    }

    func testKeepsSubdomain() {
        let s = Favicon.url(for: "https://docs.swift.org/foo")!.absoluteString
        XCTAssertTrue(s.contains("domain=docs.swift.org"), s)
    }
}
