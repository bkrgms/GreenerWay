import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var message: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Şifre Sıfırla")
                .font(.largeTitle).bold()
                .foregroundColor(.green)

            TextField("E-posta", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            if let message = message {
                Text(message)
                    .foregroundColor(.blue)
                    .font(.footnote)
            }

            Button("Şifre Sıfırlama Maili Gönder") {
                Task {
                    do {
                        try await authVM.resetPassword(email: email)
                        message = "📧 Şifre sıfırlama linki \(email) adresine gönderildi."
                    } catch {
                        message = error.localizedDescription
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .contentShape(Rectangle())
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
    }
}
