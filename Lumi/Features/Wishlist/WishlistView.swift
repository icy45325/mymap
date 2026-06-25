import SwiftUI
import SwiftData
import MapKit

/// 心愿单：想去但还没去的地方。可在此搜索添加，或在真实地图上点选标记。
struct WishlistView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Wish.createdAt, order: .reverse) private var wishes: [Wish]

    @State private var showAdd = false

    var body: some View {
        Group {
            if wishes.isEmpty { emptyState }
            else { list }
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("心愿单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .tint(Color.nPink)
            }
        }
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAdd) { AddWishView() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.text.square").font(.system(size: 44)).foregroundStyle(Color.nPink)
            Text("还没有心愿").font(.headline).foregroundStyle(Color.text)
            Text("搜索添加想去的地方，或在地图上点选标记")
                .font(.subheadline).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button { showAdd = true } label: {
                Label("添加心愿", systemImage: "plus")
                    .font(.headline).padding(.vertical, 13).padding(.horizontal, 22)
                    .background(LinearGradient.neonH, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(wishes) { wish in
                    HStack(spacing: 12) {
                        Text(wish.flag).font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(wish.title).font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.text).lineLimit(1)
                            if let country = wish.countryName, country != wish.title {
                                Text(country).font(.system(size: 11)).foregroundStyle(Color.muted)
                            }
                        }
                        Spacer()
                        Button {
                            context.delete(wish)
                            try? context.save()
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textMuted)
                        }
                    }
                    .padding(12)
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
                }
            }
            .padding(16)
        }
    }
}

/// 添加心愿：搜索地点（复用 PlaceSearchService），选定即入心愿单。
private struct AddWishView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = PlaceSearchService()
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.textMuted)
                    TextField("搜索想去的城市 / 国家", text: $query)
                        .foregroundStyle(Color.textPrimary)
                        .onChange(of: query) { _, q in search.search(q, near: nil) }
                }
                .padding(12)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
                .padding(16)

                if search.isSearching { ProgressView().tint(Color.nPink).padding(.top, 8) }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(search.results) { result in
                            Button { add(result) } label: {
                                HStack {
                                    Image(systemName: "mappin.circle").foregroundStyle(Color.textMuted)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.name).foregroundStyle(Color.textPrimary)
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle).font(.caption).foregroundStyle(Color.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "heart").foregroundStyle(Color.nPink)
                                }
                                .padding(.vertical, 10).padding(.horizontal, 16)
                            }
                            Divider().overlay(Color.lineSoft)
                        }
                    }
                }
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("添加心愿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
            }
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    private func add(_ result: PlaceResult) {
        let code = Boundaries.shared.countryCode(at: result.coordinate) ?? result.countryCode
        // 同地点（国家 + 城市）已在心愿单则不重复
        let existing = (try? context.fetch(FetchDescriptor<Wish>())) ?? []
        if existing.contains(where: { $0.countryCode == code && $0.cityName == result.cityName }) {
            dismiss(); return
        }
        let wish = Wish(placeName: result.name,
                        coordinate: result.coordinate,
                        cityName: result.cityName,
                        countryCode: code)
        context.insert(wish)
        do { try context.save() } catch { assertionFailure("保存心愿失败: \(error)") }
        dismiss()
    }
}
