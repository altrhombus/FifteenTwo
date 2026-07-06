import Vision
import CoreGraphics
import CribbageKit

/// Reads the rank glyph from a corner crop via Vision's built-in OCR — see docs/plan.md:
/// "Rank via VNRecognizeTextRequest (Vision's built-in OCR — ranks are real glyphs)." No
/// training data needed, unlike suit detection.
public enum RankRecognizer {
    public static func recognizeRank(in cgImage: CGImage) throws -> (rank: Rank?, confidence: Float) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.customWords = ["A", "J", "Q", "K", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        request.minimumTextHeight = 0.2

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            if let rank = RankTextMapper.rank(from: candidate.string) {
                return (rank, candidate.confidence)
            }
        }
        return (nil, 0)
    }
}
