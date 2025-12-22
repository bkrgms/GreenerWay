import Foundation

// MARK: - Badge Model
struct Badge: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: BadgeCategory
    let requirement: BadgeRequirement
    let points: Int
    var isUnlocked: Bool = false
    var unlockedDate: Date?
    
    enum BadgeCategory: String, Codable, CaseIterable {
        case journey = "journey"        // Yolculuk sayısı
        case emission = "emission"      // CO₂ tasarrufu
        case streak = "streak"          // Ardışık günler
        case mode = "mode"              // Ulaşım modu
        case special = "special"        // Özel başarılar
        
        var displayName: String {
            switch self {
            case .journey: return "Yolculuk"
            case .emission: return "Çevre"
            case .streak: return "Seri"
            case .mode: return "Ulaşım"
            case .special: return "Özel"
            }
        }
        
        var color: String {
            switch self {
            case .journey: return "blue"
            case .emission: return "green"
            case .streak: return "orange"
            case .mode: return "purple"
            case .special: return "yellow"
            }
        }
    }
    
    struct BadgeRequirement: Codable, Equatable {
        let type: RequirementType
        let value: Double
        
        enum RequirementType: String, Codable {
            case totalJourneys = "totalJourneys"
            case totalEmissionSaved = "totalEmissionSaved"
            case consecutiveDays = "consecutiveDays"
            case walkingDistance = "walkingDistance"
            case transitCount = "transitCount"
            case aiRecommendationUsed = "aiRecommendationUsed"
            case totalDistance = "totalDistance"
        }
    }
}

// MARK: - User Stats Model (Firebase'e kaydedilecek)
struct UserStats: Codable {
    var totalJourneys: Int = 0
    var totalEmissionSaved: Double = 0.0 // kg CO₂
    var totalDistance: Double = 0.0 // km
    var walkingDistance: Double = 0.0 // km
    var transitCount: Int = 0
    var carCount: Int = 0
    var walkingCount: Int = 0
    var aiRecommendationUsed: Int = 0
    var consecutiveDays: Int = 0
    var lastJourneyDate: Date?
    var totalPoints: Int = 0
    var unlockedBadgeIds: [String] = []
    
    // Puan hesaplama
    mutating func calculatePoints() {
        var points = 0
        points += totalJourneys * 10 // Her yolculuk 10 puan
        points += Int(totalEmissionSaved * 100) // Her kg CO₂ 100 puan
        points += Int(walkingDistance * 5) // Her km yürüyüş 5 puan
        points += transitCount * 15 // Her toplu taşıma 15 puan
        points += aiRecommendationUsed * 20 // Her AI kullanımı 20 puan
        points += consecutiveDays * 50 // Her ardışık gün 50 puan
        totalPoints = points
    }
}

