import SwiftUI
import SwiftData

/// 交换日记列表：日记本卡片（书脊色条 + 旅途信息 + 伙伴头像 + 状态）。
struct ExchangeDiaryListView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \ExchangeDiary.createdAt, order: .reverse)
    private var diaries: [ExchangeDiary]
    @Query private var footprints: [Footprint]

    @State private var showNew = false

    private var ongoing: [ExchangeDiary] { diaries.filter { !$0.isExchanged } }
    private var exchanged: [ExchangeDiary] { diaries.filter(\.isExchanged) }

    private var footprintByID: [UUID: Footprint] {
        Dictionary(uniqueKeysWithValues: footprints.map { ($0.id, $0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if diaries.isEmpty { emptyState }
                if !ongoing.isEmpty {
                    sectionTitle("进行中")
                    ForEach(ongoing) { card($0) }
                }
                if !exchanged.isEmpty {
                    sectionTitle("已交换")
                    ForEach(exchanged) { card($0) }
                }
                Color.clear.frame(height: 24)
            }
            .padding(.top, 8)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("交换日记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showNew) { NewDiarySheet() }
        .onAppear { diaries.forEach { DiaryStore.migrateIfNeeded($0, context: context) } }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.muted)
            .padding(.horizontal, 26).padding(.top, 18).padding(.bottom, 4)
    }

    private func spineColor(_ diary: ExchangeDiary) -> Color {
        diary.isExchanged ? Color(hex: 0xC9A24B) : (diary.status == .sealed ? Color.nPurple : Color.nCyan)
    }

    /// 日记本卡片：书脊色条 + 标题 + 旅途信息 + 伙伴头像 + 状态。
    private func card(_ diary: ExchangeDiary) -> some View {
        NavigationLink { ExchangeDiaryDetailView(diary: diary) } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(spineColor(diary))
                    .frame(width: 5)
                    .padding(.vertical, 14)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(verbatim: diary.title)
                            .font(Typo.serif(17)).foregroundStyle(Color.text)
                            .lineLimit(1)
                        Spacer()
                        DiaryStatusChip(diary: diary)
                    }
                    tripLine(diary)
                    HStack(spacing: 8) {
                        PartnerAvatarStack(names: diary.partners.map(\.name), size: 22)
                        Text(partnersLabel(diary))
                            .font(.system(size: 12)).foregroundStyle(Color.muted)
                            .lineLimit(1)
                        Spacer()
                        Text("\(diary.entries.count) 条").font(.system(size: 11)).foregroundStyle(Color.faint)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.faint)
                    }
                }
                .padding(.vertical, 14).padding(.horizontal, 14)
            }
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
        }
        .padding(.horizontal, 26).padding(.top, 10)
    }

    /// 旅途信息：关联足迹的 国旗+地点+日期；无关联回退开始日期。
    @ViewBuilder
    private func tripLine(_ diary: ExchangeDiary) -> some View {
        if let fpID = diary.footprintID, let fp = footprintByID[fpID] {
            HStack(spacing: 5) {
                Text(fp.flag).font(.system(size: 12))
                Text(verbatim: fp.title).font(.system(size: 12)).foregroundStyle(Color.muted).lineLimit(1)
                Text(fp.visitedAt.formatted(.dateTime.year().month(.abbreviated).day()))
                    .font(.system(size: 11)).foregroundStyle(Color.faint)
            }
        } else {
            Text("开始于 \(diary.createdAt.formatted(.dateTime.year().month().day()))")
                .font(.system(size: 11)).foregroundStyle(Color.faint)
        }
    }

    private func partnersLabel(_ diary: ExchangeDiary) -> String {
        let names = diary.partners.map(\.name).filter { !$0.isEmpty }
        guard let first = names.first else { return String(localized: "还没有交换对象") }
        if names.count == 1 { return String(localized: "与 \(first)") }
        return String(localized: "与 \(first) 等 \(names.count) 人")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.pages")
                .font(.system(size: 40)).foregroundStyle(Color.nPurple)
            Text("和旅伴各写各的日记").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
            Text("旅程结束后封存、交换，才能拆开对方写了什么 ✦")
                .font(.system(size: 12)).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
            Button { showNew = true } label: {
                Text("开一本交换日记")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 11)
                    .background(LinearGradient.neon, in: Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60).padding(.horizontal, 40)
    }
}

/// 伙伴头像堆叠：≤3 个重叠排列，多出的显示 +N。
struct PartnerAvatarStack: View {
    let names: [String]
    var size: CGFloat = 22

    var body: some View {
        let shown = Array(names.prefix(3))
        HStack(spacing: -size * 0.28) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, name in
                PersonAvatar.named(name, size: size)
                    .overlay(Circle().stroke(Color.bg, lineWidth: 1.5))
            }
            if names.count > 3 {
                ZStack {
                    Circle().fill(Color.panel).frame(width: size, height: size)
                        .overlay(Circle().stroke(Color.line, lineWidth: 1))
                    Text(verbatim: "+\(names.count - 3)")
                        .font(.system(size: size * 0.38, weight: .bold)).foregroundStyle(Color.muted)
                }
            }
        }
    }
}

