import SwiftUI

struct ModeChip: View {
    let title: String
    let system: String
    let color: Color
    let mode: TransportMode
    @Binding var selected: TransportMode

    // Ortak stil sabitleri
    private let chipSize = CGSize(width: 90, height: 64)
    private let cornerRadius: CGFloat = 12
    private let borderWidth: CGFloat = 1

    var isSelected: Bool { selected == mode }

    var body: some View {
        Button {
            selected = mode
        } label: {
            VStack(spacing: 6) {
                Image(systemName: system)
                    .font(.title2.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: chipSize.width, height: chipSize.height)
            // Arka plan: sadece renk farklı (seçili: daha dolu, değilse daha hafif)
            .background(isSelected ? color.opacity(0.9) : color.opacity(0.18))
            // Kenarlık: aynı kalınlık ve aynı renk tonu
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color.opacity(isSelected ? 0.9 : 0.6), lineWidth: borderWidth)
            )
            // Yazı/ikon rengi: seçiliyse beyaz, değilse chip rengi
            .foregroundColor(isSelected ? .white : color)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}
