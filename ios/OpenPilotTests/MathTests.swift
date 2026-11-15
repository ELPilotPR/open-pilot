import XCTest
@testable import OpenPilot

/// Parser de segmentos LaTeX (display $$…$$ / \[…\], inline $…$ / \(…\)).
final class MathTests: XCTestCase {
    func testPlainTextNoMath() {
        let segs = parseMathSegments("Hola mundo, cuesta $5 y $10.")
        XCTAssertEqual(segs.count, 1)
        if case .text = segs[0] {} else { XCTFail("esperaba texto plano") }
        XCTAssertFalse(containsMath("El precio es $5"))
    }

    func testDisplayDoubleDollar() {
        XCTAssertEqual(parseMathSegments("$$x^2$$"), [.displayMath("x^2")])
    }

    func testDisplayBracket() {
        XCTAssertEqual(parseMathSegments("\\[a+b\\]"), [.displayMath("a+b")])
    }

    func testInlineDollar() {
        XCTAssertEqual(parseMathSegments("sea $x^2$ ok"),
                       [.text("sea "), .inlineMath("x^2"), .text(" ok")])
    }

    func testInlineParen() {
        XCTAssertEqual(parseMathSegments("\\(y=mx+b\\)"), [.inlineMath("y=mx+b")])
    }

    func testPriceNotMath() {
        XCTAssertFalse(containsMath("Cuesta $5"))
        XCTAssertFalse(containsMath("$5$"))   // dígito solo, sin indicador matemático
        XCTAssertTrue(containsMath("$x$"))    // letra → fórmula
    }

    func testMixed() {
        let s = "La fórmula $e^{i\\pi}+1=0$ es famosa."
        XCTAssertTrue(parseMathSegments(s).contains(.inlineMath("e^{i\\pi}+1=0")))
        XCTAssertTrue(containsMath(s))
    }
}