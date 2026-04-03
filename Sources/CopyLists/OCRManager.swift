/* @source cursor @line_count 52 @branch main */
import AppKit
import Vision

/// 使用 Vision 框架对图片做文字识别，结果异步回填到 ClipboardHistory
enum OCRManager {

    static func recognize(image: NSImage, filename: String) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let text = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { return }

            DispatchQueue.main.async {
                guard let delegate = NSApp.delegate as? AppDelegate else { return }
                delegate.history.updateOCR(filename: filename, text: text)
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .utility).async {
            try? handler.perform([request])
        }
    }
}
