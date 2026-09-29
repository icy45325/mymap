import SwiftUI
import VisionKit

/// 登机牌条码扫描（`DataScannerViewController`，iOS 16+）。
/// 纸质登机牌多为 PDF417，移动登机牌可能是 Aztec/QR——三种都认。
/// 与 `QRScannerView` 同构，仅条码类型不同。
struct BoardingPassScannerView: UIViewControllerRepresentable {
    var onFound: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.pdf417, .aztec, .qr])],
            qualityLevel: .accurate,                 // PDF417 密度高，用高精度
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        try? vc.startScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onFound: (String) -> Void
        private var done = false
        init(onFound: @escaping (String) -> Void) { self.onFound = onFound }

        func dataScanner(_ scanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for item in addedItems {
                if case let .barcode(b) = item, let s = b.payloadStringValue, !s.isEmpty {
                    done = true
                    onFound(s)
                    break
                }
            }
        }
    }
}
