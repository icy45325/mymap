import SwiftUI

/// 交换后的阅读：全组条目按日期合流——伙伴靠前缘（各有专属色+头像）、我靠后缘（RTL 自适应）。
/// 只合流**已拆开**的伙伴；顶部可筛「全部 / 只看某人 / 只看我」。
struct ExchangedDiaryReaderView: View {

    let diary: ExchangeDiary

    @Environment(\.dismiss) private var dismiss
    /// 筛选：nil = 全部；否则只看该伙伴（"me" 特殊值 = 只看我）。
    @State private var focus: UUID?
    @State private var focusMe = false
    /// 解码缓存：伙伴 id → 整本日记。
    @State private var decoded: [UUID: DiaryPayload] = [:]

    private static let tints: [Color] = [.nPink, .nOrange, .nPurple, .nCyan]

    private struct Item: Identifiable {
        let id: String
        let date: Date
        let text: String
        let mood: String?
        let author: String       // 展示名（"我" 或伙伴名）
        let mine: Bool
        let tint: Color
    }

    private var openedPartners: [DiaryPartner] {
        diary.openedPartners.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func tint(for index: Int) -> Color {
        Self.tints[index % Self.tints.count]
    }

    private var items: [Item] {
        var all: [Item] = []
        for (i, partner) in openedPartners.enumerated() {
            if let f = focus, f != partner.id { continue }
            if focusMe { continue }
            guard let payload = decoded[partner.id] else { continue }
            let t = tint(for: i)
            all += payload.entries.enumerated().map { j, e in
                Item(id: "\(partner.id)-\(j)", date: e.d, text: e.t, mood: e.m,
                     author: partner.name, mine: false, tint: t)
            }
        }
        if focus == nil {
            all += diary.entries.map { e in
                Item(id: e.id.uuidString, date: e.date, text: e.text, mood: e.mood,
                     author: String(localized: "我"), mine: true, tint: .nCyan)
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
                    if openedPartners.count > 1 || focus != nil || focusMe {
                        filterMenu
                    }
                }
            }
            .onAppear { decodeAll() }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    private var filterMenu: some View {
        Menu {
            Button { focus = nil; focusMe = false } label: {
                Label("全部", systemImage: focus == nil && !focusMe ? "checkmark" : "person.3")
            }
            ForEach(openedPartners) { p in
                Button { focus = p.id; focusMe = false } label: {
                    Label(p.name, systemImage: focus == p.id ? "checkmark" : "person")
                }
            }
            Button { focus = nil; focusMe = true } label: {
                Label("只看我", systemImage: focusMe ? "checkmark" : "person.crop.circle")
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 15, weight: .semibold))
        }
    }

    private func decodeAll() {
        for partner in openedPartners where decoded[partner.id] == nil {
            if let raw = partner.shellToken, let payload = DiaryToken.decode(raw) {
                decoded[partner.id] = payload
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("✦").font(.system(size: 18)).foregroundStyle(Color(hex: 0xC9A24B))
            Text("\(headerNames) 与你的旅程")
                .font(Typo.serif(17)).foregroundStyle(Color.text)
                .multilineTextAlignment(.center)
            PartnerAvatarStack(names: openedPartners.map(\.name), size: 24)
            if let at = diary.exchangedAt {
                Text("交换于 \(at.formatted(.dateTime.year().month().day()))")
                    .font(.system(size: 11)).foregroundStyle(Color.faint)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var headerNames: String {
        let names = openedPartners.map(\.name).filter { !$0.isEmpty }
        return names.isEmpty ? String(localized: "对方") : names.joined(separator: "、")
    }

    private func bubble(_ item: Item) -> some View {
        VStack(alignment: item.mine ? .trailing : .leading, spacing: 5) {
            HStack(spacing: 6) {
                if item.mine { Spacer() }
                if !item.mine { PersonAvatar.named(item.author, size: 16) }
                Text(verbatim: item.author)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(item.tint)
                Text(item.date.formatted(.dateTime.month().day()))
                    .font(.system(size: 10)).foregroundStyle(Color.faint)
                if let mood = item.mood { Text(mood).font(.system(size: 12)) }
                if !item.mine { Spacer() }
            }
            Text(verbatim: item.text)
                .font(.system(size: 13.5)).foregroundStyle(Color.text)
                .multilineTextAlignment(.leading)
                .padding(13)
                .background(item.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke(item.tint.opacity(0.25), lineWidth: 1))
                .frame(maxWidth: .infinity, alignment: item.mine ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity)
    }
}
