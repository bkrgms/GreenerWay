import SwiftUI

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: icon)
                .labelStyle(.titleAndIcon)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
