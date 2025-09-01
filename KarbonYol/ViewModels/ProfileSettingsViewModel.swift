import Foundation
import FirebaseAuth

@MainActor
final class ProfileSettingsViewModel: ObservableObject {
    @Published var age: Int = 25
    @Published var carbonSensitivity: Double = 0.5
    @Published var healthStatus: String = "Normal"
    @Published var travellingWithChild: Bool = false

    // Firestore'dan profil oku
    func loadUserProfile() async {
        do {
            if let profile = try await FirestoreManager.shared.fetchUserProfile() {
                self.age = profile.age
                self.carbonSensitivity = profile.carbonSensitivity
                self.healthStatus = profile.healthStatus
                self.travellingWithChild = profile.travellingWithChild
            }
        } catch {
            print("❌ Profil yüklenemedi: \(error)")
        }
    }

    // Firestore'a profil yaz
    func saveUserProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let profile = UserProfile(
            age: age,
            carbonSensitivity: carbonSensitivity,
            healthStatus: healthStatus,
            travellingWithChild: travellingWithChild
        )

        do {
            // ⬇️ Hatanın kaynağı burasıydı: fonksiyon uid de bekliyor.
            try await FirestoreManager.shared.saveUserProfile(uid: uid, profile: profile)
            print("✅ Profil güncellendi")
        } catch {
            print("❌ Profil kaydedilemedi: \(error)")
        }
    }
}
