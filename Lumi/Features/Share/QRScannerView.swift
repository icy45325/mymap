import SwiftUI
import VisionKit
import PhotosUI
import CoreImage

/// 应用内扫码页：相机扫码 **或** 从相册选一张含二维码的图 → 交给 PostcardInbox 处理 → 关闭。
struct ScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pickedImage: PhotosPickerItem?
    @State private var notFound = false

    private var cameraOK: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        NavigationStack {
            Group {
                if cameraOK {
                    QRScannerView { text in
                        PostcardInbox.shared.handle(text: text)
                        dismiss()
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottom) {
                        Text("把二维码放进取景框，或从相册选二维码")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 9).padding(.horizontal, 16)
                            .background(.black.opacity(0.5), in: Capsule())
                            .padding(.bottom, 40)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode").font(.system(size: 40)).foregroundStyle(Color.nPink)
                        Text("从相册选二维码").foregroundStyle(Color.text)
                        Text("相机不可用时，也可从相册选一张含二维码的图收下明信片。")
                            .font(.system(size: 12)).foregroundStyle(Color.muted)
                            .multilineTextAlignment(.center).padding(.horizontal, 40)
                        PhotosPicker(selection: $pickedImage, matching: .images) {
                            Label("从相册选二维码", systemImage: "photo.on.rectangle")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                .padding(.vertical, 12).padding(.horizontal, 22)
                                .background(LinearGradient.neonH, in: Capsule())
                        }
                        .padding(.top, 6)
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
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $pickedImage, matching: .images) {
                        Label("相册", systemImage: "photo")
                    }
                    .tint(Color.nCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("没在这张图里找到二维码", isPresented: $notFound) { Button("好") {} }
        .onChange(of: pickedImage) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data), let text = Self.detectQR(in: ui) {
                    PostcardInbox.shared.handle(text: text)
                    dismiss()
                } else {
                    notFound = true
                }
            }
        }
    }

    /// 在一张图里识别二维码内容（CoreImage 二维码探测器）。
    static func detectQR(in image: UIImage) -> String? {
        guard let ci = CIImage(image: image) else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(),
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        for f in detector?.features(in: ci) ?? [] {
            if let q = f as? CIQRCodeFeature, let m = q.messageString, !m.isEmpty { return m }
        }
        return nil
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
