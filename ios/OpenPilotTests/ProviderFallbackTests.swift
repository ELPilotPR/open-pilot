import XCTest
@testable import OpenPilot

final class ProviderFallbackTests: XCTestCase {
    func testChainPrimaryFirst() {
        XCTAssertEqual(ProviderFallback.chain(primaryID: "a", fallbackIDs: ["b", "c"]), ["a", "b", "c"])
    }
    func testChainDropsPrimaryFromFallbacks() {
        XCTAssertEqual(ProviderFallback.chain(primaryID: "a", fallbackIDs: ["a", "b"]), ["a", "b"])
    }
    func testChainDedupes() {
        XCTAssertEqual(ProviderFallback.chain(primaryID: "a", fallbackIDs: ["b", "b", "c"]), ["a", "b", "c"])
    }
    func testNext() {
        let chain = ["a", "b", "c"]
        XCTAssertEqual(ProviderFallback.next(after: "a", in: chain), "b")
        XCTAssertEqual(ProviderFallback.next(after: "b", in: chain), "c")
        XCTAssertNil(ProviderFallback.next(after: "c", in: chain))
        XCTAssertNil(ProviderFallback.next(after: "z", in: chain))
    }
    func testRetryableStatus() {
        XCTAssertTrue(ProviderFallback.isRetryable(statusCode: 500))
        XCTAssertTrue(ProviderFallback.isRetryable(statusCode: 429))
        XCTAssertTrue(ProviderFallback.isRetryable(statusCode: 503))
        XCTAssertFalse(ProviderFallback.isRetryable(statusCode: 401))
        XCTAssertFalse(ProviderFallback.isRetryable(statusCode: 400))
        XCTAssertFalse(ProviderFallback.isRetryable(statusCode: 200))
    }
    func testRetryableURLError() {
        XCTAssertTrue(ProviderFallback.isRetryable(URLError(.timedOut)))
        XCTAssertTrue(ProviderFallback.isRetryable(URLError(.cannotConnectToHost)))
        XCTAssertFalse(ProviderFallback.isRetryable(URLError(.badURL)))
    }
    func testRetryableMessage() {
        let e = NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "HTTP 503 unavailable"])
        XCTAssertTrue(ProviderFallback.isRetryable(e))
        let auth = NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "401 unauthorized"])
        XCTAssertFalse(ProviderFallback.isRetryable(auth))
    }
    func testSettingsRoundTrip() {
        let saved = FallbackSettings.ids
        FallbackSettings.ids = ["p1", "p2"]
        XCTAssertEqual(FallbackSettings.ids, ["p1", "p2"])
        FallbackSettings.ids = saved
    }
}