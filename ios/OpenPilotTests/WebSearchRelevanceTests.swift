import XCTest
@testable import OpenPilot

/// 1.0.1 — calidad del browsing: limpieza de query conversacional, parseo de DDG Lite,
/// y filtro de relevancia + deduplicacion por dominio (adios a las paginas random).
final class WebSearchRelevanceTests: XCTestCase {

    // MARK: cleanQuery

    func testCleanQueryStripsConversationalFiller() {
        let out = WebSearchService.cleanQuery("oye busca en internet cual es la mejor playa para surfear en puerto rico")
        XCTAssertEqual(out, "mejor playa para surfear en puerto rico")
    }

    func testCleanQueryStripsPriceFraming() {
        let out = WebSearchService.cleanQuery("busca algo sobre cuanto cuesta un tesla model 3 usado")
        XCTAssertEqual(out, "tesla model 3 usado")
    }

    func testCleanQueryEnglish() {
        let out = WebSearchService.cleanQuery("search for the best python web framework 2026")
        XCTAssertEqual(out, "best python web framework 2026")
    }

    func testCleanQueryKeepsCleanQuery() {
        XCTAssertEqual(WebSearchService.cleanQuery("precio iPhone 17 Puerto Rico"), "precio iPhone 17 Puerto Rico")
    }

    func testCleanQueryPolitenessAndPunctuation() {
        XCTAssertEqual(WebSearchService.cleanQuery("¿capital de australia? por favor"), "capital de australia")
    }

    func testCleanQueryFallbackNonEmpty() {
        XCTAssertEqual(WebSearchService.cleanQuery("busca"), "busca")
        XCTAssertEqual(WebSearchService.cleanQuery("   "), "")
    }

    // MARK: parseLite

    private let liteFixture = """
    <table>
    <tr><td><a rel="nofollow" href="https://www.puertoricobeachfinder.com/es/surfing/" class='result-link'>Mejores Playas para Surfear en Puerto Rico</a></td></tr>
    <tr><td class='result-snippet'>Guía completa de las mejores playas para surfear en Puerto Rico, desde Rincon hasta Jobos.</td></tr>
    <tr><td><a rel="nofollow" href="https://www.puertorico.com/es/surfing" class='result-link'>Surfing en Puerto Rico - Rincon y Jobos</a></td></tr>
    <tr><td class='result-snippet'>Descubre Rincon, Jobos y las mejores playas de surf en Puerto Rico.</td></tr>
    <tr><td><a rel="nofollow" href="https://www.tripadvisor.es/Attractions-Surfing.html" class='result-link'>LAS 10 MEJORES actividades de surf en Puerto Rico</a></td></tr>
    <tr><td class='result-snippet'>Actividades de surf en Puerto Rico según Tripadvisor.</td></tr>
    </table>
    """

    func testParseLiteExtractsDirectUrlsTitlesSnippets() {
        let r = WebSearchService.parseLite(liteFixture, limit: 10)
        XCTAssertEqual(r.count, 3)
        XCTAssertEqual(r[0].url, "https://www.puertoricobeachfinder.com/es/surfing/")
        XCTAssertEqual(r[0].title, "Mejores Playas para Surfear en Puerto Rico")
        XCTAssertTrue(r[0].snippet.contains("Rincon"))
        XCTAssertEqual(r[1].url, "https://www.puertorico.com/es/surfing")
        XCTAssertEqual(r[2].title, "LAS 10 MEJORES actividades de surf en Puerto Rico")
    }

    func testParseLiteChallengeShellYieldsNothing() {
        let shell = "<html><head><link rel=\"canonical\" href=\"https://duckduckgo.com/\"></head><body>DuckDuckGo</body></html>"
        XCTAssertTrue(WebSearchService.parseLite(shell, limit: 10).isEmpty)
    }

    func testParseLiteRespectsLimit() {
        XCTAssertEqual(WebSearchService.parseLite(liteFixture, limit: 2).count, 2)
    }

