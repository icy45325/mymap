import SwiftUI
import SwiftData
import PhotosUI

/// 写 / 编辑一条日记：日期 + 正文 + 心情 emoji + 本机照片（不随口令寄出）。
struct DiaryEntryEditor: View {

    let diary: ExchangeDiary
    /// nil = 新写一条。
    var entry: DiaryEntry?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var date: Date = .now
    @State private var text: String = ""
    @State private var mood: String?
    @State private var photoIDs: [String] = []
    @State private var pickerItems: [PhotosPickerItem] = []

    private static let moods = ["😊", "🤩", "😌", "🥹", "😮‍💨", "🥶", "🥵", "😴"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DatePicker("哪一天", selection: $date, displayedComponents: .date)
                        .font(.system(size: 13)).foregroundStyle(Color.muted)
                        .tint(Color.nPink)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("写点什么").font(.system(size: 12)).foregroundStyle(Color.muted)
                        TextEditor(text: $text)
                            .font(.system(size: 15)).foregroundStyle(Color.text)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .padding(10)
                            .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("此刻心情").font(.system(size: 12)).foregroundStyle(Color.muted)
                        HStack(spacing: 8) {
                            ForEach(Self.moods, id: \.self) { m in
                                Button { mood = (mood == m ? nil : m) } label: {
                                    Text(m).font(.system(size: 22))
                                        .frame(width: 38, height: 38)
                                        .background(Color.panel, in: Circle())
                                        .overlay(Circle().stroke(mood == m ? Color.nPink : Color.line, lineWidth: mood == m ? 1.5 : 1))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("照片").font(.system(size: 12)).foregroundStyle(Color.muted)
                            Spacer()
                            PhotosPicker(selection: $pickerItems, maxSelectionCount: 6,
                                         matching: .images, photoLibrary: .shared()) {
                                Label("选照片", systemImage: "photo.on.rectangle")
                                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.nCyan)
                            }
                        }
                        if photoIDs.isEmpty {
                            Text("照片只保存在本机，不随口令寄出")
                                .font(.system(size: 11)).foregroundStyle(Color.faint)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(photoIDs, id: \.self) { id in
                                        AssetImage(assetID: id, targetSize: CGSize(width: 240, height: 240))
                                            .frame(width: 74, height: 74)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(alignment: .topTrailing) {
                                                Button { photoIDs.removeAll { $0 == id } } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 15))
                                                        .foregroundStyle(.white, .black.opacity(0.55))
                                                }
                                                .offset(x: 5, y: -5)
                                            }
                                    }
                                }
                                .padding(.top, 5)
                            }
                            Text("照片只保存在本机，不随口令寄出")
                                .font(.system(size: 11)).foregroundStyle(Color.faint)
                        }
                    }
                }
                .padding(22)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle(entry == nil ? Text("写一条") : Text("改一改"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { load() }
            .onChange(of: pickerItems) { _, items in
                for id in items.compactMap(\.itemIdentifier) where !photoIDs.contains(id) {
                    photoIDs.append(id)
                }
                pickerItems = []
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    private func load() {
        guard let entry else { return }
        date = entry.date
        text = entry.text
        mood = entry.mood
        photoIDs = entry.photoAssetIDs
    }

    private func save() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let entry {
            entry.date = date
            entry.text = body
            entry.mood = mood
            entry.photoAssetIDs = photoIDs
            entry.updatedAt = .now
        } else {
            let e = DiaryEntry(date: date, text: body, mood: mood)
            e.photoAssetIDs = photoIDs
            e.diary = diary
            context.insert(e)
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
