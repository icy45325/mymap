import SwiftUI
import SwiftData

/// 日记本详情：我的条目时间轴 + 写一条 + 封存 + 交换区（五态状态机）。
struct ExchangeDiaryDetailView: View {

    @Bindable var diary: ExchangeDiary

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lumi.profile.name") private var holderName: String = ""
    @ObservedObject private var post = LumiPost.shared

    /// 编辑目标（item 驱动 sheet，避免 isPresented + 伴随 state 的时序陷阱）。
    private struct EditorTarget: Identifiable {
        let entry: DiaryEntry?          // nil = 新写一条
        var id: UUID { entry?.id ?? Self.newID }
        private static let newID = UUID()
        static let new = EditorTarget(entry: nil)
        static func edit(_ e: DiaryEntry) -> EditorTarget { EditorTarget(entry: e) }
    }
    @State private var editorTarget: EditorTarget?
    @State private var confirmSeal = false
    @State private var showExchange = false
    @State private var showReader = false
    @State private var confirmDelete = false
    /// 拆开动效：短暂放大→跳阅读
    @State private var unsealing = false

    private var sortedEntries: [DiaryEntry] {
        diary.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerCard
                exchangeZone
                entriesSection
                Color.clear.frame(height: 30)
            }
            .padding(.top, 10)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle(Text(verbatim: diary.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("删除这本日记", systemImage: "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(item: $editorTarget) { target in
            DiaryEntryEditor(diary: diary, entry: target.entry)
        }
        .sheet(isPresented: $showExchange) { DiaryExchangeSheet(diary: diary) }
        .fullScreenCover(isPresented: $showReader) { ExchangedDiaryReaderView(diary: diary) }
        .alert("封存这本日记？", isPresented: $confirmSeal) {
            Button("封存 ✦", role: .destructive) { seal() }
            Button("再想想", role: .cancel) {}
        } message: {
            Text("封存后不能再写、不能修改——这是交换的仪式。封存才能寄给对方、拆开对方的。")
        }
        .alert("删除这本日记？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) { deleteDiary() }
            Button("取消", role: .cancel) {}
        } message: {
            diary.isExchanged ? Text("已交换的日记删了就找不回了（对方那本不受影响）。")
                              : Text("里面写的条目会一起删除。")
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    // MARK: - 头部

    private var headerCard: some View {
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 4) {
                if !diary.partnerName.isEmpty {
                    Text("与 \(diary.partnerName) 交换").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.text)
                } else {
                    Text("还没有交换对象").font(.system(size: 13)).foregroundStyle(Color.muted)
                }
                Text("开始于 \(diary.createdAt.formatted(.dateTime.year().month().day()))")
                    .font(.system(size: 11)).foregroundStyle(Color.faint)
            }
            Spacer()
            DiaryStatusChip(diary: diary)
        }
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
        .padding(.horizontal, 22)
    }

    // MARK: - 交换区（五态）

    @ViewBuilder
    private var exchangeZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            if diary.isExchanged {
                // 终态：已交换 → 阅读
                zoneCard(icon: "envelope.open.fill", tint: Color(hex: 0xC9A24B),
                         title: Text("已和 \(diary.partnerName) 交换 ✦"),
                         subtitle: Text("拆开于 \(diary.exchangedAt!.formatted(.dateTime.month().day()))")) {
                    zoneButton("一起读", prominent: true) { showReader = true }
                }
            } else {
                switch (diary.status, diary.partnerToken != nil) {
                case (.draft, false):
                    // ① 手记中：引导封存
                    zoneCard(icon: "lock.open", tint: Color.nCyan,
                             title: Text("写完这段旅程就封存"),
                             subtitle: Text("封存后不能再改，才能与对方交换")) {
                        zoneButton("封存这本日记", prominent: false, disabled: diary.entries.isEmpty) { confirmSeal = true }
                    }
                case (.draft, true):
                    // ② 对方先寄到：壳在等
                    zoneCard(icon: "lock.fill", tint: Color.nPurple,
                             title: Text("\(diary.partnerName) 的日记已寄到"),
                             subtitle: Text("密封着呢——先封存你的，才能拆开 ✦")) {
                        zoneButton("封存这本日记", prominent: true, disabled: diary.entries.isEmpty) { confirmSeal = true }
                    }
                case (.sealed, false):
                    if diary.sentAt == nil {
                        // ③ 已封存未寄
                        zoneCard(icon: "paperplane.fill", tint: Color.nPink,
                                 title: Text("封存好了，寄给对方吧"),
                                 subtitle: Text("口令 / 二维码 / AirDrop / 邮局直投都行")) {
                            zoneButton("寄给\(diary.partnerName.isEmpty ? String(localized: "对方") : diary.partnerName) ✦", prominent: true) { showExchange = true }
                        }
                    } else {
                        // ④ 已寄出等待对方
                        zoneCard(icon: "hourglass", tint: Color.muted,
                                 title: Text("等 \(diary.partnerName) 封存寄回…"),
                                 subtitle: Text("寄出于 \(diary.sentAt!.formatted(.dateTime.month().day()))；对方的日记寄到后就能拆")) {
                            zoneButton("再寄一次", prominent: false) { showExchange = true }
                        }
                    }
                case (.sealed, true):
                    // ⑤ 双方就绪：拆开
                    zoneCard(icon: "envelope.badge.fill", tint: Color(hex: 0xC9A24B),
                             title: Text("\(diary.partnerName) 的日记在这里"),
                             subtitle: Text(diary.sentAt == nil ? "别忘了把你的也寄给对方" : "两边都封存了——可以拆开了")) {
                        HStack(spacing: 10) {
                            if diary.sentAt == nil {
                                zoneButton("先寄我的", prominent: false) { showExchange = true }
                            }
                            zoneButton("拆开对方的日记 ✦", prominent: true) { unseal() }
                        }
                    }
                    .scaleEffect(unsealing ? 1.04 : 1)
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 12)
    }

