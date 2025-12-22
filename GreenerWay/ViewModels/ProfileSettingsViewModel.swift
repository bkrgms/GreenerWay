import Foundation
import FirebaseAuth

@MainActor
final class ProfileSettingsViewModel: ObservableObject {
    @Published var age: Int = 25
    @Published var carbonSensitivity: Double = 0.5
    @Published var healthStatus: String = "Normal"
    @Published var travellingWithChild: Bool = false
    @Published var selectedVehicleType: VehicleType = .unknown

    // --- YENİ EKLENDİ: Kazanılan Rozetler ---
    @Published var earnedBadges: [String] = []
    // --- YENİ EKLENDİ SONU ---

    // Firestore'dan ve UserDefaults'tan profil oku
    func loadUserProfile() async {
        // Önce UserDefaults'ten araç tipini oku (hata olsa bile bu çalışsın)
        self.selectedVehicleType = VehicleManager.shared.getSelectedVehicleType()
        print("🚗 Profil VM: Araç tipi yüklendi -> \(self.selectedVehicleType.rawValue)")

        // Sonra Firestore'dan diğer profil bilgilerini ve rozetleri çek
        do {
            if let profile = try await FirestoreManager.shared.fetchUserProfile() { //
                self.age = profile.age
                self.carbonSensitivity = profile.carbonSensitivity
                self.healthStatus = profile.healthStatus
                self.travellingWithChild = profile.travellingWithChild

                // --- YENİ EKLENDİ: Rozetleri Yükle ---
                // Firestore'dan gelen earnedBadgeIDs dizisini ViewModel'daki earnedBadges'e ata.
                // Eğer Firestore'da bu alan yoksa (nil ise), boş dizi ([]) ata.
                self.earnedBadges = profile.earnedBadgeIDs ?? [] //
                print("🏅 Profil VM: Kazanılan rozetler yüklendi -> \(self.earnedBadges)")
                // --- YENİ EKLENDİ SONU ---

            } else {
                 print("👤 Profil VM: Firestore'da profil bulunamadı.")
                 // Firestore'dan profil gelmese bile rozetleri boşaltalım
                 self.earnedBadges = []
            }
        } catch {
            print("❌ Profil yüklenemedi: \(error)")
            // Hata durumunda da rozetleri boşaltalım
            self.earnedBadges = []
        }
    }

    // Firestore'a ve UserDefaults'a profil yaz
    func saveUserProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // --- ÖNEMLİ GÜNCELLEME: Önce mevcut rozetleri oku ---
        // Firestore'a sadece değişenleri değil, tüm profili yazacağımız için,
        // kaydetmeden önce mevcut rozet listesini (eğer varsa) profile eklemeliyiz.
        // Yoksa sadece age, sensitivity vs. kaydedilirken rozetler silinebilir.
        var currentBadges: [String]? = self.earnedBadges // Önce ViewModel'dakini alalım
        do {
            // Kaydetmeden hemen önce profili tekrar çekip rozetleri alalım (daha garanti)
             if let existingProfile = try await FirestoreManager.shared.fetchUserProfile() { //
                 currentBadges = existingProfile.earnedBadgeIDs //
             }
        } catch {
             print("⚠️ Kaydetmeden önce mevcut rozetler okunamadı: \(error)")
             // Hata olursa, ViewModel'daki mevcut rozetleri kullanmaya devam et
        }
        // --- GÜNCELLEME SONU ---

        // Kaydedilecek UserProfile nesnesini oluştururken mevcut rozetleri de ekle
        let profileToSave = UserProfile( //
            age: age,
            carbonSensitivity: carbonSensitivity,
            healthStatus: healthStatus,
            travellingWithChild: travellingWithChild,
            // notifications ve carbonUnit gibi diğer alanlar varsa onları da ekle
            earnedBadgeIDs: currentBadges // <- Mevcut (veya yeni kazanılan) rozetleri ekle
        )

        do {
            // Önce araç tipini kalıcı olarak sakla
            VehicleManager.shared.saveVehicleType(selectedVehicleType)

            // Firestore profilini güncelle
            try await FirestoreManager.shared.saveUserProfile(uid: uid, profile: profileToSave) //
            print("✅ Profil güncellendi (Firestore & UserDefaults)")

            // Kaydetme başarılı olduktan sonra ViewModel'daki rozet listesini de güncelleyelim
            self.earnedBadges = currentBadges ?? []

        } catch {
            print("❌ Profil kaydedilemedi: \(error)")
        }
    }
}
