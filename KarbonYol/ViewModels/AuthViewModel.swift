import Foundation
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoggedIn: Bool = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        self.user = Auth.auth().currentUser
        self.isLoggedIn = self.user != nil

        // Oturum değişimini dinle
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isLoggedIn = (user != nil)
            }
        }
    }

    deinit {
        if let h = authStateHandle {
            Auth.auth().removeStateDidChangeListener(h)
        }
    }

    // Kayıt
    func signUp(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.user = result.user
        self.isLoggedIn = true
        return result.user
    }

    // Giriş
    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.user = result.user
        self.isLoggedIn = true
        return result.user
    }

    // Çıkış
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.isLoggedIn = false
            print("✅ Çıkış yapıldı")
        } catch {
            print("❌ Çıkış yapılamadı: \(error)")
        }
    }

    // Şifre sıfırlama
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
}
