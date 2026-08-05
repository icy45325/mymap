import SwiftUI
import SwiftData

/// 日记本内页：一页 = 一个足迹，**左页我 / 右页 TA**。
/// 未揭晓：对方半页盖火漆封印；**我的半页永远可读**（守卫规则）。
/// 双方都封存 → 封蜡发光呼吸 → 点击拆封（揭晓动画）→ 双方内容并置、永久定格。
struct DiaryBookView: View {

    @Bindable var book: DiaryBook

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lumi.profile.name") private var holderName: String = ""

    @State private var composeTarget: ComposeTarget?
    @State private var confirmDelete = false
    @State private var showFreePage = false
    @State private var freePageTitle = ""
    /// 揭晓动画中的页。
    @State private var revealing: DiaryPage?
    /// 远程交换寄送面板（邀请 / 半页）。
    @State private var shareKind: DiaryShareSheet.Kind?

    private struct ComposeTarget: Identifiable {
        let page: DiaryPage
        let asOwner: Bool
        var id: UUID { page.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                header
                if book.isRemote { remoteActions }
                ForEach(book.sortedPages) { page in
                    pageTitleRow(page)
                    spread(page)
                        .padding(.bottom, 14)
                }
                Color.clear.frame(height: 30)
            }
            .padding(.horizontal, 20).padding(.top, 8)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle(Text(verbatim: book.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showFreePage = true } label: {
                        Label("加一张自由页", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("删除这本日记", systemImage: "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(item: $composeTarget) { t in
            NavigationStack {
                DiaryComposeView(book: book, page: t.page, asOwner: t.asOwner, onDone: { composeTarget = nil })
            }
        }
        .sheet(isPresented: Binding(get: { shareKind != nil }, set: { if !$0 { shareKind = nil } })) {
            if let kind = shareKind { DiaryShareSheet(book: book, kind: kind) }
        }
        .alert("加一张自由页", isPresented: $showFreePage) {
            TextField("给这一页起个名（可空）", text: $freePageTitle)
            Button("添加") {
                _ = DiaryBookStore.addFreePage(to: book, title: freePageTitle, context: context)
                freePageTitle = ""
            }
            Button("取消", role: .cancel) { freePageTitle = "" }
        } message: {
            Text("有些心情不属于任何地点——飞机上、回家路上。")
        }
        .alert("删除这本日记？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                DiaryBookStore.deleteBook(book, context: context)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已写的内容将一并删除。")
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    private var header: some View {
        HStack(spacing: 8) {
            PersonAvatar.named(holderName.isEmpty ? "我" : holderName, size: 24)
            PersonAvatar.named(book.partnerName, size: 24).offset(x: -10)
            Text("与 \(book.partnerName) 交换 · 已写 \(book.writtenPageCount) / \(book.pages.count) 页")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.muted)
                .offset(x: -5)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    /// 远程交换动作条：未邀请 → 邀请 Ta 加入；有已封存未寄的半页 → 寄给 Ta。
    @ViewBuilder
    private var remoteActions: some View {
        let pendingCount = DiaryBookStore.pendingHalves(of: book).count
        VStack(spacing: 8) {
            if book.inviteSentAt == nil {
                remoteButton("✦ 邀请 \(book.partnerName) 加入这本日记",
                             subtitle: "Ta 在自己的 Lumi 里打开同一本", prominent: true) {
                    shareKind = .invite
                }
            }
            if pendingCount > 0 {
                remoteButton("把 \(pendingCount) 个已封存的半页寄给 \(book.partnerName) ✦",
                             subtitle: "寄到后 Ta 那边对应页就能拆", prominent: book.inviteSentAt != nil) {
                    shareKind = .halves
                }
            }
        }
        .padding(.bottom, 10)
    }

    private func remoteButton(_ title: LocalizedStringKey, subtitle: LocalizedStringKey,
                              prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                WaxSeal(size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(prominent ? .white : Color.text)
                        .multilineTextAlignment(.leading)
                    Text(subtitle).font(.system(size: 10))
                        .foregroundStyle(prominent ? .white.opacity(0.8) : Color.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(prominent ? .white.opacity(0.8) : Color.faint)
            }
            .padding(12)
            .background {
                if prominent {
                    RoundedRectangle(cornerRadius: 14).fill(LinearGradient.neonH)
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(Color.panel)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(prominent ? Color.clear : Color.nPink.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func pageTitleRow(_ page: DiaryPage) -> some View {
        HStack {
            (Text("第 \(page.orderIndex + 1) 页").bold() + Text(verbatim: " · \(page.titleSnapshot)"))
                .font(.system(size: 12)).foregroundStyle(Color.text)
            Spacer()
            HStack(spacing: 4) {
                Text(page.dateSnapshot.formatted(.dateTime.month(.defaultDigits).day()))
                stateText(page)
            }
            .font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted)
        }
        .padding(.horizontal, 2).padding(.bottom, 5)
    }

    private func stateText(_ page: DiaryPage) -> Text {
        switch page.state {
        case .empty:          return Text("· 都还没写")
        case .yourTurn:       return Text("· 该你了").foregroundStyle(Color(hex: 0xFFD23E))
        case .waitingPartner: return Text("· 等 \(book.partnerName)")
        case .revealable:     return Text("· 可拆封 ✦").foregroundStyle(WaxSeal.wax2)
        case .revealed:       return Text("· ✓ 已拆封")
        }
    }

    // MARK: - 对开

    private func spread(_ page: DiaryPage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            myHalfView(page)
            theirHalfView(page)
        }
        .overlay {
            // 可揭晓：整页盖着发光封蜡，点击拆封
            if page.state == .revealable {
                Button { reveal(page) } label: {
                    VStack(spacing: 8) {
                        WaxSeal(size: 52, glow: true)
                            .scaleEffect(revealing?.id == page.id ? 1.6 : 1)
                            .rotationEffect(.degrees(revealing?.id == page.id ? 16 : 0))
                            .opacity(revealing?.id == page.id ? 0 : 1)
                        Text("双方都写完了 · 点击拆封 ✦")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(WaxSeal.wax, in: Capsule())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bg.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 我的半页：**任何状态下都可读**（守卫规则的可视化）。
    @ViewBuilder
    private func myHalfView(_ page: DiaryPage) -> some View {
        let half = page.myHalf
        if let half, half.sealedAt != nil || !half.isEmpty {
            halfContent(half, name: String(localized: "我"), page: page)
        } else {
            // 还没写：写作入口
            Button { composeTarget = ComposeTarget(page: page, asOwner: true) } label: {
                VStack(spacing: 6) {
                    Text(verbatim: "✍️").font(.system(size: 22))
                    Text("写下这一页").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color.nPink.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .stroke(Color.nPink.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            }
            .buttonStyle(.plain)
        }
    }

    /// 对方半页：未封存 → 等 TA / 递手机；已封存未揭晓 → 火漆封印；已揭晓 → 内容并置。
    @ViewBuilder
    private func theirHalfView(_ page: DiaryPage) -> some View {
        let half = page.theirHalf
        switch page.state {
        case .revealed:
            if let half { halfContent(half, name: book.partnerName, page: page) }
            else { emptyTheirBox(page) }
        case .revealable:
            // 被 overlay 的整页封蜡盖住，这里放暗纹底
            sealedBox(text: "")
        case .waitingPartner:
            if book.isRemote {
                // 远程：等对方在 Ta 的 App 里写完寄来
                sealedBox(text: String(localized: "等 \(book.partnerName) 从 Ta 的 App 寄来…"))
            } else {
                // 本机传递：我封了、TA 没写 → 递手机入口
                Button { composeTarget = ComposeTarget(page: page, asOwner: false) } label: {
                    sealedShellContent(
                        title: String(localized: "\(book.partnerName) 还没写"),
                        subtitle: String(localized: "把手机递给 \(book.partnerName) ✍️"))
                }
                .buttonStyle(.plain)
            }
        case .yourTurn:
            // TA 已封存等我 → 封印在 TA 半页上
            sealedBox(text: String(localized: "\(book.partnerName) 已封存\n你写完后一起拆封"))
        case .empty:
            emptyTheirBox(page)
        }
    }

    @ViewBuilder
    private func emptyTheirBox(_ page: DiaryPage) -> some View {
        if book.isRemote {
            sealedShellContent(title: String(localized: "\(book.partnerName) 的半页"),
                               subtitle: String(localized: "Ta 在自己的 App 里写"))
        } else {
            Button { composeTarget = ComposeTarget(page: page, asOwner: false) } label: {
                sealedShellContent(title: String(localized: "\(book.partnerName) 的半页"),
                                   subtitle: String(localized: "递给 TA 写 →"))
            }
            .buttonStyle(.plain)
        }
    }

    private func sealedShellContent(title: String, subtitle: String) -> some View {
        VStack(spacing: 7) {
            WaxSeal(size: 38)
            Text(verbatim: title).font(.system(size: 10, weight: .bold)).foregroundStyle(Color.muted)
            Text(verbatim: subtitle).font(.system(size: 10)).foregroundStyle(Color.nPink)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(Color.glass, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.line, lineWidth: 1))
    }

    private func sealedBox(text: String) -> some View {
        VStack(spacing: 8) {
            WaxSeal(size: 44)
            if !text.isEmpty {
                Text(verbatim: text).font(.system(size: 10, weight: .bold)).foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center).lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(Color.glass, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.line, lineWidth: 1))
    }

    /// 半页内容（我的随时可读；对方的仅揭晓后）：文字 + 涂鸦缩略 + 语音条。
    private func halfContent(_ half: DiaryHalf, name: String, page: DiaryPage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                PersonAvatar.named(name == String(localized: "我") ? holderName : name, size: 17)
                Text(verbatim: name).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color.text)
                Spacer()
                if half.sealedAt != nil, page.state != .revealed {
                    Text("✓ 已封存").font(.system(size: 8.5, weight: .bold)).foregroundStyle(Color.nCyan)
                } else if half.sealedAt == nil {
                    // 草稿：可继续编辑
                    Button { composeTarget = ComposeTarget(page: page, asOwner: half.authorIsOwner) } label: {
                        Image(systemName: "pencil").font(.system(size: 10)).foregroundStyle(Color.faint)
                    }
                }
            }
            if let text = half.text, !text.isEmpty {
                Text(verbatim: text).font(.system(size: 11.5)).lineSpacing(4)
                    .foregroundStyle(Color.text)
            }
            if let data = half.drawingData { DrawingThumb(data: data, height: 80) }
            if let voice = half.voiceData { VoiceChip(data: voice, duration: half.voiceDuration) }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(paperBackground, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.line, lineWidth: 1))
    }

    /// 纸张横线纹理（暗色版）。
    private var paperBackground: some ShapeStyle {
        Color.panel
    }

    private func reveal(_ page: DiaryPage) {
        withAnimation(.spring(duration: 0.42)) { revealing = page }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            DiaryBookStore.reveal(page, context: context)
            Haptics.success()
            revealing = nil
        }
    }
}
