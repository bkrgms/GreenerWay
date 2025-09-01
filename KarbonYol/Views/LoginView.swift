import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Text("KarbonYol")
                    .font(.largeTitle).bold()
                    .foregroundColor(.green)

                VStack(spacing: 16) {
                    TextField("E-posta", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    SecureField("Şifre", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button(action: {
                    Task {
                        do {
                            _ = try await authVM.signIn(email: email, password: password)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    Text("Giriş Yap")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                NavigationLink("Şifremi Unuttum", destination: ResetPasswordView())
                    .foregroundColor(.blue)

                NavigationLink("Hesabın yok mu? Kayıt Ol", destination: RegisterView())
                    .foregroundColor(.blue)

                Spacer()
            }
            .padding()
        }
    }
}
