import SwiftUI

struct TopBarView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var showBack: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            // Sol: Geri
            if showBack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .resizable()
                        .frame(width: 18, height: 28)
                        .foregroundColor(.primary)
                        .padding(.vertical, 6)
                }
            }

            Spacer()

            // Sağ: Profil
            NavigationLink(destination: ProfileSettings()) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.blue)
            }

            // Sağ: Çıkış
            Button {
                authViewModel.signOut()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.95))
    }
}
