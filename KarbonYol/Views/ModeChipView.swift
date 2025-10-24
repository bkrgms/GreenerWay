import SwiftUI

struct ModeChip: View {
    let title: String
    let system: String
    let color: Color
    let mode: TransportMode
    @Binding var selected: TransportMode

    var body: some View {
        Button {
            selected = mode
        } label: {
            VStack(spacing: 6) {
                Image(systemName: system).font(.title2)
                Text(title).font(.caption)
            }
            .frame(width: 90, height: 64)
            .background(selected == mode ? color.opacity(0.9) : Color.gray.opacity(0.25))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}
