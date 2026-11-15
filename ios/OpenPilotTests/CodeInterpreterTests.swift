import XCTest
@testable import OpenPilot

final class CodeInterpreterTests: XCTestCase {
    func testArithmeticValue() {
        let r = CodeInterpreter.run("2 + 3 * 4")
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.value, "14")
    }

    func testConsoleLogCapture() {
        let r = CodeInterpreter.run("console.log('hola', 42); console.log({a:1});")
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.logs, ["hola 42", "{\"a\":1}"])
    }

    func testStringAndArray() {
        let r = CodeInterpreter.run("[1,2,3].map(x=>x*x).join('-')")
        XCTAssertEqual(r.value, "1-4-9")
    }

    func testSyntaxErrorReported() {
        let r = CodeInterpreter.run("function {")
        XCTAssertFalse(r.ok)
        XCTAssertNotNil(r.error)
    }

    func testRuntimeErrorReported() {
        let r = CodeInterpreter.run("null.foo")
        XCTAssertFalse(r.ok)
    }

    func testNoNetworkOrFileBridge() {
        // A bare JSContext exposes no fetch/require/process — code is sandboxed.
        let r = CodeInterpreter.run("typeof fetch + ',' + typeof require + ',' + typeof process")
        XCTAssertEqual(r.value, "undefined,undefined,undefined")
    }

    func testMathJSON() {
        let r = CodeInterpreter.run("JSON.stringify({s: Math.sqrt(16), p: Math.PI.toFixed(2)})")
        XCTAssertEqual(r.value, "{\"s\":4,\"p\":\"3.14\"}")
    }

    func testCSVParseBasic() {
        let t = CodeInterpreter.parseCSV("mes,ventas\nene,10\nfeb,20\nmar,30")
        XCTAssertEqual(t.columns, ["mes", "ventas"])
        XCTAssertEqual(t.rows.count, 3)
        XCTAssertEqual(t.numericValues(1), [10, 20, 30])
        XCTAssertEqual(t.firstNumericColumn, 1)
    }

    func testCSVQuotedFields() {
        let t = CodeInterpreter.parseCSV("name,note\n\"Doe, John\",\"say \"\"hi\"\"\"\nplain,x")
        XCTAssertEqual(t.rows[0], ["Doe, John", "say \"hi\""])
        XCTAssertEqual(t.rows[1], ["plain", "x"])
    }

    func testCSVNonNumericColumn() {
        let t = CodeInterpreter.parseCSV("a,b\nx,1\ny,foo")
        XCTAssertNil(t.numericValues(1))
        XCTAssertNil(t.firstNumericColumn)
    }

    func testCSVEmpty() {
        let t = CodeInterpreter.parseCSV("")
        XCTAssertTrue(t.columns.isEmpty)
        XCTAssertTrue(t.rows.isEmpty)
    }
}