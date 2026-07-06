import CoreImage
import CoreGraphics

/// Runs the full pipeline docs/plan.md lays out for one photo: rectangle detection →
/// perspective correction → corner crop → rank OCR → suit-color detection. One guess per
/// detected card, always paired with its corner crop so the confirmation UI can show the
/// person what the guess was actually based on.
public enum CardScanner {
    public static func scan(_ cgImage: CGImage) throws -> [ScannedCardGuess] {
        let regions = try RectangleDetector.detectCards(in: cgImage)
        let ciImage = CIImage(cgImage: cgImage)
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let context = CIContext()

        return regions.compactMap { region -> ScannedCardGuess? in
            guard let corrected = PerspectiveCorrector.correct(ciImage, region: region, imageSize: imageSize) else {
                return nil
            }
            let corner = CornerCropper.cropCorner(of: corrected)
            guard let cornerCG = context.createCGImage(corner, from: corner.extent) else { return nil }

            let (rank, confidence) = (try? RankRecognizer.recognizeRank(in: cornerCG)) ?? (nil, 0)
            let color = SuitColorDetector.detectColor(in: corner)

            return ScannedCardGuess(
                guessedRank: rank, guessedColor: color, rankConfidence: confidence, cornerImage: cornerCG
            )
        }
    }
}
