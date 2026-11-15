import XCTest
@testable import OpenPilot

/// Parseo puro sin red: divisas, intención de clima y citas [n] → fuentes.
final class ParsingTests: XCTestCase {
    func testCurrencyParse() {
        let r = CurrencyService.parse("convierte 100 USD a EUR")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.amount, 100)
        XCTAssertEqual(r?.from, "USD")
        XCTAssertEqual(r?.to, "EUR")
    }

    func testCurrencyDefaultsToOne() {
        let r = CurrencyService.parse("dólares a euros")
        XCTAssertEqual(r?.amount, 1)
        XCTAssertEqual(r?.from, "USD")
        XCTAssertEqual(r?.to, "EUR")
    }

    func testCurrencyNoConversion() {
        XCTAssertNil(CurrencyService.parse("hola como estas"))
        XCTAssertNil(CurrencyService.parse("100 USD"))   // una sola divisa
    }

    func testWeatherIntent() {
        XCTAssertTrue(WeatherService.isWeatherQuery("¿qué clima hace hoy?"))
        XCTAssertTrue(WeatherService.isWeatherQuery("will it rain tomorrow"))
        XCTAssertFalse(WeatherService.isWeatherQuery("cuéntame un chiste"))
    }

    func testCitationParse() {
        let src = WebSource(title: "Example", url: "https://www.example.com/a", snippet: "resumen")
        let refs = CitationReference.parse(text: "Dato importante [1].", sources: [src])
        XCTAssertEqual(refs.count, 1)
        XCTAssertEqual(refs.first?.name, "example.com")
        XCTAssertEqual(refs.first?.url, src.url)
        XCTAssertEqual(refs.first?.startIdx, 16)   // posición de "[" en el texto
        XCTAssertEqual(refs.first?.endIdx, 19)
    }

    func testCitationOutOfRangeIgnored() {
        let src = WebSource(title: "E", url: "https://e.com", snippet: "")
        XCTAssertTrue(CitationReference.parse(text: "Dato [5].", sources: [src]).isEmpty)
    }

    func testCitationDomainStripsWWW() {
        XCTAssertEqual(CitationReference.domain(of: "https://www.foo.com/x"), "foo.com")
        XCTAssertEqual(CitationReference.domain(of: "https://bar.org"), "bar.org")
    }
}
