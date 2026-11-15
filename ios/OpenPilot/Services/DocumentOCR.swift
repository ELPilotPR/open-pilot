import Vision
import UIKit

/// OCR on-device con Vision (VNRecognizeTextRequest). Sin red.
enum DocumentOCR {
    static func recognize(_ images: [UIImage]) async -> String {
        var pages: [String] = []
        for img in images {
            if let t = await text(from: img), !t.isEmpty { pages.append(t) }
        }
        return DocumentScanSupport.clean(DocumentScanSupport.joinPages(pages))
    }

    static func text(from image: UIImage) async -> String? {
        guard let cg = image.cgImage else { return nil }
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNRecognizeTextRequest()
                req.recognitionLevel = .accurate
                req.recognitionLanguages = ["es-ES", "en-US"]
                req.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                do {
                    try handler.perform([req])
                    let obs = req.results ?? []
                    let lines = obs.compactMap { $0.topCandidates(1).first?.string }
                    cont.resume(returning: lines.joined(separator: "\n"))
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}