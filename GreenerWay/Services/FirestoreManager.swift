import Foundation
import FirebaseAuth
import FirebaseFirestore

final class FirestoreManager {
    static let shared = FirestoreManager()
    let db = Firestore.firestore()

    private init() {}

    // MARK: - User Profile

    // Not: Projede bu fonksiyon async/await ile çağrılıyor; imzayı async throws olarak tutuyoruz.
    func saveUserProfile(uid: String, profile: UserProfile) async throws {
        try db.collection("users").document(uid).setData(from: profile)
    }

    func fetchUserProfile() async throws -> UserProfile? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let doc = try await db.collection("users").document(uid).getDocument()
        return try doc.data(as: UserProfile.self)
    }

    // MARK: - Journeys

    func saveJourney(_ journey: Journey) async throws {
        try db.collection("journeys").addDocument(from: journey)
    }

    func fetchJourneys(for userId: String) async throws -> [Journey] {
        let snapshot = try await db.collection("journeys")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Journey.self)
        }
    }

    func clearJourneys(for userId: String) async throws {
        let snapshot = try await db.collection("journeys")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    // MARK: - Badges

    // "İlk Yeşil Yolculuk" rozetini kontrol edip ver
    // Koşullar:
    // - Mevcut profil yoksa veya zaten rozet alınmışsa: çık
    // - currentJourney.mode "walking" veya "transit" değilse: çık
    // - Aksi halde earnedBadgeIDs içine "firstGreenJourney" ekleyip profili kaydet
    func checkAndAwardFirstGreenJourneyBadge(userId: String, currentJourney: Journey) async throws {
        // a) Profil getir
        guard var profile = try await fetchUserProfile() else { return }

        // b) Zaten alınmış mı?
        if let badges = profile.earnedBadgeIDs, badges.contains("firstGreenJourney") {
            return
        }

        // c) Yolculuk modu yeşil mi?
        let greenModes: Set<String> = ["walking", "transit"]
        guard greenModes.contains(currentJourney.mode) else { return }

        // d) Tebrik mesajı
        print("🏅 Tebrikler! 'firstGreenJourney' rozeti kazanıldı!")

        // e) earnedBadgeIDs dizisini hazırla
        var updated = profile.earnedBadgeIDs ?? []
        // f) ekle (tekrarı önlemek için kontrol edilse de yukarıda yaptık)
        updated.append("firstGreenJourney")
        profile.earnedBadgeIDs = updated

        // g) Profili geri kaydet
        try await saveUserProfile(uid: userId, profile: profile)
    }

    // Yeni: "İlk 10 kg CO₂ Tasarrufu" rozetini kontrol edip ver
    // Mantık:
    // - Kullanıcının tüm yolculuklarını getir
    // - walking/transit olanlarda potansiyel araba emisyonu (distanceKm * 0.192) ile gerçek emisyon farkını topla
    // - Toplam tasarruf ≥ 10.0 ise "tenKgSavings" rozetini ekle ve kaydet
    func checkAndAwardTenKgSavingsBadge(userId: String) async throws {
        // a) Profil getir
        guard var profile = try await fetchUserProfile() else { return }

        // b) Zaten alınmış mı?
        if let badges = profile.earnedBadgeIDs, badges.contains("tenKgSavings") {
            return
        }

        // c) Kullanıcının tüm yolculuklarını al
        let journeys = try await fetchJourneys(for: userId)

        // d) Toplam tasarrufu hesapla
        var totalSavings: Double = 0.0
        let greenModes: Set<String> = ["walking", "transit"]
        let carFactor: Double = 0.192 // kg/km

        for j in journeys {
            guard greenModes.contains(j.mode) else { continue }
            let potentialCarEmission = j.distanceKm * carFactor
            let saving = potentialCarEmission - j.emissionKg
            if saving > 0 {
                totalSavings += saving
            }
        }

        // f) Eşik kontrolü
        if totalSavings >= 10.0 {
            // g) Rozeti ekle ve kaydet
            print("🏅 Tebrikler! 'tenKgSavings' rozeti kazanıldı! (Toplam Tasarruf: \(String(format: "%.2f", totalSavings)) kg)")

            var updated = profile.earnedBadgeIDs ?? []
            // Tekrarlı eklemeyi engelle
            if !updated.contains("tenKgSavings") {
                updated.append("tenKgSavings")
            }
            profile.earnedBadgeIDs = updated

            try await saveUserProfile(uid: userId, profile: profile)
        }
    }
}
