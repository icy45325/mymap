import SwiftUI
import SwiftData

/// 日记本详情：我的条目时间轴 + 写一条 + 封存 + 交换区（伙伴状态清单，逐人拆开）。
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
    /// 拆开动效目标伙伴。
    @State private var unsealing: DiaryPartner?

    private var sortedEntries: [DiaryEntry] {
        diary.entries.sorted { $0.date > $1.date }
    }
    private var sortedPartners: [DiaryPartner] {
        diary.partners.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
        .onAppear { DiaryStore.migrateIfNeeded(diary, context: context) }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    // MARK: - 头部

    private var headerCard: some View {
        HStack(spacing: 13) {
            PartnerAvatarStack(names: sortedPartners.map(\.name), size: 26)
            VStack(alignment: .leading, spacing: 4) {
                if sortedPartners.isEmpty {
                    Text("还没有交换对象").font(.system(size: 13)).foregroundStyle(Color.muted)
                } else {
                    Text("与 \(partnerNamesLine) 交换").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.text).lineLimit(1)
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

    private var partnerNamesLine: String {
        sortedPartners.map(\.name).filter { !$0.isEmpty }.joined(separator: "、")
    }

    // MARK: - 交换区（我方状态 + 伙伴清单）

    @ViewBuilder
    private var exchangeZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 我方：封存 / 寄出
            myStateCard
            // 伙伴清单：每人一行状态
            if !sortedPartners.isEmpty, diary.status == .sealed || sortedPartners.contains(where: { $0.shellToken != nil }) {
                partnersCard
            }
            if diary.isExchanged {
                zoneButton("一起读 ✦", prominent: true) { showReader = true }
                    .frame(maxWidth: .infinity)
            } else if !diary.openedPartners.isEmpty {
                zoneButton("读已拆开的 ✦", prominent: false) { showReader = true }
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 22).padding(.top, 12)
    }

    @ViewBuilder
    private var myStateCard: some View {
        switch diary.status {
        case .draft:
            let shellsWaiting = sortedPartners.contains { $0.shellToken != nil }
            zoneCard(icon: shellsWaiting ? "lock.fill" : "lock.open",
                     tint: shellsWaiting ? Color.nPurple : Color.nCyan,
                     title: shellsWaiting ? Text("伙伴的日记已寄到") : Text("写完这段旅程就封存"),
                     subtitle: shellsWaiting ? Text("密封着呢——先封存你的，才能拆开 ✦")
                                             : Text("封存后不能再改，才能与对方交换")) {
                zoneButton("封存这本日记", prominent: shellsWaiting, disabled: diary.entries.isEmpty) {
                    confirmSeal = true
                }
            }
        case .sealed:
            zoneCard(icon: "paperplane.fill", tint: Color.nPink,
                     title: diary.sentAt == nil ? Text("封存好了，寄给伙伴们吧") : Text("已寄出，可随时再寄"),
                     subtitle: Text("同一份口令全员通用：口令 / 二维码 / AirDrop / 邮局直投都行")) {
                zoneButton(diary.sentAt == nil ? "寄出我的日记 ✦" : "再寄一次", prominent: diary.sentAt == nil) {
                    showExchange = true
                }
            }
        }
    }

    private var partnersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交换伙伴").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.muted)
            ForEach(sortedPartners) { partner in
                partnerRow(partner)
            }
        }
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
    }

    private func partnerRow(_ partner: DiaryPartner) -> some View {
        HStack(spacing: 10) {
            PersonAvatar.named(partner.name, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: partner.name.isEmpty ? "…" : partner.name)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
                partnerStateText(partner)
                    .font(.system(size: 10.5)).foregroundStyle(Color.muted)
            }
            Spacer()
            if partner.unsealedAt != nil {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 14)).foregroundStyle(Color(hex: 0xC9A24B))
            } else if partner.shellToken != nil {
                if diary.status == .sealed {
                    Button {
                        unseal(partner)
                    } label: {
                        Text("拆开 ✦").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .background(LinearGradient.neon, in: Capsule())
                    }
                    .scaleEffect(unsealing?.id == partner.id ? 1.08 : 1)
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(Color.nPurple)
                }
            } else {
                Image(systemName: "hourglass").font(.system(size: 13)).foregroundStyle(Color.faint)
            }
        }
    }

    private func partnerStateText(_ partner: DiaryPartner) -> Text {
        if let at = partner.unsealedAt {
            return Text("已拆开 · \(at.formatted(.dateTime.month().day()))")
        }
        if partner.shellToken != nil {
            return diary.status == .sealed ? Text("已寄到 · 可以拆开") : Text("已寄到 · 先封存你的")
        }
        return Text("等待 Ta 封存寄来…")
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
            // 邮局可用时顺手开箱，把自己的邮箱号封进口令（伙伴好回寄）
            let box = await post.ensureMailbox()?.boxID
            DiaryStore.seal(diary, senderName: holderName, senderBox: box, context: context)
            Haptics.success()
        }
    }

    private func unseal(_ partner: DiaryPartner) {
        withAnimation(.spring(duration: 0.35)) { unsealing = partner }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            _ = DiaryStore.unseal(partner, of: diary, context: context)
            Haptics.success()
            unsealing = nil
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
