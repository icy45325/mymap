import SwiftUI
import SwiftData

/// 收到对方日记但 pairID 无命中时的归属选择：收进已有本 / 新建一本。
/// 完成（含新建）后回调 `onDone`（RootTabView 借此 markSeen 该口令）。
struct DiaryAttachSheet: View {

    let payload: DiaryPayload
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Button { createNew() } label: {
                        actionRow("plus.circle.fill", Text("新建一本收下"),
                                  Text("标题和对象都从口令里带出来"), Color.nPink)
                    }
                    let candidates = DiaryStore.candidates(context: context)
                    if !candidates.isEmpty {
                        Text("或收进已有的日记本").font(.system(size: 12)).foregroundStyle(Color.muted)
                        ForEach(candidates) { diary in
                            Button { attach(to: diary) } label: {
                                actionRow("book.pages", Text(verbatim: diary.title),
                                          partnersText(diary), Color.nCyan)
                            }
                        }
                    }
                }
                .padding(22)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("收下这本日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: payload.title).font(Typo.serif(20)).foregroundStyle(Color.text)
            Text(payload.sender.map { "\($0) 寄来 · \(payload.entries.count) 条" } ?? "\(payload.entries.count) 条")
                .font(.system(size: 12)).foregroundStyle(Color.muted)
            Text("现在还拆不开——先封存你那本，交换才算数 ✦")
                .font(.system(size: 11)).foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
    }

    private func actionRow(_ icon: String, _ title: Text, _ subtitle: Text,
                           _ tint: Color) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 19)).foregroundStyle(tint).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                title.font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.text)
                subtitle.font(.system(size: 11)).foregroundStyle(Color.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.faint)
        }
        .padding(15)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.line, lineWidth: 1))
    }

    private func partnersText(_ diary: ExchangeDiary) -> Text {
        let names = diary.partners.map(\.name).filter { !$0.isEmpty }
        guard let first = names.first else { return Text("还没有交换对象") }
        return names.count == 1 ? Text("与 \(first)") : Text("与 \(first) 等 \(names.count) 人")
    }

    private func createNew() {
        _ = DiaryStore.createFromPayload(payload, context: context)
        finish()
    }

    private func attach(to diary: ExchangeDiary) {
        // 收进已有本：pairID 对齐成寄件组的，之后全组往来都自动命中
        diary.pairID = payload.pairID
        let partner = DiaryStore.matchPartner(in: diary, payload: payload)
        DiaryStore.deposit(payload, into: partner)
        try? context.save()
        finish()
    }

    private func finish() {
        Haptics.success()
        onDone()
        dismiss()
    }
}
