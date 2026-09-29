import SwiftUI
import SwiftData
import CoreLocation

/// 手动录入一段航线：选交通方式 + 起终点机场 + 日期 + 备注 → 存为 Leg。
/// 起终点从内嵌机场库（AirportDB）搜索选取，纯本地。
struct ManualLegEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("map.showRoutes") private var showRoutes = false

    @State private var mode: TransportMode = .flight
    @State private var from: AirportDB.Airport?
    @State private var to: AirportDB.Airport?
    @State private var date = Date()
    @State private var note = ""
    @State private var picking: Endpoint?

    enum Endpoint: Identifiable { case from, to; var id: Int { hashValue } }

    private var canSave: Bool {
        guard let a = from, let b = to else { return false }
        return a.iata != b.iata
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    modeRow
                    endpointRow(title: "起点", airport: from) { picking = .from }
                    endpointRow(title: "终点", airport: to) { picking = .to }
                    dateRow
                    noteRow
                    saveButton
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("手动录入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $picking) { ep in
                AirportSearchSheet { picked in
                    if ep == .from { from = picked } else { to = picked }
                    picking = nil
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: 交通方式

    private var modeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("交通方式").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.muted)
            HStack(spacing: 10) {
                modeButton(.flight, icon: "airplane", label: "航班")
                modeButton(.train, icon: "tram.fill", label: "火车")
                modeButton(.sea, icon: "ferry.fill", label: "轮船")
                modeButton(.car, icon: "car.fill", label: "自驾")
            }
        }
    }

    private func modeButton(_ m: TransportMode, icon: String, label: LocalizedStringKey) -> some View {
        let active = mode == m
        return Button {
            mode = m; Haptics.selection()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(active ? .white : Color.muted)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(active ? AnyShapeStyle(LinearGradient.neonH) : AnyShapeStyle(Color.panel),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? Color.clear : Color.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: 起终点

    private func endpointRow(title: LocalizedStringKey, airport: AirportDB.Airport?,
                             tap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.muted)
            Button(action: tap) {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.circle").font(.system(size: 18)).foregroundStyle(Color.nCyan)
                    if let a = airport {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: a.iata).font(.system(size: 15, weight: .bold)).foregroundStyle(Color.text)
                            Text(verbatim: a.name).font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(1)
                        }
                    } else {
                        Text("选择机场").font(.system(size: 14)).foregroundStyle(Color.faint)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.faint)
                }
                .padding(14).panelCard(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 日期 / 备注

    private var dateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日期").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.muted)
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden().datePickerStyle(.compact).tint(Color.nPink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noteRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.muted)
            TextField("航班号 / 一句心情", text: $note)
                .font(.system(size: 14)).foregroundStyle(Color.text)
                .padding(12).panelCard(12)
        }
    }

    // MARK: 保存

    private var saveButton: some View {
        Button(action: save) {
            Text("保存航线").font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(canSave ? AnyShapeStyle(LinearGradient.neonH) : AnyShapeStyle(Color.panel), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.top, 4)
    }

    private func save() {
        guard let a = from, let b = to else { return }
        let leg = Leg(mode: mode,
                      fromName: a.name, from: a.coordinate,
                      toName: b.name, to: b.coordinate,
                      departAt: date, note: note)
        context.insert(leg)
        try? context.save()
        showRoutes = true
        Haptics.success()
        dismiss()
    }
}

/// 机场搜索选择：输三字码或城市/机场名，从内嵌库里选。
private struct AirportSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (AirportDB.Airport) -> Void
    @State private var query = ""

    private var results: [AirportDB.Airport] {
        let q = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard q.count >= 2 else { return [] }
        return AirportDB.all.values
            .filter { $0.iata.hasPrefix(q) || $0.name.uppercased().contains(q) }
            .sorted { $0.iata < $1.iata }
            .prefix(40)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("搜索机场 / 城市", text: $query)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 15)).foregroundStyle(Color.text)
                    .padding(12).panelCard(12)
                    .padding(.horizontal, 16).padding(.top, 12)

                List(results, id: \.iata) { a in
                    Button { onPick(a); dismiss() } label: {
                        HStack(spacing: 12) {
                            Text(verbatim: a.iata).font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.nCyan).frame(width: 44, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: a.name).font(.system(size: 14)).foregroundStyle(Color.text).lineLimit(1)
                                Text(verbatim: a.country).font(.system(size: 11)).foregroundStyle(Color.muted)
                            }
                        }
                    }
                    .listRowBackground(Color.panel.opacity(0.4))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("选择机场")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
