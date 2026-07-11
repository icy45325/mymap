import SwiftUI
import SwiftData

/// 动态列表：收到的明信片 / 交换日记更新。点击标记已读并跳对应页面。
struct NoticeListView: View {

    @Environment(\.modelContext) private var context
    @ObservedObject private var center = NoticeCenter.shared

    var body: some View {
        Group {
            if center.notices.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bell").font(.system(size: 36)).foregroundStyle(Color.faint)
                    Text("暂无动态").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.muted)
                    Text("收到明信片或伙伴的日记寄到时，会出现在这里")
                        .font(.system(size: 12)).foregroundStyle(Color.faint)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(center.notices) { notice in
                            row(notice)
                        }
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 22).padding(.top, 12)
                }
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("动态")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if center.unreadCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("全部已读") { center.markAllRead() }
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    @ViewBuilder
    private func row(_ notice: Notice) -> some View {
        NavigationLink {
            destination(notice)
                .onAppear { center.markRead(notice.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: notice.kind == .postcard ? "rectangle.stack.fill" : "book.pages.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(notice.kind == .postcard ? Color.nPink : Color.nPurple)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: notice.title)
                        .font(.system(size: 13.5, weight: notice.read ? .regular : .semibold))
                        .foregroundStyle(Color.text).lineLimit(1)
                    Text(verbatim: notice.subtitle)
                        .font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(notice.date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10)).foregroundStyle(Color.faint)
                    if !notice.read {
                        Circle().fill(Color.nCyan).frame(width: 7, height: 7)
                            .shadow(color: Color.nCyan.opacity(0.8), radius: 3)
                    }
                }
            }
            .padding(13)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(notice.read ? Color.line : Color.nCyan.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// 跳转目标：明信片 → 明信片墙；日记 → 对应日记本（查不到回列表）。
    @ViewBuilder
    private func destination(_ notice: Notice) -> some View {
        switch notice.kind {
        case .postcard:
            PostcardWallView()
        case .diary:
            if let uuid = UUID(uuidString: notice.targetID), let diary = fetchDiary(uuid) {
                ExchangeDiaryDetailView(diary: diary)
            } else {
                ExchangeDiaryListView()
            }
        }
    }

    private func fetchDiary(_ id: UUID) -> ExchangeDiary? {
        let all = (try? context.fetch(FetchDescriptor<ExchangeDiary>())) ?? []
        return all.first { $0.id == id }
    }
}
