import SwiftUI
import SwiftData
import UIKit

/// 「从相册同步历史足迹」评审页：扫描相册位置 → 列出候选地点 → 勾选导入。
struct PhotoImportView: View {

    /// 已有足迹（用于跳过重复网格）。
    let existing: [Footprint]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = PhotoImportService()

    private static let dateFormat: Date.FormatStyle = .dateTime.year().month(.abbreviated).day()

    var body: some View {
        NavigationStack {
            Group {
                switch service.phase {
                case .idle, .requesting, .scanning: scanning
                case .denied:                       denied
                case .empty:                        empty
                case .ready:                        list
                }
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("同步历史足迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.foregroundStyle(Color.muted)
                }
                if service.phase == .ready {
                    ToolbarItem(placement: .primaryAction) {
                        Button(allSelected ? "全不选" : "全选") {
                            service.toggleAll(!allSelected)
                        }
                        .foregroundStyle(Color.nPink)
                    }
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
        .task { await service.start(existing: existing) }
    }

    private var allSelected: Bool {
        let selectable = service.candidates.filter { !$0.alreadyImported }
        return !selectable.isEmpty && selectable.allSatisfy(\.selected)
    }

    // MARK: - 扫描中

    private var scanning: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Color.nPink).scaleEffect(1.3)
            Text(service.phase == .requesting ? "请求相册权限…" : "正在从相册识别去过的地方…")
                .font(.subheadline).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 无权限

    private var denied: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.system(size: 40)).foregroundStyle(Color.nPurple)
            Text("无法访问相册").font(.headline).foregroundStyle(Color.text)
            Text("到「设置 › 隐私 › 照片」允许 Lumi 读取相册后再试。")
                .font(.subheadline).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.nPink).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 没有可导入的

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40))
                .foregroundStyle(Color.nPurple)
            Text("没找到带位置的新照片").font(.headline).foregroundStyle(Color.text)
            Text("相册里带定位信息的照片都已点亮，或暂时没有可识别的地点。")
                .font(.subheadline).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 候选列表

    private var granularityBinding: Binding<ImportGranularity> {
        Binding(get: { service.granularity }, set: { service.setGranularity($0) })
    }

    private var list: some View {
        VStack(spacing: 0) {
            SegmentBar(items: ImportGranularity.allCases.map { (value: $0, label: $0.label) },
                       selection: granularityBinding)
                .padding(.top, 10).padding(.bottom, 2)

            HStack {
                Text("识别到 \(service.candidates.count) 处地点")
                    .font(.system(size: 12)).foregroundStyle(Color.muted)
                if service.resolving {
                    ProgressView().tint(Color.muted).scaleEffect(0.7).padding(.leading, 4)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach($service.candidates) { $candidate in
                        row($candidate)
                    }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 16).padding(.top, 4)
            }
        }
        .safeAreaInset(edge: .bottom) { importBar }
    }

    private func row(_ candidate: Binding<ImportCandidate>) -> some View {
        let c = candidate.wrappedValue
        return Button {
            candidate.wrappedValue.selected.toggle()
        } label: {
            HStack(spacing: 12) {
                Text(c.flag).font(.system(size: 24))
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.placeName).font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.text).lineLimit(1)
                    HStack(spacing: 8) {
                        Text(c.date.formatted(Self.dateFormat))
                            .font(.system(size: 11)).foregroundStyle(Color.muted)
                        if let country = c.countryName, country != c.placeName {
                            Text(country).font(.system(size: 11)).foregroundStyle(Color.faint)
                        }
                        Label("\(c.photoCount)", systemImage: "photo")
                            .font(.system(size: 11)).foregroundStyle(Color.faint)
                    }
                }
                Spacer()
                Image(systemName: c.selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(c.selected ? Color.nPink : Color.line)
            }
            .padding(12)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(c.selected ? Color.nPink.opacity(0.4) : Color.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var importBar: some View {
        Button(action: runImport) {
            Text(service.selectedCount > 0 ? "导入 \(service.selectedCount) 个足迹 ✦" : "选择要导入的地点")
                .font(.headline)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(LinearGradient.neonH, in: Capsule())
                .foregroundStyle(.white)
                .opacity(service.selectedCount > 0 ? 1 : 0.4)
                .shadow(color: Color.nPurple.opacity(0.5), radius: 12)
        }
        .disabled(service.selectedCount == 0)
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    private func runImport() {
        let count = service.importSelected(into: context)
        guard count > 0 else { return }
        WidgetSync.refresh(context)
        Analytics.log(.photoImportCompleted(imported: count))
        dismiss()
    }
}