/// 状态角标：手记中 / 已封存（群本显示拆开进度）/ 已交换。
struct DiaryStatusChip: View {
    let diary: ExchangeDiary

    var body: some View {
        let opened = diary.openedPartners.count
        let total = diary.partners.count
        let (text, tint): (Text, Color) =
            diary.isExchanged ? (Text("已交换"), Color(hex: 0xC9A24B))
            : diary.status == .sealed
                ? (opened > 0 && total > 1 ? Text("已拆 \(opened)/\(total)") : Text("已封存"), Color.nPurple)
                : (Text("手记中"), Color.nCyan)
        text
            .font(.system(size: 10, weight: .bold)).foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

/// 新建一本：标题 + 交换伙伴（多选：旅伴建议 chips / 往来的人 chips / 手输 tag 追加）。
/// 从足迹发起时传 prefill*（标题、旅伴建议默认全选、footprintID 关联旅途）。
struct NewDiarySheet: View {

    var prefillTitle: String = ""
    var suggestedNames: [String] = []       // 足迹旅伴（默认全选）
    var footprintID: UUID? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject private var contacts = PostcardContacts.shared

    @State private var title = ""
    /// 已选伙伴（保序）。
    @State private var partnerNames: [String] = []
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field("日记标题", text: $title, prompt: "如：2026 冰岛")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("和谁交换（可多选）").font(.system(size: 12)).foregroundStyle(Color.muted)
                        if !partnerNames.isEmpty { selectedChips }
                        HStack(spacing: 8) {
                            TextField("", text: $draft,
                                      prompt: Text("输入旅伴昵称").foregroundStyle(Color.faint))
                                .font(.system(size: 14)).foregroundStyle(Color.text)
                                .onSubmit(addDraft)
                            Button(action: addDraft) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20)).foregroundStyle(Color.nPink)
                            }
                            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(11)
                        .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
                    }

                    if !suggestionChipsSource.isEmpty {
                        Text("从旅伴 / 往来的人里选").font(.system(size: 12)).foregroundStyle(Color.muted)
                        suggestionChips
                    }

                    Text("你们各写各的，互相看不到；每个人封存并互寄后，才能逐个拆开。")
                        .font(.system(size: 11)).foregroundStyle(Color.faint)
                }
                .padding(22)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("开一本交换日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || allNames.isEmpty)
                }
            }
            .onAppear {
                if title.isEmpty { title = prefillTitle }
                if partnerNames.isEmpty { partnerNames = suggestedNames }   // 足迹旅伴默认全选
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    /// 已选 + 未提交草稿。
    private var allNames: [String] {
        var names = partnerNames
        let d = draft.trimmingCharacters(in: .whitespaces)
        if !d.isEmpty, !names.contains(where: { $0.caseInsensitiveCompare(d) == .orderedSame }) {
            names.append(d)
        }
        return names
    }

    /// 建议 chips：足迹旅伴在前、往来的人在后（去重）。
    private var suggestionChipsSource: [String] {
        var seen = Set<String>(), out: [String] = []
        for n in suggestedNames + contacts.recent.prefix(12).map(\.name) {
            let key = n.lowercased()
            if !n.isEmpty, !seen.contains(key) { seen.insert(key); out.append(n) }
        }
        return out
    }

    private var selectedChips: some View {
        FlexWrap(items: partnerNames) { name in
            HStack(spacing: 6) {
                PersonAvatar.named(name, size: 20)
                Text(verbatim: name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.text)
                Button { remove(name) } label: {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.faint)
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(Color.nPink.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color.nPink.opacity(0.4), lineWidth: 1))
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestionChipsSource, id: \.self) { name in
                    let picked = partnerNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
                    Button { picked ? remove(name) : partnerNames.append(name) } label: {
                        HStack(spacing: 6) {
                            PersonAvatar.named(name, size: 22)
                            Text(verbatim: name)
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.text)
                            if picked {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.nPink)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.panel, in: Capsule())
                        .overlay(Capsule().stroke(picked ? Color.nPink : Color.line, lineWidth: 1))
                    }
                }
            }
        }
    }

    private func addDraft() {
        let d = draft.trimmingCharacters(in: .whitespaces)
        guard !d.isEmpty else { return }
        if !partnerNames.contains(where: { $0.caseInsensitiveCompare(d) == .orderedSame }) {
            partnerNames.append(d)
        }
        draft = ""
    }

    private func remove(_ name: String) {
        partnerNames.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func create() {
        let d = ExchangeDiary(title: title.trimmingCharacters(in: .whitespaces),
                              footprintID: footprintID)
        context.insert(d)
        for name in allNames {
            let p = DiaryPartner(name: name,
                                 boxID: PostcardContacts.shared.contact(named: name)?.boxID)
            p.diary = d
            d.partners.append(p)
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 12)).foregroundStyle(Color.muted)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Color.faint))
                .font(.system(size: 15))
                .foregroundStyle(Color.text)
                .padding(13)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
        }
    }
}

/// 简易换行流式布局（已选伙伴 chips 用）。
struct FlexWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        // 数量少（≤ 六七个），直接横向滚动即可；避免自定义 Layout 的复杂度
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { ForEach(items, id: \.self) { content($0) } }
        }
    }
}
