
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if authVM.isLoggedIn {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.primary.opacity(0.3))
                    Text("Zaten giriş yapıldı")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Farklı bir hesapla giriş yapmak için çıkış yapın.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button {
                        Task { try? await authVM.signOut() }
                    } label: {
                        Text("Çıkış Yap")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                NavigationView {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 32) {
                            Spacer().frame(height: 60)
                            
                            // Logo
                            VStack(spacing: 8) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.primary)
                                Text("GreenerWay")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                            }
                            
                            // Form
                            VStack(spacing: 16) {
                                // Email
                                HStack(spacing: 12) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 24)
                                    TextField("E-posta", text: $email)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)

                                // Şifre
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 24)
                                    SecureField("Şifre", text: $password)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)

                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                    .padding(.horizontal)
                            }

                            // Giriş Butonu
                            Button {
                                Task {
                                    do {
                                        _ = try await authVM.signIn(email: email, password: password)
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            } label: {
                                Text("Giriş Yap")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.primary)
                                    .foregroundColor(Color(.systemBackground))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)

                            // Linkler
                            VStack(spacing: 12) {
                                NavigationLink(destination: ResetPasswordView()) {
                                    Text("Şifremi Unuttum")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                NavigationLink(destination: RegisterView()) {
                                    Text("Hesabın yok mu? **Kayıt Ol**")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .navigationBarHidden(true)
                }
            }
        }
        .onAppear { errorMessage = nil }
    }
}

