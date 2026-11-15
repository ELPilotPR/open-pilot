import XCTest
@testable import OpenPilot

final class ImageEditTests: XCTestCase {
    private let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    func testMultipartContentTypeHasBoundary() {
        let mp = MultipartFormData(boundary: "ABC123")
        XCTAssertEqual(mp.contentType, "multipart/form-data; boundary=ABC123")
    }

    func testMultipartFieldAndFile() {
        var mp = MultipartFormData(boundary: "B")
        mp.addField("prompt", value: "hola")
        mp.addFile("image", filename: "i.png", mimeType: "image/png", data: png)
        let body = mp.build()
        XCTAssertNotNil(body.range(of: Data("name=\"prompt\"".utf8)))
        XCTAssertNotNil(body.range(of: Data("hola".utf8)))
        XCTAssertNotNil(body.range(of: Data("name=\"image\"; filename=\"i.png\"".utf8)))
        XCTAssertNotNil(body.range(of: Data("Content-Type: image/png".utf8)))
        XCTAssertNotNil(body.range(of: png))
        let closing = Data("--B--\r\n".utf8)
        XCTAssertEqual(body.suffix(closing.count), closing)
    }

    func testEditRequestShape() {
        let req = ImageGenerationService.editRequest(prompt: "más rojo", image: png, model: "gpt-image-1",
                                                     baseURL: "https://api.example.com/v1/", apiKey: "k")
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.url?.absoluteString, "https://api.example.com/v1/images/edits")
        XCTAssertEqual(req?.httpMethod, "POST")
        XCTAssertEqual(req?.value(forHTTPHeaderField: "Authorization"), "Bearer k")
        XCTAssertTrue(req?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
        let body = req?.httpBody ?? Data()
        XCTAssertNotNil(body.range(of: Data("más rojo".utf8)))
        XCTAssertNotNil(body.range(of: Data("gpt-image-1".utf8)))
        XCTAssertNotNil(body.range(of: png))
    }

    func testVariationRequestShape() {
        let req = ImageGenerationService.variationRequest(image: png, model: "dall-e-2",
                                                          baseURL: "https://api.example.com/v1", apiKey: "k")
        XCTAssertEqual(req?.url?.absoluteString, "https://api.example.com/v1/images/variations")
        let body = req?.httpBody ?? Data()
        XCTAssertNotNil(body.range(of: png))
        XCTAssertNil(body.range(of: Data("name=\"prompt\"".utf8)))
    }

    func testEditRequestBadURL() {
        XCTAssertNil(ImageGenerationService.editRequest(prompt: "x", image: png, model: "m", baseURL: "http://bad url", apiKey: ""))
    }

    func testEditRequestNoAuthWhenEmptyKey() {
        let req = ImageGenerationService.editRequest(prompt: "x", image: png, model: "m",
                                                     baseURL: "https://a.com/v1", apiKey: "")
        XCTAssertNil(req?.value(forHTTPHeaderField: "Authorization"))
    }

    func testParseB64Image() {
        let raw = Data([1, 2, 3, 4])
        let json = "{\"data\":[{\"b64_json\":\"\(raw.base64EncodedString())\"}]}"
        XCTAssertEqual(ImageGenerationService.parseB64Image(Data(json.utf8)), raw)
    }

    func testParseB64ImageMissing() {
        XCTAssertNil(ImageGenerationService.parseB64Image(Data("{}".utf8)))
        XCTAssertNil(ImageGenerationService.parseB64Image(Data("{\"data\":[]}".utf8)))
    }
}
