import XCTest
import NaturalLanguage
@testable import OpenPilot

final class LocalRAGTests: XCTestCase {
    func testChunkPacks() {
        let text = (0..<10).map { "Párrafo número \($0) con algo de contenido." }.joined(separator: "\n")
        let chunks = LocalRAG.chunk(text, source: "doc", maxChars: 120)
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(chunks.allSatisfy { $0.text.count <= 120 })
        XCTAssertTrue(chunks.allSatisfy { $0.source == "doc" })
    }
    func testChunkLongParagraphSplits() {
        let chunks = LocalRAG.chunk(String(repeating: "x", count: 1500), source: "s", maxChars: 600)
        XCTAssertEqual(chunks.count, 3)
    }
    func testChunkEmpty() {
        XCTAssertTrue(LocalRAG.chunk("  \n  ", source: "s").isEmpty)
    }
    func testCosineIdentical() {
        XCTAssertEqual(LocalRAG.cosine([1, 2, 3], [1, 2, 3]), 1.0, accuracy: 1e-9)
    }
    func testCosineOrthogonal() {
        XCTAssertEqual(LocalRAG.cosine([1, 0], [0, 1]), 0.0, accuracy: 1e-9)
    }
    func testCosineMismatch() {
        XCTAssertEqual(LocalRAG.cosine([1], [1, 2]), 0)
    }
    func testRankOrdering() {
        let a = RAGChunk(id: 0, text: "a", source: "s")
        let b = RAGChunk(id: 1, text: "b", source: "s")
        let ranked = LocalRAG.rank(query: [1, 0], items: [(a, [0, 1]), (b, [1, 0])], k: 2)
        XCTAssertEqual(ranked.first?.0.id, 1)
    }
    func testRankK() {
        let items = (0..<5).map { (RAGChunk(id: $0, text: "\($0)", source: "s"), [1.0, 0]) }
        XCTAssertEqual(LocalRAG.rank(query: [1, 0], items: items, k: 2).count, 2)
    }
    func testQAPromptContains() {
        let p = LocalRAG.qaPrompt(question: "¿cuánto?", context: "[doc] dato")
        XCTAssertTrue(p.contains("¿cuánto?"))
        XCTAssertTrue(p.contains("[doc] dato"))
        XCTAssertTrue(p.contains("ONLY the context"))
    }
    func testRetrieveDoesNotCrash() {
        // NLEmbedding puede no estar disponible en el simulador; no debe romper.
        let chunks = LocalRAG.chunk("Swift is a programming language.", source: "s")
        _ = LocalRAG.retrieve(query: "programming", chunks: chunks)
    }
}