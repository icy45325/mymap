import SwiftUI
import SwiftData

/// 写作页：左我 / 右 TA 的沉浸写作。
/// - `asOwner == true`：我写我的半页；对方半页盖蜡 +「等你写完后把手机递给 {name}」。
/// - `asOwner == false`：**传递模式**——手机已递给 TA，只显示 TA 的空白半页，
///   我的内容不可见（防偷看）；TA 封存后出现「写好了，交还给主人」。
/// 输入三选：✍️ 文字 / 🎨 涂鸦（给孩子）/ 🎤 语音（给孩子，≤60s）。
struct DiaryComposeView: View {

    let book: DiaryBook
    let page: DiaryPage
    let asOwner: Bool
    var onDone: () -> Void = {}

    @Environment(\.modelContext) private var context
    @AppStorage("lumi.profile.name") private var holderName: String = ""

    private enum Tool: String, CaseIterable { case text, draw, voice }
    @State private var tool: Tool = .text
    @State private var text = ""
    @State private var drawingData: Data?
    @State private var voiceData: Data?
    @State private var voiceDuration: Double = 0
    @StateObject private var recorder = VoiceRecorder()
    @State private var confirmSeal = false
    @State private var handoffIntro = true      // 传递模式先显示「递手机」引导页
    @State private var sealed = false

    private var authorName: String {
        asOwner ? (holderName.isEmpty ? String(localized: "我") : holderName) : book.partnerName
    }

    var body: some View {
        Group {
            if !asOwner && handoffIntro { handoffIntroView }
            else if sealed { sealedDoneView }
            else { composeBody }
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle(Text(verbatim: "第 \(page.orderIndex + 1) 页 · \(page.titleSnapshot)"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("先存草稿") { saveDraft(); onDone() }
            }
        }
        .onAppear { load() }
        .alert("封存这半页？", isPresented: $confirmSeal) {
            Button("封存 🔒", role: .destructive) { seal() }
            Button("再改改", role: .cancel) {}
        } message: {
            Text("封存后不能再改——这是交换的仪式。")
        }
        .alert("需要麦克风权限", isPresented: $recorder.permissionDenied) {
            Button("好", role: .cancel) {}
        } message: {
            Text("在 系统设置 › Lumi 里允许麦克风，才能录语音。")
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    // MARK: - 传递模式引导（防偷看：进入即不显示主人内容）

    private var handoffIntroView: some View {
        VStack(spacing: 16) {
            Spacer()
            WaxSeal(size: 64)
            Text("把手机递给 \(book.partnerName)")
                .font(Typo.serif(22)).foregroundStyle(Color.text)
            Text("Ta 在这台手机上写自己的半页；\n你已写的内容不会显示。")
                .font(.system(size: 13)).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center).lineSpacing(4)
            Spacer()
            Button {
                handoffIntro = false
                Analytics.log(.diaryHandoffStarted)
                Haptics.selection()
            } label: {
                Text("我是 \(book.partnerName)，开始写 ✍️")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient.neonH, in: Capsule())
            }
            .padding(.horizontal, 26).padding(.bottom, 24)
        }
    }

    // MARK: - 封存完成（传递模式提示交还）

    private var sealedDoneView: some View {
        VStack(spacing: 16) {
            Spacer()
            WaxSeal(size: 64, glow: true)
            Text(asOwner ? "已封存 🔒" : "写好了，封存 🔒")
                .font(Typo.serif(22)).foregroundStyle(Color.text)
            Text(!asOwner ? "把手机交还给主人吧 ✦"
                 : (book.isRemote ? "回到本子，把封存的半页寄给 \(book.partnerName) ✦"
                                  : "等 \(book.partnerName) 写完后，一起拆封 ✦"))
                .font(.system(size: 13)).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
            Spacer()
            Button { onDone() } label: {
                Text("完成")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient.neonH, in: Capsule())
            }
            .padding(.horizontal, 26).padding(.bottom, 24)
        }
    }

    // MARK: - 写作主体

