import Testing
@testable import CribbageVision

struct SuitColorDetectorTests {
    @Test func solidRedIsDetectedAsRed() {
        let image = TestImageFactory.solidColor(red: 0.8, green: 0.1, blue: 0.1)
        #expect(SuitColorDetector.detectColor(in: image) == .red)
    }

    @Test func solidBlackIsDetectedAsBlack() {
        let image = TestImageFactory.solidColor(red: 0.05, green: 0.05, blue: 0.05)
        #expect(SuitColorDetector.detectColor(in: image) == .black)
    }

    @Test func neutralGrayIsAmbiguous() {
        let image = TestImageFactory.solidColor(red: 0.5, green: 0.5, blue: 0.5)
        #expect(SuitColorDetector.detectColor(in: image) == nil)
    }

    @Test func pureWhiteIsAmbiguous() {
        let image = TestImageFactory.solidColor(red: 1, green: 1, blue: 1)
        #expect(SuitColorDetector.detectColor(in: image) == nil)
    }
}