    // MARK: domainKey

    func testDomainKeyStripsWwwAndTakesRegistrable() {
        XCTAssertEqual(WebSearchService.domainKey("https://www.puertorico.com/es/surfing"), "puertorico.com")
        XCTAssertEqual(WebSearchService.domainKey("https://discoverpuertorico.com/things/surfing/"), "discoverpuertorico.com")
        XCTAssertEqual(WebSearchService.domainKey("https://www.tripadvisor.es/Attractions.html"), "tripadvisor.es")
    }

    // MARK: queryTerms

    func testQueryTermsFiltersStopwordsAndShort() {
        let terms = WebSearchService.queryTerms("la mejor playa para surfear en puerto rico")
        XCTAssertTrue(terms.contains("playa"))
        XCTAssertTrue(terms.contains("surfear"))
        XCTAssertTrue(terms.contains("puerto"))
        XCTAssertFalse(terms.contains("la"))
        XCTAssertFalse(terms.contains("para"))
        XCTAssertFalse(terms.contains("mejor"))
    }

    // MARK: rankAndDedupe

    func testRankDropsIrrelevantWhenRelevantExist() {
        let sources = [
            WebSource(title: "Recetas de cocina", url: "https://cocina.com/pollo", snippet: "pollo al horno facil"),
            WebSource(title: "Mejores playas de surf en Puerto Rico", url: "https://surfpr.com/playas", snippet: "surfear en Rincon puerto rico"),
        ]
        let r = WebSearchService.rankAndDedupe(sources, query: "mejor playa surfear puerto rico", limit: 5)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].url, "https://surfpr.com/playas")
    }

    func testRankDedupesSameDomainKeepsDiverse() {
        let sources = [
            WebSource(title: "Surf Puerto Rico A", url: "https://www.puertorico.com/es/surfing", snippet: "playas surf puerto rico"),
            WebSource(title: "Surf Puerto Rico B", url: "https://www.puertorico.com/surfing", snippet: "playas surf puerto rico"),
            WebSource(title: "Tripadvisor surf PR", url: "https://www.tripadvisor.es/surf.html", snippet: "surf puerto rico playas"),
        ]
        let r = WebSearchService.rankAndDedupe(sources, query: "playa surfear puerto rico", limit: 5)
        XCTAssertEqual(r.count, 2)
        let domains = Set(r.map { WebSearchService.domainKey($0.url) })
        XCTAssertEqual(domains, ["puertorico.com", "tripadvisor.es"])
    }

    func testRankFiltersJunkSearchPages() {
        let sources = [
            WebSource(title: "DDG internal", url: "https://duckduckgo.com/y.js", snippet: "x"),
            WebSource(title: "Real surf PR", url: "https://surfpr.com/playas", snippet: "surfear puerto rico playa"),
        ]
        let r = WebSearchService.rankAndDedupe(sources, query: "playa surfear puerto rico", limit: 5)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].url, "https://surfpr.com/playas")
    }

    func testRankKeepsAllWhenNothingRelevant() {
        let sources = [
            WebSource(title: "Alpha", url: "https://alpha.com/a", snippet: "uno"),
            WebSource(title: "Beta", url: "https://beta.com/b", snippet: "dos"),
        ]
        let r = WebSearchService.rankAndDedupe(sources, query: "zzz", limit: 5)
        XCTAssertEqual(r.count, 2) // no vacia el resultado si nada coincide
    }

    func testRankPrefersHigherOverlap() {
        let sources = [
            WebSource(title: "Playas de Puerto Rico", url: "https://a.com/x", snippet: "puerto rico playas"),
            WebSource(title: "Surfear playa Rincon Puerto Rico", url: "https://b.com/y", snippet: "surfear playa puerto rico rincon"),
        ]
        let r = WebSearchService.rankAndDedupe(sources, query: "surfear playa puerto rico", limit: 5)
        XCTAssertEqual(r.first?.url, "https://b.com/y")
    }
}