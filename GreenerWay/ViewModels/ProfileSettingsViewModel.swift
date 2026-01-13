import Foundation
import FirebaseAuth

@MainActor
final class ProfileSettingsViewModel: ObservableObject {
    @Published var age: Int = 25
    @Published var earnedBadges: [String] = []

    // Firestore'dan profil oku
    func loadUserProfile() async {
        do {
            if let profile = try await FirestoreManager.shared.fetchUserProfile() {
                self.age = profile.age
                self.earnedBadges = profile.earnedBadgeIDs ?? []
                print("🏅 Profil VM: Yaş: \(self.age), Rozetler: \(self.earnedBadges)")
            } else {
                print("👤 Profil VM: Firestore'da profil bulunamadı.")
                self.earnedBadges = []
            }
        } catch {
            print("❌ Profil yüklenemedi: \(error)")
            self.earnedBadges = []
        }
    }

    // Firestore'a profil kaydet
    func saveUserProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Mevcut rozetleri koru
        var currentBadges: [String]? = self.earnedBadges
        do {
            if let existingProfile = try await FirestoreManager.shared.fetchUserProfile() {
                currentBadges = existingProfile.earnedBadgeIDs
            }
        } catch {
            print("⚠️ Kaydetmeden önce mevcut rozetler okunamadı: \(error)")
        }

        let profileToSave = UserProfile(
            age: age,
            carbonSensitivity: 0.5, // Varsayılan
            healthStatus: "Normal", // Varsayılan
            travellingWithChild: false, // Varsayılan
            earnedBadgeIDs: currentBadges
        )

        do {
            try await FirestoreManager.shared.saveUserProfile(uid: uid, profile: profileToSave)
            print("✅ Profil güncellendi")
            self.earnedBadges = currentBadges ?? []
        } catch {
            print("❌ Profil kaydedilemedi: \(error)")
        }
    }
}
