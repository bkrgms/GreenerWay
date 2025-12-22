import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class BadgeViewModel: ObservableObject {
    @Published var userStats: UserStats = UserStats()
    @Published var allBadges: [Badge] = BadgeDefinitions.allBadges
    @Published var unlockedBadges: [Badge] = []
    @Published var recentlyUnlocked: Badge? = nil
    @Published var isLoading = false
    @Published var showBadgeUnlockedAlert = false
    
    private let db = Firestore.firestore()
    
    // MARK: - Computed Properties
    var totalPoints: Int { userStats.totalPoints }
    
    var currentLevel: Int {
        let points = userStats.totalPoints
        if points >= 5000 { return 10 }
        if points >= 4000 { return 9 }
        if points >= 3000 { return 8 }
        if points >= 2500 { return 7 }
        if points >= 2000 { return 6 }
        if points >= 1500 { return 5 }
        if points >= 1000 { return 4 }
        if points >= 500 { return 3 }
        if points >= 200 { return 2 }
        return 1
    }
    
    var levelTitle: String {
        switch currentLevel {
        case 1: return "Başlangıç"
        case 2: return "Çaylak"
        case 3: return "Gezgin"
        case 4: return "Kaşif"
        case 5: return "Yolcu"
        case 6: return "Uzman"
        case 7: return "Usta"
        case 8: return "Efsane"
        case 9: return "Şampiyon"
        case 10: return "Gezegen Koruyucu"
        default: return "Başlangıç"
        }
    }
    
    var nextLevelPoints: Int {
        switch currentLevel {
        case 1: return 200
        case 2: return 500
        case 3: return 1000
        case 4: return 1500
        case 5: return 2000
        case 6: return 2500
        case 7: return 3000
        case 8: return 4000
        case 9: return 5000
        default: return 5000
        }
    }
    
    var progressToNextLevel: Double {
        let currentPoints = userStats.totalPoints
        let previousLevelPoints: Int
        
        switch currentLevel {
        case 1: previousLevelPoints = 0
        case 2: previousLevelPoints = 200
        case 3: previousLevelPoints = 500
        case 4: previousLevelPoints = 1000
        case 5: previousLevelPoints = 1500
        case 6: previousLevelPoints = 2000
        case 7: previousLevelPoints = 2500
        case 8: previousLevelPoints = 3000
        case 9: previousLevelPoints = 4000
        default: previousLevelPoints = 5000
        }
        
        let pointsInCurrentLevel = currentPoints - previousLevelPoints
        let pointsNeeded = nextLevelPoints - previousLevelPoints
        
        return min(Double(pointsInCurrentLevel) / Double(pointsNeeded), 1.0)
    }
    
    var unlockedCount: Int { unlockedBadges.count }
    var totalBadges: Int { allBadges.count }
    
    // MARK: - Load User Stats
    func loadUserStats() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let doc = try await db.collection("userStats").document(userId).getDocument()
            
            if let data = doc.data() {
                userStats = UserStats(
                    totalJourneys: data["totalJourneys"] as? Int ?? 0,
                    totalEmissionSaved: data["totalEmissionSaved"] as? Double ?? 0,
                    totalDistance: data["totalDistance"] as? Double ?? 0,
                    walkingDistance: data["walkingDistance"] as? Double ?? 0,
                    transitCount: data["transitCount"] as? Int ?? 0,
                    carCount: data["carCount"] as? Int ?? 0,
                    walkingCount: data["walkingCount"] as? Int ?? 0,
                    aiRecommendationUsed: data["aiRecommendationUsed"] as? Int ?? 0,
                    consecutiveDays: data["consecutiveDays"] as? Int ?? 0,
                    lastJourneyDate: (data["lastJourneyDate"] as? Timestamp)?.dateValue(),
                    totalPoints: data["totalPoints"] as? Int ?? 0,
                    unlockedBadgeIds: data["unlockedBadgeIds"] as? [String] ?? []
                )
            }
            
            updateBadgeStatuses()
            
        } catch {
            print("❌ UserStats yükleme hatası: \(error)")
        }
    }
    
    // MARK: - Save User Stats
    func saveUserStats() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        userStats.calculatePoints()
        
        let data: [String: Any] = [
            "totalJourneys": userStats.totalJourneys,
            "totalEmissionSaved": userStats.totalEmissionSaved,
            "totalDistance": userStats.totalDistance,
            "walkingDistance": userStats.walkingDistance,
            "transitCount": userStats.transitCount,
            "carCount": userStats.carCount,
            "walkingCount": userStats.walkingCount,
            "aiRecommendationUsed": userStats.aiRecommendationUsed,
            "consecutiveDays": userStats.consecutiveDays,
            "lastJourneyDate": userStats.lastJourneyDate as Any,
            "totalPoints": userStats.totalPoints,
            "unlockedBadgeIds": userStats.unlockedBadgeIds
        ]
        
        do {
            try await db.collection("userStats").document(userId).setData(data, merge: true)
            print("✅ UserStats kaydedildi")
        } catch {
            print("❌ UserStats kaydetme hatası: \(error)")
        }
    }
    
    // MARK: - Record Journey (Yolculuk kaydedildiğinde çağrılır)
    func recordJourney(mode: TransportMode, distanceKm: Double, emissionKg: Double, aiUsed: Bool) async {
        // İstatistikleri güncelle
        userStats.totalJourneys += 1
        userStats.totalDistance += distanceKm
        
        // Mod bazlı istatistikler
        switch mode {
        case .walking:
            userStats.walkingCount += 1
            userStats.walkingDistance += distanceKm
            // Yürüyüş sıfır emisyon, araba ile karşılaştırarak tasarruf hesapla
            let carEmission = distanceKm * 0.17 // Ortalama araba emisyonu
            userStats.totalEmissionSaved += carEmission
        case .transit:
            userStats.transitCount += 1
            // Toplu taşıma daha az emisyon, araba ile karşılaştır
            let carEmission = distanceKm * 0.17
            let saved = carEmission - emissionKg
            if saved > 0 {
                userStats.totalEmissionSaved += saved
            }
        case .car:
            userStats.carCount += 1
            // Araba kullanımında tasarruf yok
        }
        
        // AI kullanımı
        if aiUsed {
            userStats.aiRecommendationUsed += 1
        }
        
        // Ardışık gün hesaplama
        updateConsecutiveDays()
        
        // Puanları hesapla
        userStats.calculatePoints()
        
        // Firebase'e kaydet
        await saveUserStats()
        
        // Rozet kontrolü
        await checkAndUnlockBadges()
    }
    
    // MARK: - Update Consecutive Days
    private func updateConsecutiveDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = userStats.lastJourneyDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysDiff == 1 {
                // Ardışık gün
                userStats.consecutiveDays += 1
            } else if daysDiff > 1 {
                // Seri bozuldu
                userStats.consecutiveDays = 1
            }
            // daysDiff == 0 ise aynı gün, değişiklik yok
        } else {
            // İlk yolculuk
            userStats.consecutiveDays = 1
        }
        
        userStats.lastJourneyDate = Date()
    }
    
    // MARK: - Check and Unlock Badges
    func checkAndUnlockBadges() async {
        for badge in allBadges {
            if userStats.unlockedBadgeIds.contains(badge.id) {
                continue // Zaten açılmış
            }
            
            var shouldUnlock = false
            
            switch badge.requirement.type {
            case .totalJourneys:
                shouldUnlock = Double(userStats.totalJourneys) >= badge.requirement.value
            case .totalEmissionSaved:
                shouldUnlock = userStats.totalEmissionSaved >= badge.requirement.value
            case .consecutiveDays:
                shouldUnlock = Double(userStats.consecutiveDays) >= badge.requirement.value
            case .walkingDistance:
                shouldUnlock = userStats.walkingDistance >= badge.requirement.value
            case .transitCount:
                shouldUnlock = Double(userStats.transitCount) >= badge.requirement.value
            case .aiRecommendationUsed:
                shouldUnlock = Double(userStats.aiRecommendationUsed) >= badge.requirement.value
            case .totalDistance:
                shouldUnlock = userStats.totalDistance >= badge.requirement.value
            }
            
            if shouldUnlock {
                await unlockBadge(badge)
            }
        }
        
        updateBadgeStatuses()
    }
    
    // MARK: - Unlock Badge
    private func unlockBadge(_ badge: Badge) async {
        userStats.unlockedBadgeIds.append(badge.id)
        recentlyUnlocked = badge
        showBadgeUnlockedAlert = true
        
        // Bonus puan ekle
        userStats.totalPoints += badge.points
        
        // Firebase'e kaydet
        await saveUserStats()
        
        print("🏆 Rozet açıldı: \(badge.title) (+\(badge.points) puan)")
    }
    
    // MARK: - Update Badge Statuses
    private func updateBadgeStatuses() {
        allBadges = BadgeDefinitions.allBadges.map { badge in
            var updatedBadge = badge
            updatedBadge.isUnlocked = userStats.unlockedBadgeIds.contains(badge.id)
            return updatedBadge
        }
        
        unlockedBadges = allBadges.filter { $0.isUnlocked }
    }
    
    // MARK: - Get Progress for Badge
    func getProgress(for badge: Badge) -> Double {
        let currentValue: Double
        
        switch badge.requirement.type {
        case .totalJourneys:
            currentValue = Double(userStats.totalJourneys)
        case .totalEmissionSaved:
            currentValue = userStats.totalEmissionSaved
        case .consecutiveDays:
            currentValue = Double(userStats.consecutiveDays)
        case .walkingDistance:
            currentValue = userStats.walkingDistance
        case .transitCount:
            currentValue = Double(userStats.transitCount)
        case .aiRecommendationUsed:
            currentValue = Double(userStats.aiRecommendationUsed)
        case .totalDistance:
            currentValue = userStats.totalDistance
        }
        
        return min(currentValue / badge.requirement.value, 1.0)
    }
}
