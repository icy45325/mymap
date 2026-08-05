import SwiftUI
import SwiftData

/// 交换日记书架（Me → 交换日记）：卡片而非列表。
/// 卡面 = 书脊配色 + 旅程名 + 日期·地点·足迹数 + 两人头像交叠 + 页数进度 + 五状态徽标。
/// 「可揭晓」最抢眼（红边 + 呼吸封蜡）——它是回访钩子。
struct DiaryShelfView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \DiaryBook.createdAt, order: .reverse) private var books: [DiaryBook]

    @State private var showCreate = false

    /// 排序：可揭晓 > 待我写 > 等 TA > 已揭晓 > 空本；同档新在前。
    private var sorted: [DiaryBook] {
        books.sorted {
            let a = $0.shelfState.rawValue, b = $1.shelfState.rawValue
            return a != b ? a < b : $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        Group {
            if books.isEmpty { emptyTeaching }
            else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(sorted) { book in
                            NavigationLink { DiaryBookView(book: book) } label: {
                                DiaryBookCard(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 22).padding(.top, 12)
                }
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("交换日记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCreate) { DiaryCreateFlow(source: "me") }
        .onAppear { DiaryBookStore.degradeOrphanPages(context: context) }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    /// 空状态教学：这个机制不解释，用户不会自己发现。
    private var emptyTeaching: some View {
        VStack(spacing: 0) {
            Spacer()
            WaxSeal(size: 70, glow: true)
            Text("还没有一本日记").font(Typo.serif(20)).foregroundStyle(Color.text)
                .padding(.top, 16)
            (Text("各自写，") + Text("都写完才能拆封").bold() + Text("——\n看看对方当时在想什么。"))
                .font(.system(size: 13)).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center).lineSpacing(4)
                .padding(.top, 8)
            HStack(spacing: 8) {
                teachStep("✍️", "你写")
                teachStep("🔒", "封存")
                teachStep("✦", "一起拆")
            }
            .padding(.top, 20).padding(.horizontal, 40)
            Spacer()
            Button { showCreate = true } label: {
                Text("从一段旅程开始 →")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient.neonH, in: Capsule())
                    .shadow(color: Color.nPurple.opacity(0.5), radius: 12)
            }
            .padding(.horizontal, 26).padding(.bottom, 30)
        }
    }

    private func teachStep(_ emoji: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 5) {
            Text(verbatim: emoji).font(.system(size: 20))
            Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(Color.text)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
    }
}

/// 书架卡：真正的信息量在「状态」。
struct DiaryBookCard: View {
    let book: DiaryBook
    @AppStorage("lumi.profile.name") private var holderName: String = ""

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(book.shelfState == .revealable ? WaxSeal.wax : book.spineColor)
                .frame(width: 6)
                .padding(.vertical, 12)
            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: book.title).font(Typo.serif(17)).foregroundStyle(Color.text).lineLimit(1)
                Text(verbatim: metaLine)
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted).lineLimit(1)
                HStack(spacing: 6) {
                    PersonAvatar.named(holderName.isEmpty ? "我" : holderName, size: 22)
                    PersonAvatar.named(book.partnerName, size: 22).offset(x: -9)
                    Text("与 \(book.partnerName) 交换")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Color.text)
                        .offset(x: -5)
                }
                HStack {
                    Text(verbatim: pagesLine).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.faint)
                    Spacer()
                    stateBadge
                }
            }
            .padding(.vertical, 13).padding(.horizontal, 13)
            if book.shelfState == .revealable {
                WaxSeal(size: 34, glow: true).padding(.trailing, 12)
            }
        }
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(book.shelfState == .revealable ? WaxSeal.wax.opacity(0.7) : Color.line,
                    lineWidth: book.shelfState == .revealable ? 1.5 : 1))
        .opacity(book.shelfState == .empty ? 0.6 : 1)
    }

    private var metaLine: String {
        let dates = book.pages.map(\.dateSnapshot)
        let f: Date.FormatStyle = .dateTime.year().month(.defaultDigits).day()
        let range: String
        if let a = dates.min(), let b = dates.max() {
            range = Calendar.current.isDate(a, inSameDayAs: b)
                ? a.formatted(f) : "\(a.formatted(f)) – \(b.formatted(f))"
        } else { range = book.createdAt.formatted(f) }
        return "\(range) · \(book.pages.count) 页"
    }

    private var pagesLine: String {
        switch book.shelfState {
        case .revealed: return String(localized: "\(book.pages.count) 页 · 已拆封")
        case .empty:    return String(localized: "还没有人写过")
        default:        return String(localized: "已写 \(book.writtenPageCount) / \(book.pages.count) 页")
        }
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch book.shelfState {
        case .myTurn:     badge("✍️ 该你了", fg: Color(hex: 0x141109), bg: Color(hex: 0xFFD23E))
        case .waiting:    badge("🔒 已封存 · 等 TA", fg: Color.muted, bg: Color.glass)
        case .revealable: badge("✦ 可揭晓", fg: .white, bg: WaxSeal.wax)
        case .revealed:   badge("已揭晓", fg: Color.muted, bg: Color.glass)
        case .empty:      badge("空本子", fg: Color.faint, bg: Color.glass)
        }
    }

    private func badge(_ key: LocalizedStringKey, fg: Color, bg: Color) -> some View {
        Text(key).font(.system(size: 9.5, weight: .heavy))
            .foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(bg, in: Capsule())
            .overlay(Capsule().stroke(Color.line, lineWidth: 1))
    }
}