    private func zoneCard<Actions: View>(icon: String, tint: Color, title: Text, subtitle: Text,
                                         @ViewBuilder actions: () -> Actions) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    title.font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.text)
                    subtitle.font(.system(size: 11)).foregroundStyle(Color.muted)
                }
            }
            actions()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.35), lineWidth: 1))
    }

    private func zoneButton(_ key: LocalizedStringKey, prominent: Bool, disabled: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(key)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(prominent ? .white : Color.text)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background {
                    if prominent { Capsule().fill(LinearGradient.neon) }
                    else { Capsule().fill(Color.glass).overlay(Capsule().stroke(Color.line, lineWidth: 1)) }
                }
        }
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    // MARK: - 我的条目

    @ViewBuilder
    private var entriesSection: some View {
        HStack {
            Text("我的日记").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
            Spacer()
            if diary.status == .draft {
                Button { editorTarget = .new } label: {
                    Label("写一条", systemImage: "square.and.pencil")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.nPink)
                }
            }
        }
        .padding(.horizontal, 26).padding(.top, 20).padding(.bottom, 4)

        if diary.entries.isEmpty {
            (diary.status == .draft ? Text("今天有什么想留给对方看的？") : Text("这本是空的"))
                .font(.system(size: 12)).foregroundStyle(Color.faint)
                .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 24)
        } else {
            ForEach(sortedEntries) { entry in
                DiaryEntryCard(entry: entry, editable: diary.status == .draft) {
                    editorTarget = .edit(entry)
                }
                .padding(.horizontal, 22).padding(.top, 10)
            }
        }
    }

    // MARK: - 动作

    private func seal() {
        Task {
            // 邮局可用时顺手开箱，把自己的邮箱号封进口令（对方好回寄）
            let box = await post.ensureMailbox()?.boxID
            DiaryStore.seal(diary, senderName: holderName, senderBox: box, context: context)
            Haptics.success()
        }
    }

    private func unseal() {
        withAnimation(.spring(duration: 0.35)) { unsealing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            _ = DiaryStore.unseal(diary, context: context)
            Haptics.success()
            unsealing = false
            showReader = true
        }
    }

    private func deleteDiary() {
        context.delete(diary)
        try? context.save()
        dismiss()
    }
}

/// 单条日记卡：日期 + 心情 + 正文 +（草稿期）点击编辑。
struct DiaryEntryCard: View {
    let entry: DiaryEntry
    var editable: Bool = false
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: { if editable { onTap() } }) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(entry.date.formatted(.dateTime.month().day().weekday()))
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.nCyan)
                    if let mood = entry.mood { Text(mood).font(.system(size: 13)) }
                    Spacer()
                    if editable {
                        Image(systemName: "pencil").font(.system(size: 11)).foregroundStyle(Color.faint)
                    }
                }
                Text(verbatim: entry.text)
                    .font(.system(size: 13.5)).foregroundStyle(Color.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !entry.photoAssetIDs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(entry.photoAssetIDs, id: \.self) { id in
                                AssetImage(assetID: id, targetSize: CGSize(width: 240, height: 240))
                                    .frame(width: 74, height: 74)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.glass, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