// MARK: - Badge Definitions
struct BadgeDefinitions {
    static let allBadges: [Badge] = [
        // 🚶 Yolculuk Rozetleri
        Badge(
            id: "first_journey",
            title: "İlk Adım",
            description: "İlk yolculuğunu tamamla",
            icon: "figure.walk",
            category: .journey,
            requirement: .init(type: .totalJourneys, value: 1),
            points: 50
        ),
        Badge(
            id: "journey_10",
            title: "Yolcu",
            description: "10 yolculuk tamamla",
            icon: "map.fill",
            category: .journey,
            requirement: .init(type: .totalJourneys, value: 10),
            points: 100
        ),
        Badge(
            id: "journey_50",
            title: "Gezgin",
            description: "50 yolculuk tamamla",
            icon: "globe.europe.africa.fill",
            category: .journey,
            requirement: .init(type: .totalJourneys, value: 50),
            points: 250
        ),
        Badge(
            id: "journey_100",
            title: "Kaşif",
            description: "100 yolculuk tamamla",
            icon: "star.fill",
            category: .journey,
            requirement: .init(type: .totalJourneys, value: 100),
            points: 500
        ),
        
        // 🌿 Çevre Rozetleri
        Badge(
            id: "eco_starter",
            title: "Yeşil Başlangıç",
            description: "1 kg CO₂ tasarrufu yap",
            icon: "leaf.fill",
            category: .emission,
            requirement: .init(type: .totalEmissionSaved, value: 1),
            points: 50
        ),
        Badge(
            id: "eco_saver",
            title: "Çevre Dostu",
            description: "10 kg CO₂ tasarrufu yap",
            icon: "leaf.circle.fill",
            category: .emission,
            requirement: .init(type: .totalEmissionSaved, value: 10),
            points: 150
        ),
        Badge(
            id: "eco_hero",
            title: "Eko Kahraman",
            description: "50 kg CO₂ tasarrufu yap",
            icon: "tree.fill",
            category: .emission,
            requirement: .init(type: .totalEmissionSaved, value: 50),
            points: 300
        ),
        Badge(
            id: "eco_legend",
            title: "Gezegen Koruyucu",
            description: "100 kg CO₂ tasarrufu yap",
            icon: "globe.americas.fill",
            category: .emission,
            requirement: .init(type: .totalEmissionSaved, value: 100),
            points: 500
        ),
        
        // 🔥 Seri Rozetleri
        Badge(
            id: "streak_3",
            title: "Üç Gün Serisi",
            description: "3 gün üst üste yolculuk yap",
            icon: "flame.fill",
            category: .streak,
            requirement: .init(type: .consecutiveDays, value: 3),
            points: 75
        ),
        Badge(
            id: "streak_7",
            title: "Haftalık Seri",
            description: "7 gün üst üste yolculuk yap",
            icon: "flame.circle.fill",
            category: .streak,
            requirement: .init(type: .consecutiveDays, value: 7),
            points: 150
        ),
        Badge(
            id: "streak_30",
            title: "Aylık Seri",
            description: "30 gün üst üste yolculuk yap",
            icon: "bolt.fill",
            category: .streak,
            requirement: .init(type: .consecutiveDays, value: 30),
            points: 500
        ),
        
        // 🚶 Yürüyüş Rozetleri
        Badge(
            id: "walker_5km",
            title: "Yürüyüşçü",
            description: "Toplam 5 km yürü",
            icon: "figure.walk.circle.fill",
            category: .mode,
            requirement: .init(type: .walkingDistance, value: 5),
            points: 100
        ),
        Badge(
            id: "walker_25km",
            title: "Yürüyüş Ustası",
            description: "Toplam 25 km yürü",
            icon: "figure.walk.diamond.fill",
            category: .mode,
            requirement: .init(type: .walkingDistance, value: 25),
            points: 250
        ),
        Badge(
            id: "walker_100km",
            title: "Maraton Kahramanı",
            description: "Toplam 100 km yürü",
            icon: "trophy.fill",
            category: .mode,
            requirement: .init(type: .walkingDistance, value: 100),
            points: 500
        ),
        
        // 🚌 Toplu Taşıma Rozetleri
        Badge(
            id: "transit_5",
            title: "Toplu Taşıma Dostu",
            description: "5 kez toplu taşıma kullan",
            icon: "bus.fill",
            category: .mode,
            requirement: .init(type: .transitCount, value: 5),
            points: 75
        ),
        Badge(
            id: "transit_25",
            title: "Toplu Taşıma Uzmanı",
            description: "25 kez toplu taşıma kullan",
            icon: "tram.fill",
            category: .mode,
            requirement: .init(type: .transitCount, value: 25),
            points: 200
        ),
        
        // 🤖 AI Rozetleri
        Badge(
            id: "ai_user_5",
            title: "Akıllı Seçim",
            description: "5 kez AI önerisini kullan",
            icon: "brain.fill",
            category: .special,
            requirement: .init(type: .aiRecommendationUsed, value: 5),
            points: 100
        ),
        Badge(
            id: "ai_user_25",
            title: "AI Uzmanı",
            description: "25 kez AI önerisini kullan",
            icon: "cpu.fill",
            category: .special,
            requirement: .init(type: .aiRecommendationUsed, value: 25),
            points: 250
        ),
        
        // 📏 Mesafe Rozetleri
        Badge(
            id: "distance_50",
            title: "Yol Arkadaşı",
            description: "Toplam 50 km yol kat et",
            icon: "road.lanes",
            category: .journey,
            requirement: .init(type: .totalDistance, value: 50),
            points: 150
        ),
        Badge(
            id: "distance_250",
            title: "Uzun Yolcu",
            description: "Toplam 250 km yol kat et",
            icon: "car.rear.road.lane",
            category: .journey,
            requirement: .init(type: .totalDistance, value: 250),
            points: 350
        ),
    ]
    
    static func getBadge(by id: String) -> Badge? {
        allBadges.first { $0.id == id }
    }
    
    static func getBadges(by category: Badge.BadgeCategory) -> [Badge] {
        allBadges.filter { $0.category == category }
    }
}
