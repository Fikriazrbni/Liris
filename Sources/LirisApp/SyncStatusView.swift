import SwiftUI
import LirisCore

struct SyncStatusView: View {
    @EnvironmentObject private var model: AppModel
    private var color: Color { model.syncNeedsAttention ? .orange.opacity(0.9) : model.accent }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: model.playerTimeHealth == .waiting ? "pause.circle" : model.syncNeedsAttention ? "exclamationmark.circle" : "checkmark.shield")
                .font(.system(size: 14)).foregroundStyle(color).padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.syncHeadline).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                Text(model.syncExplanation).font(.system(size: 10)).foregroundStyle(Palette.muted)
                    .lineSpacing(3).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                if abs(model.offset) > 0.05 {
                    Text(String(format: "Koreksi tersimpan: %+.1f detik", model.offset)).font(.system(size: 9)).foregroundStyle(Palette.muted)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 10) {
                if let alternatives = model.lyricsResolution?.alternatives, alternatives.count > 1 {
                    Menu("Versi lain") {
                        ForEach(Array(alternatives.enumerated()), id: \.element.id) { index, record in
                            Button {
                                model.select(record)
                            } label: {
                                Text("\(record.id == model.record?.id ? "✓ " : "")Versi \(index + 1) · \(record.albumName?.isEmpty == false ? record.albumName! : record.trackName) · \(TimeLabel.format(record.duration)) · awal lirik \(TimeLabel.format(record.lines.first(where: { !$0.text.isEmpty })?.time ?? 0))")
                            }
                        }
                        if model.lyricsResolution?.savedChoice == true {
                            Divider()
                            Button("Gunakan pilihan otomatis") { model.useAutomaticLyrics() }
                        }
                    }.font(.system(size: 10)).menuStyle(.borderlessButton).fixedSize()
                }
                if model.connected {
                    Button { model.loadLyrics(forceRefresh: true) } label: {
                        Label("Periksa ulang", systemImage: "arrow.clockwise").font(.system(size: 9))
                    }.buttonStyle(.plain).foregroundStyle(Palette.muted).disabled(model.loading)
                        .help("Ambil ulang dan bandingkan versi lirik. Memerlukan internet.")
                }
            }
        }.padding(12).background(color.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.13)))
    }
}
