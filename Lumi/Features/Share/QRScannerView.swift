import SwiftUI
import VisionKit

/// 应用内扫码页：扫到二维码 → 交给 PostcardInbox 处理 → 关闭。仅需相机权限。
struct ScannerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    QRScannerView { text in
                        PostcardInbox.shared.handle(text: text)
                        dismiss()
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottom) {
                        Text("把二维码放进取景框")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                            .padding(.vertical, 9).padding(.horizontal, 16)
                            .background(.black.opacity(0.5), in: Capsule())
                            .padding(.bottom, 40)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.metering.unknown").font(.system(size: 40)).foregroundStyle(Color.muted)
                        Text("此设备无法扫码").foregroundStyle(Color.text)
                        Text("可改用「复制口令 / 隔空投送」接收。")
                            .font(.system(size: 12)).foregroundStyle(Color.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bg)
                }
            }
            .navigationTitle("扫码收明信片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// DataScannerViewController（iOS 16+）包装，只认 QR。
struct QRScannerView: UIViewControllerRepresentable {
    var onFound: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
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
                if case let .barcode(b) = item, let s = b.payloadStringValue {
                    done = true
                    onFound(s)
                    break
                }
            }
        }
    }
}
