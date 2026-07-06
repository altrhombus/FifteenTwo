#if os(iOS)
import SwiftUI
import AVFoundation

/// A live camera preview with a capture button — see docs/plan.md ("Vision Hand-
/// Scanning"): point the phone at a dealt hand, tap to scan. iOS only: this is
/// specifically the "turn a phone into a coach" feature, not something built for Mac's
/// webcam-pointed-at-a-table ergonomics.
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (CGImage) -> Void

    func makeUIViewController(context: Context) -> CameraCaptureViewController {
        CameraCaptureViewController(onCapture: onCapture)
    }

    func updateUIViewController(_ uiViewController: CameraCaptureViewController, context: Context) {}
}

final class CameraCaptureViewController: UIViewController {
    // `nonisolated(unsafe)`: `startRunning()` is meant to be called off the main thread
    // (Apple's own guidance, since it can block) via the detached Task below — AVFoundation
    // capture types manage their own internal thread safety for this.
    private nonisolated(unsafe) let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let onCapture: (CGImage) -> Void
    private var photoDelegate: PhotoCaptureDelegate?

    init(onCapture: @escaping (CGImage) -> Void) {
        self.onCapture = onCapture
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
        addCaptureButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        defer { captureSession.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input)
        else { return }
        captureSession.addInput(input)
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        // Plain GCD, not a structured Task: AVCaptureSession isn't Sendable, so handing
        // it to Task.detached's @Sendable closure trips Swift 6's strict-concurrency
        // check even with the property itself marked nonisolated(unsafe) above.
        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.startRunning()
        }
    }

    private func addCaptureButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.circle.fill"), for: .normal)
        button.tintColor = .white
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        button.addTarget(self, action: #selector(capture), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            button.widthAnchor.constraint(equalToConstant: 64),
            button.heightAnchor.constraint(equalToConstant: 64)
        ])
    }

    @objc private func capture() {
        let delegate = PhotoCaptureDelegate { [weak self] cgImage in
            guard let cgImage else { return }
            self?.onCapture(cgImage)
        }
        photoDelegate = delegate
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (CGImage?) -> Void

    init(completion: @escaping (CGImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        completion(photo.cgImageRepresentation())
    }
}
#endif
