import Foundation

/// Constructor puro de multipart/form-data (para /images/edits y /images/variations).
/// Testeable sin red: boundary, campos de texto y partes de archivo.
struct MultipartFormData {
    let boundary: String
    private var body = Data()

    init(boundary: String = "OpenPilot-" + UUID().uuidString) {
        self.boundary = boundary
    }

    mutating func addField(_ name: String, value: String) {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        body.append(Data("\(value)\r\n".utf8))
    }

    mutating func addFile(_ name: String, filename: String, mimeType: String, data: Data) {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
    }

    func build() -> Data {
        var out = body
        out.append(Data("--\(boundary)--\r\n".utf8))
        return out
    }

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }
}
