import XCTest
@testable import OpenPilot

/// Regresión del bug "la primera búsqueda va bien pero los follow-ups traen páginas
/// random": la query debe resolverse con el contexto del chat, no con el texto pelado.
final class ContextualQueryTests: XCTestCase {

    // MARK: - Guardas

    func testFirstTurnUsesCleanQueryAsIs() {
        let raw = "Buscame los secundarios"
        XCTAssertEqual(WebSearchService.contextualQuery(raw: raw, previousUserText: nil, isFirstTurn: true),
                       WebSearchService.cleanQuery(raw))
    }

    func testNoPreviousUsesCleanQuery() {
        let raw = "busca lo mismo"
        XCTAssertEqual(WebSearchService.contextualQuery(raw: raw, previousUserText: nil, isFirstTurn: false),
                       WebSearchService.cleanQuery(raw))
    }

    // MARK: - Anáfora

    func testPureAnaphoraReusesPreviousQuery() {
        let prev = "personajes secundarios Bob Esponja"
        let out = WebSearchService.contextualQuery(raw: "busca lo mismo", previousUserText: prev, isFirstTurn: false)
        XCTAssertEqual(out, WebSearchService.cleanQuery(prev))
    }

    func testAnaphoraWithNewTopicCombines() {
        let out = WebSearchService.contextualQuery(raw: "busca lo mismo de Bob Esponja",
                                                   previousUserText: "secundarios", isFirstTurn: false)
        XCTAssertTrue(out.contains("secundarios"))
        XCTAssertTrue(out.contains("bob"))
        XCTAssertTrue(out.contains("esponja"))
        XCTAssertFalse(out.contains("mismo"), "no debe arrastrar la palabra filler 'mismo'")
    }

    func testEsoReusesPrevious() {
        let prev = "reparto Los secundarios"
        let out = WebSearchService.contextualQuery(raw: "busca eso", previousUserText: prev, isFirstTurn: false)
        XCTAssertEqual(out, WebSearchService.cleanQuery(prev))
    }

    // MARK: - Follow-ups cortos / ambiguos

    func testShortFollowUpAugmentsWithTopic() {
        let out = WebSearchService.contextualQuery(raw: "los de Bob Esponja",
                                                   previousUserText: "secundarios", isFirstTurn: false)
        XCTAssertTrue(out.contains("secundarios"))
        XCTAssertTrue(out.contains("bob"))
        XCTAssertTrue(out.contains("esponja"))
    }

    func testSelfContainedFollowUpUnchanged() {
        let raw = "reparto de la pelicula Los secundarios 2020"
        let out = WebSearchService.contextualQuery(raw: raw, previousUserText: "Bob Esponja", isFirstTurn: false)
        XCTAssertEqual(out, WebSearchService.cleanQuery(raw))
    }

    // MARK: - Filtrado de dominios basura (páginas random para hechos)

    func testSocialBoardsAreFiltered() {
        let sources = [
            WebSource(title: "Bob Esponja pins", url: "https://es.pinterest.com/bob", snippet: "bob esponja personajes"),
            WebSource(title: "Bob Esponja insta", url: "https://www.instagram.com/bob", snippet: "bob esponja"),
            WebSource(title: "Personajes Bob Esponja", url: "https://spongebob.fandom.com/wiki/Personajes",
                      snippet: "personajes secundarios bob esponja"),
            WebSource(title: "Bob Esponja", url: "https://es.wikipedia.org/wiki/Bob_Esponja",
                      snippet: "personajes bob esponja serie"),
        ]
        let ranked = WebSearchService.rankAndDedupe(sources, query: "personajes secundarios bob esponja", limit: 6)
        let hosts = ranked.compactMap { URL(string: $0.url)?.host ?? "" }
        XCTAssertFalse(hosts.contains { $0.contains("pinterest") }, "Pinterest debe filtrarse")
        XCTAssertFalse(hosts.contains { $0.contains("instagram") }, "Instagram debe filtrarse")
        XCTAssertTrue(hosts.contains { $0.contains("fandom") }, "fandom relevante debe quedar")
        XCTAssertTrue(hosts.contains { $0.contains("wikipedia") }, "wikipedia debe quedar")
    }

    func testNetflixNotMistakenForX() {
        // "x.com" no debe matchear por substring dentro de "netflix.com".
        let sources = [
            WebSource(title: "Los secundarios", url: "https://www.netflix.com/title/81234",
                      snippet: "los secundarios pelicula reparto"),
        ]
        let ranked = WebSearchService.rankAndDedupe(sources, query: "los secundarios pelicula reparto", limit: 6)
        XCTAssertEqual(ranked.count, 1, "netflix.com no es junk")
    }
}