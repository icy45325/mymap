import SwiftUI
import SwiftData

/// 交换日记创建流程：选旅程 → 选对象 → 选页 → 成书（封面全自动）→ **直接进第一页写作页**。
/// 设计守则：创建到落笔 ≤3 次点击；「不用每页都写」必须出现。
/// 从足迹入口进入时传 `prefillFootprint`（旅程自动命中，跳过 Step 1）。
struct DiaryCreateFlow: View {

    var source: String                       // "footprint" / "me"（埋点）
    var prefillFootprint: Footprint? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var footprints: [Footprint]
    @ObservedObject private var contacts = PostcardContacts.shared

    private enum Step { case trip, partner, pages }
    @State private var step: Step = .trip
    @State private var candidate: TripCandidate?
    @State private var partnerName = ""
    @State private var customPartner = ""
    @State private var selectedPages: Set<UUID> = []
    /// 成书后直达第一页写作页
    @State private var createdBook: DiaryBook?
    @State private var firstPage: DiaryPage?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .trip:    tripStep
                case .partner: partnerStep
                case .pages:   pagesStep
                }
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        Analytics.log(.diaryCreateAbandoned(lastStep: "\(step)"))
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $firstPage) { page in
                if let book = createdBook {
                    DiaryComposeView(book: book, page: page, asOwner: true, onDone: { dismiss() })
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
        .onAppear {
            Analytics.log(.diaryCreateStarted(source: source))
            // 足迹入口：自动命中所属旅程，跳过选旅程
            if let fp = prefillFootprint, candidate == nil {
                candidate = TripSuggest.candidate(containing: fp, in: footprints)
                if let c = candidate {
                    selectedPages = Set(c.footprints.map(\.id))
                    step = .partner
                }
            }
        }
    }

    // MARK: - Step 1 · 选旅程（自动聚类，零填写）

    private var tripStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                stepHeader("选一段旅程", subtitle: "旅程与封面全自动生成，不用填表")
                let cands = TripSuggest.candidates(from: footprints)
                if cands.isEmpty {
                    Text("还没有足迹——先去地图点亮一个地方吧")
                        .font(.system(size: 12)).foregroundStyle(Color.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    ForEach(cands) { c in
                        Button {
                            candidate = c
                            selectedPages = Set(c.footprints.map(\.id))
                            step = .partner
                        } label: {
                            HStack(spacing: 11) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(verbatim: c.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Color.text)
                                    Text(verbatim: "\(c.dateRangeText) · \(c.footprints.count) 足迹")
                                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted)
                                }
                                Spacer()
                                PartnerAvatarStack(names: c.companions, size: 20)
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.faint)
                            }
                            .padding(13)
                            .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(22)
        }
        .navigationTitle("交换日记")
    }

    // MARK: - Step 2 · 选交换对象（这段旅程已有的旅伴）

    private var partnerStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                stepHeader("和谁交换？", subtitle: candidate.map { "\($0.title) · \($0.dateRangeText)" } ?? "")
                ForEach(partnerOptions, id: \.self) { name in
                    partnerRow(name)
                }
                // 手输补一个（不在旅伴里的人）
                HStack(spacing: 8) {
                    TextField("", text: $customPartner,
                              prompt: Text("或输入一个名字").foregroundStyle(Color.faint))
                        .font(.system(size: 14)).foregroundStyle(Color.text)
                        .onSubmit { pickPartner(customPartner) }
                    Button { pickPartner(customPartner) } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20)).foregroundStyle(Color.nPink)
                    }
                    .disabled(customPartner.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(11)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))

                Text("远程交换（各写各的手机）随好友体系上线；现在是本机传递——写完把手机递给 TA ✦")
                    .font(.system(size: 10.5)).foregroundStyle(Color.faint)
            }
            .padding(22)
        }
        .navigationTitle("和谁交换？")
    }

    /// 旅伴优先，其次「往来的人」（去重）。
    private var partnerOptions: [String] {
        var seen = Set<String>(), out: [String] = []
        for n in (candidate?.companions ?? []) + contacts.recent.prefix(8).map(\.name) {
            let k = n.lowercased()
            if !n.isEmpty, !seen.contains(k) { seen.insert(k); out.append(n) }
        }
        return out
    }

    private func partnerRow(_ name: String) -> some View {
        Button { pickPartner(name) } label: {
            HStack(spacing: 11) {
                PersonAvatar.named(name, size: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: name).font(.system(size: 14, weight: .bold)).foregroundStyle(Color.text)
                    Text((candidate?.companions.contains { $0.caseInsensitiveCompare(name) == .orderedSame } ?? false)
                         ? "这段旅程的旅伴" : "往来的人")
                        .font(.system(size: 10)).foregroundStyle(Color.muted)
                }
                Spacer()
                Text("📱 本机传递").font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color(hex: 0xFFD23E).opacity(0.9), in: Capsule())
                    .foregroundStyle(Color(hex: 0x141109))
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.faint)
            }
            .padding(12)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func pickPartner(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        partnerName = n
        step = .pages
    }

    // MARK: - Step 3 · 选页（默认全选 + 减负文案）→ 成书

    private var pagesStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    stepHeader("写哪几页？", subtitle: "默认全选 · 一个足迹 = 一页")
                    ForEach(candidate?.footprints ?? []) { fp in
                        pageRow(fp)
                    }
                    Text("不用每页都写，随时可以补 ✦")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0xC9A24B))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color(hex: 0xC9A24B).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(22)
            }
            Button { createBook() } label: {
                Text("成书 · 开始写第一页 ✦")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient.neonH, in: Capsule())
                    .shadow(color: Color.nPurple.opacity(0.5), radius: 12)
            }
            .disabled(selectedPages.isEmpty)
            .opacity(selectedPages.isEmpty ? 0.5 : 1)
            .padding(.horizontal, 26).padding(.bottom, 16)
        }
        .navigationTitle("写哪几页？")
    }

    private func pageRow(_ fp: Footprint) -> some View {
        let on = selectedPages.contains(fp.id)
        return Button {
            if on { selectedPages.remove(fp.id) } else { selectedPages.insert(fp.id) }
            Haptics.selection()
        } label: {
            HStack(spacing: 10) {
                Text(fp.flag).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: fp.title).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.text)
                    Text(fp.visitedAt.formatted(.dateTime.month(.defaultDigits).day()))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted)
                }
                Spacer()
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 19)).foregroundStyle(on ? Color.nPink : Color.line)
            }
            .padding(11)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Color.nPink.opacity(0.4) : Color.line, lineWidth: 1))
            .opacity(on ? 1 : 0.6)
        }
        .buttonStyle(.plain)
    }

    private func createBook() {
        guard let candidate else { return }
        let chosen = candidate.footprints.filter { selectedPages.contains($0.id) }
        let book = DiaryBookStore.createBook(from: candidate, partnerName: partnerName,
                                             selectedFootprints: chosen, context: context)
        createdBook = book
        Haptics.success()
        firstPage = book.sortedPages.first        // 直达第一页写作页（不停在空书）
    }

    private func stepHeader(_ title: LocalizedStringKey, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Typo.serif(22)).foregroundStyle(Color.text)
            if !subtitle.isEmpty {
                Text(verbatim: subtitle).font(.system(size: 11)).foregroundStyle(Color.muted)
            }
        }
        .padding(.bottom, 6)
    }
}
