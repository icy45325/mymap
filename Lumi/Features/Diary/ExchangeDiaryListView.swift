import SwiftUI
import SwiftData

/// 交换日记列表：进行中 / 已交换两节 + 空态引导 + 新建。
struct ExchangeDiaryListView: View {

    @Query(sort: \ExchangeDiary.createdAt, order: .reverse)
    private var diaries: [ExchangeDiary]

    @State private var showNew = false

    private var ongoing: [ExchangeDiary] { diaries.filter { !$0.isExchanged } }
    private var exchanged: [ExchangeDiary] { diaries.filter(\.isExchanged) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if diaries.isEmpty { emptyState }
                if !ongoing.isEmpty {
                    sectionTitle("进行中")
                    ForEach(ongoing) { row($0) }
                }
                if !exchanged.isEmpty {
                    sectionTitle("已交换")
                    ForEach(exchanged) { row($0) }
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
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.muted)
            .padding(.horizontal, 26).padding(.top, 18).padding(.bottom, 4)
    }

    private func row(_ diary: ExchangeDiary) -> some View {
        NavigationLink { ExchangeDiaryDetailView(diary: diary) } label: {
            HStack(spacing: 14) {
                Image(systemName: diary.isExchanged ? "book.pages.fill" : (diary.status == .sealed ? "lock.fill" : "pencil.line"))
                    .font(.system(size: 20))
                    .foregroundStyle(diary.isExchanged ? Color(hex: 0xC9A24B) : (diary.status == .sealed ? Color.nPurple : Color.nCyan))
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: diary.title)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
                    HStack(spacing: 6) {
                        if !diary.partnerName.isEmpty {
                            Text("与 \(diary.partnerName)").font(.system(size: 11)).foregroundStyle(Color.muted)
                        }
                        Text("\(diary.entries.count) 条").font(.system(size: 11)).foregroundStyle(Color.faint)
                    }
                }
                Spacer()
                DiaryStatusChip(diary: diary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.faint)
            }
            .padding(16)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
        }
        .padding(.horizontal, 26).padding(.top, 10)
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

/// 状态角标：手记中 / 已封存·待交换 / 已交换。
struct DiaryStatusChip: View {
    let diary: ExchangeDiary

    var body: some View {
        let (key, tint): (LocalizedStringKey, Color) =
            diary.isExchanged ? ("已交换", Color(hex: 0xC9A24B))
            : diary.status == .sealed ? ("已封存", Color.nPurple)
            : ("手记中", Color.nCyan)
        Text(key)
            .font(.system(size: 10, weight: .bold)).foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

/// 新建一本：标题 + 交换对象（手输，或从「往来的人」点选带出邮箱号）。
private struct NewDiarySheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject private var contacts = PostcardContacts.shared

    @State private var title = ""
    @State private var partnerName = ""

    /// 名字与「往来的人」对上时带出其邮箱号（手输改名后自然失配置空，不需要额外状态）。
    private var resolvedBox: String? {
        let name = partnerName.trimmingCharacters(in: .whitespaces)
        return contacts.recent.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.boxID
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field("日记标题", text: $title, prompt: "如：2026 冰岛")
                    field("和谁交换", text: $partnerName, prompt: "对方昵称")
                    if !contacts.recent.isEmpty {
                        Text("从往来的人里选").font(.system(size: 12)).foregroundStyle(Color.muted)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(contacts.recent.prefix(12)) { c in
                                    Button {
                                        partnerName = c.name
                                    } label: {
                                        HStack(spacing: 6) {
                                            PostcardWallView.avatar(c, size: 22)
                                            Text(verbatim: c.name)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color.text)
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(Color.panel, in: Capsule())
                                        .overlay(Capsule().stroke(
                                            partnerName == c.name ? Color.nPink : Color.line, lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                    Text("你们各写各的，对方看不到；两边都封存并互寄后才能拆开。")
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
                    Button("创建") {
                        let d = ExchangeDiary(title: title.trimmingCharacters(in: .whitespaces),
                                              partnerName: partnerName.trimmingCharacters(in: .whitespaces),
                                              partnerBoxID: resolvedBox)
                        context.insert(d)
                        try? context.save()
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
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
