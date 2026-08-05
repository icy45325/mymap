import SwiftUI

/// 资源商店（v1.2）：按品类陈列资源包；混合制——常规包随 Plus 免费领、限量/联名单买。
/// 目录 = 内置 manifest + 远程增值包（进页刷新，失败静默保持内置，永不白屏）。
struct StoreView: View {
    @ObservedObject private var catalog = PackCatalog.shared
    @ObservedObject private var packStore = PackStore.shared
    @ObservedObject private var plus = PlusStore.shared
    @State private var selectedPack: ContentPack?

    private var stampPacks: [ContentPack] { catalog.packs(in: .stamp) }
    private var postmarkPacks: [ContentPack] { catalog.packs(in: .postmark) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("邮票、邮戳与更多装扮，把每一张明信片寄得更好看")
                    .font(.system(size: 12)).foregroundStyle(Color.muted)

                shelf("邮票包", packs: stampPacks)
                if !postmarkPacks.isEmpty { shelf("邮戳包", packs: postmarkPacks) }

                comingSoon
            }
            .padding(20)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("商店")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(item: $selectedPack) { PackDetailSheet(pack: $0) }
        .task {
            await catalog.refreshRemote()                      // D2：增值包远程合并
            await packStore.refreshOwned()
            await packStore.loadProducts(for: catalog.packs)
        }
    }

    private func shelf(_ title: LocalizedStringKey, packs: [ContentPack]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
            VStack(spacing: 10) {
                ForEach(packs) { pack in
                    Button { selectedPack = pack } label: { packCard(pack) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func packCard(_ pack: ContentPack) -> some View {
        HStack(spacing: 12) {
            // 预览：取前 3 枚条目缩略
            HStack(spacing: -8) {
                ForEach(pack.items.prefix(3)) { item in
                    PackItemStampView(packID: pack.id, itemID: item.id, mini: true)
                        .frame(width: 26, height: 31)
                        .background(Color.bg, in: RoundedRectangle(cornerRadius: 3))
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
            .frame(width: 66, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: pack.localizedName)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
                Text("共 \(pack.items.count) 枚")
                    .font(.system(size: 11)).foregroundStyle(Color.muted)
            }
            Spacer()
            priceTag(pack)
        }
        .padding(13)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
    }

    @ViewBuilder
    private func priceTag(_ pack: ContentPack) -> some View {
        if packStore.owns(pack) {
            Label("已拥有", systemImage: "checkmark")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.nCyan)
        } else {
            switch pack.pricing {
            case .free:
                Text("免费").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.muted)
            case .plus:
                Text(verbatim: "PLUS").font(.system(size: 9, weight: .heavy)).tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.vertical, 3).padding(.horizontal, 8)
                    .background(LinearGradient.neonH, in: Capsule())
            case .paid:
                let pid = pack.productID ?? "com.lumi.pack.\(pack.id)"
                Text(verbatim: packStore.products[pid]?.displayPrice ?? "…")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.nOrange)
            }
        }
    }

    private var comingSoon: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("即将上架").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
            HStack(spacing: 10) {
                Image(systemName: "photo.artframe").font(.system(size: 16)).foregroundStyle(Color.nPurple)
                Text("明信片正面素材：城市插画 · 画框 · 复古滤镜")
                    .font(.system(size: 12)).foregroundStyle(Color.muted)
                Spacer()
                Text(verbatim: "✦").foregroundStyle(Color.nPink)
            }
            .padding(13)
            .background(Color.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        }
    }
}

/// 包详情：条目网格 + 可用性说明 + 获取按钮（免费领 / 随 Plus / 购买）。
/// 商店货架与邮票选择器的带锁票都跳到这里。
struct PackDetailSheet: View {
    let pack: ContentPack
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var packStore = PackStore.shared
    @ObservedObject private var plus = PlusStore.shared
    @State private var showPaywall = false

    private let cols = [GridItem(.adaptive(minimum: 76), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(pack.items) { item in
                            if let f = outOfWindowFestival(item) {
                                seasonalPlaceholder(f)
                            } else {
                                VStack(spacing: 6) {
                                    PackItemStampView(packID: pack.id, itemID: item.id)
                                        .frame(width: 54, height: 64)
                                    Text(verbatim: item.localizedName)
                                        .font(.system(size: 10)).foregroundStyle(Color.muted)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)

                    if pack.items.contains(where: { $0.countryCode != nil }) || pack.countryCodes != nil {
                        Label("地区票仅限对应国家足迹的明信片使用", systemImage: "mappin.and.ellipse")
                            .font(.system(size: 11)).foregroundStyle(Color.muted)
                    }

                    ctaButton

                    if let err = packStore.lastError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12)).foregroundStyle(Color.nOrange)
                    }
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle(Text(verbatim: pack.localizedName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    /// 节日/季节性条目（legacyRaw `fest:`）在流通窗口外 → 返回该节日以显示「虚位以待」占位。
    /// 地域性票（cc:/prem:/pack 手绘）恒常展示，不受影响。
    private func outOfWindowFestival(_ item: PackItem) -> Festival? {
        guard let raw = item.legacyRaw, raw.hasPrefix("fest:"),
              let f = Festival(rawValue: String(raw.dropFirst(5))),
              !f.isInWindowNow else { return nil }
        return f
    }

    /// 「虚位以待」占位：虚线框 + 日期窗——季节/节日一到自动换回真票。
    private func seasonalPlaceholder(_ f: Festival) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.line, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                Text(verbatim: "✦").font(.system(size: 18)).foregroundStyle(Color.faint)
            }
            .frame(width: 54, height: 64)
            Text("虚位以待").font(.system(size: 10)).foregroundStyle(Color.faint).lineLimit(1)
            Text(verbatim: f.windowText).font(.system(size: 8.5)).foregroundStyle(Color.faint)
        }
    }

    @ViewBuilder
    private var ctaButton: some View {
        if packStore.owns(pack) {
            Label("已拥有 · 寄明信片时可选用", systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.nCyan)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.panel, in: Capsule())
                .overlay(Capsule().stroke(Color.nCyan.opacity(0.4), lineWidth: 1))
        } else {
            switch pack.pricing {
            case .free:
                EmptyView()
            case .plus:
                Button { showPaywall = true } label: {
                    Label("升级终身会员，免费领取", systemImage: "sparkles")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(LinearGradient.neonH, in: Capsule())
                }
            case .paid:
                let pid = pack.productID ?? "com.lumi.pack.\(pack.id)"
                Button { Task { _ = await packStore.purchase(pack) } } label: {
                    Group {
                        if packStore.purchasing { ProgressView().tint(.white) }
                        else if let p = packStore.products[pid] {
                            Text("购买 \(p.displayPrice)")
                        } else {
                            Text("即将上架")
                        }
                    }
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(LinearGradient.neonH, in: Capsule())
                }
                .disabled(packStore.purchasing || packStore.products[pid] == nil)
                if plus.isPlus {
                    Text("会员专享折扣价").font(.system(size: 11)).foregroundStyle(Color.muted)
                }
            }
        }
    }
}
