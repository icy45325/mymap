import SwiftUI
import PencilKit
import AVFoundation

// ─────────────────────────────────────────────────────────────
//  交换日记的媒体基建：涂鸦画布（PencilKit）+ 语音录制/播放（AVFoundation）。
//  涂鸦/语音是给孩子的输入方式（亲子场景：接过手机涂一笔、录一段话）。
// ─────────────────────────────────────────────────────────────

/// PencilKit 画布（手指可画）。绑定 PKDrawing 数据；只读模式用于展示已封存内容。
struct DrawingCanvas: UIViewRepresentable {
    @Binding var drawingData: Data?
    var editable: Bool = true

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput          // 手指也能画（孩子没有 Pencil）
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .white, width: 4)
        canvas.isUserInteractionEnabled = editable
        canvas.delegate = context.coordinator
        if let data = drawingData, let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.isUserInteractionEnabled = editable
        // 外部清空（如「重画」）时同步
        if drawingData == nil, !canvas.drawing.strokes.isEmpty, !context.coordinator.isDrawing {
            canvas.drawing = PKDrawing()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: DrawingCanvas
        var isDrawing = false
        init(_ parent: DrawingCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            isDrawing = true
            parent.drawingData = canvasView.drawing.strokes.isEmpty
                ? nil : canvasView.drawing.dataRepresentation()
            isDrawing = false
        }
    }
}

/// 涂鸦缩略展示（已封存/已揭晓的半页）。
struct DrawingThumb: View {
    let data: Data
    var height: CGFloat = 90

    var body: some View {
        if let drawing = try? PKDrawing(data: data) {
            let img = drawing.image(from: drawing.bounds.insetBy(dx: -8, dy: -8), scale: 2)
            Image(uiImage: img)
                .resizable().scaledToFit()
                .frame(maxHeight: height)
        }
    }
}

/// 语音录制（m4a，上限 60 秒）。录完把文件读成 Data 交给调用方（SwiftData externalStorage 保存）。
@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsed: Double = 0
    @Published var permissionDenied = false

    static let maxSeconds: Double = 60

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("diary-voice.m4a")
    }

    func start() {
        AVAudioApplication.requestRecordPermission { [weak self] ok in
            Task { @MainActor in
                guard let self else { return }
                guard ok else { self.permissionDenied = true; return }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 24_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        guard let rec = try? AVAudioRecorder(url: fileURL, settings: settings) else { return }
        recorder = rec
        rec.record(forDuration: Self.maxSeconds)
        isRecording = true
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let rec = self.recorder else { return }
                self.elapsed = rec.currentTime
                if !rec.isRecording { self.finishTick() }
            }
        }
    }

    /// 停止并返回音频数据（nil = 失败/太短）。
    @discardableResult
    func stop() -> (data: Data, duration: Double)? {
        timer?.invalidate(); timer = nil
        guard let rec = recorder else { return nil }
        let duration = rec.currentTime
        rec.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        guard duration >= 0.5, let data = try? Data(contentsOf: fileURL) else { return nil }
        return (data, min(duration, Self.maxSeconds))
    }

    private func finishTick() {
        // 到达 60s 上限系统自动停——UI 侧由绑定的 elapsed/isRecording 驱动
        if recorder?.isRecording == false { isRecording = false; timer?.invalidate() }
    }
}

/// 语音条：播放已录的语音（🎤 0:12 胶囊样式，随处复用）。
struct VoiceChip: View {
    let data: Data
    let duration: Double

    @State private var player: AVAudioPlayer?
    @State private var playing = false

    var body: some View {
        Button {
            if playing { player?.stop(); playing = false; return }
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            player = try? AVAudioPlayer(data: data)
            player?.play()
            playing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (player?.duration ?? duration)) {
                playing = false
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: playing ? "stop.fill" : "play.fill").font(.system(size: 9))
                Text(verbatim: "🎤 \(timeText)")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Color.text)
            .padding(.vertical, 4).padding(.horizontal, 9)
            .background(Color.nCyan.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(Color.nCyan.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var timeText: String {
        let s = Int(duration.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
