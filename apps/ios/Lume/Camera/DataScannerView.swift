import SwiftUI
import VisionKit

/// Scanner live VisionKit pour code-barres ou texte. Renvoie la première valeur reconnue.
struct DataScannerView: UIViewControllerRepresentable {
    enum Mode { case barcode, text }
    var mode: Mode
    var onResult: (String) -> Void

    /// Disponible uniquement sur device avec Neural Engine (A12+), jamais en simulateur.
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let types: Set<DataScannerViewController.RecognizedDataType> =
            mode == .barcode ? [.barcode()] : [.text()]
        let vc = DataScannerViewController(
            recognizedDataTypes: types,
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_: DataScannerViewController, context _: Context) {}

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator _: Coordinator) {
        vc.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerView
        private var done = false
        init(_ parent: DataScannerView) {
            self.parent = parent
        }

        func dataScanner(_: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem], allItems _: [RecognizedItem])
        {
            handle(addedItems)
        }

        func dataScanner(_: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle([item])
        }

        private func handle(_ items: [RecognizedItem]) {
            guard !done else { return }
            for item in items {
                switch item {
                case let .barcode(bc):
                    if let value = bc.payloadStringValue, !value.isEmpty {
                        done = true; parent.onResult(value); return
                    }
                case let .text(txt):
                    let t = txt.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { done = true; parent.onResult(t); return }
                @unknown default:
                    break
                }
            }
        }
    }
}
