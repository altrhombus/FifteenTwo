/// Camera-based hand scanning: rectangle detection, perspective correction, and rank OCR
/// are fully automated (see `CardScanner`); suit is color-detected (red/black, see
/// `SuitColorDetector`) with the exact suit left to the confirmation UI, since a trained
/// 4-suit classifier needs real photographed training cards this project doesn't have.
public enum CribbageVision {}
