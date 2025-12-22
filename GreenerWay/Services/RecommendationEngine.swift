import Foundation

// Basitleştirilmiş öneri motoru
// Not: Ana öneri mantığı RouteDetailView içinde computeAIRecommendation() fonksiyonunda
struct RecommendationEngine {
    
    /// Basit mod önerisi
    func recommend(weather: WeatherInfo?,
                   distanceKm: Double,
                   profile: UserProfile?) -> TransportMode {
        
        var scores: [TransportMode: Double] = [
            .car: 0,
            .walking: 0,
            .transit: 0
        ]
        
        // Hava durumu
        if let w = weather {
            switch w.condition {
            case .rain, .snow:
                scores[.car]! += 2
                scores[.transit]! += 1
            case .clear:
                scores[.walking]! += 1
            default:
                break
            }
        }
        
        // Mesafe bazlı
        if distanceKm < 2.0 {
            scores[.walking]! += 3
        } else if distanceKm < 8.0 {
            scores[.transit]! += 2
            scores[.walking]! += 1
        } else {
            scores[.car]! += 2
            scores[.transit]! += 1
        }
        
        // Profil bazlı
        if let p = profile {
            if p.travellingWithChild {
                scores[.car]! += 1
                scores[.walking]! -= 1
            }
            if p.carbonSensitivity >= 0.7 {
                scores[.walking]! += 1
                scores[.transit]! += 1
            }
        }
        
        return scores.max(by: { $0.value < $1.value })?.key ?? .car
    }
}
