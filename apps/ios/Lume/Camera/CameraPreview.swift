import AVFoundation
import SwiftUI

/// Viseur caméra live + capture photo, intégré directement dans la vue (pas de
/// `UIImagePickerController` plein écran). Pensé pour le mode « photo du repas ».
///
/// Indisponible en simulateur (pas de caméra matérielle) → `isAvailable` renvoie `false`,
/// l'appelant doit alors proposer un repli (galerie).
@MainActor
final class CameraController: ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var configured = false
    private var captureHandler: ((Result<Data, CaptureError>) -> Void)?
    private let delegate = PhotoCaptureDelegate()

    /// Une vraie caméra arrière est-elle disponible (false en simulateur) ?
    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    /// Configure puis démarre la session. À appeler à l'apparition de la vue.
    func start() {
        guard CameraController.isAvailable else { return }
        configureIfNeeded()
        guard !session.isRunning else { return }
        // `startRunning` est bloquant : hors du main thread.
        let session = self.session
        Task.detached { session.startRunning() }
    }

    /// Arrête la session. À appeler au démontage de la vue (libère la caméra).
    func stop() {
        guard session.isRunning else { return }
        let session = self.session
        Task.detached { session.stopRunning() }
    }

    /// Déclenche une capture. Succès (JPEG) ou échec arrive dans `completion`, sur le main actor.
    func capturePhoto(_ completion: @escaping (Result<Data, CaptureError>) -> Void) {
        guard configured else { completion(.failure(.notReady)); return }
        captureHandler = completion
        // Le delegate AVFoundation rappelle sur une queue interne → on repasse sur le main
        // avant de toucher l'état SwiftUI de l'appelant.
        delegate.onResult = { [weak self] result in
            Task { @MainActor in
                self?.captureHandler?(result)
                self?.captureHandler = nil
            }
        }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input)
        {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
        configured = true
    }
}

/// Échec possible d'une capture photo.
enum CaptureError: Error { case notReady, failed }

/// Delegate de capture : convertit la photo en JPEG et la remonte (succès ou échec).
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    var onResult: ((Result<Data, CaptureError>) -> Void)?

    func photoOutput(_: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?)
    {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.7)
        else {
            onResult?(.failure(.failed))
            return
        }
        onResult?(.success(jpeg))
    }
}

/// Couche d'aperçu (preview layer) de la session, en SwiftUI.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context _: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_: PreviewView, context _: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
