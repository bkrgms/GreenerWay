import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var message: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)
                
                // Başlık
                VStack(spacing: 8) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 40))
                        .foregroundColor(.primary)
                    Text("Şifre Sıfırla")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("E-posta adresinize sıfırlama linki göndereceğiz")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 20)

                // Email Input
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    TextField("E-posta", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

                if let message = message {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }

                // Gönder Butonu
                Button {
                    Task {
                        do {
                            try await authVM.resetPassword(email: email)
                            message = "📧 Şifre sıfırlama linki \(email) adresine gönderildi."
                        } catch {
                            message = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Sıfırlama Maili Gönder")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primary)
                        .foregroundColor(Color(.systemBackground))
                        .cornerRadius(12)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Şifre Sıfırlama")
        .navigationBarTitleDisplayMode(.inline)
    }
}
