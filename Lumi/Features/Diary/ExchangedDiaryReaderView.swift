import SwiftUI

/// 交换后的阅读：双方条目按日期合流成一条时间轴——对方靠前缘、我靠后缘（RTL 自适应）。
struct ExchangedDiaryReaderView: View {

    let diary: ExchangeDiary

    @Environment(\.dismiss) private var dismiss
    /// 只看对方（默认合流）。
    @State private var partnerOnly = false
    /// 解码一次缓存：对方整本日记。
    @State private var partner: DiaryPayload?

    private struct Item: Identifiable {
        let id: String
        let date: Date
        let text: String
        let mood: String?
        let mine: Bool
    }

    private var items: [Item] {
        var all: [Item] = (partner?.entries ?? []).enumerated().map { i, e in
            Item(id: "p\(i)", date: e.d, text: e.t, mood: e.m, mine: false)
        }
        if !partnerOnly {
            all += diary.entries.map { e in
                Item(id: e.id.uuidString, date: e.date, text: e.text, mood: e.mood, mine: true)
            }
        }
        return all.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    ForEach(items) { bubble($0) }
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 20).padding(.top, 12)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle(Text(verbatim: diary.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation { partnerOnly.toggle() } } label: {
                        (partnerOnly ? Text("看合流") : Text("只看对方"))
                            .font(.system(size: 12, weight: .bold))
                    }
                }
            }
            .onAppear {
                if partner == nil, let raw = diary.partnerToken {
                    partner = DiaryToken.decode(raw)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("✦").font(.system(size: 18)).foregroundStyle(Color(hex: 0xC9A24B))
            Text("\(partnerName) 与你的旅程")
                .font(Typo.serif(17)).foregroundStyle(Color.text)
            if let at = diary.exchangedAt {
                Text("交换于 \(at.formatted(.dateTime.year().month().day()))")
                    .font(.system(size: 11)).foregroundStyle(Color.faint)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var partnerName: String {
        diary.partnerName.isEmpty ? (partner?.sender ?? String(localized: "对方")) : diary.partnerName
    }

    private func bubble(_ item: Item) -> some View {
        VStack(alignment: item.mine ? .trailing : .leading, spacing: 5) {
            HStack(spacing: 6) {
                if item.mine { Spacer() }
                Text(item.mine ? String(localized: "我") : partnerName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(item.mine ? Color.nCyan : Color.nPink)
                Text(item.date.formatted(.dateTime.month().day()))
                    .font(.system(size: 10)).foregroundStyle(Color.faint)
                if let mood = item.mood { Text(mood).font(.system(size: 12)) }
                if !item.mine { Spacer() }
            }
            Text(verbatim: item.text)
                .font(.system(size: 13.5)).foregroundStyle(Color.text)
                .multilineTextAlignment(.leading)
                .padding(13)
                .background(
                    (item.mine ? Color.nCyan : Color.nPink).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke((item.mine ? Color.nCyan : Color.nPink).opacity(0.25), lineWidth: 1))
                .frame(maxWidth: .infinity, alignment: item.mine ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity)
    }
}