    private var composeBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        writingHalf
                        otherHalfHint
                    }
                    toolPicker
                    inputArea
                }
                .padding(20)
            }
            Button { confirmSeal = true } label: {
                Text("封存我的这半页 🔒")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient.neonH, in: Capsule())
                    .shadow(color: Color.nPurple.opacity(0.5), radius: 12)
            }
            .disabled(contentEmpty)
            .opacity(contentEmpty ? 0.5 : 1)
            .padding(.horizontal, 26).padding(.bottom, 14)
        }
    }

    private var contentEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && drawingData == nil && voiceData == nil
    }

    /// 正在写的半页预览（作者头像 + 已有内容摘要）。
    private var writingHalf: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                PersonAvatar.named(authorName, size: 17)
                Text(verbatim: authorName).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color.text)
            }
            if !text.isEmpty {
                Text(verbatim: text).font(.system(size: 11)).lineSpacing(3)
                    .foregroundStyle(Color.text).lineLimit(4)
            }
            if let d = drawingData { DrawingThumb(data: d, height: 50) }
            if let v = voiceData { VoiceChip(data: v, duration: voiceDuration) }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.nPink.opacity(0.4), lineWidth: 1))
    }

    /// 另一半：盖蜡提示。
    private var otherHalfHint: some View {
        VStack(spacing: 7) {
            WaxSeal(size: 36)
            Text(!asOwner
                 ? "主人的半页\n已封存，拆封时再看"
                 : (book.isRemote ? "\(book.partnerName) 的那半页\nTa 在自己的 App 里写"
                                  : "\(book.partnerName) 的那半页\n等你写完后\n把手机递给 Ta"))
                .font(.system(size: 9.5, weight: .bold)).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center).lineSpacing(3)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(Color.glass, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.line, lineWidth: 1))
    }

    private var toolPicker: some View {
        HStack(spacing: 8) {
            toolChip(.text, "✍️ 文字")
            toolChip(.draw, "🎨 涂鸦")
            toolChip(.voice, "🎤 语音")
        }
    }

    private func toolChip(_ t: Tool, _ label: LocalizedStringKey) -> some View {
        Button { tool = t; Haptics.selection() } label: {
            Text(label).font(.system(size: 12, weight: .heavy))
                .foregroundStyle(tool == t ? Color(hex: 0x141109) : Color.text)
                .padding(.vertical, 7).padding(.horizontal, 14)
                .background(tool == t ? Color(hex: 0xFFD23E) : Color.panel, in: Capsule())
                .overlay(Capsule().stroke(Color.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var inputArea: some View {
        switch tool {
        case .text:
            TextEditor(text: $text)
                .font(.system(size: 15)).foregroundStyle(Color.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180)
                .padding(10)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
        case .draw:
            VStack(alignment: .trailing, spacing: 6) {
                DrawingCanvas(drawingData: $drawingData)
                    .frame(height: 240)
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
                if drawingData != nil {
                    Button("重画") { drawingData = nil }
                        .font(.system(size: 12)).foregroundStyle(Color.faint)
                }
            }
        case .voice:
            VStack(spacing: 12) {
                if let v = voiceData {
                    VoiceChip(data: v, duration: voiceDuration)
                    Button("重录") { voiceData = nil; voiceDuration = 0 }
                        .font(.system(size: 12)).foregroundStyle(Color.faint)
                } else if recorder.isRecording {
                    Text(verbatim: String(format: "● %02d:%02d / 1:00",
                                          Int(recorder.elapsed) / 60, Int(recorder.elapsed) % 60))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(WaxSeal.wax2)
                    Button {
                        if let out = recorder.stop() {
                            voiceData = out.data; voiceDuration = out.duration
                        }
                    } label: {
                        Label("停止", systemImage: "stop.circle.fill")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .padding(.vertical, 10).padding(.horizontal, 22)
                            .background(WaxSeal.wax, in: Capsule())
                    }
                } else {
                    Button { recorder.start() } label: {
                        Label("按一下开始录（最长 1 分钟）", systemImage: "mic.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(Color.text)
                            .padding(.vertical, 12).padding(.horizontal, 20)
                            .background(Color.panel, in: Capsule())
                            .overlay(Capsule().stroke(Color.nCyan.opacity(0.5), lineWidth: 1))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140)
        }
    }

    // MARK: - 数据

    private func load() {
        let half = DiaryBookStore.half(of: page, mine: asOwner, context: context)
        text = half.text ?? ""
        drawingData = half.drawingData
        voiceData = half.voiceData
        voiceDuration = half.voiceDuration
        if half.drawingData != nil { tool = .draw }
        else if half.voiceData != nil { tool = .voice }
    }

    private func saveDraft() {
        let half = DiaryBookStore.half(of: page, mine: asOwner, context: context)
        guard half.sealedAt == nil else { return }
        half.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        half.drawingData = drawingData
        half.voiceData = voiceData
        half.voiceDuration = voiceDuration
        half.updatedAt = .now
        try? context.save()
    }

    private func seal() {
        saveDraft()
        let half = DiaryBookStore.half(of: page, mine: asOwner, context: context)
        DiaryBookStore.seal(half, context: context)
        Haptics.success()
        withAnimation { sealed = true }
    }
}
