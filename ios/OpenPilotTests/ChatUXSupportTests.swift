import XCTest
@testable import OpenPilot

/// Lote 22: borradores por chat, citar al composer, continuar truncadas y el
/// informe de compactación manual. Helpers puros → tests deterministas.
final class ChatUXSupportTests: XCTestCase {

    // MARK: - DraftStore

    private func freshDefaults() -> UserDefaults {
        let name = "draft.test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testDraftRoundTrip() {
        let d = freshDefaults()
        XCTAssertEqual(DraftStore.text(for: "c1", in: d), "")
        DraftStore.save("hola mundo", for: "c1", in: d)
        XCTAssertEqual(DraftStore.text(for: "c1", in: d), "hola mundo")
        // otro chat no comparte borrador
        XCTAssertEqual(DraftStore.text(for: "c2", in: d), "")
    }

    func testDraftEmptyRemovesKey() {
        let d = freshDefaults()
        DraftStore.save("algo", for: "c1", in: d)
        DraftStore.save("", for: "c1", in: d)
        XCTAssertEqual(DraftStore.text(for: "c1", in: d), "")
        XCTAssertNil(d.string(forKey: DraftStore.key("c1")))
    }

    func testDraftClear() {
        let d = freshDefaults()
        DraftStore.save("algo", for: "c1", in: d)
        DraftStore.clear(for: "c1", in: d)
        XCTAssertEqual(DraftStore.text(for: "c1", in: d), "")
    }

    func testDraftKeyNamespaced() {
        XCTAssertEqual(DraftStore.key("abc"), "draft.abc")
    }

    // MARK: - QuoteSupport

    func testQuoteMultiline() {
        XCTAssertEqual(QuoteSupport.blockquote("hola\nmundo"), "> hola\n> mundo")
    }

    func testQuoteEmpty() {
        XCTAssertEqual(QuoteSupport.blockquote("   \n  "), "")
        XCTAssertEqual(QuoteSupport.blockquote(""), "")
    }

    func testQuoteTrimsOuterWhitespace() {
        XCTAssertEqual(QuoteSupport.blockquote("\n  hola  \n"), "> hola")
    }

    func testQuoteTruncation() {
        let long = String(repeating: "a", count: QuoteSupport.maxChars + 50)
        let q = QuoteSupport.blockquote(long)
        XCTAssertTrue(q.hasSuffix("> …"))
        // el cuerpo citado no excede maxChars por línea
        XCTAssertLessThanOrEqual(q.count, QuoteSupport.maxChars + 20)
    }

    func testQuoteShortNoEllipsis() {
        let q = QuoteSupport.blockquote("corto")
        XCTAssertFalse(q.contains("…"))
    }

    // MARK: - ContinueSupport

    func testTruncatedOpenFence() {
        XCTAssertTrue(ContinueSupport.looksTruncated("```swift\nlet x = 1"))
    }

    func testClosedFenceNotTruncated() {
        XCTAssertFalse(ContinueSupport.looksTruncated("```swift\nlet x = 1\n```"))
    }

    func testTruncatedTrailingPunctuation() {
        XCTAssertTrue(ContinueSupport.looksTruncated("y entonces,"))
        XCTAssertTrue(ContinueSupport.looksTruncated("la función ("))
        XCTAssertFalse(ContinueSupport.looksTruncated("Terminó bien."))
    }

    func testTruncatedEmpty() {
        XCTAssertFalse(ContinueSupport.looksTruncated(""))
        XCTAssertFalse(ContinueSupport.looksTruncated("   "))
    }

    func testContinueInstructionNonEmpty() {
        XCTAssertFalse(ContinueSupport.instruction.isEmpty)
    }

    // MARK: - ContextManager.compactReport

    func testCompactReportNoCompaction() {
        let plan = ContextManager.Plan(compacted: [], didCompact: false, foldedCount: 0, beforeTokens: 100, afterTokens: 100)
        let r = ContextManager.compactReport(plan)
        XCTAssertTrue(r.contains("100"))
    }

    func testCompactReportWithCompaction() {
        let plan = ContextManager.Plan(compacted: [], didCompact: true, foldedCount: 3, beforeTokens: 1000, afterTokens: 400)
        let r = ContextManager.compactReport(plan)
        XCTAssertTrue(r.contains("1000"))
        XCTAssertTrue(r.contains("400"))
        XCTAssertTrue(r.contains("3"))
        XCTAssertTrue(r.contains("60"))   // −60%
    }
}